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

if (!function_exists('lpco_dms_get_api_cache_versions')) {
function lpco_dms_get_api_cache_versions() {
    $versions = wp_cache_get('api_cache_versions', 'dms_api');
    if ($versions === false) {
        $versions = get_option('lpco_dms_api_cache_versions', array());
        if (!is_array($versions)) {
            $versions = array();
        }
        wp_cache_set('api_cache_versions', $versions, 'dms_api', 300);
    }
    return $versions;
}
}

if (!function_exists('lpco_dms_set_api_cache_versions')) {
function lpco_dms_set_api_cache_versions($versions) {
    if (!is_array($versions)) {
        $versions = array();
    }
    update_option('lpco_dms_api_cache_versions', $versions, false);
    wp_cache_set('api_cache_versions', $versions, 'dms_api', 300);
}
}

if (!function_exists('lpco_dms_api_cache_version')) {
function lpco_dms_api_cache_version($bucket = 'catalog') {
    $bucket = sanitize_key((string) $bucket);
    $versions = lpco_dms_get_api_cache_versions();
    $version = isset($versions[$bucket]) ? (int) $versions[$bucket] : 1;
    return max(1, $version);
}
}

if (!function_exists('lpco_dms_bump_api_cache_version')) {
function lpco_dms_bump_api_cache_version($bucket = 'catalog') {
    $bucket = sanitize_key((string) $bucket);
    $versions = lpco_dms_get_api_cache_versions();
    $versions[$bucket] = lpco_dms_api_cache_version($bucket) + 1;
    lpco_dms_set_api_cache_versions($versions);
    return $versions[$bucket];
}
}

if (!function_exists('lpco_dms_build_api_cache_key')) {
function lpco_dms_build_api_cache_key($prefix, $request, $scope = 'guest', $bucket = 'catalog') {
    if (!($request instanceof WP_REST_Request)) {
        return '';
    }

    $params = $request->get_params();
    if (!is_array($params)) {
        $params = array();
    }

    unset($params['token'], $params['jwt'], $params['authorization'], $params['access_token']);
    unset($params['_t'], $params['_'], $params['cache_buster'], $params['_cache_buster'], $params['timestamp']);

    $layout_rev = lpco_dms_layout_cache_version_for_prefix($prefix);
    if ($layout_rev !== '') {
        $params['_layout_rev'] = $layout_rev;
    }

    ksort($params);
    $bucket = sanitize_key((string) $bucket);
    $scope = sanitize_key((string) $scope);

    return sprintf(
        'lpco_dms_%s_v%d_%s_%s',
        $bucket,
        lpco_dms_api_cache_version($bucket),
        sanitize_key((string) $prefix),
        $scope . '_' . md5(wp_json_encode($params))
    );
}
}

/**
 * Cache Helpers
 */
if (!function_exists('lpco_dms_guest_cache_key')) {
function lpco_dms_guest_cache_key($prefix, $request) {
    return lpco_dms_build_api_cache_key($prefix, $request, 'guest', 'catalog');
}
}

if (!function_exists('lpco_dms_guest_cache_get')) {
function lpco_dms_guest_cache_get($key) {
    return lpco_dms_api_cache_get($key);
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
    $scope = sprintf(
        'user_%d_%s_%s',
        absint($user_id),
        sanitize_key((string) $group),
        sanitize_key((string) $currency)
    );

    return lpco_dms_build_api_cache_key($prefix, $request, $scope, 'catalog');
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
    if (!$key) {
        return false;
    }

    $cached = wp_cache_get($key, 'dms_api');
    if ($cached !== false) {
        return $cached;
    }

    return get_transient($key);
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

if (!function_exists('lpco_dms_catalog_revision')) {
function lpco_dms_catalog_revision() {
    $revision = get_option('lpco_dms_catalog_revision', 0);
    $revision = is_numeric($revision) ? (int) $revision : 0;
    if ($revision <= 0) {
        $revision = function_exists('current_time') ? (int) current_time('timestamp', true) : time();
        update_option('lpco_dms_catalog_revision', $revision, false);
    }
    return $revision;
}
}

if (!function_exists('lpco_dms_debug_log')) {
function lpco_dms_debug_log($message, $context = array()) {
    if (!defined('DMS_ECOM_DEBUG') || !DMS_ECOM_DEBUG) {
        return;
    }

    if (function_exists('dms_ecom_log')) {
        dms_ecom_log($message, 'debug', is_array($context) ? $context : array());
        return;
    }

    if (defined('WP_DEBUG') && WP_DEBUG) {
        error_log('[LPCO DMS] ' . $message . ' ' . wp_json_encode($context));
    }
}
}

if (!function_exists('lpco_dms_delete_catalog_transients')) {
function lpco_dms_delete_catalog_transients() {
    global $wpdb;
    if (!isset($wpdb) || !is_object($wpdb)) {
        return;
    }

    $patterns = array(
        '\_transient\_lpco\_dms\_catalog\_%',
        '\_transient\_timeout\_lpco\_dms\_catalog\_%',
        '\_transient\_lpco\_dms\_guest\_%',
        '\_transient\_timeout\_lpco\_dms\_guest\_%',
        '\_transient\_lpco\_dms\_auth\_%',
        '\_transient\_timeout\_lpco\_dms\_auth\_%',
    );

    $where = array();
    foreach ($patterns as $pattern) {
        $where[] = $wpdb->prepare('option_name LIKE %s', $pattern);
    }

    if (!empty($where)) {
        $wpdb->query('DELETE FROM ' . $wpdb->options . ' WHERE ' . implode(' OR ', $where));
    }
}
}

if (!function_exists('lpco_dms_clear_catalog_cache')) {
function lpco_dms_clear_catalog_cache($reason = '', $product_id = 0) {
    if (!empty($GLOBALS['lpco_dms_suspend_catalog_cache_flush'])) {
        $GLOBALS['lpco_dms_deferred_catalog_cache_flush'] = array(
            'reason' => (string) $reason,
            'product_id' => absint($product_id),
        );
        return lpco_dms_catalog_revision();
    }

    $product_id = absint($product_id);
    $current = lpco_dms_catalog_revision();
    $now = function_exists('current_time') ? (int) current_time('timestamp', true) : time();
    $next = max($current + 1, $now);

    update_option('lpco_dms_catalog_revision', $next, false);
    update_option('lpco_dms_products_updated_at', gmdate('Y-m-d H:i:s'), false);
    lpco_dms_bump_api_cache_version('catalog');
    wp_cache_delete('api_cache_versions', 'dms_api');
    lpco_dms_delete_catalog_transients();

    if (function_exists('wc_delete_product_transients')) {
        wc_delete_product_transients($product_id > 0 ? $product_id : 0);
    }
    if ($product_id > 0 && function_exists('clean_post_cache')) {
        clean_post_cache($product_id);
    }

    lpco_dms_debug_log('Catalog cache cleared', array(
        'reason' => (string) $reason,
        'product_id' => $product_id,
        'catalog_revision' => $next,
    ));

    return $next;
}
}

if (!function_exists('lpco_dms_flush_catalog_api_cache')) {
function lpco_dms_flush_catalog_api_cache($reason = 'legacy_flush') {
    return lpco_dms_clear_catalog_cache($reason, 0);
}
}

if (!function_exists('lpco_dms_product_id_from_mixed')) {
function lpco_dms_product_id_from_mixed($product_or_id) {
    if (is_object($product_or_id) && method_exists($product_or_id, 'get_id')) {
        return absint($product_or_id->get_id());
    }
    return absint($product_or_id);
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_product')) {
function lpco_dms_clear_catalog_cache_for_product($product_or_id = 0, $reason = 'product_changed') {
    $post_id = lpco_dms_product_id_from_mixed($product_or_id);
    if ($post_id <= 0 || get_post_type($post_id) !== 'product') {
        return;
    }
    lpco_dms_clear_catalog_cache($reason, $post_id);
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_post')) {
function lpco_dms_clear_catalog_cache_for_post($post_id) {
    lpco_dms_clear_catalog_cache_for_product($post_id, current_filter());
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_post_meta')) {
function lpco_dms_clear_catalog_cache_for_post_meta($meta_id, $post_id, $meta_key = '') {
    $post_id = absint($post_id);
    if ($post_id <= 0 || get_post_type($post_id) !== 'product') {
        return;
    }

    $watched_meta_keys = array(
        '_dms_prices',
        '_custom_product_order',
        '_stock_status',
        '_stock',
        '_manage_stock',
        '_thumbnail_id',
        '_product_image_gallery',
        '_featured',
        '_price',
        '_regular_price',
        '_sale_price',
        '_sku',
        '_barcode_1',
        '_barcode_2',
        '_barcode_3',
        '_barcode_4',
    );

    if ($meta_key !== '' && !in_array((string) $meta_key, $watched_meta_keys, true)) {
        return;
    }

    lpco_dms_clear_catalog_cache('product_meta_' . (string) $meta_key, $post_id);
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_status_transition')) {
function lpco_dms_clear_catalog_cache_for_status_transition($new_status, $old_status, $post) {
    if (!($post instanceof WP_Post) || $post->post_type !== 'product' || $new_status === $old_status) {
        return;
    }
    lpco_dms_clear_catalog_cache('product_status_' . $old_status . '_to_' . $new_status, $post->ID);
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_terms')) {
function lpco_dms_clear_catalog_cache_for_terms($object_id = 0, $terms = null, $tt_ids = null, $taxonomy = '', ...$unused) {
    $taxonomy = sanitize_key((string) $taxonomy);
    if ($taxonomy !== '' && !in_array($taxonomy, array('product_cat', 'product_brand', 'product_tag'), true)) {
        return;
    }

    $product_id = absint($object_id);
    if ($product_id > 0 && get_post_type($product_id) !== 'product') {
        $product_id = 0;
    }

    lpco_dms_clear_catalog_cache('terms_' . ($taxonomy ?: current_filter()), $product_id);
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_stock')) {
function lpco_dms_clear_catalog_cache_for_stock($product_or_id = 0, ...$args) {
    lpco_dms_clear_catalog_cache_for_product($product_or_id, current_filter());
}
}

if (!function_exists('lpco_dms_clear_catalog_cache_for_taxonomy')) {
function lpco_dms_clear_catalog_cache_for_taxonomy(...$args) {
    lpco_dms_clear_catalog_cache(current_filter(), 0);
}
}

add_action('woocommerce_update_product', 'lpco_dms_clear_catalog_cache_for_stock', 20, 1);
add_action('woocommerce_new_product', 'lpco_dms_clear_catalog_cache_for_stock', 20, 1);
add_action('woocommerce_delete_product', 'lpco_dms_clear_catalog_cache_for_stock', 20, 1);
add_action('before_delete_post', 'lpco_dms_clear_catalog_cache_for_post', 20, 1);
add_action('deleted_post', 'lpco_dms_clear_catalog_cache_for_post', 20, 1);
add_action('trashed_post', 'lpco_dms_clear_catalog_cache_for_post', 20, 1);
add_action('untrashed_post', 'lpco_dms_clear_catalog_cache_for_post', 20, 1);
add_action('save_post_product', 'lpco_dms_clear_catalog_cache_for_post', 30, 1);
add_action('transition_post_status', 'lpco_dms_clear_catalog_cache_for_status_transition', 20, 3);
add_action('added_post_meta', 'lpco_dms_clear_catalog_cache_for_post_meta', 20, 4);
add_action('updated_post_meta', 'lpco_dms_clear_catalog_cache_for_post_meta', 20, 4);
add_action('deleted_post_meta', 'lpco_dms_clear_catalog_cache_for_post_meta', 20, 4);
add_action('set_object_terms', 'lpco_dms_clear_catalog_cache_for_terms', 20, 6);
add_action('edited_product_cat', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('created_product_cat', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('delete_product_cat', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('edited_product_brand', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('created_product_brand', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('delete_product_brand', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('edited_product_tag', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('created_product_tag', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('delete_product_tag', 'lpco_dms_clear_catalog_cache_for_taxonomy', 20, 1);
add_action('woocommerce_product_set_stock', 'lpco_dms_clear_catalog_cache_for_stock', 20, 1);
add_action('woocommerce_variation_set_stock', 'lpco_dms_clear_catalog_cache_for_stock', 20, 1);
add_action('woocommerce_product_set_stock_status', 'lpco_dms_clear_catalog_cache_for_stock', 20, 3);
add_action('woocommerce_variation_set_stock_status', 'lpco_dms_clear_catalog_cache_for_stock', 20, 3);

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
    header('Content-Type: application/json; charset=UTF-8');
    header('X-Content-Type-Options: nosniff');
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
