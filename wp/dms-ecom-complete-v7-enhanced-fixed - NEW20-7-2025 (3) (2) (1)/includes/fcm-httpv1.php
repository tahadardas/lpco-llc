<?php
/**
 * Firebase Cloud Messaging HTTP v1 helper (Service Account based)
 *
 * - Stores config in WP options (project id + service account JSON)
 * - Generates OAuth2 access tokens via JWT (RS256)
 * - Sends individual device messages and cleans invalid tokens
 *
 * Security: never expose service account JSON to the frontend.
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Bootstrap settings from local project files if options are empty.
 * This allows moving the downloaded Firebase files into WP settings without manual copy/paste.
 */
function dms_fcm_bootstrap_from_local_files() {
    static $bootstrapped = false;
    if ($bootstrapped) {
        return;
    }
    $bootstrapped = true;

    $project_set = get_option('dms_fcm_project_id', '');

    // Optional server-side bootstrap: allow admins to drop the JSON in uploads (never from the mobile app)
    $uploads = wp_upload_dir();
    $server_sa_path = trailingslashit($uploads['basedir']) . 'dms-fcm-service-account.json';
    if (file_exists($server_sa_path)) {
        $raw = file_get_contents($server_sa_path);
        $decoded = json_decode($raw, true);
        if (is_array($decoded) && !empty($decoded['client_email']) && !empty($decoded['private_key']) && !empty($decoded['token_uri'])) {
            update_option('dms_fcm_service_account_json', wp_json_encode($decoded), false);
            if (!empty($decoded['project_id'])) {
                update_option('dms_fcm_project_id', sanitize_text_field($decoded['project_id']), false);
                $project_set = $decoded['project_id'];
            }
        }
    }
}

/**
 * Option keys
 */
function dms_fcm_project_id() {
    dms_fcm_bootstrap_from_local_files();
    return get_option('dms_fcm_project_id', '');
}

function dms_fcm_default_icon() {
    return get_option('dms_fcm_default_icon', '');
}

function dms_fcm_default_channel() {
    return get_option('dms_fcm_default_channel', 'LPCO_Notifications');
}

function dms_fcm_service_account_raw() {
    dms_fcm_bootstrap_from_local_files();
    return get_option('dms_fcm_service_account_json', '');
}

function dms_fcm_service_account() {
    $raw = dms_fcm_service_account_raw();
    if (empty($raw)) {
        return null;
    }
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : null;
}

function dms_fcm_is_configured() {
    $project = dms_fcm_project_id();
    $sa = dms_fcm_service_account();
    return !empty($project) && !empty($sa['client_email']) && !empty($sa['private_key']) && !empty($sa['token_uri']);
}

/**
 * Base64 URL encoding helper
 */
function dms_fcm_base64url_encode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/**
 * Generate (or reuse cached) OAuth2 access token for FCM HTTP v1
 *
 * @return string|WP_Error
 */
function dms_fcm_get_access_token() {
    $cached = get_transient('dms_fcm_httpv1_access_token');
    if (!empty($cached)) {
        return $cached;
    }

    $sa = dms_fcm_service_account();
    if (!$sa || empty($sa['client_email']) || empty($sa['private_key']) || empty($sa['token_uri'])) {
        return new WP_Error('fcm_config_missing', 'FCM Service Account is not configured');
    }

    $now = time();
    $header = array('alg' => 'RS256', 'typ' => 'JWT');
    $claims = array(
        'iss' => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => $sa['token_uri'],
        'iat' => $now,
        'exp' => $now + 3600
    );

    $jwt = dms_fcm_base64url_encode(wp_json_encode($header)) . '.' . dms_fcm_base64url_encode(wp_json_encode($claims));
    $signature = '';
    $signed = openssl_sign($jwt, $signature, $sa['private_key'], 'sha256WithRSAEncryption');
    if (!$signed) {
        return new WP_Error('fcm_sign_error', 'Failed to sign JWT for FCM');
    }
    $assertion = $jwt . '.' . dms_fcm_base64url_encode($signature);

    $response = wp_remote_post($sa['token_uri'], array(
        'headers' => array('Content-Type' => 'application/x-www-form-urlencoded'),
        'body' => array(
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $assertion
        ),
        'timeout' => 20
    ));

    if (is_wp_error($response)) {
        return $response;
    }
    $code = wp_remote_retrieve_response_code($response);
    $body = json_decode(wp_remote_retrieve_body($response), true);
    if ($code !== 200 || empty($body['access_token'])) {
        return new WP_Error('fcm_token_error', 'Failed to obtain FCM access token', array('code' => $code, 'body' => $body));
    }

    $token = $body['access_token'];
    // Cache for 50 minutes to stay under 1 hour expiry
    set_transient('dms_fcm_httpv1_access_token', $token, 50 * MINUTE_IN_SECONDS);
    return $token;
}

/**
 * Send a message to a single device token via FCM HTTP v1
 *
 * @param string $token
 * @param string $title
 * @param string $body
 * @param array  $data
 * @param string|null $image
 * @return array|WP_Error
 */
function dms_fcm_send_message($token, $title, $body, $data = array(), $image = null) {
    if (empty($token)) {
        return new WP_Error('fcm_missing_token', 'Device token missing');
    }
    if (!dms_fcm_is_configured()) {
        return new WP_Error('fcm_not_configured', 'FCM HTTP v1 settings missing');
    }

    $project_id = dms_fcm_project_id();
    $access_token = dms_fcm_get_access_token();
    if (is_wp_error($access_token)) {
        return $access_token;
    }

    // Ensure data values are strings
    $safe_data = array();
    foreach ($data as $k => $v) {
        $safe_data[$k] = is_scalar($v) ? (string) $v : wp_json_encode($v);
    }

    $message = array(
        'token' => $token,
        'notification' => array(
            'title' => $title,
            'body' => $body,
        ),
        'data' => $safe_data,
        'android' => array(
            'priority' => 'HIGH',
            'notification' => array(
                'channel_id' => dms_fcm_default_channel(),
                'sound' => 'default'
            )
        ),
        'apns' => array(
            'payload' => array(
                'aps' => array(
                    'sound' => 'default',
                    // Badge will be set by client after fetching unread count; set 1 for compatibility
                    'badge' => 1
                )
            )
        )
    );

    if (!empty($image)) {
        $message['notification']['image'] = $image;
    }
    $icon = dms_fcm_default_icon();
    if (!empty($icon)) {
        $message['android']['notification']['icon'] = $icon;
    }

    $payload = array('message' => $message);
    $response = wp_remote_post("https://fcm.googleapis.com/v1/projects/{$project_id}/messages:send", array(
        'headers' => array(
            'Authorization' => 'Bearer ' . $access_token,
            'Content-Type' => 'application/json'
        ),
        'body' => wp_json_encode($payload),
        'timeout' => 20
    ));

    if (is_wp_error($response)) {
        return $response;
    }

    $code = wp_remote_retrieve_response_code($response);
    $body = json_decode(wp_remote_retrieve_body($response), true);

    if ($code === 200 && !empty($body['name'])) {
        return array('success' => true, 'name' => $body['name']);
    }

    // Handle invalid token errors to allow cleanup upstream
    $error_code = '';
    if (!empty($body['error']['status'])) {
        $error_code = strtoupper($body['error']['status']);
    } elseif (!empty($body['error']['message'])) {
        $error_code = strtoupper($body['error']['message']);
    }

    return new WP_Error('fcm_send_error', 'Failed to send via FCM', array(
        'http_code' => $code,
        'fcm_status' => $error_code,
        'body' => $body
    ));
}
