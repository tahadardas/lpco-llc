<?php
if (!defined('ABSPATH')) {
    exit;
}

/**
 * Order-related logic for DMS Mobile App
 */

/**
 * Get user's orders with standardized formatting
 */
if (!function_exists('dms_get_user_orders')) {
function dms_get_user_orders($request) {
    $user_id = $request['user_id'];
    $per_page = $request->get_param('per_page') ?: 20;
    $page = $request->get_param('page') ?: 1;
    $current_user_id = function_exists('get_current_user_id') ? get_current_user_id() : 0;
    
    if ($current_user_id && intval($current_user_id) !== intval($user_id)) {
        return new WP_Error('forbidden_orders', 'ليس لديك صلاحية لعرض طلبات هذا المستخدم', array('status' => 403));
    }
    
    // Verify user exists
    $user = function_exists('get_userdata') ? get_userdata($user_id) : null;
    if (!$user) {
        return new WP_Error('user_not_found', 'المستخدم غير موجود', array('status' => 404));
    }
    
    // Get user's orders
    $args = array(
        'customer_id' => $user_id,
        'limit' => $per_page,
        'offset' => ($page - 1) * $per_page,
        'orderby' => 'date',
        'order' => 'DESC'
    );
    
    $orders = function_exists('wc_get_orders') ? wc_get_orders($args) : array();
    
    return array_map(function($order) {
        $invoice_url = function_exists('dms_ecom_safe_invoice_url')
            ? dms_ecom_safe_invoice_url($order->get_id(), 86400) // DAY_IN_SECONDS
            : '';
        $order_uuid = function_exists('sanitize_text_field') ? sanitize_text_field($order->get_meta('dms_order_uuid')) : $order->get_meta('dms_order_uuid');

        return array(
            'id' => $order->get_id(),
            'order_number' => $order->get_order_number(),
            'status' => $order->get_status(),
            'date' => $order->get_date_created() ? $order->get_date_created()->format('Y-m-d H:i:s') : '',
            'total' => $order->get_total(),
            'currency' => $order->get_currency(),
            'payment_method' => $order->get_payment_method_title(),
            'invoice_url' => $invoice_url,
            'order_uuid' => $order_uuid,
            'idempotency_key' => $order_uuid,
            'line_items' => array_values(array_map(function($item) {
                $variation_id = $item->get_variation_id();
                $attributes = array();
                foreach ($item->get_meta_data() as $meta) {
                    if (strpos((string)$meta->key, 'attribute_') === 0) {
                        $attributes[substr($meta->key, 10)] = $meta->value;
                    }
                }
                $unit_type = $item->get_meta('unit_type');
                $unit_name = $item->get_meta('unit_name');
                $unit_pieces = $item->get_meta('unit_pieces');
                $unit_price = $item->get_meta('unit_price');
                
                // Backward compatibility for older orders
                if (empty($unit_type)) { $unit_type = $item->get_meta('dms_unit_type'); }
                if (empty($unit_name)) { $unit_name = $item->get_meta('dms_unit_name'); }
                if (empty($unit_pieces)) { $unit_pieces = $item->get_meta('dms_unit_pieces_count'); }
                if (empty($unit_price)) { $unit_price = $item->get_meta('dms_calculated_unit_price'); }
                
                return array(
                    'product_id' => $item->get_product_id(),
                    'product_name' => $item->get_name(),
                    'variation_id' => $variation_id ?: null,
                    'quantity' => $item->get_quantity(),
                    'total' => $item->get_total(),
                    'attributes' => $attributes,
                    'unit' => array(
                        'type' => $unit_type ?: null,
                        'name' => $unit_name ?: null,
                        'pieces' => $unit_pieces ?: null,
                        'price' => $unit_price !== '' ? $unit_price : null
                    )
                );
            }, $order->get_items())),
            'billing' => array(
                'first_name' => $order->get_billing_first_name(),
                'last_name' => $order->get_billing_last_name(),
                'phone' => $order->get_billing_phone(),
                'email' => $order->get_billing_email(),
                'address' => $order->get_billing_address_1(),
                'city' => $order->get_billing_city()
            )
        );
    }, $orders);
}
}

if (!function_exists('dms_ecom_product_brand_taxonomy')) {
function dms_ecom_product_brand_taxonomy() {
    if (taxonomy_exists('product_brand')) {
        return 'product_brand';
    }
    if (taxonomy_exists('product_tag')) {
        return 'product_tag';
    }
    return '';
}
}

if (!function_exists('dms_ecom_normalize_warehouse_key')) {
function dms_ecom_normalize_warehouse_key($value) {
    $value = strtolower(trim((string) $value));
    if ($value === '') {
        return '';
    }
    if (function_exists('sanitize_title')) {
        $value = sanitize_title($value);
    }
    return str_replace('_', '-', $value);
}
}

if (!function_exists('dms_ecom_default_warehouse_config')) {
function dms_ecom_default_warehouse_config() {
    return array(
        'warehouse_a' => array(
            'label' => 'Lexi + Zidny + Zero + Stationery',
            'brands' => array('lexi', 'zidny', 'zero', 'stationery'),
            'categories' => array(),
        ),
        'warehouse_b' => array(
            'label' => 'Daily + Yumor',
            'brands' => array('daily', 'yumor'),
            'categories' => array(),
        ),
        'bags' => array(
            'label' => 'Bags',
            'brands' => array('bags', 'bag'),
            'categories' => array('bags', 'bag'),
        ),
    );
}
}

if (!function_exists('dms_ecom_warehouse_config')) {
function dms_ecom_warehouse_config() {
    $defaults = function_exists('dms_ecom_default_warehouse_config')
        ? dms_ecom_default_warehouse_config()
        : array();
    $stored = get_option('dms_warehouse_config', array());
    $config = is_array($stored) ? $stored : array();

    foreach ($defaults as $code => $default_row) {
        $stored_row = isset($config[$code]) && is_array($config[$code]) ? $config[$code] : array();
        $config[$code] = array(
            'label' => trim((string) ($stored_row['label'] ?? $default_row['label'] ?? $code)),
            'brands' => array_values(array_filter(array_map('dms_ecom_normalize_warehouse_key', (array) ($stored_row['brands'] ?? $default_row['brands'] ?? array())))),
            'categories' => array_values(array_filter(array_map('dms_ecom_normalize_warehouse_key', (array) ($stored_row['categories'] ?? $default_row['categories'] ?? array())))),
        );
    }

    foreach ($config as $code => $row) {
        if (!is_array($row)) {
            unset($config[$code]);
            continue;
        }
        $config[$code] = array(
            'label' => trim((string) ($row['label'] ?? $code)),
            'brands' => array_values(array_filter(array_map('dms_ecom_normalize_warehouse_key', (array) ($row['brands'] ?? array())))),
            'categories' => array_values(array_filter(array_map('dms_ecom_normalize_warehouse_key', (array) ($row['categories'] ?? array())))),
        );
    }

    return apply_filters('dms_ecom_warehouse_config', $config);
}
}

if (!function_exists('dms_ecom_warehouse_label')) {
function dms_ecom_warehouse_label($code) {
    $code = trim((string) $code);
    if ($code === '') {
        return '';
    }
    if ($code === 'mixed') {
        return 'متعدد المستودعات';
    }
    $config = function_exists('dms_ecom_warehouse_config') ? dms_ecom_warehouse_config() : array();
    if (isset($config[$code]['label'])) {
        return trim((string) $config[$code]['label']);
    }
    return $code;
}
}

if (!function_exists('dms_ecom_term_slug_set')) {
function dms_ecom_term_slug_set($product_id, $taxonomy) {
    $slugs = array();
    if ($product_id <= 0 || $taxonomy === '' || !taxonomy_exists($taxonomy)) {
        return $slugs;
    }
    foreach ((array) get_the_terms($product_id, $taxonomy) as $term) {
        if ($term instanceof WP_Term) {
            $slug = dms_ecom_normalize_warehouse_key($term->slug);
            if ($slug !== '') {
                $slugs[$slug] = true;
            }
        }
    }
    return $slugs;
}
}

if (!function_exists('dms_ecom_resolve_product_image_url')) {
function dms_ecom_resolve_product_image_url($product = null, $product_id = 0, $variation_id = 0, $size = 'thumbnail') {
    $attachment_id = 0;
    if ($product && is_object($product) && method_exists($product, 'get_image_id')) {
        $attachment_id = absint($product->get_image_id());
    }
    if ($attachment_id <= 0 && $variation_id > 0) {
        $attachment_id = absint(get_post_thumbnail_id($variation_id));
    }
    if ($attachment_id <= 0 && $product_id > 0) {
        $attachment_id = absint(get_post_thumbnail_id($product_id));
    }
    if ($attachment_id <= 0 && $variation_id > 0) {
        $parent_id = wp_get_post_parent_id($variation_id);
        if ($parent_id > 0) {
            $attachment_id = absint(get_post_thumbnail_id($parent_id));
        }
    }
    if ($attachment_id > 0) {
        $url = wp_get_attachment_image_url($attachment_id, $size);
        if (is_string($url) && $url !== '') {
            return $url;
        }
    }
    if (function_exists('wc_placeholder_img_src')) {
        return (string) wc_placeholder_img_src($size);
    }
    return '';
}
}

if (!function_exists('dms_ecom_resolve_product_warehouse')) {
function dms_ecom_resolve_product_warehouse($product = null, $product_id = 0, $variation_id = 0) {
    $source_product_id = absint($product_id);
    if ($source_product_id <= 0 && $product && is_object($product) && method_exists($product, 'get_id')) {
        $source_product_id = absint($product->get_id());
    }
    if ($variation_id > 0) {
        $parent_id = wp_get_post_parent_id($variation_id);
        if ($parent_id > 0) {
            $source_product_id = $parent_id;
        }
    }
    if ($source_product_id <= 0) {
        return array('code' => '', 'label' => '');
    }

    $brand_taxonomy = function_exists('dms_ecom_product_brand_taxonomy') ? dms_ecom_product_brand_taxonomy() : '';
    $brand_slugs = function_exists('dms_ecom_term_slug_set') ? dms_ecom_term_slug_set($source_product_id, $brand_taxonomy) : array();
    $category_slugs = function_exists('dms_ecom_term_slug_set') ? dms_ecom_term_slug_set($source_product_id, 'product_cat') : array();
    $config = function_exists('dms_ecom_warehouse_config') ? dms_ecom_warehouse_config() : array();

    foreach ($config as $code => $row) {
        $match_brands = array_intersect_key(array_flip((array) ($row['brands'] ?? array())), $brand_slugs);
        $match_categories = array_intersect_key(array_flip((array) ($row['categories'] ?? array())), $category_slugs);
        if (!empty($match_brands) || !empty($match_categories)) {
            return array(
                'code' => (string) $code,
                'label' => trim((string) ($row['label'] ?? $code)),
            );
        }
    }

    return apply_filters(
        'dms_ecom_resolve_product_warehouse',
        array('code' => '', 'label' => ''),
        $product,
        $product_id,
        $variation_id,
        $brand_slugs,
        $category_slugs
    );
}
}

if (!function_exists('dms_ecom_order_warehouse_payload_from_codes')) {
function dms_ecom_order_warehouse_payload_from_codes($codes) {
    $normalized = array();
    foreach ((array) $codes as $code) {
        $code = trim((string) $code);
        if ($code === '') {
            continue;
        }
        $normalized[$code] = true;
    }
    $codes = array_keys($normalized);
    if (empty($codes)) {
        return array(
            'code' => '',
            'label' => '',
            'codes' => array(),
            'labels' => array(),
        );
    }

    if (count($codes) === 1) {
        $code = $codes[0];
        return array(
            'code' => $code,
            'label' => function_exists('dms_ecom_warehouse_label') ? dms_ecom_warehouse_label($code) : $code,
            'codes' => $codes,
            'labels' => array(function_exists('dms_ecom_warehouse_label') ? dms_ecom_warehouse_label($code) : $code),
        );
    }

    $labels = array();
    foreach ($codes as $code) {
        $labels[] = function_exists('dms_ecom_warehouse_label') ? dms_ecom_warehouse_label($code) : $code;
    }

    return array(
        'code' => 'mixed',
        'label' => 'متعدد المستودعات',
        'codes' => $codes,
        'labels' => $labels,
    );
}
}

if (!function_exists('dms_ecom_get_order_warehouse_payload')) {
function dms_ecom_get_order_warehouse_payload($order) {
    if (!$order || !is_a($order, 'WC_Order')) {
        return array(
            'code' => '',
            'label' => '',
            'codes' => array(),
            'labels' => array(),
        );
    }

    $stored_code = trim((string) ($order->get_meta('warehouse_code', true) ?: $order->get_meta('dms_warehouse_code', true)));
    $stored_label = trim((string) ($order->get_meta('warehouse_label', true) ?: $order->get_meta('dms_warehouse_label', true)));
    $stored_codes_raw = $order->get_meta('warehouse_codes', true);
    if ($stored_codes_raw === '') {
        $stored_codes_raw = $order->get_meta('dms_warehouse_codes', true);
    }

    $stored_codes = array();
    if (is_array($stored_codes_raw)) {
        $stored_codes = $stored_codes_raw;
    } elseif (is_string($stored_codes_raw) && trim($stored_codes_raw) !== '') {
        $decoded = json_decode($stored_codes_raw, true);
        if (is_array($decoded)) {
            $stored_codes = $decoded;
        } else {
            $stored_codes = array_map('trim', explode(',', $stored_codes_raw));
        }
    }
    if (!empty($stored_code)) {
        $stored_codes[] = $stored_code;
    }

    $payload = function_exists('dms_ecom_order_warehouse_payload_from_codes')
        ? dms_ecom_order_warehouse_payload_from_codes($stored_codes)
        : array('code' => '', 'label' => '', 'codes' => array(), 'labels' => array());

    if ($payload['code'] !== '') {
        if ($stored_label !== '' && count($payload['codes']) === 1) {
            $payload['label'] = $stored_label;
            $payload['labels'] = array($stored_label);
        }
        return $payload;
    }

    $derived_codes = array();
    foreach ($order->get_items() as $item) {
        $item_code = trim((string) ($item->get_meta('warehouse_code') ?: $item->get_meta('dms_warehouse_code')));
        if ($item_code === '') {
            $resolved = function_exists('dms_ecom_resolve_product_warehouse')
                ? dms_ecom_resolve_product_warehouse($item->get_product(), $item->get_product_id(), $item->get_variation_id())
                : array('code' => '', 'label' => '');
            $item_code = trim((string) ($resolved['code'] ?? ''));
        }
        if ($item_code !== '') {
            $derived_codes[] = $item_code;
        }
    }

    return function_exists('dms_ecom_order_warehouse_payload_from_codes')
        ? dms_ecom_order_warehouse_payload_from_codes($derived_codes)
        : array('code' => '', 'label' => '', 'codes' => array(), 'labels' => array());
}
}

/**
 * Core order creation logic
 */
if (!function_exists('dms_create_order')) {
function dms_create_order($request) {
    try {
        $params = $request->get_json_params();
        if (!is_array($params)) {
            return new WP_Error('invalid_json', 'صيغة الطلب غير صحيحة. يرجى إعادة المحاولة.', array('status' => 400));
        }
        
        if (!function_exists('wc_get_orders')) {
            return new WP_Error('woocommerce_missing', 'خدمة الطلبات غير متاحة حالياً.', array('status' => 500));
        }
        
        $meta_entries = is_array($params['meta_data'] ?? null) ? $params['meta_data'] : array();
        $order_meta = array();
        foreach ($meta_entries as $entry) {
            if (isset($entry['key']) && array_key_exists('value', $entry)) {
                $order_meta[$entry['key']] = $entry['value'];
            }
        }
        $order_uuid = function_exists('sanitize_text_field') ? sanitize_text_field($params['order_uuid'] ?? ($order_meta['order_uuid'] ?? '')) : ($params['order_uuid'] ?? ($order_meta['order_uuid'] ?? ''));
        
        if (empty($params['line_items']) || !is_array($params['line_items'])) {
            return new WP_Error('invalid_params', 'بيانات الطلب غير مكتملة. يرجى مراجعة السلة وبيانات العميل.', array('status' => 400));
        }

        $customer_id = intval($params['customer_id'] ?? 0);
        if ($customer_id <= 0) {
            return new WP_Error('guest_checkout_disabled', 'إتمام الطلب كضيف غير متاح حالياً. يرجى تسجيل الدخول.', array('status' => 403));
        }

        $current_user_id = function_exists('get_current_user_id') ? get_current_user_id() : 0;
        if ($current_user_id && $current_user_id !== $customer_id) {
            return new WP_Error('forbidden_order', 'لا يمكنك إنشاء طلب لهذا المستخدم.', array('status' => 403));
        }

        // Idempotency check
        if (!empty($order_uuid)) {
            $existing = wc_get_orders(array('limit' => 1, 'meta_key' => 'dms_order_uuid', 'meta_value' => $order_uuid, 'return' => 'objects'));
            if (!empty($existing)) {
                $existing_order = $existing[0];
                if (function_exists('dms_ecom_defer_admin_order_notification')) {
                    dms_ecom_defer_admin_order_notification($existing_order);
                }
                $invoice_url = function_exists('dms_ecom_safe_invoice_url') ? dms_ecom_safe_invoice_url($existing_order->get_id(), 1800) : '';
                $existing_sham_cash = null;
                if ($existing_order->get_payment_method() === 'instant_barcode' && function_exists('dms_ecom_build_sham_cash_payload')) {
                    $existing_sham_cash = dms_ecom_build_sham_cash_payload($existing_order);
                }
                return array(
                    'id' => $existing_order->get_id(),
                    'order_number' => $existing_order->get_order_number(),
                    'status' => $existing_order->get_status(),
                    'total' => $existing_order->get_total(),
                    'currency' => strtolower($existing_order->get_currency()),
                    'order_uuid' => $order_uuid,
                    'duplicate_protected' => true,
                    'reused_existing' => true,
                    'existing_order_id' => $existing_order->get_id(),
                    'message' => 'تم إنشاء الطلب مسبقاً',
                    'invoice_url' => $invoice_url,
                    'sham_cash' => $existing_sham_cash
                );
            }
        }
        
        $line_items = $params['line_items'];
        $billing = is_array($params['billing'] ?? null) ? $params['billing'] : array();
        $shipping = is_array($params['shipping'] ?? null) ? $params['shipping'] : array();
        $payment_method = function_exists('sanitize_text_field') ? sanitize_text_field($params['payment_method'] ?? 'cod') : ($params['payment_method'] ?? 'cod');
        $notes = function_exists('sanitize_textarea_field') ? sanitize_textarea_field($params['customer_note'] ?? '') : ($params['customer_note'] ?? '');
        
        $customer = function_exists('get_userdata') ? get_userdata($customer_id) : null;
        if (!$customer) {
            if (function_exists('dms_ecom_log')) dms_ecom_log('error', 'Customer not found', array('customer_id' => $customer_id));
            return new WP_Error('customer_not_found', 'تعذر العثور على بيانات العميل.', array('status' => 404));
        }
        
        $order = function_exists('wc_create_order') ? wc_create_order() : null;
        if (!$order) {
            return new WP_Error('order_creation_failed', 'تعذر إنشاء الطلب حالياً. يرجى المحاولة لاحقاً.', array('status' => 500));
        }
        if (is_wp_error($order)) { return $order; }
        
        $order->set_customer_id($customer_id);
        if (!empty($params['currency'])) {
            $currency_code = function_exists('sanitize_text_field') ? sanitize_text_field(strtoupper($params['currency'])) : strtoupper($params['currency']);
            try { $order->set_currency($currency_code); } catch (Throwable $currency_error) {
                if (function_exists('dms_ecom_log')) dms_ecom_log('warning', 'Invalid currency code, using shop default', array('requested_currency' => $currency_code, 'error' => $currency_error->getMessage()));
            }
        }
        
        $items_added = 0;
        $order_warehouse_codes = array();
        foreach ($line_items as $item) {
            if (!is_array($item)) continue;
            $product_id = intval($item['product_id'] ?? 0);
            $quantity = max(1, intval($item['quantity'] ?? 1));
            $variation_id = intval($item['variation_id'] ?? ($item['variationId'] ?? 0));
            $attributes = is_array($item['attributes'] ?? null) ? $item['attributes'] : array();
            
            if ($product_id <= 0) continue;
            
            $product = function_exists('wc_get_product') ? wc_get_product($product_id) : null;
            if (!$product) continue;
            if ($variation_id > 0) {
                $v_prod = wc_get_product($variation_id);
                if ($v_prod && $v_prod->get_parent_id() === $product_id) { $product = $v_prod; } else { $variation_id = 0; }
            }

            $meta_lookup = array();
            if (!empty($item['meta_data']) && is_array($item['meta_data'])) {
                foreach ($item['meta_data'] as $m_entry) { if (isset($m_entry['key']) && array_key_exists('value', $m_entry)) { $meta_lookup[$m_entry['key']] = $m_entry['value']; } }
            }
            
            $unit_type = function_exists('sanitize_text_field') ? sanitize_text_field($item['unit_type'] ?? ($item['dms_unit_type'] ?? ($meta_lookup['unit_type'] ?? 'piece'))) : ($item['unit_type'] ?? ($item['dms_unit_type'] ?? ($meta_lookup['unit_type'] ?? 'piece')));
            $unit_name = function_exists('sanitize_text_field') ? sanitize_text_field($item['unit_name'] ?? ($item['dms_unit_name'] ?? ($meta_lookup['unit_name'] ?? (($unit_type === 'package') ? 'طرد' : 'قطعة')))) : ($item['unit_name'] ?? ($item['dms_unit_name'] ?? ($meta_lookup['unit_name'] ?? (($unit_type === 'package') ? 'طرد' : 'قطعة'))));
            $unit_pieces = function_exists('absint') ? absint($item['unit_pieces'] ?? ($item['dms_unit_pieces_count'] ?? ($meta_lookup['unit_pieces'] ?? ($meta_lookup['pieces_count'] ?? 1)))) : ($item['unit_pieces'] ?? ($item['dms_unit_pieces_count'] ?? ($meta_lookup['unit_pieces'] ?? ($meta_lookup['pieces_count'] ?? 1))));
            if ($unit_pieces <= 0) $unit_pieces = 1;
            
            $unit_price = isset($item['unit_price']) ? floatval($item['unit_price']) : (isset($item['dms_calculated_unit_price']) ? floatval($item['dms_calculated_unit_price']) : (isset($meta_lookup['unit_price']) ? floatval($meta_lookup['unit_price']) : floatval($product->get_price())));
            
            // Scaled price for multi-piece units
            if ($unit_type !== 'piece' && $unit_pieces > 1) {
                $p_price = floatval($product->get_price());
                if ($unit_price <= ($p_price * 1.01)) { $unit_price = $unit_price * $unit_pieces; }
            }
            
            $line_total = round($unit_price * $quantity, function_exists('wc_get_price_decimals') ? wc_get_price_decimals() : 2);
            if (!class_exists('WC_Order_Item_Product')) { continue; }
            $order_item = new WC_Order_Item_Product();
            $order_item->set_product($product);
            $order_item->set_quantity($quantity);
            $order_item->set_subtotal($line_total);
            $order_item->set_total($line_total);
            if ($variation_id > 0) $order_item->set_variation_id($variation_id);
            if (!empty($attributes)) { 
                foreach ($attributes as $ak => $av) {
                    $clean_ak = function_exists('wc_clean') ? wc_clean($ak) : $ak;
                    $clean_av = function_exists('sanitize_text_field') ? sanitize_text_field($av) : $av;
                    $order_item->add_meta_data('attribute_' . $clean_ak, $clean_av, true);
                }
            }
            
            $order_item->add_meta_data('unit_type', $unit_type, true); $order_item->add_meta_data('unit_name', $unit_name, true); $order_item->add_meta_data('unit_pieces', $unit_pieces, true); $order_item->add_meta_data('unit_price', $unit_price, true);
            $order_item->add_meta_data('dms_unit_type', $unit_type, true); $order_item->add_meta_data('dms_unit_name', $unit_name, true); $order_item->add_meta_data('dms_unit_pieces_count', $unit_pieces, true); $order_item->add_meta_data('dms_calculated_unit_price', $unit_price, true);

            $image_url = function_exists('dms_ecom_resolve_product_image_url')
                ? dms_ecom_resolve_product_image_url($product, $product_id, $variation_id, 'thumbnail')
                : '';
            if ($image_url !== '') {
                $order_item->add_meta_data('image_url', $image_url, true);
                $order_item->add_meta_data('product_image', $image_url, true);
            }

            $warehouse_payload = function_exists('dms_ecom_resolve_product_warehouse')
                ? dms_ecom_resolve_product_warehouse($product, $product_id, $variation_id)
                : array('code' => '', 'label' => '');
            $warehouse_code = trim((string) ($warehouse_payload['code'] ?? ''));
            $warehouse_label = trim((string) ($warehouse_payload['label'] ?? ''));
            if ($warehouse_code !== '') {
                $order_item->add_meta_data('warehouse_code', $warehouse_code, true);
                $order_item->add_meta_data('warehouse_label', $warehouse_label, true);
                $order_item->add_meta_data('dms_warehouse_code', $warehouse_code, true);
                $order_item->add_meta_data('dms_warehouse_label', $warehouse_label, true);
                $order_warehouse_codes[] = $warehouse_code;
            }
            
            $order->add_item($order_item);
            $items_added++;
        }
        
        if ($items_added === 0) { $order->delete(true); return new WP_Error('invalid_items', 'تعذر إنشاء الطلب لأن عناصر السلة غير صالحة.', array('status' => 400)); }

        $order_warehouse_payload = function_exists('dms_ecom_order_warehouse_payload_from_codes')
            ? dms_ecom_order_warehouse_payload_from_codes($order_warehouse_codes)
            : array('code' => '', 'label' => '', 'codes' => array(), 'labels' => array());
        if (!empty($order_warehouse_payload['codes'])) {
            $codes_json = function_exists('wp_json_encode')
                ? wp_json_encode($order_warehouse_payload['codes'])
                : json_encode($order_warehouse_payload['codes']);
            $order->add_meta_data('warehouse_code', $order_warehouse_payload['code'], true);
            $order->add_meta_data('warehouse_label', $order_warehouse_payload['label'], true);
            $order->add_meta_data('warehouse_codes', $codes_json, true);
            $order->add_meta_data('dms_warehouse_code', $order_warehouse_payload['code'], true);
            $order->add_meta_data('dms_warehouse_label', $order_warehouse_payload['label'], true);
            $order->add_meta_data('dms_warehouse_codes', $codes_json, true);
        }
        
        if (!empty($billing)) {
            $order->set_billing_first_name(function_exists('sanitize_text_field') ? sanitize_text_field($billing['first_name'] ?? '') : ($billing['first_name'] ?? '')); 
            $order->set_billing_last_name(function_exists('sanitize_text_field') ? sanitize_text_field($billing['last_name'] ?? '') : ($billing['last_name'] ?? '')); 
            $order->set_billing_phone(function_exists('sanitize_text_field') ? sanitize_text_field($billing['phone'] ?? '') : ($billing['phone'] ?? ''));
            $b_email = !empty($billing['email']) ? (function_exists('sanitize_email') ? sanitize_email($billing['email']) : $billing['email']) : ($customer->user_email ? (function_exists('sanitize_email') ? sanitize_email($customer->user_email) : $customer->user_email) : '');
            if ($b_email) $order->set_billing_email($b_email);
            $order->set_billing_address_1(function_exists('sanitize_text_field') ? sanitize_text_field($billing['address_1'] ?? '') : ($billing['address_1'] ?? '')); 
            $order->set_billing_city(function_exists('sanitize_text_field') ? sanitize_text_field($billing['city'] ?? '') : ($billing['city'] ?? '')); 
            $order->set_billing_state(function_exists('sanitize_text_field') ? sanitize_text_field($billing['state'] ?? '') : ($billing['state'] ?? '')); 
            $order->set_billing_company(function_exists('sanitize_text_field') ? sanitize_text_field($billing['company'] ?? '') : ($billing['company'] ?? ''));
        }
        
        $s_data = !empty($shipping) ? $shipping : $billing;
        if (!empty($s_data)) {
            $order->set_shipping_first_name(function_exists('sanitize_text_field') ? sanitize_text_field($s_data['first_name'] ?? '') : ($s_data['first_name'] ?? '')); 
            $order->set_shipping_last_name(function_exists('sanitize_text_field') ? sanitize_text_field($s_data['last_name'] ?? '') : ($s_data['last_name'] ?? '')); 
            $order->set_shipping_company(function_exists('sanitize_text_field') ? sanitize_text_field($s_data['company'] ?? '') : ($s_data['company'] ?? ''));
            $order->set_shipping_address_1(function_exists('sanitize_text_field') ? sanitize_text_field($s_data['address_1'] ?? '') : ($s_data['address_1'] ?? '')); 
            $order->set_shipping_city(function_exists('sanitize_text_field') ? sanitize_text_field($s_data['city'] ?? '') : ($s_data['city'] ?? '')); 
            $order->set_shipping_state(function_exists('sanitize_text_field') ? sanitize_text_field($s_data['state'] ?? '') : ($s_data['state'] ?? ''));
            if (!empty($s_data['phone'])) $order->add_meta_data('shipping_phone', function_exists('sanitize_text_field') ? sanitize_text_field($s_data['phone']) : $s_data['phone'], true);
        }
        
        $order->set_payment_method($payment_method);
        $pm_title = function_exists('dms_ecom_get_default_payment_title') ? dms_ecom_get_default_payment_title($payment_method) : 'Payment';
        $order->set_payment_method_title(function_exists('sanitize_text_field') ? sanitize_text_field($params['payment_method_title'] ?? $pm_title) : ($params['payment_method_title'] ?? $pm_title));
        $order->add_meta_data('dms_order_source', 'app', true);
        if (!empty($order_uuid)) $order->add_meta_data('dms_order_uuid', $order_uuid, true);
        
        foreach (array('dms_price_group', 'dms_currency', 'order_contact_name', 'order_phone', 'order_address', 'order_city', 'order_state', 'order_company') as $m_key) {
            if (!empty($order_meta[$m_key])) $order->add_meta_data($m_key, function_exists('sanitize_text_field') ? sanitize_text_field($order_meta[$m_key]) : $order_meta[$m_key], true);
        }
        if (!empty($notes)) $order->add_order_note($notes);
        
        $order->calculate_totals();
        
        $sham_cash_payload = null;
        if ($payment_method === 'instant_barcode' && function_exists('dms_ecom_setup_sham_cash')) {
            $sham_cash_payload = dms_ecom_setup_sham_cash($order);
        }
        
        $order->save();
        if (function_exists('dms_ecom_log')) dms_ecom_log('info', 'Order created via API', array('order_id' => $order->get_id(), 'customer_id' => $customer_id));
        if (function_exists('dms_ecom_defer_admin_order_notification')) dms_ecom_defer_admin_order_notification($order);
        
        return array(
            'id' => $order->get_id(), 'order_number' => $order->get_order_number(), 'status' => $order->get_status(), 'total' => $order->get_total(), 'currency' => strtolower($order->get_currency()),
            'order_uuid' => $order_uuid, 'duplicate_protected' => false, 'reused_existing' => false, 'message' => 'تم إنشاء الطلب بنجاح',
            'invoice_url' => function_exists('dms_ecom_safe_invoice_url') ? dms_ecom_safe_invoice_url($order->get_id(), 1800) : '', 'sham_cash' => $sham_cash_payload
        );
        
    } catch (Throwable $e) {
        if (function_exists('dms_ecom_log')) dms_ecom_log('error', 'Order creation exception', array('msg' => $e->getMessage(), 'file' => $e->getFile(), 'line' => $e->getLine()));
        return new WP_Error('order_creation_exception', 'تعذر إنشاء الطلب حالياً، يرجى المحاولة لاحقاً.', array('status' => 500));
    }
}
}

/**
 * Sham Cash transfer confirmation
 */
if (!function_exists('dms_confirm_sham_cash_transfer')) {
function dms_confirm_sham_cash_transfer($request) {
    if (!function_exists('wc_get_order')) { return new WP_Error('wc_missing', 'خدمة الطلبات غير متاحة حالياً.', array('status'=>500)); }
    $order_id = intval($request['id'] ?? 0);
    $order = wc_get_order($order_id);
    if (!$order) return new WP_Error('order_not_found', 'الطلب غير موجود.', array('status' => 404));

    $uid = function_exists('get_current_user_id') ? get_current_user_id() : 0;
    if ($uid && intval($order->get_customer_id()) && $uid !== intval($order->get_customer_id()) && !current_user_can('manage_woocommerce')) {
        return new WP_Error('forbidden_order', 'لا يمكنك تعديل هذا الطلب.', array('status' => 403));
    }

    if ($order->get_payment_method() !== 'instant_barcode') return new WP_Error('invalid_payment_method', 'طريقة الدفع لهذا الطلب ليست شام كاش.', array('status' => 400));

    $params = $request->get_json_params() ?: array();
    $tid = function_exists('sanitize_text_field') ? sanitize_text_field($params['transaction_id'] ?? ('APP-' . $order_id . '-' . time())) : ($params['transaction_id'] ?? ('APP-' . $order_id . '-' . time()));
    $proof = function_exists('esc_url_raw') ? esc_url_raw($params['proof_image_url'] ?? '') : ($params['proof_image_url'] ?? '');

    $order->set_transaction_id($tid);
    if ($proof !== '') $order->update_meta_data('_payment_proof_url', $proof);
    $order->update_meta_data('_sham_cash_status', 'awaiting_review');

    if (in_array($order->get_status(), array('pending', 'failed'), true)) $order->set_status('on-hold');
    $order->add_order_note(sprintf('Sham Cash transfer confirmation submitted from app. Transaction ID: %s%s', $tid, $proof !== '' ? ' | Proof: ' . $proof : ''));
    $order->save();

    return array('success' => true, 'order_id' => $order->get_id(), 'status' => $order->get_status(), 'transaction_id' => $tid, 'proof_image_url' => $proof, 'message' => 'تم إرسال تأكيد التحويل بنجاح.');
}
}

// Helpers
if (!function_exists('dms_ecom_get_default_payment_title')) {
function dms_ecom_get_default_payment_title($method) {
    switch ($method) {
        case 'cod': return 'الدفع عند الاستلام';
        case 'bacs': return 'حوالة مصرفية';
        case 'instant_barcode': return 'شام كاش - الباركود الفوري';
        default: return 'Online Payment';
    }
}
}

if (!function_exists('dms_ecom_build_sham_cash_payload')) {
function dms_ecom_build_sham_cash_payload($order) {
    $acc = function_exists('sanitize_text_field') ? sanitize_text_field($order->get_meta('_sham_cash_account')) : $order->get_meta('_sham_cash_account');
    $comp = function_exists('sanitize_text_field') ? sanitize_text_field($order->get_meta('_sham_cash_company')) : $order->get_meta('_sham_cash_company');
    $amt = floatval($order->get_meta('_sham_cash_amount')) ?: floatval($order->get_total());
    $exp = intval($order->get_meta('_sham_cash_expiry')) ?: (time() + 900);
    $stat = function_exists('sanitize_text_field') ? sanitize_text_field($order->get_meta('_sham_cash_status')) : ($order->get_meta('_sham_cash_status') ?: 'pending');
    $qr_text = function_exists('sanitize_text_field') ? sanitize_text_field($order->get_meta('_sham_cash_qr_text')) : ($order->get_meta('_sham_cash_qr_text') ?: $acc);
    
    return array(
        'company' => $comp, 'account' => $acc, 'amount' => $amt, 'expiry' => $exp, 'time_limit' => max(1, intval(($exp - time()) / 60)),
        'currency' => strtolower($order->get_currency()), 'qr_text' => $qr_text, 'qr_url' => 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data='.rawurlencode($qr_text).'&color=dc2626&bgcolor=ffffff',
        'status' => $stat, 'confirmation_endpoint' => function_exists('rest_url') ? rest_url('dms/v1/orders/' . $order->get_id() . '/sham-cash-confirm') : ''
    );
}
}

if (!function_exists('dms_ecom_setup_sham_cash')) {
function dms_ecom_setup_sham_cash($order) {
    $cfg = function_exists('dms_get_sham_cash_config') ? dms_get_sham_cash_config() : array();
    $tl = max(1, intval($cfg['time_limit'] ?? 15));
    $acc = function_exists('sanitize_text_field') ? sanitize_text_field(($cfg['account_code'] ?? '') ?: '2f3b91dd0befb9f619ef06697e7a1dc8') : (($cfg['account_code'] ?? '') ?: '2f3b91dd0befb9f619ef06697e7a1dc8');
    $comp = function_exists('sanitize_text_field') ? sanitize_text_field(($cfg['company_name'] ?? '') ?: 'لبكو المحدودة المسؤولية') : (($cfg['company_name'] ?? '') ?: 'لبكو المحدودة المسؤولية');
    $total = floatval($order->get_total());
    $exp = time() + ($tl * 60);
    
    $order->update_meta_data('_sham_cash_method', 'barcode_transfer');
    $order->update_meta_data('_sham_cash_account', $acc);
    $order->update_meta_data('_sham_cash_company', $comp);
    $order->update_meta_data('_sham_cash_amount', $total);
    $order->update_meta_data('_sham_cash_expiry', $exp);
    $order->update_meta_data('_sham_cash_status', 'pending');
    $order->update_meta_data('_sham_cash_qr_text', $acc);
    $order->set_status('pending');
    if (function_exists('wc_price')) {
         $order->add_order_note(sprintf('تم اختيار الدفع عبر شام كاش - الباركود الفوري. رقم الحساب: %s. المبلغ: %s. المهلة: %s دقيقة.', $acc, wc_price($total), $tl));
    }
    
    return dms_ecom_build_sham_cash_payload($order);
}
}
