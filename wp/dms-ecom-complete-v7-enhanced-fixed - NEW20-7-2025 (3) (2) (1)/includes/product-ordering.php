<?php
/**
 * Product ordering helpers for DMS Ecom.
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!defined('DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT')) {
    define('DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT', 999999);
}

function dms_product_order_meta_query($order_meta_key = '_custom_product_order') {
    $order_meta_key = is_string($order_meta_key) && $order_meta_key !== ''
        ? sanitize_key($order_meta_key)
        : '_custom_product_order';

    return array(
        'relation' => 'OR',
        'dms_order_exists' => array(
            'key' => $order_meta_key,
            'compare' => 'EXISTS',
            'type' => 'NUMERIC',
        ),
        'dms_order_missing' => array(
            'key' => $order_meta_key,
            'compare' => 'NOT EXISTS',
        ),
    );
}

function dms_merge_product_order_meta_query($existing_meta_query, $order_meta_key = '_custom_product_order') {
    $order_query = dms_product_order_meta_query($order_meta_key);
    if (empty($existing_meta_query) || !is_array($existing_meta_query)) {
        return $order_query;
    }

    return array(
        'relation' => 'AND',
        $existing_meta_query,
        $order_query,
    );
}

function dms_apply_product_ordering_args($args, $order_meta_key = '_custom_product_order') {
    if (!is_array($args)) {
        $args = array();
    }

    unset($args['meta_key']);
    $args['meta_query'] = dms_merge_product_order_meta_query(
        isset($args['meta_query']) ? $args['meta_query'] : array(),
        $order_meta_key
    );
    $args['orderby'] = array(
        'dms_order_exists' => 'ASC',
        'date' => 'DESC',
        'ID' => 'DESC',
    );
    $args['dms_order_meta_key'] = $order_meta_key;
    unset($args['order']);

    return $args;
}

function dms_product_ordering_posts_clauses($clauses, $query) {
    $order_meta_key = $query instanceof WP_Query ? $query->get('dms_order_meta_key') : '';
    if (!is_string($order_meta_key) || $order_meta_key === '') {
        return $clauses;
    }

    $orderby = $query->get('orderby');
    $orderby_keys = is_array($orderby) ? array_keys($orderby) : array();
    if (($orderby_keys[0] ?? '') !== 'dms_order_exists') {
        return $clauses;
    }

    global $wpdb;
    if (!$wpdb || !isset($wpdb->postmeta, $wpdb->posts)) {
        return $clauses;
    }

    $alias = 'dms_app_order_pm';
    if (strpos($clauses['join'], " AS {$alias} ") === false) {
        $clauses['join'] .= $wpdb->prepare(
            " LEFT JOIN {$wpdb->postmeta} AS {$alias} ON ({$alias}.post_id = {$wpdb->posts}.ID AND {$alias}.meta_key = %s)",
            $order_meta_key
        );
    }

    $default_order = defined('DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT')
        ? intval(DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT)
        : 999999;

    $clauses['orderby'] = "CASE WHEN {$alias}.meta_value IS NULL OR {$alias}.meta_value = '' THEN {$default_order} ELSE CAST({$alias}.meta_value AS SIGNED) END ASC, {$wpdb->posts}.post_date DESC, {$wpdb->posts}.ID DESC";

    return $clauses;
}
add_filter('posts_clauses', 'dms_product_ordering_posts_clauses', 20, 2);

/**
 * Default app order for newly published products.
 *
 * Manual product order stays authoritative, but a product created from
 * WooCommerce without an explicit order must not disappear beyond the first
 * mobile page. A negative timestamp keeps newest uncurated products first
 * until the admin assigns a manual priority.
 *
 * @param int $product_id Product ID.
 * @return int
 */
function dms_new_product_order_value($product_id) {
    $product_id = absint($product_id);
    $created_gmt = $product_id > 0 ? get_post_field('post_date_gmt', $product_id) : '';
    $created_ts = $created_gmt ? strtotime($created_gmt) : 0;
    if (!$created_ts && $product_id > 0) {
        $created_local = get_post_field('post_date', $product_id);
        $created_ts = $created_local ? strtotime($created_local) : 0;
    }
    if (!$created_ts) {
        $created_ts = current_time('timestamp', true);
    }

    return 0 - absint($created_ts);
}

/**
 * Build common product query args with custom product order.
 *
 * @param array $extra_args Additional WP_Query args.
 * @return array
 */
function dms_build_ordered_product_query_args($extra_args = array()) {
    $defaults = array(
        'post_type' => 'product',
        'post_status' => 'publish',
    );

    $meta_query = array();
    if (!empty($extra_args['meta_query']) && is_array($extra_args['meta_query'])) {
        $meta_query = $extra_args['meta_query'];
        unset($extra_args['meta_query']);
    }

    if (!empty($extra_args['stock_status']) && $extra_args['stock_status'] !== 'all') {
        $meta_query['stock_status'] = array(
            'key' => '_stock_status',
            'value' => $extra_args['stock_status'],
            'compare' => '=',
        );
        unset($extra_args['stock_status']);
    }

    $args = array_merge($defaults, $extra_args);
    if (!empty($meta_query)) {
        $args['meta_query'] = $meta_query;
    }

    return dms_apply_product_ordering_args($args, '_custom_product_order');
}

/**
 * Clean product caches after order updates.
 *
 * @param int  $product_id Product ID.
 * @param bool $flush_api_cache Whether to invalidate catalog API cache.
 * @return void
 */
function dms_clean_product_cache($product_id, $flush_api_cache = true) {
    $product_id = absint($product_id);
    if ($product_id <= 0) {
        return;
    }

    clean_post_cache($product_id);
    if (function_exists('wc_delete_product_transients')) {
        wc_delete_product_transients($product_id);
    }
    if ($flush_api_cache && function_exists('lpco_dms_flush_catalog_api_cache')) {
        lpco_dms_flush_catalog_api_cache();
    }
}

/**
 * Normalize missing or empty custom order values.
 *
 * @return void
 */
function dms_normalize_missing_custom_order() {
    $query = new WP_Query(array(
        'post_type' => 'product',
        'post_status' => 'any',
        'fields' => 'ids',
        'posts_per_page' => -1,
        'meta_query' => array(
            'relation' => 'OR',
            array(
                'key' => '_custom_product_order',
                'compare' => 'NOT EXISTS',
            ),
            array(
                'key' => '_custom_product_order',
                'value' => '',
                'compare' => '=',
            ),
        ),
        'no_found_rows' => true,
    ));

    if (empty($query->posts)) {
        return;
    }

    $GLOBALS['lpco_dms_suspend_catalog_cache_flush'] = true;
    foreach ($query->posts as $product_id) {
        $priority = get_post_meta($product_id, '_custom_product_priority', true);
        $order_value = is_numeric($priority) ? intval($priority) : DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT;
        update_post_meta($product_id, '_custom_product_order', $order_value);
        dms_clean_product_cache($product_id, false);
    }
    unset($GLOBALS['lpco_dms_suspend_catalog_cache_flush'], $GLOBALS['lpco_dms_deferred_catalog_cache_flush']);

    if (function_exists('lpco_dms_flush_catalog_api_cache')) {
        lpco_dms_flush_catalog_api_cache();
    }
}

/**
 * Ensure custom order exists on product save.
 *
 * @param int     $post_id Post ID.
 * @param WP_Post $post Post object.
 * @param bool    $update Whether this is an existing post.
 * @return void
 */
function dms_ensure_custom_product_order_on_save($post_id, $post, $update) {
    if ($post->post_type !== 'product') {
        return;
    }
    if (wp_is_post_autosave($post_id) || wp_is_post_revision($post_id)) {
        return;
    }

    $current = get_post_meta($post_id, '_custom_product_order', true);
    if ($current === '' || $current === null) {
        $order_value = $update ? DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT : dms_new_product_order_value($post_id);
        update_post_meta($post_id, '_custom_product_order', $order_value);
        dms_clean_product_cache($post_id);
    }
}
add_action('save_post_product', 'dms_ensure_custom_product_order_on_save', 10, 3);

/**
 * WooCommerce can create products through paths that do not reliably carry the
 * save_post update flag we need. Keep the app order invariant at the product
 * lifecycle level too.
 *
 * @param int $product_id Product ID.
 * @return void
 */
function dms_ensure_custom_product_order_on_new_product($product_id) {
    $product_id = absint($product_id);
    if ($product_id <= 0) {
        return;
    }

    $current = get_post_meta($product_id, '_custom_product_order', true);
    if ($current !== '' && $current !== null) {
        return;
    }

    update_post_meta($product_id, '_custom_product_order', dms_new_product_order_value($product_id));
    dms_clean_product_cache($product_id);
}
add_action('woocommerce_new_product', 'dms_ensure_custom_product_order_on_new_product', 10, 1);

/**
 * Promote recently created products that already received the old default
 * order before this fix was deployed.
 *
 * @return void
 */
function dms_promote_recent_default_order_products() {
    $new_days = defined('DMS_NEW_DAYS') ? absint(DMS_NEW_DAYS) : 30;
    if ($new_days <= 0) {
        $new_days = 30;
    }

    $after_ts = current_time('timestamp', true) - ($new_days * DAY_IN_SECONDS);
    $query = new WP_Query(array(
        'post_type' => 'product',
        'post_status' => 'publish',
        'fields' => 'ids',
        'posts_per_page' => 200,
        'no_found_rows' => true,
        'date_query' => array(
            array(
                'after' => gmdate('Y-m-d H:i:s', $after_ts),
                'inclusive' => true,
                'column' => 'post_date_gmt',
            ),
        ),
        'meta_query' => array(
            array(
                'key' => '_custom_product_order',
                'value' => DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT,
                'compare' => '=',
                'type' => 'NUMERIC',
            ),
        ),
    ));

    if (empty($query->posts)) {
        return;
    }

    $GLOBALS['lpco_dms_suspend_catalog_cache_flush'] = true;
    foreach ($query->posts as $product_id) {
        update_post_meta($product_id, '_custom_product_order', dms_new_product_order_value($product_id));
        dms_clean_product_cache($product_id, false);
    }
    unset($GLOBALS['lpco_dms_suspend_catalog_cache_flush'], $GLOBALS['lpco_dms_deferred_catalog_cache_flush']);

    if (function_exists('lpco_dms_flush_catalog_api_cache')) {
        lpco_dms_flush_catalog_api_cache();
    }
}

/**
 * Run the compatibility promotion periodically, not on every request.
 *
 * @return void
 */
function dms_maybe_promote_recent_default_order_products() {
    if (get_transient('dms_recent_default_order_promoted')) {
        return;
    }

    dms_promote_recent_default_order_products();
    set_transient('dms_recent_default_order_promoted', 1, HOUR_IN_SECONDS);
}
add_action('init', 'dms_maybe_promote_recent_default_order_products', 25);

/**
 * Normalize once per day to include legacy products without custom order.
 *
 * @return void
 */
function dms_maybe_normalize_missing_custom_order() {
    if (get_transient('dms_custom_order_normalized')) {
        return;
    }

    dms_normalize_missing_custom_order();
    set_transient('dms_custom_order_normalized', 1, DAY_IN_SECONDS);
}
add_action('init', 'dms_maybe_normalize_missing_custom_order', 20);
