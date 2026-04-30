<?php
/**
 * App Orders admin page + PDF invoice generation (HTTP download + REST token)
 */

if (!defined('ABSPATH')) {
    exit;
}

// Always show item meta in WooCommerce emails (color/unit, etc.)
add_filter('woocommerce_email_order_items_args', function ($args) {
    $args['show_meta'] = true;
    return $args;
});

function dms_invoice_supported_email_ids() {
    return array(
        'new_order',
        'customer_invoice',
        'customer_processing_order',
        'customer_on_hold_order',
        'customer_completed_order',
    );
}

function dms_invoice_resolve_attachment_path($order, $force = false) {
    if (!$order instanceof WC_Order) {
        $order = wc_get_order($order);
    }

    if (!$order) {
        return new WP_Error('order_not_found', 'الطلب غير موجود.', array('status' => 404));
    }

    $stored_path = $order->get_meta('dms_invoice_pdf', true);
    if (
        !$force &&
        is_string($stored_path) &&
        $stored_path !== '' &&
        file_exists($stored_path) &&
        is_readable($stored_path) &&
        filesize($stored_path) > 0
    ) {
        return $stored_path;
    }

    $pdf_result = dms_invoice_generate_pdf($order->get_id(), $force);
    if (is_wp_error($pdf_result)) {
        return $pdf_result;
    }

    $pdf_path = isset($pdf_result['path']) ? (string) $pdf_result['path'] : '';
    if (
        $pdf_path === '' ||
        !file_exists($pdf_path) ||
        !is_readable($pdf_path) ||
        filesize($pdf_path) <= 0
    ) {
        return new WP_Error(
            'invoice_pdf_missing',
            'تعذر تجهيز ملف PDF صالح لإرفاقه مع البريد.'
        );
    }

    return $pdf_path;
}

add_filter('woocommerce_email_attachments', function ($attachments, $email_id, $order, $email) {
    if (!in_array($email_id, dms_invoice_supported_email_ids(), true)) {
        return $attachments;
    }

    if (!$order instanceof WC_Order) {
        $order = wc_get_order($order);
    }

    if (!$order || $order->get_meta('dms_order_source', true) !== 'app') {
        return $attachments;
    }

    $pdf_path = dms_invoice_resolve_attachment_path($order);
    if (is_wp_error($pdf_path)) {
        if (function_exists('dms_ecom_log')) {
            dms_ecom_log(
                'Failed to attach invoice PDF to WooCommerce email',
                'error',
                array(
                    'order_id' => $order->get_id(),
                    'email_id' => $email_id,
                    'message' => $pdf_path->get_error_message(),
                )
            );
        }

        $pdf_path = dms_invoice_resolve_attachment_path($order, true);
        if (is_wp_error($pdf_path)) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log(
                    'Retry failed while attaching invoice PDF to WooCommerce email',
                    'error',
                    array(
                        'order_id' => $order->get_id(),
                        'email_id' => $email_id,
                        'message' => $pdf_path->get_error_message(),
                    )
                );
            }
            return $attachments;
        }
    }

    if (!in_array($pdf_path, $attachments, true)) {
        $attachments[] = $pdf_path;
    }

    return $attachments;
}, 10, 4);

add_action('admin_menu', function () {
    add_submenu_page(
        'dms-store-main',
        'طلبات التطبيق',
        'طلبات التطبيق',
        'manage_woocommerce',
        'dms-app-orders',
        'dms_app_orders_admin_page'
    );
});

add_action('admin_init', 'dms_invoice_admin_download_handler');

if (!function_exists('dms_invoice_current_user_can_manage')) {
function dms_invoice_current_user_can_manage() {
    $allowed = current_user_can('manage_woocommerce') || current_user_can('manage_options');
    return (bool) apply_filters('dms_invoice_current_user_can_manage', $allowed, get_current_user_id());
}
}

function dms_invoice_permission(WP_REST_Request $request) {
    $order_id = intval($request->get_param('order_id'));
    if ($order_id <= 0) {
        return new WP_Error('invalid_order_id', 'رقم الطلب غير صالح', array('status' => 400));
    }

    $order = wc_get_order($order_id);
    if (!$order) {
        return new WP_Error('order_not_found', 'الطلب غير موجود', array('status' => 404));
    }

    $token = sanitize_text_field($request->get_param('token'));
    if ($token !== '' && function_exists('dms_invoice_validate_token')) {
        if (dms_invoice_validate_token($order, $token)) {
            return true;
        }
    }

    $current_user = get_current_user_id();
    $is_owner = $current_user && intval($order->get_customer_id()) === $current_user;
    $has_cap = function_exists('dms_invoice_current_user_can_manage') ? dms_invoice_current_user_can_manage() : current_user_can('manage_woocommerce');
    if ($is_owner || $has_cap) {
        return true;
    }

    return new WP_Error('forbidden', 'غير مسموح بتحميل الفاتورة', array('status' => 403));
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/orders/invoice', array(
        'methods' => 'GET',
        'callback' => 'dms_invoice_rest_download',
        'permission_callback' => 'dms_invoice_permission',
        'args' => array(
            'order_id' => array(
                'required' => true,
                'type' => 'integer'
            ),
            'token' => array(
                'required' => false,
                'type' => 'string'
            )
        )
    ));
});

/**
 * Directories
 */
function dms_invoice_upload_dir() {
    $uploads = wp_upload_dir();
    return trailingslashit($uploads['basedir']) . 'dms-invoices';
}

function dms_invoice_upload_url() {
    $uploads = wp_upload_dir();
    return trailingslashit($uploads['baseurl']) . 'dms-invoices';
}

function dms_invoice_recursive_delete($path) {
    if (!is_string($path) || $path === '' || !file_exists($path)) {
        return;
    }

    if (is_file($path) || is_link($path)) {
        @unlink($path);
        return;
    }

    $entries = scandir($path);
    if (!is_array($entries)) {
        return;
    }

    foreach ($entries as $entry) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        dms_invoice_recursive_delete($path . DIRECTORY_SEPARATOR . $entry);
    }

    @rmdir($path);
}

function dms_invoice_release_urls() {
    return array(
        '2.0.8' => 'https://github.com/dompdf/dompdf/releases/download/v2.0.8/dompdf-2.0.8.zip',
        '2.0.3' => 'https://github.com/dompdf/dompdf/releases/download/v2.0.3/dompdf-2.0.3.zip',
    );
}

function dms_invoice_plugin_vendor_root() {
    if (!defined('DMS_ECOM_PATH')) {
        return '';
    }

    return trailingslashit(DMS_ECOM_PATH) . 'vendor';
}

function dms_invoice_bundled_dompdf_autoload_path() {
    $vendor_root = dms_invoice_plugin_vendor_root();
    if ($vendor_root === '') {
        return '';
    }

    return trailingslashit($vendor_root) . 'dompdf/autoload.inc.php';
}

function dms_invoice_library_root() {
    $uploads = wp_upload_dir();
    return trailingslashit($uploads['basedir']) . 'dms-dompdf';
}

function dms_invoice_dompdf_autoload_path() {
    return trailingslashit(dms_invoice_library_root()) . 'dompdf/autoload.inc.php';
}

function dms_invoice_require_dompdf($autoload) {
    if (!is_string($autoload) || $autoload === '' || !file_exists($autoload)) {
        return false;
    }

    require_once $autoload;
    return class_exists('\\Dompdf\\Dompdf');
}

function dms_invoice_attachment_file_path($attachment_id, $size = 'full') {
    $attachment_id = absint($attachment_id);
    if ($attachment_id <= 0) {
        return '';
    }

    $original_path = get_attached_file($attachment_id);
    if (!is_string($original_path) || $original_path === '' || !file_exists($original_path)) {
        return '';
    }

    if ($size !== 'full') {
        $image = image_get_intermediate_size($attachment_id, $size);
        if (is_array($image) && !empty($image['file'])) {
            $candidate = trailingslashit(dirname($original_path)) . wp_basename($image['file']);
            if (file_exists($candidate)) {
                return $candidate;
            }
        }
    }

    return $original_path;
}

function dms_invoice_file_to_data_uri($file_path) {
    if (!is_string($file_path) || $file_path === '' || !file_exists($file_path) || !is_readable($file_path)) {
        return '';
    }

    $contents = file_get_contents($file_path);
    if ($contents === false || $contents === '') {
        return '';
    }

    $filetype = wp_check_filetype($file_path);
    $mime = !empty($filetype['type']) ? $filetype['type'] : 'application/octet-stream';

    return 'data:' . $mime . ';base64,' . base64_encode($contents);
}

function dms_invoice_attachment_src($attachment_id, $size = 'full') {
    $file_path = dms_invoice_attachment_file_path($attachment_id, $size);
    if ($file_path !== '') {
        $data_uri = dms_invoice_file_to_data_uri($file_path);
        if ($data_uri !== '') {
            return $data_uri;
        }
    }

    $url = wp_get_attachment_image_url($attachment_id, $size);
    return is_string($url) ? $url : '';
}

function dms_invoice_order_item_image_src($item) {
    if (!$item instanceof WC_Order_Item_Product) {
        return '';
    }

    $stored_url = '';
    foreach (array('image_url', 'product_image') as $meta_key) {
        $candidate = trim((string) $item->get_meta($meta_key));
        if ($candidate !== '') {
            $stored_url = $candidate;
            break;
        }
    }

    $attachment_id = 0;
    $product = $item->get_product();
    if ($product) {
        $attachment_id = absint($product->get_image_id());
    }

    if ($attachment_id <= 0) {
        $variation_id = absint($item->get_variation_id());
        if ($variation_id > 0) {
            $attachment_id = absint(get_post_thumbnail_id($variation_id));
        }
    }

    if ($attachment_id <= 0) {
        $product_id = absint($item->get_product_id());
        if ($product_id > 0) {
            $attachment_id = absint(get_post_thumbnail_id($product_id));
        }
    }

    if ($attachment_id > 0) {
        $src = dms_invoice_attachment_src($attachment_id, 'thumbnail');
        if ($src !== '') {
            return $src;
        }
    }

    if ($stored_url !== '') {
        return $stored_url;
    }

    if (function_exists('dms_ecom_resolve_product_image_url')) {
        $resolved = dms_ecom_resolve_product_image_url(
            $item->get_product(),
            $item->get_product_id(),
            $item->get_variation_id(),
            'thumbnail'
        );
        if (is_string($resolved) && $resolved !== '') {
            return $resolved;
        }
    }

    if (function_exists('dms_ecom_log')) {
        dms_ecom_log('warning', 'Invoice item image could not be resolved', array(
            'item_id' => $item->get_id(),
            'product_id' => $item->get_product_id(),
            'variation_id' => $item->get_variation_id(),
        ));
    }

    if (function_exists('wc_placeholder_img_src')) {
        return (string) wc_placeholder_img_src('thumbnail');
    }

    return '';
}

function dms_invoice_has_arabic($text) {
    if (!is_string($text) || $text === '') {
        return false;
    }

    return preg_match('/\p{Arabic}/u', $text) === 1;
}

function dms_invoice_arphp_dir() {
    $uploads = wp_upload_dir();
    return trailingslashit($uploads['basedir']) . 'dms-arphp';
}

function dms_invoice_bundled_arphp_file() {
    $vendor_root = dms_invoice_plugin_vendor_root();
    if ($vendor_root === '') {
        return '';
    }

    return trailingslashit($vendor_root) . 'arphp/Arabic.php';
}

function dms_invoice_arphp_file() {
    return trailingslashit(dms_invoice_arphp_dir()) . 'Arabic.php';
}

function dms_invoice_arphp_urls() {
    return array(
        '7.0.0' => 'https://raw.githubusercontent.com/khaled-alshamaa/ar-php/v7.0.0/src/Arabic.php',
        '7.0.0-fallback' => 'https://raw.githubusercontent.com/khaled-alshamaa/ar-php/master/src/Arabic.php',
    );
}

function dms_invoice_require_arphp($file) {
    if (!is_string($file) || $file === '' || !file_exists($file)) {
        return false;
    }

    require_once $file;
    return class_exists('\\ArPHP\\I18N\\Arabic');
}

function dms_invoice_ensure_arphp() {
    if (class_exists('\\ArPHP\\I18N\\Arabic')) {
        return true;
    }

    $bundled_file = dms_invoice_bundled_arphp_file();
    if ($bundled_file !== '' && dms_invoice_require_arphp($bundled_file)) {
        return true;
    }

    $dir = dms_invoice_arphp_dir();
    $file = dms_invoice_arphp_file();
    $version_file = trailingslashit($dir) . 'version.txt';
    $known_versions = array_keys(dms_invoice_arphp_urls());
    $installed_version = file_exists($version_file) ? trim((string) file_get_contents($version_file)) : '';

    if (in_array($installed_version, $known_versions, true) && dms_invoice_require_arphp($file)) {
        return true;
    }

    wp_mkdir_p($dir);

    foreach (dms_invoice_arphp_urls() as $version => $url) {
        $response = wp_remote_get($url, array('timeout' => 60));
        if (is_wp_error($response)) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log('Failed to download Arabic shaping helper from ' . $url . ': ' . $response->get_error_message(), 'error');
            }
            continue;
        }

        $body = wp_remote_retrieve_body($response);
        if (empty($body)) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log('Downloaded Arabic shaping helper was empty from ' . $url, 'error');
            }
            continue;
        }

        if (file_put_contents($file, $body) === false) {
            return new WP_Error('arphp_download_failed', 'تعذر حفظ معالج العربية على الخادم.');
        }

        if (dms_invoice_require_arphp($file)) {
            file_put_contents($version_file, $version);
            return true;
        }
    }

    return new WP_Error('arphp_missing', 'تعذر تجهيز معالج النص العربي للفاتورة.');
}

function dms_invoice_pdf_text($text) {
    if ($text === null) {
        return '';
    }

    if (!is_scalar($text)) {
        return '';
    }

    $text = (string) $text;
    if ($text === '' || !dms_invoice_has_arabic($text)) {
        return $text;
    }

    static $arabic = null;
    static $arphp_ready = null;

    if ($arphp_ready === null) {
        $arphp_ready = dms_invoice_ensure_arphp();
    }

    if (is_wp_error($arphp_ready) || $arphp_ready !== true) {
        return $text;
    }

    if ($arabic === null) {
        try {
            $arabic = new \ArPHP\I18N\Arabic();
        } catch (Throwable $e) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log('Failed to initialize Arabic library: ' . $e->getMessage(), 'error');
            }
            $arphp_ready = false;
            return $text;
        }
    }

    try {
        return $arabic->utf8Glyphs($text, 512, false, true);
    } catch (Throwable $e) {
        if (function_exists('dms_ecom_log')) {
            dms_ecom_log('Arabic glyph shaping failed: ' . $e->getMessage(), 'error');
        }
        return $text;
    }
}

function dms_invoice_esc_html($text) {
    return esc_html(dms_invoice_pdf_text($text));
}

function dms_invoice_esc_attr($text) {
    return esc_attr(dms_invoice_pdf_text($text));
}

/**
 * Ensure dompdf library is available (download-on-demand to uploads/)
 */
function dms_invoice_ensure_dompdf() {
    if (class_exists('\\Dompdf\\Dompdf')) {
        return true;
    }

    $bundled_autoload = dms_invoice_bundled_dompdf_autoload_path();
    if ($bundled_autoload !== '' && dms_invoice_require_dompdf($bundled_autoload)) {
        return true;
    }

    $uploads = wp_upload_dir();
    $lib_root = trailingslashit($uploads['basedir']) . 'dms-dompdf';
    $autoload = $lib_root . '/dompdf/autoload.inc.php';

    if (!file_exists($autoload)) {
        wp_mkdir_p($lib_root);
        $zip_url = 'https://github.com/dompdf/dompdf/archive/refs/tags/v2.0.3.zip';
        $zip_path = $lib_root . '/dompdf.zip';

        $response = wp_remote_get($zip_url, array('timeout' => 45));
        if (is_wp_error($response)) {
            return $response;
        }
        $body = wp_remote_retrieve_body($response);
        if (empty($body)) {
            return new WP_Error('dompdf_download_failed', 'تعذر تنزيل مكتبة PDF (dompdf).');
        }
        file_put_contents($zip_path, $body);

        // Extract
        $extracted = false;
        if (class_exists('ZipArchive')) {
            $zip = new ZipArchive();
            if ($zip->open($zip_path) === true) {
                $zip->extractTo($lib_root);
                $zip->close();
                $extracted = true;
            }
        }

        if (!$extracted) {
            require_once ABSPATH . 'wp-admin/includes/class-pclzip.php';
            $archive = new PclZip($zip_path);
            $extracted = (bool) $archive->extract(PCLZIP_OPT_PATH, $lib_root);
        }

        @unlink($zip_path);

        if (!$extracted) {
            return new WP_Error('dompdf_extract_failed', 'تعذر استخراج مكتبة PDF.');
        }

        // Normalize folder name to /dompdf
        $glob = glob($lib_root . '/dompdf-*');
        if (!empty($glob)) {
            @rename($glob[0], $lib_root . '/dompdf');
        }
    }

    if (file_exists($autoload)) {
        require_once $autoload;
        return class_exists('\\Dompdf\\Dompdf');
    }

    return new WP_Error('dompdf_missing', 'مكتبة PDF غير متوفرة.');
}

function dms_invoice_prepare_dompdf() {
    if (class_exists('\\Dompdf\\Dompdf')) {
        return true;
    }

    $bundled_autoload = dms_invoice_bundled_dompdf_autoload_path();
    if ($bundled_autoload !== '' && dms_invoice_require_dompdf($bundled_autoload)) {
        return true;
    }

    $lib_root = dms_invoice_library_root();
    $autoload = dms_invoice_dompdf_autoload_path();

    $version_file = trailingslashit($lib_root) . 'version.txt';
    $installed_version = file_exists($version_file) ? trim((string) file_get_contents($version_file)) : '';
    $known_versions = array_keys(dms_invoice_release_urls());

    if (in_array($installed_version, $known_versions, true) && dms_invoice_require_dompdf($autoload)) {
        return true;
    }

    wp_mkdir_p($lib_root);

    foreach (dms_invoice_release_urls() as $version => $zip_url) {
        if ($installed_version === $version && dms_invoice_require_dompdf($autoload)) {
            return true;
        }

        dms_invoice_recursive_delete(trailingslashit($lib_root) . 'dompdf');
        foreach (glob(trailingslashit($lib_root) . 'dompdf-*') ?: array() as $legacy_dir) {
            dms_invoice_recursive_delete($legacy_dir);
        }
        foreach (glob(trailingslashit($lib_root) . 'dompdf_*') ?: array() as $legacy_dir) {
            dms_invoice_recursive_delete($legacy_dir);
        }

        $zip_path = trailingslashit($lib_root) . 'dompdf.zip';
        $response = wp_remote_get($zip_url, array('timeout' => 60));
        if (is_wp_error($response)) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log('Failed to download dompdf package from ' . $zip_url . ': ' . $response->get_error_message(), 'error');
            }
            continue;
        }

        $body = wp_remote_retrieve_body($response);
        if (empty($body)) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log('Downloaded dompdf package was empty from ' . $zip_url, 'error');
            }
            continue;
        }

        if (file_put_contents($zip_path, $body) === false) {
            return new WP_Error('dompdf_download_failed', 'تعذر حفظ مكتبة PDF على الخادم.');
        }

        $extracted = false;
        if (class_exists('ZipArchive')) {
            $zip = new ZipArchive();
            if ($zip->open($zip_path) === true) {
                $zip->extractTo($lib_root);
                $zip->close();
                $extracted = true;
            }
        }

        if (!$extracted) {
            require_once ABSPATH . 'wp-admin/includes/class-pclzip.php';
            $archive = new PclZip($zip_path);
            $extracted = (bool) $archive->extract(PCLZIP_OPT_PATH, $lib_root);
        }

        @unlink($zip_path);

        if (!$extracted) {
            if (function_exists('dms_ecom_log')) {
                dms_ecom_log('Failed to extract dompdf package ' . $zip_url, 'error');
            }
            continue;
        }

        foreach (glob(trailingslashit($lib_root) . 'dompdf-*') ?: array() as $extracted_dir) {
            if (is_dir($extracted_dir)) {
                @rename($extracted_dir, trailingslashit($lib_root) . 'dompdf');
                break;
            }
        }
        foreach (glob(trailingslashit($lib_root) . 'dompdf_*') ?: array() as $extracted_dir) {
            if (is_dir($extracted_dir) && !file_exists(trailingslashit($lib_root) . 'dompdf')) {
                @rename($extracted_dir, trailingslashit($lib_root) . 'dompdf');
                break;
            }
        }

        if (file_exists($autoload) && dms_invoice_require_dompdf($autoload)) {
            file_put_contents($version_file, $version);
            return true;
        }
    }

    return new WP_Error('dompdf_missing', 'تعذر تجهيز مكتبة PDF (dompdf).');
}

/**
 * Build invoice HTML (RTL friendly)
 */
function dms_invoice_build_html($order) {
    if (!$order || !is_a($order, 'WC_Order')) {
        return '';
    }

    $logo = '';
    $custom_logo_id = get_theme_mod('custom_logo');
    if ($custom_logo_id) {
        $logo = dms_invoice_attachment_src($custom_logo_id, 'medium');
    } else {
        $email_settings = get_option('woocommerce_email_header_image');
        if (!empty($email_settings)) {
            $logo = $email_settings;
        }
    }

    $store_name = get_bloginfo('name');
    $order_date = $order->get_date_created() ? $order->get_date_created()->date_i18n('Y-m-d H:i') : '';
    $billing_phone = $order->get_billing_phone();
    $billing_company = $order->get_billing_company();
    $warehouse = function_exists('dms_ecom_get_order_warehouse_payload')
        ? dms_ecom_get_order_warehouse_payload($order)
        : array('label' => '', 'codes' => array());
    $warehouse_label = trim((string) ($warehouse['label'] ?? ''));

    ob_start();
    ?>
    <html dir="rtl" lang="ar">
    <head>
        <meta charset="UTF-8">
        <style>
            body { font-family: 'DejaVu Sans', sans-serif; direction: rtl; }
            .header { display: flex; justify-content: space-between; align-items: center; }
            .logo { max-height: 60px; }
            .meta { margin-top: 10px; }
            table { width: 100%; border-collapse: collapse; margin-top: 15px; }
            th, td { border: 1px solid #ccc; padding: 8px; text-align: right; }
            th { background: #f5f5f5; }
            .image-cell { width: 74px; text-align: center; vertical-align: middle; }
            .item-image { width: 56px; height: 56px; object-fit: cover; border: 1px solid #ddd; border-radius: 6px; padding: 2px; background: #fff; }
            .no-image { display: inline-block; width: 56px; height: 56px; line-height: 56px; text-align: center; border: 1px solid #ddd; border-radius: 6px; color: #777; font-size: 10px; background: #fafafa; }
            .totals { margin-top: 15px; width: 40%; float: left; }
            .totals table { width: 100%; }
        </style>
    </head>
    <body>
        <div class="header">
            <div>
                <h2><?php echo dms_invoice_esc_html($store_name); ?></h2>
                <div class="meta">
                    <div><?php echo dms_invoice_esc_html('رقم الطلب'); ?>: #<?php echo esc_html($order->get_order_number()); ?></div>
                    <div><?php echo dms_invoice_esc_html('التاريخ'); ?>: <?php echo esc_html($order_date); ?></div>
                </div>
            </div>
            <?php if ($warehouse_label !== ''): ?>
                <div class="meta"><?php echo dms_invoice_esc_html('المستودع'); ?>: <?php echo dms_invoice_esc_html($warehouse_label); ?></div>
            <?php endif; ?>
            <?php if ($logo): ?>
                <div><img class="logo" src="<?php echo esc_attr($logo); ?>" alt=""></div>
            <?php endif; ?>
        </div>

        <h3><?php echo dms_invoice_esc_html('بيانات العميل'); ?></h3>
        <div>
            <div><?php echo dms_invoice_esc_html('الاسم'); ?>: <?php echo dms_invoice_esc_html($order->get_formatted_billing_full_name()); ?></div>
            <?php if ($billing_company): ?>
                <div><?php echo dms_invoice_esc_html('المنشأة'); ?>: <?php echo dms_invoice_esc_html($billing_company); ?></div>
            <?php endif; ?>
            <div><?php echo dms_invoice_esc_html('الهاتف'); ?>: <?php echo dms_invoice_esc_html($billing_phone); ?></div>
            <div><?php echo dms_invoice_esc_html('العنوان'); ?>: <?php echo dms_invoice_esc_html($order->get_billing_address_1()); ?></div>
            <div><?php echo dms_invoice_esc_html('المدينة'); ?>: <?php echo dms_invoice_esc_html($order->get_billing_city()); ?></div>
        </div>

        <h3><?php echo dms_invoice_esc_html('المنتجات'); ?></h3>
        <table>
            <thead>
                <tr>
                    <th class="image-cell"><?php echo dms_invoice_esc_html('الصورة'); ?></th>
                    <th><?php echo dms_invoice_esc_html('المنتج'); ?></th>
                    <th><?php echo dms_invoice_esc_html('اللون/السمات'); ?></th>
                    <th><?php echo dms_invoice_esc_html('الوحدة'); ?></th>
                    <th><?php echo dms_invoice_esc_html('الكمية'); ?></th>
                    <th><?php echo dms_invoice_esc_html('السعر'); ?></th>
                    <th><?php echo dms_invoice_esc_html('المجموع'); ?></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($order->get_items() as $item_id => $item): ?>
                    <?php
                    $meta = $item->get_meta_data();
                    $attrs = array();
                    foreach ($meta as $m) {
                        if (strpos($m->key, 'attribute_') === 0) {
                            $attrs[] = wc_attribute_label(substr($m->key, 10)) . ': ' . $m->value;
                        }
                    }
                    $image_src = dms_invoice_order_item_image_src($item);
                    $unit = $item->get_meta('unit_name') ?: $item->get_meta('dms_unit_name');
                    $unit_type = $item->get_meta('unit_type') ?: $item->get_meta('dms_unit_type');
                    $unit_pieces = $item->get_meta('unit_pieces') ?: $item->get_meta('dms_unit_pieces_count');
                    ?>
                    <tr>
                        <td class="image-cell">
                            <?php if ($image_src !== ''): ?>
                                <img class="item-image" src="<?php echo esc_attr($image_src); ?>" alt="<?php echo dms_invoice_esc_attr($item->get_name()); ?>">
                            <?php else: ?>
                                <span class="no-image"><?php echo dms_invoice_esc_html('بدون صورة'); ?></span>
                            <?php endif; ?>
                        </td>
                        <td><?php echo dms_invoice_esc_html($item->get_name()); ?></td>
                        <td><?php echo dms_invoice_esc_html(implode(' | ', $attrs)); ?></td>
                        <td><?php echo dms_invoice_esc_html(trim(($unit ?: '') . ($unit_type ? " ({$unit_type})" : '') . ($unit_pieces ? " ({$unit_pieces})" : ''))); ?></td>
                        <td><?php echo esc_html($item->get_quantity()); ?></td>
                        <td><?php echo wp_kses_post(wc_price($item->get_total() / max(1, $item->get_quantity()), array('currency' => $order->get_currency()))); ?></td>
                        <td><?php echo wp_kses_post(wc_price($item->get_total(), array('currency' => $order->get_currency()))); ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>

        <div class="totals">
            <table>
                <tr>
                    <th><?php echo dms_invoice_esc_html('الإجمالي'); ?></th>
                    <td><?php echo wp_kses_post(wc_price($order->get_total(), array('currency' => $order->get_currency()))); ?></td>
                </tr>
            </table>
        </div>
    </body>
    </html>
    <?php
    return ob_get_clean();
}

/**
 * Generate PDF to uploads folder
 */
function dms_invoice_generate_pdf($order_id, $force = false) {
    if (function_exists('dms_ecom_log')) {
        dms_ecom_log('Starting PDF generation for order ' . $order_id);
    }
    
    $order = wc_get_order($order_id);
    if (!$order) {
        return new WP_Error('order_not_found', 'الطلب غير موجود.', array('status' => 404));
    }

    $upload_dir = dms_invoice_upload_dir();
    $mkdir_res = wp_mkdir_p($upload_dir);
    if (!$mkdir_res) {
        if (function_exists('dms_ecom_log')) {
            dms_ecom_log('Failed to create/verify upload directory: ' . $upload_dir, 'error');
        }
    }
    
    $pdf_path = trailingslashit($upload_dir) . 'invoice-' . $order->get_id() . '.pdf';

    if (
        !$force &&
        file_exists($pdf_path) &&
        is_readable($pdf_path) &&
        filesize($pdf_path) > 0
    ) {
        if (function_exists('dms_ecom_log')) {
            dms_ecom_log('PDF already exists: ' . $pdf_path);
        }
        return array(
            'path' => $pdf_path,
            'url' => trailingslashit(dms_invoice_upload_url()) . basename($pdf_path)
        );
    }

    $dompdf_ready = dms_invoice_prepare_dompdf();
    if (is_wp_error($dompdf_ready)) {
        if (function_exists('dms_ecom_log')) {
            dms_ecom_log('Dompdf library not ready: ' . $dompdf_ready->get_error_message(), 'error');
        }
        return $dompdf_ready;
    }

    if (function_exists('dms_ecom_log')) {
        dms_ecom_log('Dompdf library ready, building HTML');
    }

    $html = dms_invoice_build_html($order);
    
    try {
        $options = new Dompdf\Options();
        $options->set('isRemoteEnabled', true);
        $options->set('defaultFont', 'DejaVu Sans');
        $dompdf = new Dompdf\Dompdf($options);
        $dompdf->loadHtml($html, 'UTF-8');
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();

        $output = $dompdf->output();
        if (empty($output)) {
            throw new Exception('Dompdf output is empty.');
        }

        $write_res = file_put_contents($pdf_path, $output);
        if ($write_res === false) {
             throw new Exception('Failed to write PDF to disk at ' . $pdf_path);
        }
        clearstatcache(true, $pdf_path);
        if (!file_exists($pdf_path) || filesize($pdf_path) <= 0) {
            throw new Exception('PDF file was created but is empty at ' . $pdf_path);
        }

        if (function_exists('dms_ecom_log')) {
            dms_ecom_log('PDF successfully written to ' . $pdf_path);
        }

        $url = trailingslashit(dms_invoice_upload_url()) . basename($pdf_path);
        $order->update_meta_data('dms_invoice_pdf', $pdf_path);
        $order->save_meta_data();

        return array('path' => $pdf_path, 'url' => $url);
    } catch (Throwable $e) {
        if (function_exists('dms_ecom_log')) {
            dms_ecom_log('PDF generation exception: ' . $e->getMessage(), 'error');
        }
        return new WP_Error('pdf_exception', 'خطأ أثناء إنشاء PDF: ' . $e->getMessage());
    }
}

/**
 * Token helpers
 */
function dms_invoice_issue_token($order_id, $ttl = 3600) {
    $order = wc_get_order($order_id);
    if (!$order) {
        return '';
    }
    $token = wp_generate_password(32, false, false);
    $order->update_meta_data('dms_invoice_token', $token);
    $order->update_meta_data('dms_invoice_token_expiration', time() + absint($ttl));
    $order->save_meta_data();
    return $token;
}

function dms_invoice_validate_token($order, $token) {
    if (!$order || !$token) return false;
    $stored = $order->get_meta('dms_invoice_token');
    $expires = intval($order->get_meta('dms_invoice_token_expiration'));
    if (empty($stored) || $stored !== $token) return false;
    if ($expires && time() > $expires) return false;
    return true;
}

function dms_invoice_get_download_url($order_id, $token) {
    $base = rest_url('dms/v1/orders/invoice');
    return add_query_arg(array(
        'order_id' => $order_id,
        'token' => $token
    ), $base);
}

/**
 * REST download
 */
function dms_invoice_rest_download(WP_REST_Request $request) {
    $order_id = intval($request->get_param('order_id'));
    $token = sanitize_text_field($request->get_param('token'));
    $order = wc_get_order($order_id);

    if (!$order) {
        return new WP_Error('order_not_found', 'الطلب غير موجود', array('status' => 404));
    }

    $current_user = get_current_user_id();
    $is_owner = $current_user && intval($order->get_customer_id()) === $current_user;
    $has_cap = function_exists('dms_invoice_current_user_can_manage') ? dms_invoice_current_user_can_manage() : current_user_can('manage_woocommerce');

    $token_valid = dms_invoice_validate_token($order, $token);
    if (!$token_valid && !$is_owner && !$has_cap) {
        return new WP_Error('forbidden', 'غير مسموح بتحميل الفاتورة', array('status' => 403));
    }

    $pdf = dms_invoice_generate_pdf($order_id);
    if (is_wp_error($pdf)) {
        return $pdf;
    }

    $file = $pdf['path'];
    if (!file_exists($file)) {
        return new WP_Error('not_found', 'تعذر العثور على الفاتورة', array('status' => 404));
    }

    $response = new WP_REST_Response(file_get_contents($file));
    $response->set_status(200);
    $response->header('Content-Type', 'application/pdf');
    $response->header('Content-Disposition', 'attachment; filename="invoice-' . $order->get_order_number() . '.pdf"');
    return $response;
}

/**
 * Admin page renderer
 */
function dms_app_orders_admin_page() {
    if (!(function_exists('dms_invoice_current_user_can_manage') ? dms_invoice_current_user_can_manage() : current_user_can('manage_woocommerce'))) {
        wp_die(__('Unauthorized', 'dms'));
    }

    $orders = wc_get_orders(array(
        'limit' => 50,
        'orderby' => 'date',
        'order' => 'DESC',
        'meta_key' => 'dms_order_source',
        'meta_value' => 'app'
    ));
    ?>
    <div class="wrap">
        <h1>طلبات التطبيق</h1>
        <table class="widefat striped">
            <thead>
                <tr>
                    <th>#</th>
                    <th>التاريخ</th>
                    <th>العميل</th>
                    <th>الهاتف</th>
                    <th>الإجمالي</th>
                    <th>الحالة</th>
                    <th>إجراءات</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($orders)): ?>
                    <tr><td colspan="7">لا توجد طلبات من التطبيق.</td></tr>
                <?php else: ?>
                    <?php foreach ($orders as $order): ?>
                        <?php
                        $order_id = $order->get_id();
                        $download_url = wp_nonce_url(
                            add_query_arg(array(
                                'page' => 'dms-app-orders',
                                'dms_download_invoice' => $order_id
                            ), admin_url('admin.php')),
                            'dms_download_invoice_' . $order_id
                        );
                        ?>
                        <tr>
                            <td>#<?php echo esc_html($order->get_order_number()); ?></td>
                            <td><?php echo esc_html($order->get_date_created() ? $order->get_date_created()->date_i18n('Y-m-d H:i') : ''); ?></td>
                            <td><?php echo esc_html($order->get_formatted_billing_full_name()); ?></td>
                            <td><?php echo esc_html($order->get_billing_phone()); ?></td>
                            <td><?php echo wp_kses_post(wc_price($order->get_total(), array('currency' => $order->get_currency()))); ?></td>
                            <td><?php echo esc_html(wc_get_order_status_name($order->get_status())); ?></td>
                            <td>
                                <a class="button" href="<?php echo esc_url(get_edit_post_link($order_id)); ?>">عرض في ووكومرس</a>
                                <a class="button button-secondary" href="<?php echo esc_url($download_url); ?>">تحميل PDF</a>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
    <?php
}

/**
 * Admin download handler (nonce protected)
 */
function dms_invoice_admin_download_handler() {
    if (empty($_GET['dms_download_invoice'])) {
        return;
    }
    $order_id = absint($_GET['dms_download_invoice']);
    if (!(function_exists('dms_invoice_current_user_can_manage') ? dms_invoice_current_user_can_manage() : current_user_can('manage_woocommerce'))) {
        wp_die(__('Unauthorized', 'dms'));
    }
    check_admin_referer('dms_download_invoice_' . $order_id);

    $pdf = dms_invoice_generate_pdf($order_id, true);
    if (is_wp_error($pdf)) {
        wp_die($pdf->get_error_message());
    }

    $file = $pdf['path'];
    if (!file_exists($file)) {
        wp_die('File not found');
    }

    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="invoice-' . basename($file) . '"');
    readfile($file);
    exit;
}
