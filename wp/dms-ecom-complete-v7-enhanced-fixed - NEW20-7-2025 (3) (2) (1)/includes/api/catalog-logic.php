<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Catalog-related logic for DMS Mobile App
 */

if (!defined('DMS_NEW_DAYS')) {
    define('DMS_NEW_DAYS', 30);
}

if (!function_exists('dms_ecom_get_product_created_ts')) {
function dms_ecom_get_product_created_ts($product_id, $product = null) {
    $product = $product instanceof WC_Product ? $product : (is_numeric($product_id) ? wc_get_product($product_id) : null);
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

if (!function_exists('dms_ecom_get_all_term_meta')) {
function dms_ecom_get_all_term_meta($term_id) {
    static $term_meta_cache = array();
    $term_id = absint($term_id);
    if ($term_id <= 0) return array();
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
    if (!isset($all_meta[$meta_key][0])) return $default;
    return $all_meta[$meta_key][0];
}
}

if (!function_exists('dms_ecom_is_truthy_meta_value')) {
function dms_ecom_is_truthy_meta_value($value) {
    if (is_bool($value)) return $value;
    if (is_numeric($value)) return floatval($value) > 0;
    $normalized = strtolower(trim((string) $value));
    if ($normalized === '') return false;
    return in_array($normalized, array('1', 'true', 'yes', 'on', 'hide', 'hidden', 'private'), true);
}
}

if (!function_exists('dms_ecom_is_hidden_term_for_app')) {
function dms_ecom_is_hidden_term_for_app($term, $taxonomy = 'product_cat') {
    $term_id = 0;
    if ($term instanceof WP_Term) {
        $term_id = (int) $term->term_id;
        if ($taxonomy === '' && !empty($term->taxonomy)) {
            $taxonomy = (string) $term->taxonomy;
        }
    }
    elseif (is_object($term) && isset($term->term_id)) {
        $term_id = (int) $term->term_id;
        if ($taxonomy === '' && !empty($term->taxonomy)) {
            $taxonomy = (string) $term->taxonomy;
        }
    }
    elseif (is_array($term) && isset($term['term_id'])) {
        $term_id = (int) $term['term_id'];
        if ($taxonomy === '' && !empty($term['taxonomy'])) {
            $taxonomy = (string) $term['taxonomy'];
        }
    }
    else { $term_id = (int) $term; }
    if ($term_id <= 0) return false;

    $config_hidden = function_exists('lpco_app_layout_is_term_hidden')
        ? (bool) lpco_app_layout_is_term_hidden($term_id, $taxonomy)
        : false;
    $is_hidden = $config_hidden;
    $all_meta = function_exists('dms_ecom_get_all_term_meta') ? dms_ecom_get_all_term_meta($term_id) : array();
    $hide_keys = array(
        'dms_hide_in_app',
        'lpco_hide_in_app',
        'hide_in_app',
        'is_hidden',
        'hidden',
        'dms_hidden',
        'lpco_hidden',
        'app_hidden',
        'dms_app_hidden',
    );
    $show_keys = array(
        'show_in_app',
        'lpco_show_in_app',
        'dms_show_in_app',
    );
    $visibility_keys = array(
        'visibility',
        'app_visibility',
        'dms_visibility',
    );

    $explicit_show = null;
    foreach ($show_keys as $k) {
        if (isset($all_meta[$k][0])) {
            $explicit_show = dms_ecom_is_truthy_meta_value($all_meta[$k][0]);
            break;
        }
    }

    $visibility = '';
    foreach ($visibility_keys as $k) {
        if (isset($all_meta[$k][0])) {
            $visibility = strtolower(trim((string) $all_meta[$k][0]));
            if ($visibility !== '') {
                break;
            }
        }
    }

    foreach ($hide_keys as $k) {
        if (isset($all_meta[$k][0]) && dms_ecom_is_truthy_meta_value($all_meta[$k][0])) {
            $is_hidden = true; break;
        }
    }

    if ($explicit_show !== null) {
        $is_hidden = !$explicit_show;
    } elseif ($visibility !== '') {
        if (in_array($visibility, array('hidden', 'hide', 'private', 'none', 'off', 'disabled'), true)) {
            $is_hidden = true;
        } elseif (in_array($visibility, array('visible', 'show', 'public', 'on', 'enabled', 'app'), true)) {
            $is_hidden = false;
        }
    }

    if ($config_hidden) {
        $is_hidden = true;
    }

    return (bool) apply_filters('dms_ecom_is_hidden_term_for_app', $is_hidden, $term, $taxonomy);
}
}

if (!function_exists('dms_format_category_term')) {
function dms_format_category_term($term) {
    if (!$term || is_wp_error($term)) return null;
    $term_id = $term->term_id;
    $is_hidden = function_exists('dms_ecom_is_hidden_term_for_app') ? dms_ecom_is_hidden_term_for_app($term) : false;
    if ($is_hidden) {
        return null;
    }
    $thumbnail_id = function_exists('dms_ecom_get_term_meta_value') ? dms_ecom_get_term_meta_value($term_id, 'thumbnail_id') : 0;
    $image_url = '';
    if ($thumbnail_id && function_exists('dms_ecom_get_attachment_url_cached')) {
        $image_url = dms_ecom_get_attachment_url_cached($thumbnail_id);
    }
    if (empty($image_url) && function_exists('dms_ecom_get_term_meta_value')) {
        $image_url = dms_ecom_get_term_meta_value($term_id, 'brand_image') ?: (dms_ecom_get_term_meta_value($term_id, 'image') ?: '');
    }
    $show_in_app = function_exists('dms_ecom_is_hidden_term_for_app') ? !dms_ecom_is_hidden_term_for_app($term) : true;
    $menu_order = function_exists('dms_ecom_get_term_meta_value') ? intval(dms_ecom_get_term_meta_value($term_id, 'menu_order')) : 0;
    $visible_count = function_exists('dms_ecom_get_visible_term_product_count')
        ? dms_ecom_get_visible_term_product_count('product_cat', $term_id, true)
        : intval($term->count);
    
    return array(
        'id'          => intval($term_id),
        'name'        => $term->name,
        'slug'        => $term->slug,
        'parent'      => intval($term->parent),
        'description' => $term->description,
        'display'     => (function_exists('dms_ecom_get_term_meta_value') ? dms_ecom_get_term_meta_value($term_id, 'display_type') : 'default') ?: 'default',
        'image_url'   => $image_url,
        'count'       => $visible_count,
        'show_in_app' => $show_in_app,
        'hidden'      => !$show_in_app,
        'menu_order'  => $menu_order,
    );
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

if (!function_exists('dms_ecom_prime_attachment_ids')) {
function dms_ecom_prime_attachment_ids($attachment_ids) {
    if (!function_exists('_prime_post_caches')) return;
    $attachment_ids = array_values(array_filter(array_map('absint', (array) $attachment_ids)));
    if (empty($attachment_ids)) return;
    _prime_post_caches($attachment_ids, false, true);
}
}

if (!function_exists('dms_ecom_build_product_images_payload')) {
function dms_ecom_build_product_images_payload($product) {
    if (!$product || !is_object($product)) return array();

    $images = array();
    $seen = array();
    $append_image = function($image_id) use (&$images, &$seen) {
        $image_id = function_exists('absint') ? absint($image_id) : (int) $image_id;
        if ($image_id <= 0 || isset($seen[$image_id])) return;

        $src = '';
        if (function_exists('dms_ecom_get_attachment_url_cached')) {
            $src = (string) dms_ecom_get_attachment_url_cached($image_id);
        } elseif (function_exists('wp_get_attachment_image_url')) {
            $src = (string) wp_get_attachment_image_url($image_id, 'full');
        }
        $src = trim($src);
        if ($src === '') return;

        $seen[$image_id] = true;
        $images[] = array(
            'id' => $image_id,
            'src' => $src,
            'name' => function_exists('dms_ecom_get_attachment_title_cached') ? dms_ecom_get_attachment_title_cached($image_id) : '',
            'alt' => function_exists('dms_ecom_get_attachment_alt_cached') ? dms_ecom_get_attachment_alt_cached($image_id) : '',
        );
    };

    if (method_exists($product, 'get_image_id')) {
        $append_image($product->get_image_id());
    }
    if (method_exists($product, 'get_gallery_image_ids')) {
        foreach ((array) $product->get_gallery_image_ids() as $gallery_image_id) {
            $append_image($gallery_image_id);
        }
    }

    return $images;
}
}

if (!function_exists('dms_ecom_get_bulk_post_meta')) {
function dms_ecom_get_bulk_post_meta($post_ids, $meta_keys) {
    global $wpdb;
    $post_ids = array_values(array_filter(array_map('absint', (array) $post_ids)));
    $meta_keys = array_values(array_filter(array_map('strval', (array) $meta_keys)));
    if (empty($post_ids) || empty($meta_keys)) return array();
    $post_placeholders = implode(',', array_fill(0, count($post_ids), '%d'));
    $meta_placeholders = implode(',', array_fill(0, count($meta_keys), '%s'));
    $prepared_query = $wpdb->prepare(
        "SELECT post_id, meta_key, meta_value FROM {$wpdb->postmeta} WHERE post_id IN ({$post_placeholders}) AND meta_key IN ({$meta_placeholders})",
        array_merge($post_ids, $meta_keys)
    );
    if (!$prepared_query) return array();
    $rows = $wpdb->get_results($prepared_query);
    $meta_map = array();
    foreach ((array) $rows as $row) {
        $post_id = (int) $row->post_id;
        $meta_key = (string) $row->meta_key;
        if (!isset($meta_map[$post_id])) $meta_map[$post_id] = array();
        $meta_map[$post_id][$meta_key] = function_exists('maybe_unserialize') ? maybe_unserialize($row->meta_value) : $row->meta_value;
    }
    return $meta_map;
}
}

if (!function_exists('dms_ecom_get_request_user_context')) {
function dms_ecom_get_request_user_context($request, $is_guest) {
    $current_user_id = $is_guest ? 0 : (function_exists('get_current_user_id') ? get_current_user_id() : 0);
    $requested_group = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('user_group') : null;
    $requested_currency = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('currency') : null;
    if ($is_guest) {
        list($default_group, $default_currency) = function_exists('dms_ecom_guest_defaults') ? dms_ecom_guest_defaults() : array('default', 'syp');
        $current_group = $requested_group ? (function_exists('sanitize_text_field') ? sanitize_text_field($requested_group) : $requested_group) : $default_group;
        $current_currency = $requested_currency ? (function_exists('sanitize_text_field') ? sanitize_text_field($requested_currency) : $requested_currency) : $default_currency;
    } else {
        $all_user_meta = ($current_user_id && function_exists('get_user_meta')) ? get_user_meta($current_user_id) : array();
        $current_group = $requested_group ? (function_exists('sanitize_text_field') ? sanitize_text_field($requested_group) : $requested_group) : (isset($all_user_meta['dms_user_group'][0]) ? (string) $all_user_meta['dms_user_group'][0] : '');
        $current_currency = $requested_currency ? (function_exists('sanitize_text_field') ? sanitize_text_field($requested_currency) : $requested_currency) : (isset($all_user_meta['dms_user_currency'][0]) ? (string) $all_user_meta['dms_user_currency'][0] : 'syp');
    }
    if ($current_group === '') $current_group = 'default';
    if ($current_currency === '') $current_currency = 'syp';
    return array($current_user_id, $current_group, $current_currency);
}
}

if (!function_exists('dms_ecom_unit_price_bucket')) {
function dms_ecom_unit_price_bucket($dms_prices, $group = 'default') {
    if (!is_array($dms_prices) || empty($dms_prices)) return array();
    $group = is_string($group) ? trim($group) : '';
    if ($group !== '' && isset($dms_prices[$group]) && is_array($dms_prices[$group])) return $dms_prices[$group];
    if (isset($dms_prices['default']) && is_array($dms_prices['default'])) return $dms_prices['default'];
    foreach ($dms_prices as $candidate) if (is_array($candidate)) return $candidate;
    return array();
}
}

if (!function_exists('dms_ecom_resolve_unit_presentation')) {
function dms_ecom_resolve_unit_presentation($dms_prices, $active_group = 'default') {
    $default_bucket = dms_ecom_unit_price_bucket($dms_prices, 'default');
    $active_bucket = dms_ecom_unit_price_bucket($dms_prices, $active_group);

    $piece_name = function_exists('sanitize_text_field') ? sanitize_text_field($default_bucket['box_unit_name'] ?? '') : ($default_bucket['box_unit_name'] ?? '');
    if ($piece_name === '') $piece_name = function_exists('sanitize_text_field') ? sanitize_text_field($active_bucket['box_unit_name'] ?? '') : ($active_bucket['box_unit_name'] ?? '');
    if ($piece_name === '') $piece_name = 'Ù‚Ø·Ø¹Ø©';

    $package_name = function_exists('sanitize_text_field') ? sanitize_text_field($default_bucket['package_unit_name'] ?? '') : ($default_bucket['package_unit_name'] ?? '');
    if ($package_name === '') $package_name = function_exists('sanitize_text_field') ? sanitize_text_field($active_bucket['package_unit_name'] ?? '') : ($active_bucket['package_unit_name'] ?? '');
    if ($package_name === '') $package_name = 'Ø·Ø±Ø¯';

    $piece_pieces = absint($default_bucket['box_pieces_count'] ?? 0);
    if ($piece_pieces <= 0) $piece_pieces = absint($active_bucket['box_pieces_count'] ?? 0);
    if ($piece_pieces <= 0) $piece_pieces = 1;

    $package_pieces = absint($default_bucket['package_pieces_count'] ?? 0);
    if ($package_pieces <= 0) $package_pieces = absint($active_bucket['package_pieces_count'] ?? 0);

    return array(
        'piece_name' => $piece_name,
        'piece_pieces' => $piece_pieces,
        'package_name' => $package_name,
        'package_pieces' => $package_pieces,
    );
}
}

if (!function_exists('dms_ecom_resolve_piece_price')) {
function dms_ecom_resolve_piece_price($product, $dms_prices, $group, $currency, $is_guest) {
    $fallback = method_exists($product, 'get_price') ? floatval($product->get_price()) : 0;
    if ($fallback <= 0 && method_exists($product, 'get_regular_price')) $fallback = floatval($product->get_regular_price());
    if ($is_guest) return $fallback;

    $bucket = dms_ecom_unit_price_bucket($dms_prices, $group);
    $price_key = strtolower((string) $currency) === 'usd' ? 'usd_piece' : 'syp_piece';
    $piece_price = floatval($bucket[$price_key] ?? 0);
    if ($piece_price <= 0) $piece_price = floatval($bucket['price'] ?? 0);
    if ($piece_price <= 0) $piece_price = $fallback;
    return $piece_price;
}
}

if (!function_exists('dms_ecom_resolve_package_price')) {
function dms_ecom_resolve_package_price($piece_price, $dms_prices, $group, $currency, $package_pieces) {
    $bucket = dms_ecom_unit_price_bucket($dms_prices, $group);
    $package_keys = strtolower((string) $currency) === 'usd' ? array('usd_pack', 'usd_package') : array('syp_pack', 'syp_package');
    $package_price = 0;
    foreach ($package_keys as $package_key) {
        $candidate = floatval($bucket[$package_key] ?? 0);
        if ($candidate > 0) { $package_price = $candidate; break; }
    }
    if ($package_price <= 0 && $piece_price > 0 && $package_pieces > 0) $package_price = $piece_price * $package_pieces;
    return $package_price;
}
}

if (!function_exists('dms_ecom_build_unit_options_payload')) {
function dms_ecom_build_unit_options_payload($product_id, $product, $dms_prices, $current_group, $current_currency, $is_guest) {
    $presentation = dms_ecom_resolve_unit_presentation($dms_prices, $current_group);
    $piece_price = dms_ecom_resolve_piece_price($product, $dms_prices, $current_group, $current_currency, $is_guest);
    $unit_options = array();

    if ($piece_price > 0) {
        $unit_options[] = array(
            'type' => 'piece',
            'name' => $presentation['piece_name'],
            'pieces_count' => $presentation['piece_pieces'],
            'price' => $piece_price,
            'currency' => $current_currency,
        );
    }

    $package_pieces = absint($presentation['package_pieces']);
    $package_price = dms_ecom_resolve_package_price($piece_price, $dms_prices, $current_group, $current_currency, $package_pieces);
    if ($piece_price > 0 && $package_pieces > 0 && $package_price > 0 && abs(floatval($package_price) - floatval($piece_price)) > 0.00001) {
        $unit_options[] = array(
            'type' => 'package',
            'name' => $presentation['package_name'],
            'pieces_count' => $package_pieces,
            'price' => $package_price,
            'currency' => $current_currency,
        );
    }

    if (!empty($unit_options) && function_exists('dms_get_unit_label_display')) {
        foreach ($unit_options as &$unit_option) {
            $labels = dms_get_unit_label_display($product_id, $unit_option['type'] ?? '', 'api', $unit_option['name'] ?? '', $unit_option['pieces_count'] ?? null, '');
            $unit_option['label_display_ar'] = (string) ($labels['ar'] ?? '');
            $unit_option['label_display_en'] = (string) ($labels['en'] ?? '');
        }
        unset($unit_option);
    }

    return $unit_options;
}
}

if (!function_exists('dms_ecom_prime_product_query_context')) {
function dms_ecom_prime_product_query_context($query, $has_brand_taxonomy, $extra_meta_keys = array()) {
    $context = array('post_ids' => array(), 'products' => array(), 'categories' => array(), 'brands' => array(), 'tags' => array(), 'variations' => array(), 'meta' => array());
    if (!class_exists('WP_Query') || !($query instanceof WP_Query) || empty($query->posts)) return $context;
    $post_ids = array_values(array_filter(array_map('intval', wp_list_pluck($query->posts, 'ID'))));
    if (empty($post_ids)) return $context;
    $context['post_ids'] = $post_ids;
    
    $meta_keys = array_merge(array('_dms_prices', '_custom_product_order', '_stock_status', '_featured'), (array) $extra_meta_keys);
    $meta_keys = array_values(array_unique(array_filter(array_map('strval', $meta_keys))));
    $context['meta'] = dms_ecom_get_bulk_post_meta($post_ids, $meta_keys);
    
    if (function_exists('_prime_post_caches')) {
        _prime_post_caches($post_ids, false, true);
    }
    if (function_exists('update_post_thumbnail_cache')) {
        update_post_thumbnail_cache($query);
    }
    
    $taxonomies_to_prime = array('product_cat', 'product_tag');
    if ($has_brand_taxonomy) $taxonomies_to_prime[] = 'product_brand';
    if (function_exists('update_object_term_cache')) {
        update_object_term_cache($post_ids, array_values(array_unique($taxonomies_to_prime)));
    }
    
    $attachment_ids = array(); $term_ids = array(); $variation_ids = array();
    foreach ($post_ids as $post_id) {
        $product = function_exists('wc_get_product') ? wc_get_product($post_id) : null;
        if (!$product) continue;
        $context['products'][$post_id] = $product;
        
        $img_id = method_exists($product, 'get_image_id') ? $product->get_image_id() : 0;
        if ($img_id) $attachment_ids[$img_id] = (int) $img_id;
        if (method_exists($product, 'get_gallery_image_ids')) {
            foreach ($product->get_gallery_image_ids() as $gal_id) {
                $gal_id = absint($gal_id);
                if ($gal_id > 0) $attachment_ids[$gal_id] = $gal_id;
            }
        }
        
        $cats = function_exists('get_the_terms') ? get_the_terms($post_id, 'product_cat') : false;
        if (!empty($cats) && !is_wp_error($cats)) {
            $context['categories'][$post_id] = $cats;
            foreach ($cats as $t) $term_ids[$t->term_id] = (int) $t->term_id;
        }
        
        $brands = $has_brand_taxonomy ? (function_exists('get_the_terms') ? get_the_terms($post_id, 'product_brand') : false) : false;
        if (empty($brands) || (function_exists('is_wp_error') && is_wp_error($brands))) {
            $brands = function_exists('get_the_terms') ? get_the_terms($post_id, 'product_tag') : false;
        }
        if (!empty($brands) && !(function_exists('is_wp_error') && is_wp_error($brands))) {
            $context['brands'][$post_id] = $brands;
            foreach ($brands as $t) $term_ids[$t->term_id] = (int) $t->term_id;
        }
        
        if (method_exists($product, 'is_type') && $product->is_type('variable') && method_exists($product, 'get_children')) {
            foreach ($product->get_children() as $v_id) {
                if ($v_id > 0) $variation_ids[$v_id] = $v_id;
            }
        }
    }
    
    if (!empty($variation_ids)) {
        $v_ids = array_values($variation_ids);
        if (function_exists('_prime_post_caches')) {
            _prime_post_caches($v_ids, false, true);
        }
        foreach ($v_ids as $v_id) {
            $v_prod = function_exists('wc_get_product') ? wc_get_product($v_id) : null;
            if (!$v_prod) continue;
            $context['variations'][$v_id] = $v_prod;
            $v_img_id = method_exists($v_prod, 'get_image_id') ? $v_prod->get_image_id() : 0;
            if ($v_img_id) $attachment_ids[$v_img_id] = (int) $v_img_id;
        }
    }
    
    if (!empty($term_ids)) {
        if (function_exists('update_meta_cache')) {
            update_meta_cache('term', array_values($term_ids));
        }
        foreach ($term_ids as $tid) {
            foreach (array('thumbnail_id', 'brand_logo_id', 'brand_image_id') as $mk) {
                $aid = absint(dms_ecom_get_term_meta_value($tid, $mk));
                if ($aid > 0) $attachment_ids[$aid] = $aid;
            }
        }
    }
    dms_ecom_prime_attachment_ids($attachment_ids);
    return $context;
}
}

if (!function_exists('dms_ecom_get_product_order_value')) {
function dms_ecom_get_product_order_value($product_id, $product_meta = array(), $order_meta_key = '_custom_product_order') {
    $order_meta_key = is_string($order_meta_key) && $order_meta_key !== '' ? $order_meta_key : '_custom_product_order';
    $custom_order = array_key_exists($order_meta_key, $product_meta) ? $product_meta[$order_meta_key] : (function_exists('get_post_meta') ? get_post_meta($product_id, $order_meta_key, true) : '');
    if (($custom_order === '' || $custom_order === null) && $order_meta_key !== '_custom_product_order') {
        $custom_order = array_key_exists('_custom_product_order', $product_meta) ? $product_meta['_custom_product_order'] : (function_exists('get_post_meta') ? get_post_meta($product_id, '_custom_product_order', true) : '');
    }
    return ($custom_order !== '' && $custom_order !== null) ? intval($custom_order) : (defined('DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT') ? DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT : 1000000);
}
}

if (!function_exists('dms_get_products_with_prices')) {
function dms_get_products_with_prices($request) {
    if (!function_exists('absint')) return array();
    $per_page = is_object($request) && method_exists($request, 'get_param') ? ($request->get_param('per_page') ?: 100) : 100;
    $page = is_object($request) && method_exists($request, 'get_param') ? ($request->get_param('page') ?: 1) : 1;
    $category = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('category') : null;
    $search = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('search') : null;
    $brand_slug = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('brand_slug') : null;
    $include = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('include') : null;
    $include_ids = !empty($include) ? array_values(array_filter(array_map('absint', explode(',', (string) $include)))) : array();
    $stock_order = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('stock_order') : null;
    $latest_days = is_object($request) && method_exists($request, 'get_param') ? absint($request->get_param('latest_days')) : 0;
    $stock_status = is_object($request) && method_exists($request, 'get_param') && $request->get_param('stock') !== null ? (function_exists('sanitize_text_field') ? sanitize_text_field($request->get_param('stock')) : $request->get_param('stock')) : '';
    $is_guest = function_exists('lpco_dms_is_guest_request') ? lpco_dms_is_guest_request($request) : true;
    list($current_user_id, $current_group, $current_currency) = dms_ecom_get_request_user_context($request, $is_guest);
    
    $cache_key = $is_guest ? (function_exists('lpco_dms_guest_cache_key') ? lpco_dms_guest_cache_key('products', $request) : '') : (function_exists('lpco_dms_auth_cache_key') ? lpco_dms_auth_cache_key('products', $request, $current_user_id, $current_group, $current_currency) : '');
    $cached = $is_guest ? (function_exists('lpco_dms_guest_cache_get') ? lpco_dms_guest_cache_get($cache_key) : false) : (function_exists('lpco_dms_auth_cache_get') ? lpco_dms_auth_cache_get($cache_key) : false);
    if ($cached !== false) {
        if ($is_guest && function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('products_guest_' . md5(wp_json_encode($cached)));
        return $cached;
    }
    
    $has_brand_taxonomy = function_exists('taxonomy_exists') ? taxonomy_exists('product_brand') : false;
    $args = function_exists('dms_build_ordered_product_query_args') ? dms_build_ordered_product_query_args(array('posts_per_page' => $per_page, 'paged' => $page, 'stock_status' => $stock_status)) : array();
    $args['no_found_rows'] = true;
    $args['update_post_meta_cache'] = true;
    $args['update_post_term_cache'] = true;
    $order_meta_key = dms_ecom_get_app_order_meta_key($brand_slug);
    if ($order_meta_key && function_exists('dms_apply_product_ordering_args')) {
        $args = dms_apply_product_ordering_args($args, $order_meta_key);
    }
    
    $tax_query = array();
    if ($category) $tax_query[] = array('taxonomy' => 'product_cat', 'field' => 'term_id', 'terms' => $category);
    if ($brand_slug) $tax_query[] = array('taxonomy' => $has_brand_taxonomy ? 'product_brand' : 'product_tag', 'field' => 'slug', 'terms' => $brand_slug);
    if (!empty($tax_query)) {
        $args['tax_query'] = $tax_query;
        if (count($tax_query) > 1) $args['tax_query']['relation'] = 'AND';
    }
    if (!empty($include_ids)) {
        $args['post__in'] = $include_ids;
        $args['orderby'] = 'post__in';
        $args['posts_per_page'] = count($include_ids);
        $args['paged'] = 1;
    } elseif ($search) {
        $search_ids = dms_ecom_find_catalog_search_ids($search);
        if (empty($search_ids)) {
            return array();
        }
        $args['post__in'] = $search_ids;
        $args['orderby'] = 'post__in';
        $args['posts_per_page'] = (intval($per_page) > 0) ? min(intval($per_page), count($search_ids)) : count($search_ids);
        $args['paged'] = 1;
    }

    if ($latest_days > 0 && dms_ecom_manual_latest_enabled() && empty($include_ids) && empty($category) && empty($search) && empty($brand_slug)) {
        $args['meta_query'] = array(array('key' => '_dms_app_latest_order', 'compare' => 'EXISTS'));
        $args['meta_key'] = '_dms_app_latest_order'; $args['orderby'] = 'meta_value_num'; $args['order'] = 'ASC';
    } elseif ($latest_days > 0) {
        $after_ts = (function_exists('current_time') ? current_time('timestamp', true) : time()) - ($latest_days * (defined('DAY_IN_SECONDS') ? DAY_IN_SECONDS : 86400));
        $args['date_query'] = array(array('after' => gmdate('Y-m-d H:i:s', $after_ts), 'inclusive' => true, 'column' => 'post_date_gmt'));
        $args['orderby'] = 'date'; $args['order'] = 'DESC';
    }

    if ($stock_order === 'in_first' && empty($brand_slug) && empty($include_ids) && $latest_days <= 0) {
        if (empty($args['meta_query'])) $args['meta_query'] = array();
        if (empty($stock_status) || $stock_status === 'all') {
            $args['meta_query']['stock_status'] = array('key' => '_stock_status', 'compare' => 'EXISTS');
        }
        $args['orderby'] = array('stock_status' => 'ASC', 'dms_order_exists' => 'ASC', 'date' => 'DESC', 'ID' => 'DESC');
    }
    
    $query = class_exists('WP_Query') ? new WP_Query($args) : null;
    if (!$query) return array();
    $prepared = dms_ecom_prime_product_query_context($query, $has_brand_taxonomy, array_merge(array($order_meta_key), dms_ecom_catalog_barcode_meta_keys()));
    $product_meta_map = $prepared['meta'];
    $products = array();
    
    if ($query->have_posts()) {
        while ($query->have_posts()) {
            $query->the_post();
            $product_id = function_exists('get_the_ID') ? get_the_ID() : 0;
            if (!$product_id) continue;
            $product = $prepared['products'][$product_id] ?? (function_exists('wc_get_product') ? wc_get_product($product_id) : null);
            if (!$product) continue;
            if (function_exists('dms_ecom_product_is_hidden_for_app') && dms_ecom_product_is_hidden_for_app($product_id, $product)) continue;
            
            $product_meta = $product_meta_map[$product_id] ?? array();
            $dms_prices = array_key_exists('_dms_prices', $product_meta) ? $product_meta['_dms_prices'] : (function_exists('get_post_meta') ? get_post_meta($product_id, '_dms_prices', true) : array());

            $unit_options = dms_ecom_build_unit_options_payload(
                $product_id,
                $product,
                $dms_prices,
                $current_group,
                $current_currency,
                $is_guest
            );
 
            $unit_display_default_ar = !empty($unit_options) ? ($unit_options[0]['label_display_ar'] ?? null) : null;
            $unit_display_default_en = !empty($unit_options) ? ($unit_options[0]['label_display_en'] ?? null) : null;
            $custom_order_value = dms_ecom_get_product_order_value($product_id, $product_meta, $order_meta_key);
            $global_order_value = dms_ecom_get_product_order_value($product_id, $product_meta, '_custom_product_order');
            $image_id = method_exists($product, 'get_image_id') ? $product->get_image_id() : 0;
            $image_url = $image_id ? dms_ecom_get_attachment_url_cached($image_id) : '';
            $brand_slug_value = ''; $brand_terms = $prepared['brands'][$product_id] ?? array();
            if (!empty($brand_terms)) $brand_slug_value = $brand_terms[0]->slug;
            $created_ts = dms_ecom_get_product_created_ts($product_id, $product);
            $post_object = function_exists('get_post') ? get_post($product_id) : null; $published_gmt = $post_object ? $post_object->post_date_gmt : ''; $published_local = $post_object ? $post_object->post_date : '';
            $is_new = dms_ecom_is_new_product($created_ts);
            $category_terms = $prepared['categories'][$product_id] ?? array();
            $barcode_payload = dms_ecom_get_product_barcode_payload($product_id, $product_meta);
 
            $product_data = array(
                'id' => $product_id, 'name' => method_exists($product, 'get_name') ? $product->get_name() : '', 'slug' => method_exists($product, 'get_slug') ? $product->get_slug() : '', 'permalink' => function_exists('get_permalink') ? get_permalink($product_id) : '', 'type' => method_exists($product, 'get_type') ? $product->get_type() : '', 'status' => method_exists($product, 'get_status') ? $product->get_status() : '', 'description' => method_exists($product, 'get_description') ? $product->get_description() : '', 'short_description' => method_exists($product, 'get_short_description') ? $product->get_short_description() : '', 'sku' => method_exists($product, 'get_sku') ? $product->get_sku() : '', 'price' => method_exists($product, 'get_price') ? $product->get_price() : '', 'regular_price' => method_exists($product, 'get_regular_price') ? $product->get_regular_price() : '', 'sale_price' => method_exists($product, 'get_sale_price') ? $product->get_sale_price() : '', 'custom_order' => $custom_order_value, 'app_order' => $custom_order_value, 'brand_order' => $brand_slug ? $custom_order_value : $global_order_value, 'stock_status' => (method_exists($product, 'get_stock_status') ? $product->get_stock_status() : 'outofstock') ?: 'outofstock', 'stock_quantity' => method_exists($product, 'get_stock_quantity') ? $product->get_stock_quantity() : 0, 'image_url' => $image_url, 'brand_slug' => $brand_slug_value, 'is_new' => $is_new, 'new_badge_label_ar' => 'Ø­Ø¯ÙŠØ«', 'new_badge_days' => defined('DMS_NEW_DAYS') ? DMS_NEW_DAYS : 30, 'created_at_gmt' => $created_ts ? gmdate('c', $created_ts) : null, 'published_at_gmt' => $published_gmt ? gmdate('c', strtotime($published_gmt)) : null, 'published_at_local' => $published_local ? date('c', strtotime($published_local)) : null,
                'categories' => array_map(function($term) { return array('id' => $term->term_id, 'name' => $term->name, 'slug' => $term->slug); }, $category_terms ?: array()),
                'images' => method_exists($product, 'get_gallery_image_ids') ? array_map(function($image_id) { return array('id' => $image_id, 'src' => dms_ecom_get_attachment_url_cached($image_id), 'name' => dms_ecom_get_attachment_title_cached($image_id), 'alt' => dms_ecom_get_attachment_alt_cached($image_id)); }, $product->get_gallery_image_ids()) : array(),
                'unit_options' => $unit_options, 'unit_display_default_ar' => $unit_display_default_ar, 'unit_display_default_en' => $unit_display_default_en,
                'meta_data' => array(array('key' => '_dms_prices', 'value' => $dms_prices ?: array()))
            );
            $product_data['barcode_1'] = $barcode_payload['barcode_1'];
            $product_data['barcode_2'] = $barcode_payload['barcode_2'];
            $product_data['barcode_3'] = $barcode_payload['barcode_3'];
            $product_data['barcode_4'] = $barcode_payload['barcode_4'];
            $product_data['barcodes'] = $barcode_payload['barcodes'];
            foreach (dms_ecom_catalog_barcode_meta_keys() as $index => $barcode_meta_key) {
                $product_data['meta_data'][] = array('key' => $barcode_meta_key, 'value' => $barcode_payload['barcode_' . ($index + 1)] ?? '');
            }
            
            if ($image_id) array_unshift($product_data['images'], array('id' => $image_id, 'src' => dms_ecom_get_attachment_url_cached($image_id), 'name' => dms_ecom_get_attachment_title_cached($image_id), 'alt' => dms_ecom_get_attachment_alt_cached($image_id)));
            $products[] = $product_data;
        }
    }
    if (function_exists('wp_reset_postdata')) wp_reset_postdata();
    if ($is_guest && $cache_key) { if (function_exists('lpco_dms_guest_cache_set')) lpco_dms_guest_cache_set($cache_key, $products); if (function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('products_guest_' . md5(wp_json_encode($products))); } elseif ($cache_key) { if (function_exists('lpco_dms_auth_cache_set')) lpco_dms_auth_cache_set($cache_key, $products); }
    return $products;
}
}

if (!function_exists('dms_ecom_is_color_attribute_key')) {
function dms_ecom_is_color_attribute_key($key) {
    if (!is_string($key) || $key === '') return false;
    $normalized = strtolower($key);
    return strpos((string)$normalized, 'color') !== false || strpos((string)$normalized, 'colour') !== false || strpos((string)$key, 'Ù„ÙˆÙ†') !== false;
}
}

if (!function_exists('dms_ecom_extract_color_from_attributes')) {
function dms_ecom_extract_color_from_attributes($attributes) {
    static $term_cache = array();
    if (!is_array($attributes)) return array('', '', '');
    foreach ($attributes as $attr_key => $attr_value) {
        if (!function_exists('dms_ecom_is_color_attribute_key')) continue;
        if (!dms_ecom_is_color_attribute_key($attr_key)) continue;
        $taxonomy = (strpos((string)$attr_key, 'attribute_') === 0) ? substr($attr_key, 10) : $attr_key;
        $value = trim(is_array($attr_value) ? (string) reset($attr_value) : (string) $attr_value);
        if ($value === '') continue;
        $color_name = $value; $color_slug = $value; $color_hex = '';
        if ($taxonomy && function_exists('taxonomy_exists') && taxonomy_exists($taxonomy)) {
            $term_cache_key = $taxonomy . '::' . $value;
            if (!array_key_exists($term_cache_key, $term_cache)) $term_cache[$term_cache_key] = function_exists('get_term_by') ? get_term_by('slug', $value, $taxonomy) : null;
            $term = $term_cache[$term_cache_key];
            if ($term && !is_wp_error($term)) {
                $color_name = $term->name; $color_slug = $term->slug;
                $all_term_meta = function_exists('dms_ecom_get_all_term_meta') ? dms_ecom_get_all_term_meta($term->term_id) : array();
                $hex = $all_term_meta['color'][0] ?? ($all_term_meta['product_attribute_color'][0] ?? ($all_term_meta['_color'][0] ?? ''));
                if (!empty($hex) && function_exists('sanitize_hex_color')) $color_hex = sanitize_hex_color($hex);
            }
        }
        return array($color_name, $color_slug, $color_hex);
    }
    return array('', '', '');
}
}

if (!function_exists('dms_get_products_plus')) {
function dms_ecom_parse_id_list_param($value) {
    if (is_array($value)) {
        return array_values(array_filter(array_map('absint', $value)));
    }
    $raw = trim((string) $value);
    if ($raw === '') {
        return array();
    }
    return array_values(array_filter(array_map('absint', array_map('trim', explode(',', $raw)))));
}

function dms_ecom_truthy_param($value) {
    if (is_bool($value)) return $value;
    if (is_numeric($value)) return intval($value) === 1;
    $normalized = strtolower(trim((string) $value));
    return in_array($normalized, array('1', 'true', 'yes', 'on'), true);
}

function dms_ecom_normalize_term_slug_for_compare($value) {
    $value = trim((string) $value);
    if ($value === '') return '';
    $decoded = rawurldecode($value);
    $decoded = function_exists('sanitize_title') ? sanitize_title($decoded) : strtolower($decoded);
    return strtolower(trim((string) $decoded));
}

function dms_ecom_select_brand_term($brand_terms, $preferred_slug = '') {
    $brand_terms = is_array($brand_terms) ? array_values($brand_terms) : array();
    if (empty($brand_terms)) return null;

    $preferred = dms_ecom_normalize_term_slug_for_compare($preferred_slug);
    if ($preferred !== '') {
        foreach ($brand_terms as $term) {
            if (!$term || empty($term->slug)) continue;
            if (dms_ecom_normalize_term_slug_for_compare($term->slug) === $preferred) {
                return $term;
            }
        }
    }

    return $brand_terms[0];
}

function dms_ecom_brand_term_payload($term) {
    if (!$term) return null;
    $image = '';
    if (function_exists('dms_ecom_resolve_brand_image_url')) {
        $image = dms_ecom_resolve_brand_image_url($term);
    } elseif (function_exists('dms_ecom_get_attachment_url_cached') && function_exists('dms_ecom_get_term_meta_value')) {
        $image = dms_ecom_get_attachment_url_cached(dms_ecom_get_term_meta_value($term->term_id, 'thumbnail_id')) ?: (dms_ecom_get_term_meta_value($term->term_id, 'brand_image') ?: '');
    }

    return array(
        'id' => isset($term->term_id) ? (int) $term->term_id : 0,
        'name' => isset($term->name) ? $term->name : '',
        'slug' => isset($term->slug) ? $term->slug : '',
        'image_url' => $image,
    );
}

function dms_ecom_filter_products_plus_response($products, $request) {
    $filtered = is_array($products) ? $products : array();
    if (empty($filtered)) return $filtered;

    $min_price_raw = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('min_price') : null;
    if ($min_price_raw === null && is_object($request) && method_exists($request, 'get_param')) $min_price_raw = $request->get_param('minPrice');
    $max_price_raw = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('max_price') : null;
    if ($max_price_raw === null && is_object($request) && method_exists($request, 'get_param')) $max_price_raw = $request->get_param('maxPrice');
    $min_price = is_numeric($min_price_raw) ? floatval($min_price_raw) : null;
    $max_price = is_numeric($max_price_raw) ? floatval($max_price_raw) : null;
    $featured_only = is_object($request) && method_exists($request, 'get_param') ? dms_ecom_truthy_param($request->get_param('featured')) : false;

    if ($featured_only || $min_price !== null || $max_price !== null) {
        $filtered = array_values(array_filter($filtered, function ($product) use ($featured_only, $min_price, $max_price) {
            $is_featured = !empty($product['is_featured']) || !empty($product['featured']);
            if ($featured_only && !$is_featured) return false;
            $price = isset($product['price']) ? floatval($product['price']) : 0;
            if ($min_price !== null && $price < $min_price) return false;
            if ($max_price !== null && $price > $max_price) return false;
            return true;
        }));
    }

    $attribute = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('attribute'))) : '';
    $attribute_term = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('attribute_term'))) : '';
    if ($attribute !== '' && $attribute_term !== '') {
        $filtered = array_values(array_filter($filtered, function ($product) use ($attribute, $attribute_term) {
            foreach ((array) ($product['attributes'] ?? array()) as $attr) {
                $slug = strtolower(trim((string) ($attr['slug'] ?? $attr['name'] ?? '')));
                if ($slug !== $attribute) continue;
                foreach ((array) ($attr['options'] ?? array()) as $option) {
                    if (strtolower(trim((string) $option)) === $attribute_term) return true;
                }
            }
            return false;
        }));
    }

    $sku = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('sku'))) : '';
    $barcode = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('barcode'))) : '';
    if ($sku !== '' || $barcode !== '') {
        $filtered = array_values(array_filter($filtered, function ($product) use ($sku, $barcode) {
            $product_sku = strtolower(trim((string) ($product['sku'] ?? '')));
            if ($sku !== '' && $product_sku !== '' && strpos($product_sku, $sku) !== false) return true;
            if ($barcode !== '') {
                if ($product_sku !== '' && strpos($product_sku, $barcode) !== false) return true;
                foreach ((array) ($product['meta_data'] ?? array()) as $meta) {
                    $key = strtolower((string) ($meta['key'] ?? ''));
                    if ($key === '' || (strpos($key, 'barcode') === false && strpos($key, 'sku') === false && strpos($key, 'code') === false)) continue;
                    $value = strtolower(trim((string) ($meta['value'] ?? '')));
                    if ($value !== '' && strpos($value, $barcode) !== false) return true;
                }
            }
            return false;
        }));
    }

    return $filtered;
}

function dms_ecom_sort_products_plus_response($products, $request) {
    $sorted = is_array($products) ? array_values($products) : array();
    if (count($sorted) < 2) return $sorted;

    $sort = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('sort'))) : '';
    $orderby = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('orderby'))) : '';
    $order = is_object($request) && method_exists($request, 'get_param') ? strtoupper(trim((string) $request->get_param('order'))) : 'DESC';

    if ($sort === 'price_asc' || ($orderby === 'price' && $order === 'ASC')) {
        usort($sorted, function ($a, $b) { return floatval($a['price'] ?? 0) <=> floatval($b['price'] ?? 0); });
        return $sorted;
    }
    if ($sort === 'price_desc' || ($orderby === 'price' && $order !== 'ASC')) {
        usort($sorted, function ($a, $b) { return floatval($b['price'] ?? 0) <=> floatval($a['price'] ?? 0); });
        return $sorted;
    }
    return $sorted;
}

function dms_ecom_products_plus_wants_envelope($request) {
    if (!is_object($request) || !method_exists($request, 'get_param')) return false;
    return dms_ecom_truthy_param($request->get_param('envelope'))
        || dms_ecom_truthy_param($request->get_param('with_meta'))
        || strtolower(trim((string) $request->get_param('format'))) === 'envelope';
}

function dms_ecom_products_plus_meta($query, $page, $per_page, $count) {
    $total = 0;
    $total_pages = 0;
    if ($query instanceof WP_Query) {
        $total = isset($query->found_posts) ? (int) $query->found_posts : (int) $count;
        $total_pages = isset($query->max_num_pages) ? (int) $query->max_num_pages : 0;
    }
    if ($total <= 0) $total = (int) $count;
    if ($total_pages <= 0 && $per_page > 0) $total_pages = (int) ceil($total / $per_page);

    return array(
        'page' => max(1, (int) $page),
        'per_page' => (int) $per_page,
        'count' => (int) $count,
        'total' => (int) $total,
        'total_pages' => (int) $total_pages,
        'catalog_revision' => function_exists('lpco_dms_catalog_revision') ? (string) lpco_dms_catalog_revision() : '',
    );
}

function dms_ecom_products_plus_response($products, $request, $meta = array()) {
    $products = is_array($products) ? array_values($products) : array();
    $meta = is_array($meta) ? $meta : array();
    $payload = dms_ecom_products_plus_wants_envelope($request)
        ? array('data' => $products, 'meta' => $meta)
        : $products;

    if (class_exists('WP_REST_Response')) {
        $response = new WP_REST_Response($payload, 200);
        if (!empty($meta['total'])) $response->header('X-WP-Total', (string) $meta['total']);
        if (!empty($meta['total_pages'])) $response->header('X-WP-TotalPages', (string) $meta['total_pages']);
        if (!empty($meta['catalog_revision'])) $response->header('X-DMS-Catalog-Revision', (string) $meta['catalog_revision']);
        $response->header('Content-Type', 'application/json; charset=UTF-8');
        $response->header('X-Content-Type-Options', 'nosniff');
        return $response;
    }

    return $payload;
}

function dms_ecom_product_is_hidden_for_app($product_id, $product = null) {
    $product_id = absint($product_id);
    if ($product_id <= 0) return true;

    $product = $product instanceof WC_Product ? $product : (function_exists('wc_get_product') ? wc_get_product($product_id) : null);
    if ($product && method_exists($product, 'get_catalog_visibility') && $product->get_catalog_visibility() === 'hidden') {
        return true;
    }

    if (function_exists('has_term')
        && has_term('exclude-from-catalog', 'product_visibility', $product_id)
        && has_term('exclude-from-search', 'product_visibility', $product_id)) {
        return true;
    }

    $hide_keys = array(
        'dms_hide_in_app',
        'lpco_hide_in_app',
        'hide_in_app',
        'is_hidden',
        'hidden',
        'dms_hidden',
        'lpco_hidden',
        'app_hidden',
        'dms_app_hidden',
    );
    foreach ($hide_keys as $key) {
        if (dms_ecom_is_truthy_meta_value(get_post_meta($product_id, $key, true))) {
            return true;
        }
    }

    $show_keys = array('show_in_app', 'lpco_show_in_app', 'dms_show_in_app');
    foreach ($show_keys as $key) {
        $value = get_post_meta($product_id, $key, true);
        if ($value !== '' && $value !== null && !dms_ecom_is_truthy_meta_value($value)) {
            return true;
        }
    }

    $visibility_keys = array('visibility', 'app_visibility', 'dms_visibility');
    foreach ($visibility_keys as $key) {
        $visibility = strtolower(trim((string) get_post_meta($product_id, $key, true)));
        if ($visibility !== '' && in_array($visibility, array('hidden', 'hide', 'private', 'none', 'off', 'disabled', '0', 'false', 'no'), true)) {
            return true;
        }
    }

    return false;
}

function dms_ecom_get_visible_term_product_count($taxonomy, $term_id, $include_children = false) {
    static $count_cache = array();

    $taxonomy = function_exists('sanitize_key') ? sanitize_key((string) $taxonomy) : (string) $taxonomy;
    $term_id = function_exists('absint') ? absint($term_id) : (int) $term_id;
    if ($taxonomy === '' || $term_id <= 0 || !function_exists('taxonomy_exists') || !taxonomy_exists($taxonomy)) {
        return 0;
    }

    $cache_key = $taxonomy . ':' . $term_id . ':' . ($include_children ? '1' : '0');
    if (array_key_exists($cache_key, $count_cache)) {
        return $count_cache[$cache_key];
    }

    $query = class_exists('WP_Query') ? new WP_Query(array(
        'post_type' => 'product',
        'post_status' => 'publish',
        'fields' => 'ids',
        'posts_per_page' => -1,
        'no_found_rows' => true,
        'update_post_meta_cache' => true,
        'update_post_term_cache' => true,
        'tax_query' => array(
            array(
                'taxonomy' => $taxonomy,
                'field' => 'term_id',
                'terms' => array($term_id),
                'include_children' => (bool) $include_children,
            ),
        ),
    )) : null;

    if (!$query) {
        $count_cache[$cache_key] = 0;
        return 0;
    }

    $count = 0;
    foreach ((array) $query->posts as $product_id) {
        $product_id = function_exists('absint') ? absint($product_id) : (int) $product_id;
        if ($product_id <= 0) continue;

        $product = function_exists('wc_get_product') ? wc_get_product($product_id) : null;
        if (function_exists('wc_get_product') && !$product) continue;
        if (function_exists('dms_ecom_product_is_hidden_for_app') && dms_ecom_product_is_hidden_for_app($product_id, $product)) continue;

        $count++;
    }

    if (function_exists('wp_reset_postdata')) wp_reset_postdata();
    $count_cache[$cache_key] = $count;
    return $count;
}

function dms_ecom_catalog_barcode_meta_keys() {
    if (function_exists('lpco_dms_product_barcode_meta_keys')) {
        return lpco_dms_product_barcode_meta_keys();
    }
    return array('_barcode_1', '_barcode_2', '_barcode_3', '_barcode_4');
}

function dms_ecom_catalog_search_meta_keys() {
    return array_values(array_unique(array_merge(
        array('_sku'),
        dms_ecom_catalog_barcode_meta_keys(),
        array('_global_unique_id', 'barcode', '_barcode', 'dms_barcode', '_dms_barcode', 'product_barcode')
    )));
}

function dms_ecom_append_unique_product_ids(&$ids, $candidates, $limit = 2000) {
    $limit = max(1, absint($limit));
    foreach ((array) $candidates as $candidate_id) {
        $candidate_id = absint($candidate_id);
        if ($candidate_id <= 0 || in_array($candidate_id, $ids, true)) {
            continue;
        }
        $ids[] = $candidate_id;
        if (count($ids) >= $limit) {
            break;
        }
    }
}

function dms_ecom_get_product_barcode_payload($product_id, $product_meta = array()) {
    $product_id = absint($product_id);
    $payload = array(
        'barcode_1' => '',
        'barcode_2' => '',
        'barcode_3' => '',
        'barcode_4' => '',
        'barcodes' => array(),
    );
    if ($product_id <= 0) return $payload;

    $seen = array();
    foreach (dms_ecom_catalog_barcode_meta_keys() as $index => $meta_key) {
        $field = 'barcode_' . ($index + 1);
        $raw_value = array_key_exists($meta_key, (array) $product_meta)
            ? $product_meta[$meta_key]
            : (function_exists('get_post_meta') ? get_post_meta($product_id, $meta_key, true) : '');
        if (is_array($raw_value)) {
            $raw_value = reset($raw_value);
        }
        $value = is_scalar($raw_value) ? trim((string) $raw_value) : '';
        $payload[$field] = $value;
        if ($value !== '' && !isset($seen[$value])) {
            $seen[$value] = true;
            $payload['barcodes'][] = $value;
        }
    }

    return $payload;
}

function dms_ecom_find_catalog_search_ids($search, $limit = 2000) {
    global $wpdb;
    $search = trim((string) $search);
    if ($search === '' || !isset($wpdb) || !is_object($wpdb)) return array();

    $limit = max(1, absint($limit));
    $ids = array();
    $meta_keys = dms_ecom_catalog_search_meta_keys();
    $meta_placeholders = implode(',', array_fill(0, count($meta_keys), '%s'));

    $exact_args = array_merge($meta_keys, array($search, $limit));
    $exact_sql = $wpdb->prepare(
        "SELECT DISTINCT p.ID
         FROM {$wpdb->posts} p
         INNER JOIN {$wpdb->postmeta} pm
            ON pm.post_id = p.ID
            AND pm.meta_key IN ($meta_placeholders)
         WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            AND pm.meta_value = %s
         ORDER BY CASE WHEN pm.meta_key = '_sku' THEN 0 ELSE 1 END, p.ID DESC
         LIMIT %d",
        $exact_args
    );
    if ($exact_sql) {
        dms_ecom_append_unique_product_ids($ids, $wpdb->get_col($exact_sql), $limit);
    }

    if (count($ids) < $limit && function_exists('wc_get_product_id_by_sku')) {
        $sku_product_id = absint(wc_get_product_id_by_sku($search));
        if ($sku_product_id > 0 && get_post_type($sku_product_id) === 'product' && get_post_status($sku_product_id) === 'publish') {
            dms_ecom_append_unique_product_ids($ids, array($sku_product_id), $limit);
        }
    }

    if (count($ids) < $limit && ctype_digit($search)) {
        $candidate_id = absint($search);
        if ($candidate_id > 0 && get_post_type($candidate_id) === 'product' && get_post_status($candidate_id) === 'publish') {
            dms_ecom_append_unique_product_ids($ids, array($candidate_id), $limit);
        }
    }

    if (count($ids) >= $limit) {
        return $ids;
    }

    $like = '%' . $wpdb->esc_like($search) . '%';
    $args = array_merge(
        $meta_keys,
        array($like, $like, $like, $like, $like, $limit)
    );

    $sql = $wpdb->prepare(
        "SELECT DISTINCT p.ID
         FROM {$wpdb->posts} p
         LEFT JOIN {$wpdb->postmeta} pm
            ON pm.post_id = p.ID
            AND pm.meta_key IN ($meta_placeholders)
         WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            AND (
                p.post_title LIKE %s
                OR p.post_name LIKE %s
                OR p.post_excerpt LIKE %s
                OR p.post_content LIKE %s
                OR pm.meta_value LIKE %s
            )
         ORDER BY p.post_date_gmt DESC, p.ID DESC
         LIMIT %d",
        $args
    );

    if (!$sql) return array();
    dms_ecom_append_unique_product_ids($ids, $wpdb->get_col($sql), $limit);
    return $ids;
}

function dms_get_catalog_version($request) {
    global $wpdb;
    $updated_at = get_option('lpco_dms_products_updated_at', '');
    if ($updated_at === '' && isset($wpdb) && is_object($wpdb)) {
        $updated_at = (string) $wpdb->get_var(
            "SELECT MAX(post_modified_gmt) FROM {$wpdb->posts} WHERE post_type = 'product' AND post_status = 'publish'"
        );
    }

    return array(
        'catalog_revision' => function_exists('lpco_dms_catalog_revision') ? (string) lpco_dms_catalog_revision() : '',
        'products_updated_at' => $updated_at ? (strpos((string) $updated_at, 'T') !== false ? (string) $updated_at : mysql_to_rfc3339($updated_at)) : '',
        'plugin_version' => '7.0',
    );
}

function dms_ecom_product_diagnostics_scope_result($product_id, $guest = true) {
    if (!class_exists('WP_REST_Request')) {
        return array('appears' => false, 'ids' => array());
    }

    $request = new WP_REST_Request('GET', '/dms/v1/products-plus');
    $request->set_param('include', (string) absint($product_id));
    $request->set_param('per_page', 1);
    if ($guest) {
        $request->set_param('guest', 1);
    }

    $response = dms_get_products_plus($request);
    $payload = $response instanceof WP_REST_Response ? $response->get_data() : $response;
    $rows = is_array($payload) && isset($payload['data']) ? $payload['data'] : $payload;
    $ids = array();
    foreach ((array) $rows as $row) {
        if (is_array($row) && isset($row['id'])) $ids[] = absint($row['id']);
    }

    return array('appears' => in_array(absint($product_id), $ids, true), 'ids' => $ids);
}

function dms_get_product_diagnostics($request) {
    if (!current_user_can('manage_woocommerce')) {
        return new WP_Error('forbidden', 'Forbidden', array('status' => 403));
    }

    $product_id = is_object($request) && method_exists($request, 'get_param') ? absint($request->get_param('id')) : 0;
    if ($product_id <= 0) {
        return new WP_Error('invalid_product_id', 'Product id is required.', array('status' => 400));
    }

    $post = get_post($product_id);
    $product = function_exists('wc_get_product') ? wc_get_product($product_id) : null;
    $brand_tax = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
    $reasons = array();

    if (!$post) {
        $reasons[] = 'product_not_found';
    } else {
        if ($post->post_type !== 'product') $reasons[] = 'not_product_post_type';
        if ($post->post_status !== 'publish') $reasons[] = 'not_published';
    }
    if (!$product) $reasons[] = 'wc_product_not_loaded';
    if ($product && dms_ecom_product_is_hidden_for_app($product_id, $product)) $reasons[] = 'hidden_from_app_or_catalog';

    $categories = array();
    foreach ((array) get_the_terms($product_id, 'product_cat') as $term) {
        if ($term && !is_wp_error($term)) $categories[] = array('id' => $term->term_id, 'name' => $term->name, 'slug' => $term->slug);
    }

    $brands = array();
    foreach ((array) get_the_terms($product_id, $brand_tax) as $term) {
        if ($term && !is_wp_error($term)) $brands[] = array('id' => $term->term_id, 'name' => $term->name, 'slug' => $term->slug);
    }

    return array(
        'exists' => (bool) $post,
        'product_id' => $product_id,
        'post_status' => $post ? $post->post_status : null,
        'post_type' => $post ? $post->post_type : null,
        'catalog_visibility' => ($product && method_exists($product, 'get_catalog_visibility')) ? $product->get_catalog_visibility() : null,
        'stock_status' => ($product && method_exists($product, 'get_stock_status')) ? $product->get_stock_status() : null,
        'categories' => $categories,
        'brands' => $brands,
        '_custom_product_order' => get_post_meta($product_id, '_custom_product_order', true),
        '_stock_status' => get_post_meta($product_id, '_stock_status', true),
        '_dms_prices' => get_post_meta($product_id, '_dms_prices', true),
        'appears_guest_query' => dms_ecom_product_diagnostics_scope_result($product_id, true),
        'appears_auth_query' => dms_ecom_product_diagnostics_scope_result($product_id, false),
        'exclusion_reasons' => array_values(array_unique($reasons)),
        'catalog_revision' => function_exists('lpco_dms_catalog_revision') ? (string) lpco_dms_catalog_revision() : '',
    );
}

function dms_get_products_plus($request) {
    if (!function_exists('absint')) return array();
    $per_page = is_object($request) && method_exists($request, 'get_param') ? intval($request->get_param('per_page') ?: 100) : 100;
    $per_page = max(1, min(100, $per_page));
    $page = is_object($request) && method_exists($request, 'get_param') ? max(1, absint($request->get_param('page') ?: 1)) : 1;
    $category = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('category') : null;
    $category_ids = function_exists('dms_ecom_parse_id_list_param') ? dms_ecom_parse_id_list_param($category) : array();
    $search = is_object($request) && method_exists($request, 'get_param') ? sanitize_text_field((string) $request->get_param('search')) : '';
    $slug = is_object($request) && method_exists($request, 'get_param') ? sanitize_title((string) $request->get_param('slug')) : '';
    $brand_slug = is_object($request) && method_exists($request, 'get_param') ? sanitize_title((string) $request->get_param('brand_slug')) : '';
    $stock_order = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('stock_order') : null; 
    $latest_days = is_object($request) && method_exists($request, 'get_param') ? absint($request->get_param('latest_days')) : 0; 
    $stock_status = '';
    if (is_object($request) && method_exists($request, 'get_param')) {
        $raw_stock = $request->get_param('stock');
        if ($raw_stock === null || $raw_stock === '') $raw_stock = $request->get_param('stock_status');
        if ($raw_stock !== null && $raw_stock !== '') $stock_status = function_exists('sanitize_text_field') ? sanitize_text_field($raw_stock) : $raw_stock;
    }
    $include = is_object($request) && method_exists($request, 'get_param') ? $request->get_param('include') : null;
    $include_ids = function_exists('dms_ecom_parse_id_list_param') ? dms_ecom_parse_id_list_param($include) : array();
    $include_gallery = is_object($request) && method_exists($request, 'get_param')
        ? (dms_ecom_truthy_param($request->get_param('include_gallery')) || dms_ecom_truthy_param($request->get_param('gallery')))
        : false;
    $featured_only = is_object($request) && method_exists($request, 'get_param') ? dms_ecom_truthy_param($request->get_param('featured')) : false;
    $orderby = is_object($request) && method_exists($request, 'get_param') ? strtolower(trim((string) $request->get_param('orderby'))) : '';
    $order = is_object($request) && method_exists($request, 'get_param') ? strtoupper(trim((string) $request->get_param('order'))) : 'DESC';
    $is_guest = function_exists('lpco_dms_is_guest_request') ? lpco_dms_is_guest_request($request) : true;
    list($current_user_id, $current_group, $current_currency) = dms_ecom_get_request_user_context($request, $is_guest);
    
    $cache_key = $is_guest ? (function_exists('lpco_dms_guest_cache_key') ? lpco_dms_guest_cache_key('products_plus', $request) : '') : (function_exists('lpco_dms_auth_cache_key') ? lpco_dms_auth_cache_key('products_plus', $request, $current_user_id, $current_group, $current_currency) : '');
    $cached = $is_guest ? (function_exists('lpco_dms_guest_cache_get') ? lpco_dms_guest_cache_get($cache_key) : false) : (function_exists('lpco_dms_auth_cache_get') ? lpco_dms_auth_cache_get($cache_key) : false);
    if ($cached !== false) {
        if ($is_guest && function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('products_plus_guest_' . md5(wp_json_encode($cached)));
        return $cached;
    }
    
    $has_brand_taxonomy = function_exists('taxonomy_exists') ? taxonomy_exists('product_brand') : false;
    $order_meta_key = dms_ecom_get_app_order_meta_key($brand_slug);

    if (!empty($include_ids)) {
        $per_page = count($include_ids);
        $args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'post__in' => $include_ids,
            'orderby' => 'post__in',
            'posts_per_page' => $per_page,
            'paged' => 1,
            'no_found_rows' => false,
            'update_post_meta_cache' => true,
            'update_post_term_cache' => true,
        );
    } else {
        $args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => $per_page,
            'paged' => $page,
            'no_found_rows' => false,
            'update_post_meta_cache' => true,
            'update_post_term_cache' => true,
        );

        if (!empty($stock_status) && $stock_status !== 'all') {
            $args['meta_query']['stock_status'] = array(
                'key' => '_stock_status',
                'value' => $stock_status,
                'compare' => '=',
            );
        }

        if (function_exists('dms_apply_product_ordering_args')) {
            $args = dms_apply_product_ordering_args($args, $order_meta_key);
        }

        $tax_query = array();
        if (!empty($category_ids)) $tax_query[] = array('taxonomy' => 'product_cat', 'field' => 'term_id', 'terms' => $category_ids);
        if ($brand_slug) $tax_query[] = array('taxonomy' => $has_brand_taxonomy ? 'product_brand' : 'product_tag', 'field' => 'slug', 'terms' => $brand_slug);
        if (!empty($tax_query)) { $args['tax_query'] = $tax_query; if (count($tax_query) > 1) $args['tax_query']['relation'] = 'AND'; }

        if ($slug !== '') {
            $args['name'] = $slug;
        }

        if ($search !== '') {
            $search_ids = dms_ecom_find_catalog_search_ids($search);
            if (empty($search_ids)) {
                $meta = dms_ecom_products_plus_meta(null, $page, $per_page, 0);
                return dms_ecom_products_plus_response(array(), $request, $meta);
            }
            $args['post__in'] = $search_ids;
            $args['orderby'] = 'post__in';
            $args['posts_per_page'] = min($per_page, count($search_ids));
            $args['paged'] = 1;
        }

        if ($featured_only) {
            if (empty($args['meta_query'])) $args['meta_query'] = array();
            $args['meta_query'][] = array('key' => '_featured', 'value' => 'yes', 'compare' => '=');
        }

        if ($latest_days > 0 && dms_ecom_manual_latest_enabled() && empty($category) && empty($search) && empty($brand_slug)) {
            $args['meta_query'] = array(array('key' => '_dms_app_latest_order', 'compare' => 'EXISTS'));
            $args['meta_key'] = '_dms_app_latest_order'; $args['orderby'] = 'meta_value_num'; $args['order'] = 'ASC';
        } elseif ($latest_days > 0) {
            $after_ts = (function_exists('current_time') ? current_time('timestamp', true) : time()) - ($latest_days * (defined('DAY_IN_SECONDS') ? DAY_IN_SECONDS : 86400));
            $args['date_query'] = array(array('after' => gmdate('Y-m-d H:i:s', $after_ts), 'inclusive' => true, 'column' => 'post_date_gmt'));
            $args['orderby'] = 'date'; $args['order'] = 'DESC';
        }

        if ($stock_order === 'in_first' && empty($brand_slug) && $latest_days <= 0) {
            if (empty($args['meta_query'])) $args['meta_query'] = array();
            if (empty($stock_status) || $stock_status === 'all') {
                $args['meta_query']['stock_status'] = array('key' => '_stock_status', 'compare' => 'EXISTS');
            }
            $args['orderby'] = array('stock_status' => 'ASC', 'dms_order_exists' => 'ASC', 'date' => 'DESC', 'ID' => 'DESC');
        }
        if ($orderby === 'date') {
            $args['orderby'] = 'date';
            $args['order'] = $order === 'ASC' ? 'ASC' : 'DESC';
        }
    }
    
    $query = class_exists('WP_Query') ? new WP_Query($args) : null;
    if (!$query) return dms_ecom_products_plus_response(array(), $request, dms_ecom_products_plus_meta(null, $page, $per_page, 0));
    $prepared = dms_ecom_prime_product_query_context($query, $has_brand_taxonomy, array_merge(array($order_meta_key), dms_ecom_catalog_barcode_meta_keys()));
    $product_meta_map = $prepared['meta'];
    $products = array();
    
    if ($query->have_posts()) {
        while ($query->have_posts()) {
            $query->the_post(); $product_id = function_exists('get_the_ID') ? get_the_ID() : 0;
            if (!$product_id) continue;
            $product = $prepared['products'][$product_id] ?? (function_exists('wc_get_product') ? wc_get_product($product_id) : null);
            if (!$product) continue;
            if (function_exists('dms_ecom_product_is_hidden_for_app') && dms_ecom_product_is_hidden_for_app($product_id, $product)) continue;
            
            $product_meta = $product_meta_map[$product_id] ?? array();
            $dms_prices = array_key_exists('_dms_prices', $product_meta) ? $product_meta['_dms_prices'] : (function_exists('get_post_meta') ? get_post_meta($product_id, '_dms_prices', true) : array());

            $unit_options = dms_ecom_build_unit_options_payload(
                $product_id,
                $product,
                $dms_prices,
                $current_group,
                $current_currency,
                $is_guest
            );
            $piece_price = !empty($unit_options) ? floatval($unit_options[0]['price'] ?? 0) : 0;
            $unit_display_default_ar = !empty($unit_options) ? ($unit_options[0]['label_display_ar'] ?? null) : null;
            $unit_display_default_en = !empty($unit_options) ? ($unit_options[0]['label_display_en'] ?? null) : null;

            $brand_terms = $prepared['brands'][$product_id] ?? array();
            $brand_term = function_exists('dms_ecom_select_brand_term') ? dms_ecom_select_brand_term($brand_terms, $brand_slug) : ($brand_terms[0] ?? null);
            $brand_payload = function_exists('dms_ecom_brand_term_payload') ? dms_ecom_brand_term_payload($brand_term) : null;
            $brands_payload = array();
            foreach ((array) $brand_terms as $bt) {
                $payload = function_exists('dms_ecom_brand_term_payload') ? dms_ecom_brand_term_payload($bt) : null;
                if ($payload) $brands_payload[] = $payload;
            }
            
            $cats_payload = array(); $cat_terms = $prepared['categories'][$product_id] ?? array();
            foreach ($cat_terms as $cat) {
                $cats_payload[] = array('id' => $cat->term_id, 'name' => $cat->name, 'slug' => $cat->slug, 'image_url' => (function_exists('dms_ecom_get_attachment_url_cached') && function_exists('dms_ecom_get_term_meta_value')) ? dms_ecom_get_attachment_url_cached(dms_ecom_get_term_meta_value($cat->term_id, 'thumbnail_id')) : '', 'count' => $cat->count);
            }
            
            $attrs_payload = array();
            if (method_exists($product, 'get_attributes')) {
                foreach ($product->get_attributes() as $a) {
                    if (is_a($a, 'WC_Product_Attribute')) {
                        $opts = method_exists($a, 'get_options') ? $a->get_options() : array(); $attrs_payload[] = array('name' => method_exists($a, 'get_name') ? $a->get_name() : '', 'slug' => method_exists($a, 'get_name') ? $a->get_name() : '', 'options' => is_array($opts) ? array_values(array_map('wc_clean', array_map('strval', $opts))) : array(), 'variation' => method_exists($a, 'get_variation') ? $a->get_variation() : false, 'visible' => method_exists($a, 'get_visible') ? $a->get_visible() : false, 'required' => (method_exists($a, 'get_variation') && $a->get_variation()) ? true : false);
                    }
                }
            }
            
            $vars_payload = array(); $color_opts = array();
            if (method_exists($product, 'is_type') && $product->is_type('variable') && method_exists($product, 'get_children')) {
                foreach ($product->get_children() as $vid) {
                    $vp = $prepared['variations'][$vid] ?? (function_exists('wc_get_product') ? wc_get_product($vid) : null);
                    if (!$vp) continue;
                    $raw_attrs = method_exists($vp, 'get_attributes') ? $vp->get_attributes() : array(); $attrs_map = array();
                    foreach ($raw_attrs as $k => $v) $attrs_map[(strpos((string)$k,'attribute_')===0 ? $k : 'attribute_'.$k)] = is_array($v) ? (is_array($v) ? reset($v) : $v) : $v;
                    list($cn, $cs, $ch) = dms_ecom_extract_color_from_attributes($attrs_map);
                    $vars_payload[] = array('id' => $vid, 'variation_id' => $vid, 'price' => method_exists($vp, 'get_price') ? floatval($vp->get_price()) : 0, 'regular_price' => method_exists($vp, 'get_regular_price') ? floatval($vp->get_regular_price()) : 0, 'stock_status' => (method_exists($vp, 'is_in_stock') && $vp->is_in_stock()) ? 'instock' : 'outofstock', 'is_in_stock' => method_exists($vp, 'is_in_stock') ? $vp->is_in_stock() : false, 'stock_quantity' => method_exists($vp, 'get_stock_quantity') ? $vp->get_stock_quantity() : 0, 'image' => array('src' => method_exists($vp, 'get_image_id') ? dms_ecom_get_attachment_url_cached($vp->get_image_id()) : ''), 'attributes' => $attrs_map, 'color_name' => $cn, 'color_slug' => $cs, 'color_hex' => $ch);
                    $ck = $cs ?: $cn;
                    if ($ck !== '') { $exist = $color_opts[$ck] ?? null; if (!$exist || (!$exist['is_in_stock'] && method_exists($vp, 'is_in_stock') && $vp->is_in_stock())) $color_opts[$ck] = array('color_name' => $cn ?: $cs, 'color_slug' => $cs ?: $cn, 'variation_id' => $vid, 'color_hex' => $ch, 'is_in_stock' => method_exists($vp, 'is_in_stock') ? $vp->is_in_stock() : false); }
                }
            }
            
            $image_id = method_exists($product, 'get_image_id') ? $product->get_image_id() : 0;
            $image_src = $image_id ? (function_exists('dms_ecom_get_attachment_url_cached') ? dms_ecom_get_attachment_url_cached($image_id) : '') : '';
            $images_payload = $include_gallery && function_exists('dms_ecom_build_product_images_payload')
                ? dms_ecom_build_product_images_payload($product)
                : ($image_id ? array(array('id' => $image_id, 'src' => $image_src)) : array());
            $is_featured = method_exists($product, 'is_featured') ? $product->is_featured() : (array_key_exists('_featured', $product_meta) ? $product_meta['_featured'] === 'yes' : false);
            $stock_status = (method_exists($product, 'get_stock_status') ? $product->get_stock_status() : 'outofstock') ?: 'outofstock';
            $barcode_payload = dms_ecom_get_product_barcode_payload($product_id, $product_meta);
            $app_order_value = function_exists('dms_ecom_get_product_order_value') ? dms_ecom_get_product_order_value($product_id, $product_meta, $order_meta_key) : 999;
            $global_order_value = function_exists('dms_ecom_get_product_order_value') ? dms_ecom_get_product_order_value($product_id, $product_meta, '_custom_product_order') : $app_order_value;

            $product_data = array(
                'id' => $product_id, 
                'name' => method_exists($product, 'get_name') ? $product->get_name() : '', 
                'slug' => method_exists($product, 'get_slug') ? $product->get_slug() : (function_exists('get_post_field') ? get_post_field('post_name', $product_id) : ''),
                'sku' => method_exists($product, 'get_sku') ? $product->get_sku() : '', 
                'description' => method_exists($product, 'get_description') ? $product->get_description() : '', 
                'short_description' => method_exists($product, 'get_short_description') ? $product->get_short_description() : '', 
                'price' => $piece_price, 
                'regular_price' => method_exists($product, 'get_regular_price') ? floatval($product->get_regular_price()) : $piece_price,
                'sale_price' => method_exists($product, 'get_sale_price') ? floatval($product->get_sale_price()) : $piece_price,
                'stock_status' => $stock_status, 
                'in_stock' => ($stock_status === 'instock' || $stock_status === 'onbackorder'),
                'stock_quantity' => method_exists($product, 'get_stock_quantity') ? $product->get_stock_quantity() : 0,
                'image_url' => $image_src, 
                'images' => $images_payload,
                'brand' => $brand_payload,
                'brands' => $brands_payload,
                'categories' => $cats_payload, 
                'attributes' => $attrs_payload, 
                'variations' => $vars_payload, 
                'color_options' => array_values($color_opts), 
                'unit_options' => $unit_options,
                'unit_display_default_ar' => $unit_display_default_ar,
                'unit_display_default_en' => $unit_display_default_en,
                'is_featured' => $is_featured,
                'custom_order' => $app_order_value,
                'app_order' => $app_order_value,
                'brand_order' => $brand_slug ? $app_order_value : $global_order_value,
                'meta_data' => array(array('key' => '_dms_prices', 'value' => $dms_prices ?: array()))
            );
            $product_data['barcode_1'] = $barcode_payload['barcode_1'];
            $product_data['barcode_2'] = $barcode_payload['barcode_2'];
            $product_data['barcode_3'] = $barcode_payload['barcode_3'];
            $product_data['barcode_4'] = $barcode_payload['barcode_4'];
            $product_data['barcodes'] = $barcode_payload['barcodes'];
            foreach (dms_ecom_catalog_barcode_meta_keys() as $index => $barcode_meta_key) {
                $product_data['meta_data'][] = array('key' => $barcode_meta_key, 'value' => $barcode_payload['barcode_' . ($index + 1)] ?? '');
            }
            $products[] = $product_data;
        }
    }
    if (function_exists('wp_reset_postdata')) wp_reset_postdata();
    if (function_exists('dms_ecom_filter_products_plus_response')) $products = dms_ecom_filter_products_plus_response($products, $request);
    if (function_exists('dms_ecom_sort_products_plus_response')) $products = dms_ecom_sort_products_plus_response($products, $request);
    $meta = dms_ecom_products_plus_meta($query, $page, $per_page, count($products));
    $payload = dms_ecom_products_plus_wants_envelope($request) ? array('data' => $products, 'meta' => $meta) : $products;
    if ($is_guest && $cache_key) { if (function_exists('lpco_dms_guest_cache_set')) lpco_dms_guest_cache_set($cache_key, $payload); if (function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('products_plus_guest_' . md5(wp_json_encode($payload))); } elseif ($cache_key) { if (function_exists('lpco_dms_auth_cache_set')) lpco_dms_auth_cache_set($cache_key, $payload); }
    return dms_ecom_products_plus_response($products, $request, $meta);
}
function dms_get_categories_base($request) {
    if (!function_exists('absint')) return array();
    $terms = function_exists('get_terms') ? get_terms(array('taxonomy' => 'product_cat', 'hide_empty' => false, 'pad_counts' => true, 'update_term_meta_cache' => true, 'orderby' => 'menu_order', 'order' => 'ASC')) : array();
    if (is_wp_error($terms)) return $terms;
    
    $results = array();
    foreach ($terms as $t) {
        $formatted = dms_format_category_term($t);
        if ($formatted) {
            $results[] = $formatted;
        }
    }
    
    if (function_exists('lpco_app_layout_config_get') && function_exists('lpco_app_layout_apply_order')) {
        $cfg = lpco_app_layout_config_get();
        if (!empty($cfg['categories'])) {
            $results = lpco_app_layout_apply_order($results, $cfg['categories'], 'id');
        }
    }
    
    $results = array_values($results);
    
    return $results;
}
}

if (!function_exists('dms_get_categories_guest')) {
function dms_get_categories_guest($request) {
    if (function_exists('wp_set_current_user')) wp_set_current_user(0);
    if (is_object($request) && method_exists($request, 'get_param') && method_exists($request, 'set_param')) {
        if (!$request->get_param('guest') && !$request->get_param('mode')) $request->set_param('guest', 1);
    }
    $cats = dms_get_categories_base($request);
    if (!is_wp_error($cats) && function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('categories_guest_' . md5(wp_json_encode($cats)));
    return $cats;
}
}

if (!function_exists('dms_get_categories_auth')) {
function dms_get_categories_auth($request) {
    $cats = dms_get_categories_base($request);
    if (!is_wp_error($cats) && function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('categories_auth_' . md5(wp_json_encode($cats)));
    return $cats;
}
}

if (!function_exists('dms_home_by_category')) {
function dms_home_by_category($request) {
    $per_category = is_object($request) && method_exists($request, 'get_param') ? max(-1, intval($request->get_param('per_category') ?: -1)) : -1;
    $is_guest = function_exists('lpco_dms_is_guest_request') ? lpco_dms_is_guest_request($request) : true;
    list($uid, $grp, $cur) = dms_ecom_get_request_user_context($request, $is_guest);
    $ckey = $is_guest ? (function_exists('lpco_dms_guest_cache_key') ? lpco_dms_guest_cache_key('home_by_category', $request) : '') : (function_exists('lpco_dms_auth_cache_key') ? lpco_dms_auth_cache_key('home_by_category', $request, $uid, $grp, $cur) : '');
    if ($ckey && function_exists('lpco_dms_guest_cache_get') && ($cached = ($is_guest ? lpco_dms_guest_cache_get($ckey) : (function_exists('lpco_dms_auth_cache_get') ? lpco_dms_auth_cache_get($ckey) : false))) !== false) {
        if (function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('home_by_category_' . md5(wp_json_encode($cached)));
        return $cached;
    }
    $cats = dms_get_categories_base($request);
    if (is_wp_error($cats)) return $cats;
    if (empty($cats)) return array('categories' => array());
    
    $all_prods = array();
    if (class_exists('WP_REST_Request')) {
        $preq = new WP_REST_Request('GET', '/dms/v1/products');
        $preq->set_param('per_page', -1); $preq->set_param('page', 1); $preq->set_param('stock_order', 'in_first');
        if ($is_guest) $preq->set_param('guest', 1);
        if (is_object($request) && method_exists($request, 'get_param')) {
            if ($request->get_param('user_group')) $preq->set_param('user_group', $request->get_param('user_group'));
            if ($request->get_param('currency')) $preq->set_param('currency', $request->get_param('currency'));
        }
        if (function_exists('dms_get_products_with_prices')) {
            $all_prods = dms_get_products_with_prices($preq);
        }
    }
    
    if (is_wp_error($all_prods)) $all_prods = array();
    $by_cat = array();
    foreach ($all_prods as $p) {
        if (empty($p['categories'])) continue;
        foreach ($p['categories'] as $c_item) { if ($cid = (int)($c_item['id']??0)) $by_cat[$cid][] = $p; }
    }
    $resp = array();
    foreach ($cats as $c) {
        $c_prods = $by_cat[$c['id']] ?? array();
        if ($per_category > 0) $c_prods = array_slice($c_prods, 0, $per_category);
        $resp[] = array('id' => $c['id'], 'name' => $c['name'], 'products' => $c_prods);
    }
    $payload = array('categories' => $resp);
    if ($ckey && function_exists('lpco_dms_guest_cache_set')) {
        if ($is_guest) lpco_dms_guest_cache_set($ckey, $payload); elseif (function_exists('lpco_dms_auth_cache_set')) lpco_dms_auth_cache_set($ckey, $payload);
    }
    if (function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('home_by_category_' . md5(wp_json_encode($payload)));
    return $payload;
}
}

if (!function_exists('dms_ecom_resolve_brand_image_url')) {
function dms_ecom_resolve_brand_image_url($term) {
    if (!class_exists('WP_Term') || !($term instanceof WP_Term)) return '';
    if (!function_exists('dms_ecom_get_term_meta_value')) return '';
    $cands = array(dms_ecom_get_term_meta_value($term->term_id, 'thumbnail_id'), dms_ecom_get_term_meta_value($term->term_id, 'brand_logo_id'), dms_ecom_get_term_meta_value($term->term_id, 'brand_image_id'), dms_ecom_get_term_meta_value($term->term_id, 'brand_logo'), dms_ecom_get_term_meta_value($term->term_id, 'brand_image'));
    foreach ($cands as $val) {
        if (empty($val)) continue;
        if (function_exists('dms_ecom_get_attachment_url_cached') && is_numeric($val)) {
            $url = dms_ecom_get_attachment_url_cached($val);
        } else {
            $url = function_exists('esc_url_raw') ? esc_url_raw($val) : $val;
        }
        if (!empty($url)) return $url;
    }
    return '';
}
}

if (!function_exists('dms_ecom_brand_category_slug_matches')) {
function dms_ecom_brand_category_slug_matches($category_slug, $brand_slug) {
    $category_slug = sanitize_title((string) $category_slug);
    $brand_slug = sanitize_title((string) $brand_slug);
    if ($category_slug === '' || $brand_slug === '') return false;
    return $category_slug === $brand_slug
        || strpos($category_slug, $brand_slug . '-') === 0
        || substr($category_slug, -strlen('-' . $brand_slug)) === '-' . $brand_slug
        || strpos($category_slug, '-' . $brand_slug . '-') !== false;
}
}

if (!function_exists('dms_ecom_get_linked_categories_for_brand')) {
function dms_ecom_get_linked_categories_for_brand($brand_slug) {
    $brand_slug = sanitize_title((string) $brand_slug);
    if ($brand_slug === '' || !function_exists('get_terms')) {
        return array('ids' => array(), 'slugs' => array());
    }

    $terms = get_terms(array(
        'taxonomy' => 'product_cat',
        'hide_empty' => false,
        'update_term_meta_cache' => true,
        'orderby' => 'menu_order',
        'order' => 'ASC',
    ));
    if (is_wp_error($terms) || empty($terms)) {
        return array('ids' => array(), 'slugs' => array());
    }

    $root_ids = array();
    foreach ((array) $terms as $term) {
        if (!$term || (function_exists('dms_ecom_is_hidden_term_for_app') && dms_ecom_is_hidden_term_for_app($term, 'product_cat'))) {
            continue;
        }
        if (sanitize_title((string) $term->slug) === $brand_slug) {
            $root_ids[(int) $term->term_id] = true;
        }
    }

    $matched = array();
    foreach ((array) $terms as $term) {
        if (!$term || (function_exists('dms_ecom_is_hidden_term_for_app') && dms_ecom_is_hidden_term_for_app($term, 'product_cat'))) {
            continue;
        }
        $term_id = (int) $term->term_id;
        $is_root = isset($root_ids[$term_id]);
        $is_child = isset($root_ids[(int) $term->parent]);
        $is_token_match = dms_ecom_brand_category_slug_matches($term->slug, $brand_slug);
        if (!$is_root && !$is_child && !$is_token_match) {
            continue;
        }
        $matched[$term_id] = $term;
    }

    uasort($matched, function($a, $b) use ($root_ids) {
        $a_root = isset($root_ids[(int) $a->term_id]);
        $b_root = isset($root_ids[(int) $b->term_id]);
        if ($a_root !== $b_root) return $a_root ? -1 : 1;
        $a_order = function_exists('dms_ecom_get_term_meta_value') ? intval(dms_ecom_get_term_meta_value($a->term_id, 'menu_order')) : 0;
        $b_order = function_exists('dms_ecom_get_term_meta_value') ? intval(dms_ecom_get_term_meta_value($b->term_id, 'menu_order')) : 0;
        if ($a_order !== $b_order) return $a_order <=> $b_order;
        $name_compare = strcasecmp((string) $a->name, (string) $b->name);
        if ($name_compare !== 0) return $name_compare;
        return ((int) $a->term_id) <=> ((int) $b->term_id);
    });

    $ids = array();
    $slugs = array();
    foreach ($matched as $term) {
        $ids[] = (int) $term->term_id;
        $slugs[] = (string) $term->slug;
    }

    return array('ids' => $ids, 'slugs' => $slugs);
}
}

if (!function_exists('dms_get_brands_base')) {
function dms_get_brands_base($request) {
    if (!function_exists('max')) return array();
    $is_guest = function_exists('lpco_dms_is_guest_request') ? lpco_dms_is_guest_request($request) : true;
    list($uid, $grp, $cur) = dms_ecom_get_request_user_context($request, $is_guest);
    $ckey = $is_guest ? (function_exists('lpco_dms_guest_cache_key') ? lpco_dms_guest_cache_key('brands', $request) : '') : (function_exists('lpco_dms_auth_cache_key') ? lpco_dms_auth_cache_key('brands', $request, $uid, $grp, $cur) : '');
    if ($ckey && function_exists('lpco_dms_guest_cache_get') && ($cached = ($is_guest ? lpco_dms_guest_cache_get($ckey) : (function_exists('lpco_dms_auth_cache_get') ? lpco_dms_auth_cache_get($ckey) : false))) !== false) return $cached;
    
    $limit = is_object($request) && method_exists($request, 'get_param') ? max(1, intval($request->get_param('per_page') ?: 50)) : 50;
    $page = is_object($request) && method_exists($request, 'get_param') ? max(1, intval($request->get_param('page') ?: 1)) : 1;
    $tax = (function_exists('taxonomy_exists') && taxonomy_exists('product_brand')) ? 'product_brand' : 'product_tag';
    $terms = function_exists('get_terms') ? get_terms(array('taxonomy' => $tax, 'hide_empty' => false, 'number' => 0, 'update_term_meta_cache' => true)) : array();
    if (is_wp_error($terms)) return $terms;
    
    $attachments = array();
    if (function_exists('dms_ecom_get_term_meta_value') && function_exists('absint')) {
        foreach ($terms as $t) {
            foreach (array('thumbnail_id', 'brand_logo_id', 'brand_image_id') as $m) {
                if ($aid = absint(dms_ecom_get_term_meta_value($t->term_id, $m))) $attachments[$aid] = $aid;
            }
        }
    }
    if (function_exists('dms_ecom_prime_attachment_ids')) dms_ecom_prime_attachment_ids($attachments);
    
    $brands = array();
    foreach ((array) $terms as $t) {
        if (!$t || (function_exists('is_wp_error') && is_wp_error($t))) {
            continue;
        }

        $is_hidden = function_exists('dms_ecom_is_hidden_term_for_app')
            ? dms_ecom_is_hidden_term_for_app($t, $tax)
            : false;
        if ($is_hidden) {
            continue;
        }

        $visible_count = function_exists('dms_ecom_get_visible_term_product_count')
            ? dms_ecom_get_visible_term_product_count($tax, $t->term_id, false)
            : intval($t->count);

        $linked_categories = function_exists('dms_ecom_get_linked_categories_for_brand')
            ? dms_ecom_get_linked_categories_for_brand($t->slug)
            : array('ids' => array(), 'slugs' => array());

        $brands[] = array(
            'id' => $t->term_id,
            'name' => $t->name,
            'slug' => $t->slug,
            'count' => $visible_count,
            'image_url' => function_exists('dms_ecom_resolve_brand_image_url') ? dms_ecom_resolve_brand_image_url($t) : '',
            'linked_category_ids' => $linked_categories['ids'],
            'linked_category_slugs' => $linked_categories['slugs'],
            'taxonomy' => $tax,
            'show_in_app' => true,
            'hidden' => false,
        );
    }
    
    if (function_exists('lpco_app_layout_config_get') && function_exists('lpco_app_layout_apply_order')) {
        $cfg = lpco_app_layout_config_get(); if (!empty($cfg['brands'])) $brands = lpco_app_layout_apply_order($brands, $cfg['brands'], 'id');
    }

    if ($limit > 0) {
        $brands = array_slice(array_values($brands), ($page - 1) * $limit, $limit);
    } else {
        $brands = array_values($brands);
    }
    
    if ($ckey && function_exists('lpco_dms_guest_cache_set')) {
        if ($is_guest) lpco_dms_guest_cache_set($ckey, $brands); elseif (function_exists('lpco_dms_auth_cache_set')) lpco_dms_auth_cache_set($ckey, $brands);
    }
    return $brands;
}
}

if (!function_exists('dms_get_brands_guest')) {
function dms_get_brands_guest($request) {
    if (function_exists('wp_set_current_user')) wp_set_current_user(0); 
    if (is_object($request) && method_exists($request, 'get_param') && method_exists($request, 'set_param')) {
        if (!$request->get_param('guest') && !$request->get_param('mode')) $request->set_param('guest', 1);
    }
    $brands = dms_get_brands_base($request);
    if (!is_wp_error($brands) && function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('brands_guest_' . md5(wp_json_encode($brands)));
    return $brands;
}
}

if (!function_exists('dms_get_brands_auth')) {
function dms_get_brands_auth($request) {
    $brands = dms_get_brands_base($request);
    if (!is_wp_error($brands) && function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) dms_send_cache_headers('brands_auth_' . md5(wp_json_encode($brands)));
    return $brands;
}
}
