<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Check if the current request is a guest request.
 */
if (!function_exists('lpco_dms_is_guest_request')) {
function lpco_dms_is_guest_request($request) {
    if (!($request instanceof WP_REST_Request)) {
        return false;
    }
    $guest = $request->get_param('guest');
    $mode = $request->get_param('mode');
    if (is_string($mode) && strtolower($mode) === 'guest') {
        return true;
    }
    if ($guest === true || $guest === 1 || $guest === '1' || $guest === 'true' || $guest === 'guest') {
        return true;
    }
    return false;
}
}

/**
 * Allow guest or authenticated request.
 */
if (!function_exists('lpco_dms_allow_guest_or_auth')) {
function lpco_dms_allow_guest_or_auth($request) {
    if (lpco_dms_is_guest_request($request)) {
        return true;
    }
    return function_exists('dms_validate_jwt_request') ? dms_validate_jwt_request($request) : false;
}
}

/**
 * Verification for app tokens (Permissions Callbacks)
 */
if (!function_exists('lpco_dms_verify_app_token_or_guest')) {
    function lpco_dms_verify_app_token_or_guest(WP_REST_Request $request) {
        return lpco_dms_allow_guest_or_auth($request);
    }
}

if (!function_exists('lpco_dms_verify_app_token_auth')) {
    function lpco_dms_verify_app_token_auth(WP_REST_Request $request) {
        return function_exists('dms_validate_jwt_request') ? dms_validate_jwt_request($request) : false;
    }
}

if (!function_exists('lpco_dms_layout_cache_sensitive_prefixes')) {
function lpco_dms_layout_cache_sensitive_prefixes() {
    return array('brands', 'home_by_category');
}
}

if (!function_exists('lpco_dms_layout_cache_version_for_prefix')) {
function lpco_dms_layout_cache_version_for_prefix($prefix) {
    $prefix = is_string($prefix) ? sanitize_key($prefix) : '';
    if ($prefix === '' || !in_array($prefix, lpco_dms_layout_cache_sensitive_prefixes(), true)) {
        return '';
    }
    if (!function_exists('lpco_app_layout_config_get')) {
        return '';
    }

    $config = lpco_app_layout_config_get();
    return isset($config['updated_at']) ? sanitize_text_field((string) $config['updated_at']) : '';
}
}

/**
 * Cache Helpers
 */
if (!function_exists('lpco_dms_guest_cache_key')) {
function lpco_dms_guest_cache_key($prefix, $request) {
    if (!($request instanceof WP_REST_Request)) return '';
    $params = $request->get_params();
    unset($params['token'], $params['jwt']);
    $layout_rev = lpco_dms_layout_cache_version_for_prefix($prefix);
    if ($layout_rev !== '') {
        $params['_layout_rev'] = $layout_rev;
    }
    ksort($params);
    return 'lpco_dms_guest_' . sanitize_key($prefix) . '_' . md5(wp_json_encode($params));
}
}

if (!function_exists('lpco_dms_guest_cache_get')) {
function lpco_dms_guest_cache_get($key) {
    return $key ? (wp_cache_get($key, 'dms_api') ?: get_transient($key)) : false;
}
}

if (!function_exists('lpco_dms_guest_cache_set')) {
function lpco_dms_guest_cache_set($key, $value, $ttl = 300) {
    if ($key) {
        wp_cache_set($key, $value, 'dms_api', $ttl);
        set_transient($key, $value, $ttl);
    }
}
}

if (!function_exists('lpco_dms_auth_cache_key')) {
function lpco_dms_auth_cache_key($prefix, $request, $user_id, $group, $currency) {
    $params = $request instanceof WP_REST_Request ? $request->get_params() : array();
    $layout_rev = lpco_dms_layout_cache_version_for_prefix($prefix);
    if ($layout_rev !== '') {
        $params['_layout_rev'] = $layout_rev;
    }
    ksort($params);
    return 'lpco_dms_auth_' . absint($user_id) . '_' . sanitize_key($group) . '_' . sanitize_key($currency) . '_' . md5(wp_json_encode($params));
}
}

if (!function_exists('lpco_dms_auth_cache_get')) {
function lpco_dms_auth_cache_get($key) {
    return lpco_dms_api_cache_get($key);
}
}

if (!function_exists('lpco_dms_auth_cache_set')) {
function lpco_dms_auth_cache_set($key, $value) {
    lpco_dms_api_cache_set($key, $value, 120);
}
}

if (!function_exists('lpco_dms_api_cache_get')) {
function lpco_dms_api_cache_get($key) {
    return $key ? (wp_cache_get($key, 'dms_api') ?: get_transient($key)) : false;
}
}

if (!function_exists('lpco_dms_api_cache_set')) {
function lpco_dms_api_cache_set($key, $value, $ttl = 300) {
    if ($key) {
        wp_cache_set($key, $value, 'dms_api', $ttl);
        set_transient($key, $value, $ttl);
    }
}
}

/**
 * Generic Permission Callbacks
 */
if (!function_exists('dms_permission_guest_or_auth')) {
    function dms_permission_guest_or_auth(WP_REST_Request $request) {
        return lpco_dms_verify_app_token_or_guest($request);
    }
}

if (!function_exists('dms_permission_jwt')) {
    function dms_permission_jwt(WP_REST_Request $request) {
        return lpco_dms_verify_app_token_auth($request);
    }
}
if (!function_exists('dms_send_cache_headers')) {
function dms_send_cache_headers($etag_key, $last_modified = null) {
    if (headers_sent()) return;
    $etag = '"' . md5((string) $etag_key) . '"';
    header('Cache-Control: public, max-age=60, s-maxage=300');
    header('ETag: ' . $etag);
    if (!empty($last_modified)) {
        $timestamp = is_numeric($last_modified) ? intval($last_modified) : strtotime((string) $last_modified);
        if ($timestamp) header('Last-Modified: ' . gmdate('D, d M Y H:i:s', $timestamp) . ' GMT');
    }
    $if_none_match = isset($_SERVER['HTTP_IF_NONE_MATCH']) ? trim($_SERVER['HTTP_IF_NONE_MATCH']) : '';
    if ($if_none_match && $if_none_match === $etag) {
        status_header(304);
        exit;
    }
}
}

/**
 * Handle CORS for Flutter Web development.
 * Allows custom headers and preflight (OPTIONS) requests.
 */
add_filter('rest_allowed_cors_headers', function($headers) {
    if (!in_array('x-device-token', $headers)) {
        $headers[] = 'x-device-token';
    }
    if (!in_array('X-Device-Token', $headers)) {
        $headers[] = 'X-Device-Token';
    }
    return $headers;
});

add_filter('rest_pre_serve_request', function($served, $result, $request, $server) {
    $origin = get_http_origin();
    if ($origin) {
        header('Access-Control-Allow-Origin: ' . $origin);
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS, PUT, DELETE');
        header('Access-Control-Allow-Credentials: true');
    }
    return $served;
}, 10, 4);
