<?php
/**
 * LPCO E-Commerce API Utilities
 * Shared helper functions for performance, caching, and data retrieval.
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Send public cache headers + ETag for safe catalog endpoints.
 */
if (!function_exists('dms_send_cache_headers')) {
    function dms_send_cache_headers($etag_key, $last_modified = null) {
        if (headers_sent()) {
            return;
        }
        $etag = '"' . md5((string) $etag_key) . '"';
        header('Content-Type: application/json; charset=UTF-8');
        header('X-Content-Type-Options: nosniff');
        header('Cache-Control: public, max-age=60, s-maxage=300');
        header('ETag: ' . $etag);
        if (!empty($last_modified)) {
            $timestamp = is_numeric($last_modified) ? intval($last_modified) : strtotime((string) $last_modified);
            if ($timestamp) {
                header('Last-Modified: ' . gmdate('D, d M Y H:i:s', $timestamp) . ' GMT');
            }
        }
        $if_none_match = isset($_SERVER['HTTP_IF_NONE_MATCH']) ? trim($_SERVER['HTTP_IF_NONE_MATCH']) : '';
        if ($if_none_match && $if_none_match === $etag) {
            status_header(304);
            exit;
        }
    }
}

/**
 * Bulk meta retrieval for multiple posts.
 */
if (!function_exists('dms_ecom_get_bulk_post_meta')) {
function dms_ecom_get_bulk_post_meta($post_ids, $meta_keys) {
    global $wpdb;

    $post_ids = array_values(array_filter(array_map('absint', (array) $post_ids)));
    $meta_keys = array_values(array_filter(array_map('strval', (array) $meta_keys)));

    if (empty($post_ids) || empty($meta_keys)) {
        return array();
    }

    $post_placeholders = implode(',', array_fill(0, count($post_ids), '%d'));
    $meta_placeholders = implode(',', array_fill(0, count($meta_keys), '%s'));
    $prepared_query = $wpdb->prepare(
        "SELECT post_id, meta_key, meta_value
         FROM {$wpdb->postmeta}
         WHERE post_id IN ({$post_placeholders})
         AND meta_key IN ({$meta_placeholders})",
        array_merge($post_ids, $meta_keys)
    );

    if (!$prepared_query) {
        return array();
    }

    $rows = $wpdb->get_results($prepared_query);
    $meta_map = array();

    foreach ((array) $rows as $row) {
        $post_id = isset($row->post_id) ? (int) $row->post_id : 0;
        $meta_key = isset($row->meta_key) ? (string) $row->meta_key : '';
        if ($post_id <= 0 || $meta_key === '') {
            continue;
        }
        if (!isset($meta_map[$post_id])) {
            $meta_map[$post_id] = array();
        }
        if (!array_key_exists($meta_key, $meta_map[$post_id])) {
            $meta_map[$post_id][$meta_key] = maybe_unserialize($row->meta_value);
        }
    }

    return $meta_map;
}
}

/**
 * Prime query context for performance.
 */
if (!function_exists('dms_ecom_prime_product_query_context')) {
function dms_ecom_prime_product_query_context($query, $has_brand_taxonomy, $extra_meta_keys = array()) {
    $context = array(
        'post_ids' => array(),
        'products' => array(),
        'categories' => array(),
        'brands' => array(),
        'tags' => array(),
        'variations' => array(),
        'meta' => array(),
    );

    if (!($query instanceof WP_Query) || empty($query->posts)) {
        return $context;
    }

    $post_ids = array_values(array_filter(array_map('intval', wp_list_pluck($query->posts, 'ID'))));
    if (empty($post_ids)) {
        return $context;
    }

    $context['post_ids'] = $post_ids;
    $meta_keys = array_merge(array('_dms_prices', '_custom_product_order'), (array) $extra_meta_keys);
    $meta_keys = array_values(array_unique(array_filter(array_map('strval', $meta_keys))));
    $context['meta'] = dms_ecom_get_bulk_post_meta($post_ids, $meta_keys);

    if (function_exists('_prime_post_caches')) {
        _prime_post_caches($post_ids, false, true);
    }
    if (function_exists('update_post_thumbnail_cache')) {
        update_post_thumbnail_cache($query);
    }

    $taxonomies_to_prime = array('product_cat', 'product_tag', 'brand');
    if ($has_brand_taxonomy) {
        $taxonomies_to_prime[] = 'product_brand';
    }
    if (function_exists('update_object_term_cache')) {
        update_object_term_cache($post_ids, array_values(array_unique($taxonomies_to_prime)));
    }

    $attachment_ids = array();
    $term_ids = array();
    $variation_ids = array();

    foreach ($post_ids as $post_id) {
        $product = function_exists('wc_get_product') ? wc_get_product($post_id) : null;
        if (!$product) {
            continue;
        }

        $context['products'][$post_id] = $product;

        $featured_id = $product->get_image_id();
        if ($featured_id) {
            $attachment_ids[$featured_id] = (int) $featured_id;
        }
        foreach ($product->get_gallery_image_ids() as $gallery_id) {
            $gallery_id = absint($gallery_id);
            if ($gallery_id > 0) {
                $attachment_ids[$gallery_id] = $gallery_id;
            }
        }

        $category_terms = function_exists('get_the_terms') ? get_the_terms($post_id, 'product_cat') : false;
        if (!empty($category_terms) && !is_wp_error($category_terms)) {
            $context['categories'][$post_id] = $category_terms;
            foreach ($category_terms as $term) {
                $term_ids[$term->term_id] = (int) $term->term_id;
            }
        }

        $brand_terms = ($has_brand_taxonomy && function_exists('get_the_terms')) ? get_the_terms($post_id, 'product_brand') : false;
        if (empty($brand_terms) || is_wp_error($brand_terms)) {
            $brand_terms = function_exists('get_the_terms') ? get_the_terms($post_id, 'product_tag') : false;
        }
        if (!empty($brand_terms) && !is_wp_error($brand_terms)) {
            $context['brands'][$post_id] = $brand_terms;
            foreach ($brand_terms as $term) {
                $term_ids[$term->term_id] = (int) $term->term_id;
            }
        }

        $tag_terms = function_exists('get_the_terms') ? get_the_terms($post_id, 'product_tag') : false;
        if (!empty($tag_terms) && !is_wp_error($tag_terms)) {
            $context['tags'][$post_id] = $tag_terms;
            foreach ($tag_terms as $term) {
                $term_ids[$term->term_id] = (int) $term->term_id;
            }
        }

        if ($product->is_type('variable')) {
            foreach ($product->get_children() as $variation_id) {
                $variation_id = absint($variation_id);
                if ($variation_id > 0) {
                    $variation_ids[$variation_id] = $variation_id;
                }
            }
        }
    }

    if (!empty($variation_ids)) {
        $variation_ids = array_values($variation_ids);
        if (function_exists('_prime_post_caches')) {
            _prime_post_caches($variation_ids, false, true);
        }

        foreach ($variation_ids as $variation_id) {
            $variation_product = function_exists('wc_get_product') ? wc_get_product($variation_id) : null;
            if (!$variation_product) {
                continue;
            }

            $context['variations'][$variation_id] = $variation_product;
            $variation_image_id = $variation_product->get_image_id();
            if ($variation_image_id) {
                $attachment_ids[$variation_image_id] = (int) $variation_image_id;
            }
        }
    }

    if (!empty($term_ids)) {
        if (function_exists('update_meta_cache')) {
            update_meta_cache('term', array_values($term_ids));
        }
        foreach ($term_ids as $term_id) {
            foreach (array('thumbnail_id', 'brand_logo_id', 'brand_image_id', 'brand_logo', 'brand_image') as $meta_key) {
                $attachment_id = dms_ecom_get_term_meta_value($term_id, $meta_key);
                if (is_numeric($attachment_id)) {
                    $attachment_id = absint($attachment_id);
                    if ($attachment_id > 0) {
                        $attachment_ids[$attachment_id] = $attachment_id;
                    }
                }
            }
        }
    }

    dms_ecom_prime_attachment_ids($attachment_ids);

    return $context;
}
}

/**
 * Bulk prime attachment caches.
 */
if (!function_exists('dms_ecom_prime_attachment_ids')) {
function dms_ecom_prime_attachment_ids($attachment_ids) {
    $attachment_ids = array_values(array_filter(array_map('absint', (array) $attachment_ids)));
    if (empty($attachment_ids)) {
        return;
    }
    if (function_exists('_prime_post_caches')) {
        _prime_post_caches($attachment_ids, false, true);
    }
}
}

/**
 * Get term meta value from cache.
 */
if (!function_exists('dms_ecom_get_all_term_meta')) {
function dms_ecom_get_all_term_meta($term_id) {
    static $term_meta_cache = array();

    $term_id = absint($term_id);
    if ($term_id <= 0) {
        return array();
    }

    if (!array_key_exists($term_id, $term_meta_cache)) {
        $all_meta = get_term_meta($term_id);
        $term_meta_cache[$term_id] = is_array($all_meta) ? $all_meta : array();
    }

    return $term_meta_cache[$term_id];
}
}

if (!function_exists('dms_ecom_get_term_meta_value')) {
function dms_ecom_get_term_meta_value($term_id, $meta_key, $default = '') {
    $all_meta = dms_ecom_get_all_term_meta($term_id);
    if (!isset($all_meta[$meta_key][0])) {
        return $default;
    }
    return $all_meta[$meta_key][0];
}
}

/**
 * Cached attachment property retrieval.
 */
if (!function_exists('dms_ecom_get_attachment_url_cached')) {
function dms_ecom_get_attachment_url_cached($attachment_id) {
    if (!$attachment_id) return '';
    static $url_cache = array();
    $attachment_id = absint($attachment_id);
    if ($attachment_id <= 0) return '';
    if (!array_key_exists($attachment_id, $url_cache)) {
        if (function_exists('_prime_post_caches')) {
            _prime_post_caches(array($attachment_id), false, true);
        }
        $url = wp_get_attachment_url($attachment_id);
        if (!$url) {
            $file = get_post_meta($attachment_id, '_wp_attached_file', true);
            if ($file) {
                $upload_dir = wp_upload_dir();
                $base_url = (isset($upload_dir['baseurl']) && !empty($upload_dir['baseurl'])) ? $upload_dir['baseurl'] : (content_url() . '/uploads');
                $url = rtrim($base_url, '/') . '/' . ltrim($file, '/');
            }
        }
        $url_cache[$attachment_id] = $url ?: '';
    }
    return $url_cache[$attachment_id];
}
}

if (!function_exists('dms_ecom_get_attachment_alt_cached')) {
function dms_ecom_get_attachment_alt_cached($attachment_id) {
    static $alt_cache = array();
    $attachment_id = absint($attachment_id);
    if ($attachment_id <= 0) return '';
    if (!array_key_exists($attachment_id, $alt_cache)) {
        $alt_cache[$attachment_id] = get_post_meta($attachment_id, '_wp_attachment_image_alt', true) ?: '';
    }
    return $alt_cache[$attachment_id];
}
}

if (!function_exists('dms_ecom_get_attachment_title_cached')) {
function dms_ecom_get_attachment_title_cached($attachment_id) {
    static $title_cache = array();
    $attachment_id = absint($attachment_id);
    if ($attachment_id <= 0) return '';
    if (!array_key_exists($attachment_id, $title_cache)) {
        $title_cache[$attachment_id] = get_the_title($attachment_id);
    }
    return $title_cache[$attachment_id];
}
}

/**
 * Product metadata helpers.
 */
if (!function_exists('dms_ecom_get_product_created_ts')) {
function dms_ecom_get_product_created_ts($product_id, $product = null) {
    $product = $product instanceof WC_Product ? $product : (function_exists('wc_get_product') ? wc_get_product($product_id) : null);
    $dt = $product ? $product->get_date_created() : null;
    if ($dt) {
        return $dt->getTimestamp();
    }
    $gmt = get_post_field('post_date_gmt', $product_id);
    $created_ts = $gmt ? strtotime($gmt) : 0;
    if (!$created_ts) {
        $local = get_post_field('post_date', $product_id);
        $created_ts = $local ? strtotime($local) : 0;
    }
    return $created_ts ?: 0;
}
}

if (!function_exists('dms_ecom_is_new_product')) {
function dms_ecom_is_new_product($created_ts, &$age_days = null) {
    $age_days = null;
    if (empty($created_ts) || !is_numeric($created_ts)) {
        return false;
    }
    $now_ts = current_time('timestamp', true);
    $age_days = (int) floor(($now_ts - (int) $created_ts) / DAY_IN_SECONDS);
    if (!defined('DMS_NEW_DAYS')) {
        define('DMS_NEW_DAYS', 30);
    }
    return $age_days <= DMS_NEW_DAYS;
}
}

if (!function_exists('dms_ecom_partition_new_first')) {
function dms_ecom_partition_new_first($products) {
    if (!is_array($products) || empty($products)) {
        return $products;
    }
    $new_items = array();
    $old_items = array();
    foreach ($products as $product) {
        if (!empty($product['is_new'])) {
            $new_items[] = $product;
        } else {
            $old_items[] = $product;
        }
    }
    return array_merge($new_items, $old_items);
}
}

if (!function_exists('dms_ecom_get_app_order_meta_key')) {
function dms_ecom_get_app_order_meta_key($brand_slug = '') {
    $brand_slug = is_string($brand_slug) ? sanitize_text_field($brand_slug) : '';
    if ($brand_slug !== '') {
        $taxonomy = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
        $term = get_term_by('slug', $brand_slug, $taxonomy);
        if ($term && !is_wp_error($term)) {
            $enabled = get_option(dms_app_order_enabled_key($term->term_id));
            if ($enabled) {
                return dms_app_order_meta_key($term->term_id);
            }
        }
    }
    $enabled = get_option(dms_app_order_enabled_key(0));
    if ($enabled) {
        return dms_app_order_meta_key(0);
    }
    return '_custom_product_order';
}
}

if (!function_exists('dms_ecom_manual_latest_enabled')) {
function dms_ecom_manual_latest_enabled() {
    return (bool) get_option('dms_app_latest_manual_enabled');
}
}

/**
 * Product sort helper.
 */
if (!function_exists('dms_ecom_get_product_order_value')) {
function dms_ecom_get_product_order_value($product_id, $product_meta = array(), $order_meta_key = '_custom_product_order') {
    $order_meta_key = is_string($order_meta_key) && $order_meta_key !== ''
        ? $order_meta_key
        : '_custom_product_order';

    $custom_order = array_key_exists($order_meta_key, $product_meta)
        ? $product_meta[$order_meta_key]
        : get_post_meta($product_id, $order_meta_key, true);

    if (($custom_order === '' || $custom_order === null) && $order_meta_key !== '_custom_product_order') {
        $custom_order = array_key_exists('_custom_product_order', $product_meta)
            ? $product_meta['_custom_product_order']
            : get_post_meta($product_id, '_custom_product_order', true);
    }

    if (!defined('DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT')) {
        define('DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT', 9999);
    }

    return ($custom_order !== '' && $custom_order !== null)
        ? intval($custom_order)
        : DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT;
}
}
