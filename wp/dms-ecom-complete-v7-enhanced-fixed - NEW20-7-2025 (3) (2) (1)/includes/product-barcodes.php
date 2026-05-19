<?php
if (!defined('ABSPATH')) exit;

if (!function_exists('lpco_dms_product_barcode_meta_keys')) {
function lpco_dms_product_barcode_meta_keys() {
    return array('_barcode_1', '_barcode_2', '_barcode_3', '_barcode_4');
}
}

if (!function_exists('lpco_dms_get_product_barcode_values')) {
function lpco_dms_get_product_barcode_values($product_id) {
    $product_id = absint($product_id);
    $values = array();
    if ($product_id <= 0) return $values;

    foreach (lpco_dms_product_barcode_meta_keys() as $index => $meta_key) {
        $values[$meta_key] = function_exists('get_post_meta')
            ? (string) get_post_meta($product_id, $meta_key, true)
            : '';
    }
    return $values;
}
}

if (!function_exists('lpco_dms_clear_barcode_product_cache')) {
function lpco_dms_clear_barcode_product_cache($product_id, $reason = 'barcode_update') {
    $product_id = absint($product_id);
    if ($product_id <= 0) return;

    if (function_exists('wc_delete_product_transients')) {
        wc_delete_product_transients($product_id);
    }
    if (function_exists('lpco_dms_clear_catalog_cache_for_product')) {
        lpco_dms_clear_catalog_cache_for_product($product_id, $reason);
    } elseif (function_exists('lpco_dms_clear_catalog_cache')) {
        lpco_dms_clear_catalog_cache($reason, $product_id);
    }
}
}

if (!function_exists('lpco_dms_render_product_barcode_fields')) {
function lpco_dms_render_product_barcode_fields() {
    global $post;
    $product_id = isset($post->ID) ? absint($post->ID) : 0;
    if ($product_id <= 0) return;

    echo '<div class="options_group lpco-dms-product-barcodes">';
    foreach (lpco_dms_product_barcode_meta_keys() as $index => $meta_key) {
        $label = sprintf(__('Barcode %d', 'dms-ecom'), $index + 1);
        $value = function_exists('get_post_meta') ? get_post_meta($product_id, $meta_key, true) : '';
        if (function_exists('woocommerce_wp_text_input')) {
            woocommerce_wp_text_input(array(
                'id' => $meta_key,
                'label' => $label,
                'value' => $value,
                'desc_tip' => true,
                'description' => __('Used by the LPCO app search and barcode scanner.', 'dms-ecom'),
            ));
        } else {
            echo '<p class="form-field">';
            echo '<label for="' . esc_attr($meta_key) . '">' . esc_html($label) . '</label>';
            echo '<input type="text" class="short" name="' . esc_attr($meta_key) . '" id="' . esc_attr($meta_key) . '" value="' . esc_attr($value) . '">';
            echo '</p>';
        }
    }
    echo '</div>';
}
}
add_action('woocommerce_product_options_general_product_data', 'lpco_dms_render_product_barcode_fields');

if (!function_exists('lpco_dms_save_product_barcode_fields')) {
function lpco_dms_save_product_barcode_fields($post_id) {
    $post_id = absint($post_id);
    if ($post_id <= 0 || !current_user_can('edit_post', $post_id)) return;

    $changed = false;
    foreach (lpco_dms_product_barcode_meta_keys() as $meta_key) {
        if (!array_key_exists($meta_key, $_POST)) {
            continue;
        }

        $new_value = sanitize_text_field(wp_unslash($_POST[$meta_key]));
        $old_value = (string) get_post_meta($post_id, $meta_key, true);
        if ($new_value === '') {
            if ($old_value !== '') {
                delete_post_meta($post_id, $meta_key);
                $changed = true;
            }
            continue;
        }

        if ($new_value !== $old_value) {
            update_post_meta($post_id, $meta_key, $new_value);
            $changed = true;
        }
    }

    if ($changed) {
        lpco_dms_clear_barcode_product_cache($post_id, 'barcode_product_save');
    }
}
}
add_action('woocommerce_process_product_meta', 'lpco_dms_save_product_barcode_fields', 20);

if (!function_exists('lpco_dms_register_product_barcodes_admin_page')) {
function lpco_dms_register_product_barcodes_admin_page() {
    $parent_slug = function_exists('menu_page_url') ? 'dms-store-main' : 'woocommerce';
    add_submenu_page(
        $parent_slug,
        'Product Barcodes',
        'Product Barcodes',
        'manage_woocommerce',
        'lpco-product-barcodes',
        'lpco_dms_render_product_barcodes_admin_page'
    );
}
}
add_action('admin_menu', 'lpco_dms_register_product_barcodes_admin_page', 30);

if (!function_exists('lpco_dms_render_product_barcodes_admin_page')) {
function lpco_dms_render_product_barcodes_admin_page() {
    if (!current_user_can('manage_woocommerce')) {
        wp_die(esc_html__('You do not have permission to manage WooCommerce.', 'dms-ecom'));
    }

    $updated = isset($_GET['updated']) ? absint($_GET['updated']) : 0;
    $skipped = isset($_GET['skipped']) ? absint($_GET['skipped']) : 0;
    $errors = isset($_GET['errors']) ? absint($_GET['errors']) : 0;
    $message = isset($_GET['message']) ? sanitize_text_field(wp_unslash($_GET['message'])) : '';

    echo '<div class="wrap">';
    echo '<h1>' . esc_html__('Product Barcodes', 'dms-ecom') . '</h1>';

    if ($message !== '') {
        $notice_class = $errors > 0 ? 'notice-warning' : 'notice-success';
        echo '<div class="notice ' . esc_attr($notice_class) . ' is-dismissible"><p>';
        echo esc_html($message);
        if ($updated || $skipped || $errors) {
            echo ' ' . esc_html(sprintf('Updated: %d, skipped: %d, errors: %d.', $updated, $skipped, $errors));
        }
        echo '</p></div>';
    }

    echo '<p>' . esc_html__('CSV only. Empty barcode cells are ignored so existing barcodes are not cleared by accident.', 'dms-ecom') . '</p>';

    echo '<div class="card" style="max-width: 920px; padding: 16px; margin-top: 16px;">';
    echo '<h2>' . esc_html__('Export Barcodes', 'dms-ecom') . '</h2>';
    echo '<p>' . esc_html__('Exports SKU, Product ID, Product Name, and Barcode 1-4 as UTF-8 CSV for Excel.', 'dms-ecom') . '</p>';
    echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '">';
    echo '<input type="hidden" name="action" value="lpco_dms_export_product_barcodes">';
    wp_nonce_field('lpco_dms_export_product_barcodes');
    submit_button(__('Export CSV', 'dms-ecom'), 'primary', 'submit', false);
    echo '</form>';
    echo '</div>';

    echo '<div class="card" style="max-width: 920px; padding: 16px; margin-top: 16px;">';
    echo '<h2>' . esc_html__('Import Barcodes', 'dms-ecom') . '</h2>';
    echo '<p>' . esc_html__('Accepted headers: SKU, Product ID, Barcode1, Barcode2, Barcode3, Barcode4. SKU is used first, then Product ID as fallback.', 'dms-ecom') . '</p>';
    echo '<form method="post" action="' . esc_url(admin_url('admin-post.php')) . '" enctype="multipart/form-data">';
    echo '<input type="hidden" name="action" value="lpco_dms_import_product_barcodes">';
    wp_nonce_field('lpco_dms_import_product_barcodes');
    echo '<input type="file" name="barcode_csv" accept=".csv,text/csv" required>';
    submit_button(__('Import CSV', 'dms-ecom'), 'primary', 'submit', false);
    echo '</form>';
    echo '</div>';

    echo '</div>';
}
}

if (!function_exists('lpco_dms_export_product_barcodes')) {
function lpco_dms_export_product_barcodes() {
    if (!current_user_can('manage_woocommerce')) {
        wp_die(esc_html__('You do not have permission to manage WooCommerce.', 'dms-ecom'));
    }
    check_admin_referer('lpco_dms_export_product_barcodes');

    if (!function_exists('wc_get_products')) {
        wp_die(esc_html__('WooCommerce is required.', 'dms-ecom'));
    }

    nocache_headers();
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename=lpco-product-barcodes-' . gmdate('Y-m-d-H-i-s') . '.csv');

    $output = fopen('php://output', 'w');
    if (!$output) {
        exit;
    }

    fwrite($output, "\xEF\xBB\xBF");
    fputcsv($output, array('SKU', 'Product ID', 'Product Name', 'Barcode1', 'Barcode2', 'Barcode3', 'Barcode4'));

    $page = 1;
    do {
        $products = wc_get_products(array(
            'limit' => 200,
            'page' => $page,
            'status' => array('publish', 'draft', 'pending', 'private'),
            'return' => 'objects',
            'orderby' => 'ID',
            'order' => 'ASC',
        ));

        foreach ($products as $product) {
            if (!is_object($product) || !method_exists($product, 'get_id')) continue;
            $product_id = $product->get_id();
            $barcodes = lpco_dms_get_product_barcode_values($product_id);
            fputcsv($output, array(
                method_exists($product, 'get_sku') ? $product->get_sku() : '',
                $product_id,
                method_exists($product, 'get_name') ? $product->get_name() : '',
                $barcodes['_barcode_1'] ?? '',
                $barcodes['_barcode_2'] ?? '',
                $barcodes['_barcode_3'] ?? '',
                $barcodes['_barcode_4'] ?? '',
            ));
        }

        $page++;
    } while (!empty($products));

    fclose($output);
    exit;
}
}
add_action('admin_post_lpco_dms_export_product_barcodes', 'lpco_dms_export_product_barcodes');

if (!function_exists('lpco_dms_csv_header_key')) {
function lpco_dms_csv_header_key($value) {
    $value = preg_replace('/^\xEF\xBB\xBF/', '', (string) $value);
    $value = strtolower(trim($value));
    $value = str_replace(array(' ', '-', '__'), array('_', '_', '_'), $value);
    return preg_replace('/[^a-z0-9_]/', '', $value);
}
}

if (!function_exists('lpco_dms_build_barcode_import_header_map')) {
function lpco_dms_build_barcode_import_header_map($headers) {
    $aliases = array(
        'sku' => array('sku', 'product_sku'),
        'product_id' => array('product_id', 'productid', 'id', 'product'),
        '_barcode_1' => array('barcode1', 'barcode_1', '_barcode_1', 'barcode_01', 'barcode_1_'),
        '_barcode_2' => array('barcode2', 'barcode_2', '_barcode_2', 'barcode_02', 'barcode_2_'),
        '_barcode_3' => array('barcode3', 'barcode_3', '_barcode_3', 'barcode_03', 'barcode_3_'),
        '_barcode_4' => array('barcode4', 'barcode_4', '_barcode_4', 'barcode_04', 'barcode_4_'),
    );

    $map = array();
    foreach ((array) $headers as $index => $header) {
        $normalized = lpco_dms_csv_header_key($header);
        foreach ($aliases as $field => $field_aliases) {
            if (in_array($normalized, $field_aliases, true)) {
                $map[$field] = (int) $index;
                break;
            }
        }
    }
    return $map;
}
}

if (!function_exists('lpco_dms_import_product_barcodes_redirect')) {
function lpco_dms_import_product_barcodes_redirect($message, $updated = 0, $skipped = 0, $errors = 0) {
    $url = add_query_arg(
        array(
            'page' => 'lpco-product-barcodes',
            'message' => (string) $message,
            'updated' => absint($updated),
            'skipped' => absint($skipped),
            'errors' => absint($errors),
        ),
        admin_url('admin.php')
    );
    wp_safe_redirect($url);
    exit;
}
}

if (!function_exists('lpco_dms_import_product_barcodes')) {
function lpco_dms_import_product_barcodes() {
    if (!current_user_can('manage_woocommerce')) {
        wp_die(esc_html__('You do not have permission to manage WooCommerce.', 'dms-ecom'));
    }
    check_admin_referer('lpco_dms_import_product_barcodes');

    if (empty($_FILES['barcode_csv']) || !is_array($_FILES['barcode_csv'])) {
        lpco_dms_import_product_barcodes_redirect(__('No CSV file was uploaded.', 'dms-ecom'), 0, 0, 1);
    }

    $file = $_FILES['barcode_csv'];
    if (!empty($file['error'])) {
        lpco_dms_import_product_barcodes_redirect(__('Upload failed.', 'dms-ecom'), 0, 0, 1);
    }

    $file_name = isset($file['name']) ? sanitize_file_name($file['name']) : '';
    $file_size = isset($file['size']) ? absint($file['size']) : 0;
    $tmp_name = isset($file['tmp_name']) ? (string) $file['tmp_name'] : '';
    $extension = strtolower(pathinfo($file_name, PATHINFO_EXTENSION));

    if ($extension !== 'csv') {
        lpco_dms_import_product_barcodes_redirect(__('Only CSV files are supported for barcode import.', 'dms-ecom'), 0, 0, 1);
    }
    if ($file_size <= 0 || $file_size > 10 * 1024 * 1024) {
        lpco_dms_import_product_barcodes_redirect(__('CSV file size is invalid or larger than 10 MB.', 'dms-ecom'), 0, 0, 1);
    }
    if ($tmp_name === '' || !is_uploaded_file($tmp_name)) {
        lpco_dms_import_product_barcodes_redirect(__('Uploaded CSV file is not valid.', 'dms-ecom'), 0, 0, 1);
    }

    $handle = fopen($tmp_name, 'r');
    if (!$handle) {
        lpco_dms_import_product_barcodes_redirect(__('Could not read the uploaded CSV file.', 'dms-ecom'), 0, 0, 1);
    }

    $headers = fgetcsv($handle);
    if (!is_array($headers)) {
        fclose($handle);
        lpco_dms_import_product_barcodes_redirect(__('CSV file has no header row.', 'dms-ecom'), 0, 0, 1);
    }

    $map = lpco_dms_build_barcode_import_header_map($headers);
    if (empty($map['sku']) && empty($map['product_id'])) {
        fclose($handle);
        lpco_dms_import_product_barcodes_redirect(__('CSV must contain SKU or Product ID.', 'dms-ecom'), 0, 0, 1);
    }

    $updated = 0;
    $skipped = 0;
    $errors = 0;
    $changed_products = array();

    $GLOBALS['lpco_dms_suspend_catalog_cache_flush'] = true;
    while (($row = fgetcsv($handle)) !== false) {
        if (!is_array($row) || count(array_filter($row, 'strlen')) === 0) {
            continue;
        }

        $sku = isset($map['sku'], $row[$map['sku']]) ? sanitize_text_field($row[$map['sku']]) : '';
        $product_id = 0;
        if ($sku !== '' && function_exists('wc_get_product_id_by_sku')) {
            $product_id = absint(wc_get_product_id_by_sku($sku));
        }
        if ($product_id <= 0 && isset($map['product_id'], $row[$map['product_id']])) {
            $product_id = absint($row[$map['product_id']]);
        }

        if ($product_id <= 0 || get_post_type($product_id) !== 'product') {
            $errors++;
            continue;
        }

        $row_changed = false;
        foreach (lpco_dms_product_barcode_meta_keys() as $meta_key) {
            if (!isset($map[$meta_key]) || !array_key_exists($map[$meta_key], $row)) {
                continue;
            }

            $value = sanitize_text_field($row[$map[$meta_key]]);
            if ($value === '') {
                continue;
            }

            $old_value = (string) get_post_meta($product_id, $meta_key, true);
            if ($value !== $old_value) {
                update_post_meta($product_id, $meta_key, $value);
                $row_changed = true;
            }
        }

        if ($row_changed) {
            $updated++;
            $changed_products[$product_id] = $product_id;
        } else {
            $skipped++;
        }
    }
    fclose($handle);
    unset($GLOBALS['lpco_dms_suspend_catalog_cache_flush'], $GLOBALS['lpco_dms_deferred_catalog_cache_flush']);

    foreach ($changed_products as $changed_product_id) {
        if (function_exists('wc_delete_product_transients')) {
            wc_delete_product_transients($changed_product_id);
        }
        if (function_exists('clean_post_cache')) {
            clean_post_cache($changed_product_id);
        }
    }

    if (!empty($changed_products) && function_exists('lpco_dms_clear_catalog_cache')) {
        lpco_dms_clear_catalog_cache('barcode_import', 0);
    }

    lpco_dms_import_product_barcodes_redirect(__('Barcode import completed.', 'dms-ecom'), $updated, $skipped, $errors);
}
}
add_action('admin_post_lpco_dms_import_product_barcodes', 'lpco_dms_import_product_barcodes');
