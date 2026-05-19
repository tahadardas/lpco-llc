<?php
/*
Plugin Name: LPCO LLC Commerce API
Description: نظام تسجيل وتصنيف زبائن وأسعار حسب التصنيف مع استيراد وتصدير، متوافقة مع ووكومرس.
Version: 7.0
Author: dms
*/
// القائمة الجانبية الرئيسية
add_action('admin_menu', function() {
    // 1. لوحة تحكم التطبيق
    add_menu_page(
        'لوحة تحكم التطبيق',
        'لوحة تحكم التطبيق',
        'manage_woocommerce',
        'dms-app-main',
        '__return_null',
        'dashicons-smartphone',
        55
    );

    // 2. إدارة المتجر والبيانات
    add_menu_page(
        'إدارة المتجر والبيانات',
        'إدارة المتجر والبيانات',
        'manage_woocommerce',
        'dms-store-main',
        '__return_null',
        'dashicons-database-add',
        56
    );
});


if (!defined('ABSPATH')) exit;

// Load API Foundations Early (to prevent TypeError during early REST requests)
require_once plugin_dir_path(__FILE__) . 'includes/api/contracts.php';
require_once plugin_dir_path(__FILE__) . 'includes/api/utils.php';
require_once plugin_dir_path(__FILE__) . 'includes/api/security-helpers.php';

/**
 * Check if WooCommerce is active
 */
if (!in_array('woocommerce/woocommerce.php', apply_filters('active_plugins', get_option('active_plugins')))) {
    add_action('admin_notices', function() {
        echo '<div class="notice notice-error"><p><strong>LPCO LLC Commerce:</strong> WooCommerce must be active for this plugin to function.</p></div>';
    });
    return;
}

define('DMS_ECOM_PATH', plugin_dir_path(__FILE__));

// JWT secret must be configured in wp-config.php (fail closed, no local fallback secret).
if (!defined('JWT_AUTH_SECRET_KEY') || trim((string) JWT_AUTH_SECRET_KEY) === '') {
    add_action('admin_notices', function () {
        if (!current_user_can('manage_options')) {
            return;
        }
        echo '<div class="notice notice-error"><p><strong>LPCO LLC Commerce:</strong> JWT_AUTH_SECRET_KEY is missing in wp-config.php. Auth-protected API endpoints will fail closed until it is configured.</p></div>';
    });
}

if (!defined('JWT_AUTH_CORS_ENABLE')) {
    define('JWT_AUTH_CORS_ENABLE', true);
}

// Toggle plugin debug logging (kept false in production to avoid noisy logs)
if (!defined('DMS_ECOM_DEBUG')) {
    $dms_settings = get_option('dms_app_settings', array());
    $debug_enabled = isset($dms_settings['enable_debug_logs']) && (bool) $dms_settings['enable_debug_logs'];
    define('DMS_ECOM_DEBUG', $debug_enabled);
}

// Load includes
include_once DMS_ECOM_PATH . 'includes/members.php';
include_once DMS_ECOM_PATH . 'includes/categories.php';
include_once DMS_ECOM_PATH . 'includes/products.php';
include_once DMS_ECOM_PATH . 'includes/product-barcodes.php';
include_once DMS_ECOM_PATH . 'includes/pricing-display.php';
include_once DMS_ECOM_PATH . 'includes/display-everywhere.php';
include_once DMS_ECOM_PATH . 'includes/product-ordering.php';
include_once DMS_ECOM_PATH . 'includes/member-sync.php';
require_once plugin_dir_path(__FILE__) . 'includes/import-export-products.php';
require_once plugin_dir_path(__FILE__) . 'includes/registration-fields.php';
include_once DMS_ECOM_PATH . 'includes/frontend-units.php';
include_once DMS_ECOM_PATH . 'includes/fcm-httpv1.php';
include_once DMS_ECOM_PATH . 'includes/notifications.php';
require_once DMS_ECOM_PATH . 'admin-notifications.php';
include_once DMS_ECOM_PATH . 'includes/app-layout-control.php';
include_once DMS_ECOM_PATH . 'includes/app-home-banner.php';
include_once DMS_ECOM_PATH . 'includes/app-popup-ad.php';
include_once DMS_ECOM_PATH . 'includes/api-endpoints.php';
include_once DMS_ECOM_PATH . 'includes/api/catalog-routes.php';
include_once DMS_ECOM_PATH . 'includes/api/orders-routes.php';
include_once DMS_ECOM_PATH . 'includes/api/users-routes.php';
include_once DMS_ECOM_PATH . 'includes/api/catalog-logic.php';
include_once DMS_ECOM_PATH . 'includes/api/order-logic.php';
include_once DMS_ECOM_PATH . 'includes/api/user-logic.php';
include_once DMS_ECOM_PATH . 'includes/admin-dashboard.php';
include_once DMS_ECOM_PATH . 'includes/admin-endpoints.php';
include_once DMS_ECOM_PATH . 'includes/app-home-layout.php';
include_once DMS_ECOM_PATH . 'includes/app-product-order-csv.php';
include_once DMS_ECOM_PATH . 'includes/invoices.php';
include_once DMS_ECOM_PATH . 'includes/payment-gateway-sham-cash.php';

if (!function_exists('dms_ecom_product_deeplink_bridge')) {
    function dms_ecom_product_deeplink_bridge() {
        if (is_admin() || wp_doing_ajax() || (defined('REST_REQUEST') && REST_REQUEST)) {
            return;
        }

        $request_uri = isset($_SERVER['REQUEST_URI']) ? (string) $_SERVER['REQUEST_URI'] : '';
        $request_path = parse_url($request_uri, PHP_URL_PATH);
        if (!is_string($request_path) || !preg_match('#^/product/(\d+)/?$#', $request_path, $matches)) {
            return;
        }

        $product_id = absint($matches[1]);
        if ($product_id <= 0) {
            return;
        }

        $product = function_exists('wc_get_product') ? wc_get_product($product_id) : null;
        if (!$product) {
            return;
        }

        $fallback_url = get_permalink($product_id);
        if (!is_string($fallback_url) || $fallback_url === '') {
            $fallback_url = home_url('/?p=' . $product_id);
        }
        if ($fallback_url === '' || strpos($fallback_url, '/product/' . $product_id) !== false) {
            $fallback_url = home_url('/?p=' . $product_id);
        }

        if (!empty($_GET) && function_exists('add_query_arg')) {
            $fallback_url = add_query_arg(wp_unslash($_GET), $fallback_url);
        }

        $deep_link = 'lpco:///product/' . $product_id;
        $title = function_exists('wp_strip_all_tags') ? wp_strip_all_tags($product->get_name()) : ('Product #' . $product_id);

        status_header(200);
        nocache_headers();
        header('Content-Type: text/html; charset=utf-8');
        ?>
        <!doctype html>
        <html lang="ar" dir="rtl">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <meta http-equiv="refresh" content="5;url=<?php echo esc_url($fallback_url); ?>">
            <title><?php echo esc_html($title); ?></title>
            <style>
                body { font-family: Arial, sans-serif; background: #f7f7f7; color: #111; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 24px; }
                .card { max-width: 420px; width: 100%; background: #fff; border-radius: 16px; padding: 24px; box-shadow: 0 12px 34px rgba(0,0,0,0.08); text-align: center; }
                .actions { margin-top: 18px; display: flex; flex-direction: column; gap: 10px; }
                .button { display: inline-block; padding: 12px 16px; border-radius: 10px; text-decoration: none; font-weight: 700; }
                .button-primary { background: #d31225; color: #fff; }
                .button-secondary { background: #f1f3f5; color: #111; }
                .muted { color: #666; font-size: 14px; }
            </style>
        </head>
        <body>
            <div class="card">
                <h1><?php echo esc_html($title); ?></h1>
                <p class="muted">جاري فتح المنتج داخل التطبيق، وسيتم التحويل إلى الموقع إذا لم يكن التطبيق مثبتاً.</p>
                <div class="actions">
                    <a class="button button-primary" href="<?php echo esc_attr($deep_link); ?>">فتح في التطبيق</a>
                    <a class="button button-secondary" href="<?php echo esc_url($fallback_url); ?>">المتابعة في الموقع</a>
                </div>
            </div>
            <script>
                (function () {
                    var deepLink = <?php echo wp_json_encode($deep_link); ?>;
                    var fallback = <?php echo wp_json_encode($fallback_url); ?>;
                    var navigated = false;
                    var timer = setTimeout(function () {
                        if (!navigated) {
                            window.location.replace(fallback);
                        }
                    }, 1400);

                    window.addEventListener('pagehide', function () {
                        navigated = true;
                        clearTimeout(timer);
                    });

                    window.location.href = deepLink;
                })();
            </script>
        </body>
        </html>
        <?php
        exit;
    }
}

add_action('template_redirect', 'dms_ecom_product_deeplink_bridge', 1);

if (class_exists('DMS_App_Notifications_Admin')) {
    new DMS_App_Notifications_Admin();
}

// Create required tables on activation
if (function_exists('dms_notifications_activate')) {
    register_activation_hook(__FILE__, 'dms_notifications_activate');
}
