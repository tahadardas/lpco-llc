<?php
/**
 * Custom REST API Endpoints for DMS Mobile App
 * نقاط نهاية API مخصصة لتطبيق DMS للموبايل
 */

/**
 * قراءة ترويسة Authorization بصيغة Bearer
 */
if (!function_exists('dms_get_auth_header')) {
function dms_get_auth_header() {
    $auth_header = '';
    
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth_header = trim($_SERVER['HTTP_AUTHORIZATION']);
    } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth_header = trim($_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
    } elseif (function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        if (isset($headers['Authorization'])) {
            $auth_header = trim($headers['Authorization']);
        }
    }
    
    return $auth_header;
}
}

/**
 * فك ترميز base64url
 */
if (!function_exists('dms_base64url_decode')) {
function dms_base64url_decode($data) {
    if (!is_string($data)) return '';
    $remainder = strlen($data) % 4;
    if ($remainder) {
        $padlen = 4 - $remainder;
        $data .= str_repeat('=', $padlen);
    }
    return base64_decode(strtr($data, '-_', '+/'));
}
}

/**
 * Structured debug logging gated behind DMS_ECOM_DEBUG
 */
if (!function_exists('dms_ecom_log')) {
function dms_ecom_log($message, $level = 'info', $context = array()) {
    if (!defined('DMS_ECOM_DEBUG') || DMS_ECOM_DEBUG !== true) {
        if ($level !== 'error') {
            return;
        }
    }
    
    if (!empty($context) && is_array($context)) {
        $message .= ' | ' . wp_json_encode($context);
    }
    
    error_log(sprintf('DMS-Ecom [%s] %s', strtoupper($level), $message));
}
}

/**
 * Send an admin email notification safely with optional attachments.
 */
if (!function_exists('dms_ecom_send_admin_email')) {
function dms_ecom_send_admin_email($subject, $message, $attachments = array(), $headers = array()) {
    $admin_emails_raw = get_option('dms_notification_emails', '');
    if (!empty($admin_emails_raw)) {
        $admin_emails = array_filter(array_map('trim', explode(',', $admin_emails_raw)), 'is_email');
    } else {
        $admin_emails = array(get_option('admin_email'));
    }

    if (empty($admin_emails)) {
        return false;
    }

    $normalized_headers = array();
    if (is_array($headers)) {
        foreach ($headers as $header) {
            if (is_scalar($header)) $normalized_headers[] = trim((string) $header);
        }
    }

    $normalized_attachments = array();
    foreach ((array) $attachments as $attachment) {
        if (is_string($attachment) && file_exists($attachment)) {
            $normalized_attachments[] = $attachment;
        }
    }

    return wp_mail($admin_emails, $subject, $message, $normalized_headers, $normalized_attachments);
}
}

// ============================================================================
// INCLUDES
// ============================================================================
require_once dirname(__FILE__) . '/api/contracts.php';
require_once dirname(__FILE__) . '/api/utils.php';
require_once dirname(__FILE__) . '/api/security-helpers.php';
require_once dirname(__FILE__) . '/api/catalog-logic.php';
require_once dirname(__FILE__) . '/api/order-logic.php';
require_once dirname(__FILE__) . '/api/user-logic.php';

// ============================================================================
// ROUTE REGISTRATION
// ============================================================================

add_action('rest_api_init', function () {
    $namespace = 'dms/v1';

    // Catalog Routes
    register_rest_route($namespace, '/products', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_products_with_prices',
        'permission_callback' => 'lpco_dms_verify_app_token_or_guest',
    ));

    register_rest_route($namespace, '/products-plus', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_products_plus',
        'permission_callback' => 'lpco_dms_verify_app_token_or_guest',
    ));

    register_rest_route($namespace, '/public/products', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_products_guest',
        'permission_callback' => '__return_true',
    ));

    register_rest_route($namespace, '/categories', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_categories_auth',
        'permission_callback' => 'lpco_dms_verify_app_token_or_guest',
    ));

    register_rest_route($namespace, '/public/categories', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_categories_guest',
        'permission_callback' => '__return_true',
    ));

    register_rest_route($namespace, '/home-by-category', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_home_by_category',
        'permission_callback' => 'lpco_dms_verify_app_token_or_guest',
    ));

    register_rest_route($namespace, '/brands', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_brands_auth',
        'permission_callback' => 'lpco_dms_verify_app_token_or_guest',
    ));

    register_rest_route($namespace, '/public/brands', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_brands_guest',
        'permission_callback' => '__return_true',
    ));

    // Order Routes
    register_rest_route($namespace, '/orders', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_user_orders',
        'permission_callback' => 'lpco_dms_verify_app_token_auth',
        'args'                => array(
            'user_id' => array(
                'required' => true,
                'validate_callback' => function($param) { return is_numeric($param); }
            ),
        ),
    ));

    register_rest_route($namespace, '/orders', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => 'dms_create_order',
        'permission_callback' => 'lpco_dms_verify_app_token_auth',
    ));

    register_rest_route($namespace, '/orders/(?P<id>\d+)/sham-cash-confirm', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => 'dms_confirm_sham_cash_transfer',
        'permission_callback' => 'lpco_dms_verify_app_token_auth',
    ));

    // User Profile Routes
    register_rest_route($namespace, '/users/(?P<id>\d+)', array(
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => 'dms_get_user_with_meta',
        'permission_callback' => 'dms_permission_jwt',
    ));

    register_rest_route($namespace, '/users/(?P<id>\d+)', array(
        'methods'             => WP_REST_Server::EDITABLE,
        'callback'            => 'dms_update_user_profile',
        'permission_callback' => 'dms_permission_jwt',
    ));

    // Registration & Job Routes
    register_rest_route($namespace, '/register', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => 'dms_register_user',
        'permission_callback' => '__return_true',
    ));

    register_rest_route($namespace, '/jobs/apply', array(
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => 'dms_submit_job_application',
        'permission_callback' => '__return_true',
    ));
});

add_action('wp_mail_failed', function ($error) {
    if (!$error instanceof WP_Error) return;
    dms_ecom_log('wp_mail_failed', 'error', array('message' => $error->get_error_message()));
});

/**
 * Shared Caching & Rate Limiting Helpers
 */
if (!function_exists('dms_ecom_get_client_ip')) {
function dms_ecom_get_client_ip() {
    $ip_keys = array('HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR');
    foreach ($ip_keys as $key) {
        if (!empty($_SERVER[$key])) {
            $raw = explode(',', $_SERVER[$key]);
            return sanitize_text_field(trim($raw[0]));
        }
    }
    return '';
}
}

if (!function_exists('dms_ecom_rate_limit')) {
function dms_ecom_rate_limit($action, $ip, $limit = 5, $window = 600) {
    if (empty($ip)) return true;
    $key = 'dms_rate_' . $action . '_' . md5($ip);
    $cache_group = 'dms_api_rate_limit';
    $bucket = wp_cache_get($key, $cache_group) ?: get_transient($key);
    
    if (!$bucket || !is_array($bucket)) {
        $bucket = array('count' => 0, 'start' => time());
    }
    
    $elapsed = time() - intval($bucket['start']);
    if ($elapsed >= $window) {
        $bucket = array('count' => 0, 'start' => time());
    }
    
    if ($bucket['count'] >= $limit) {
        return new WP_Error('rate_limited', 'Too many requests, please try again later.', array('status' => 429));
    }
    
    $bucket['count']++;
    $ttl = max($window - $elapsed, 1);
    wp_cache_set($key, $bucket, $cache_group, $ttl);
    set_transient($key, $bucket, $ttl);
    return true;
}
}

/**
 * Captcha validation helper.
 */
if (!function_exists('dms_ecom_validate_captcha_if_required')) {
function dms_ecom_validate_captcha_if_required($token, $ip) {
    // Shared captcha logic placeholder - can be implemented as needed
    return true;
}
}

/**
 * Admin HTML Mail Helpers
 */
if (!function_exists('dms_ecom_admin_html_mail_headers')) {
function dms_ecom_admin_html_mail_headers() {
    return array('Content-Type: text/html; charset=UTF-8');
}
}

if (!function_exists('dms_ecom_order_email_card_row')) {
function dms_ecom_order_email_card_row($label, $value) {
    $text = trim((string) $value) ?: '-';
    return '<tr><td style="padding:12px 14px 4px;color:#7a1f1f;font-size:14px;font-weight:700;">' . esc_html($label) . '</td></tr>'
         . '<tr><td style="padding:0 14px 12px;border-bottom:1px solid #f1d9d9;color:#202124;font-size:16px;line-height:1.8;">' . nl2br(esc_html($text)) . '</td></tr>';
}
}
