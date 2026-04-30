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
        'meta_key' => '_custom_product_order',
        'orderby' => 'meta_value_num',
        'order' => 'ASC',
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

    if (!empty($meta_query)) {
        $defaults['meta_query'] = $meta_query;
    }

    return array_merge($defaults, $extra_args);
}

/**
 * Clean product caches after order updates.
 *
 * @param int $product_id Product ID.
 * @return void
 */
function dms_clean_product_cache($product_id) {
    $product_id = absint($product_id);
    if ($product_id <= 0) {
        return;
    }

    clean_post_cache($product_id);
    if (function_exists('wc_delete_product_transients')) {
        wc_delete_product_transients($product_id);
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

    foreach ($query->posts as $product_id) {
        $priority = get_post_meta($product_id, '_custom_product_priority', true);
        $order_value = is_numeric($priority) ? intval($priority) : DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT;
        update_post_meta($product_id, '_custom_product_order', $order_value);
        dms_clean_product_cache($product_id);
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
        update_post_meta($post_id, '_custom_product_order', DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT);
        dms_clean_product_cache($post_id);
    }
}
add_action('save_post_product', 'dms_ensure_custom_product_order_on_save', 10, 3);

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
