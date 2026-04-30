<?php
/**
 * Admin Dashboard for Mobile App
 *
 * Adds secured admin pages for managing the mobile app settings, users, orders, and diagnostics.
 * Access is restricted to administrators (manage_options).
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_menu', function () {
    add_submenu_page(
        'dms-app-main',
        __('إحصائيات التطبيق', 'dms-ecom'),
        __('إحصائيات التطبيق', 'dms-ecom'),
        'manage_options',
        'dms-app-dashboard',
        'dms_app_admin_render'
    );

    $subpages = array(
        'dms-app-dashboard'          => __('نظرة عامة', 'dms-ecom'),
        'dms-app-dashboard-orders'   => __('مراقبة الطلبات', 'dms-ecom'),
        'dms-app-dashboard-users'    => __('المستخدمون والأدوار', 'dms-ecom'),
        'dms-app-dashboard-products' => __('المزامنة / التخزين المؤقت', 'dms-ecom'),
        'dms-app-dashboard-push'     => __('إرسال إشعار', 'dms-ecom'),
        'dms-app-dashboard-settings' => __('إعدادات التطبيق', 'dms-ecom'),
        'dms-app-dashboard-logs'     => __('السجلات والتشخيص', 'dms-ecom'),
    );

    foreach ($subpages as $slug => $title) {
        add_submenu_page(
            'dms-app-dashboard',
            $title,
            $title,
            'manage_options',
            $slug,
            'dms_app_admin_render'
        );
    }
});

/**
 * Render admin dashboard
 */
if (!function_exists('dms_app_admin_render')) {
    function dms_app_admin_render() {
        if (!current_user_can('manage_options')) {
            wp_die(__('ليس لديك صلاحية للوصول إلى هذه الصفحة', 'dms-ecom'), 403);
        }

        $current_page = isset($_GET['page']) ? sanitize_text_field(wp_unslash($_GET['page'])) : 'dms-app-dashboard';
        $active_tab   = isset($_GET['tab']) ? sanitize_text_field(wp_unslash($_GET['tab'])) : $current_page;

        // Handle settings save
        if (isset($_POST['dms_app_settings_nonce'])) {
            check_admin_referer('dms_app_settings_action', 'dms_app_settings_nonce');
            dms_app_save_settings();
            echo '<div class="updated"><p>' . esc_html__('تم حفظ الإعدادات', 'dms-ecom') . '</p></div>';
        }

        $settings = dms_app_get_settings();
        ?>
        <div class="wrap">
            <h1><?php esc_html_e('لوحة تحكم التطبيق', 'dms-ecom'); ?></h1>
            <nav class="nav-tab-wrapper">
                <?php
                $tabs = array(
                    'dms-app-dashboard'          => __('نظرة عامة', 'dms-ecom'),
                    'dms-app-dashboard-orders'   => __('مراقبة الطلبات', 'dms-ecom'),
                    'dms-app-dashboard-users'    => __('المستخدمون والأدوار', 'dms-ecom'),
                    'dms-app-dashboard-products' => __('المزامنة / التخزين المؤقت', 'dms-ecom'),
                    'dms-app-dashboard-push'     => __('إرسال إشعار', 'dms-ecom'),
                    'dms-app-dashboard-settings' => __('إعدادات التطبيق', 'dms-ecom'),
                    'dms-app-dashboard-logs'     => __('السجلات والتشخيص', 'dms-ecom'),
                );
                foreach ($tabs as $slug => $label) {
                    $class = $slug === $current_page ? 'nav-tab nav-tab-active' : 'nav-tab';
                    $url = admin_url('admin.php?page=' . $slug);
                    printf('<a href="%s" class="%s">%s</a>', esc_url($url), esc_attr($class), esc_html($label));
                }
                ?>
            </nav>

            <div class="dms-app-panel">
                <?php
                switch ($current_page) {
                    case 'dms-app-dashboard-orders':
                        dms_app_render_orders_monitor();
                        break;
                    case 'dms-app-dashboard-users':
                        dms_app_render_users();
                        break;
                    case 'dms-app-dashboard-products':
                        dms_app_render_products();
                        break;
                    case 'dms-app-dashboard-push':
                        dms_app_render_push($settings);
                        break;
                    case 'dms-app-dashboard-settings':
                        dms_app_render_settings_form($settings);
                        break;
                    case 'dms-app-dashboard-logs':
                        dms_app_render_logs_diag($settings);
                        break;
                    default:
                        dms_app_render_overview();
                }
                ?>
            </div>
        </div>
        <style>
            .dms-app-panel {background:#fff;border:1px solid #ccd0d4;padding:16px;margin-top:10px;}
            .dms-grid {display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;}
            .dms-card {border:1px solid #e1e1e1;padding:12px;border-radius:4px;background:#fafafa;}
            .dms-form-table th {width:240px;}
        </style>
        <?php
    }
}

if (!function_exists('dms_app_render_overview')) {
    function dms_app_render_overview() {
        $stats = function_exists('dms_admin_calculate_stats') ? dms_admin_calculate_stats() : array();
        ?>
        <div class="dms-grid">
            <div class="dms-card">
                <h3><?php esc_html_e('الطلبات اليوم', 'dms-ecom'); ?></h3>
                <p class="dms-stat"><?php echo (int)($stats['orders_today'] ?? 0); ?></p>
            </div>
            <div class="dms-card">
                <h3><?php esc_html_e('الطلبات هذا الشهر', 'dms-ecom'); ?></h3>
                <p class="dms-stat"><?php echo (int)($stats['orders_month'] ?? 0); ?></p>
            </div>
            <div class="dms-card">
                <h3><?php esc_html_e('مبيعات الشهر الحالي', 'dms-ecom'); ?></h3>
                <p class="dms-stat"><?php echo wc_price($stats['revenue_month'] ?? 0); ?></p>
            </div>
            <div class="dms-card">
                <h3><?php esc_html_e('إجمالي العملاء', 'dms-ecom'); ?></h3>
                <p class="dms-stat"><?php echo (int)($stats['total_members'] ?? 0); ?></p>
            </div>
        </div>

        <div style="margin-top: 20px;">
            <h3><?php esc_html_e('آخر الطلبات', 'dms-ecom'); ?></h3>
            <table class="wp-list-table widefat fixed striped">
                <thead>
                    <tr>
                        <th><?php esc_html_e('رقم الطلب', 'dms-ecom'); ?></th>
                        <th><?php esc_html_e('العميل', 'dms-ecom'); ?></th>
                        <th><?php esc_html_e('الحالة', 'dms-ecom'); ?></th>
                        <th><?php esc_html_e('الإجمالي', 'dms-ecom'); ?></th>
                        <th><?php esc_html_e('التاريخ', 'dms-ecom'); ?></th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (!empty($stats['latest_orders'])) : ?>
                        <?php foreach ($stats['latest_orders'] as $order) : ?>
                            <tr>
                                <td><a href="<?php echo get_edit_post_link($order['id']); ?>">#<?php echo esc_html($order['number']); ?></a></td>
                                <td><?php echo esc_html($order['customer']); ?></td>
                                <td><?php echo esc_html(wc_get_order_status_name($order['status'])); ?></td>
                                <td><?php echo wc_price($order['total']); ?></td>
                                <td><?php echo esc_html($order['date']); ?></td>
                            </tr>
                        <?php endforeach; ?>
                    <?php else : ?>
                        <tr><td colspan="5"><?php esc_html_e('لا توجد طلبات بعد.', 'dms-ecom'); ?></td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>

        <style>
            .dms-stat { font-size: 24px; font-weight: bold; color: #0073aa; margin: 10px 0 0; }
        </style>
        <?php
    }
}

if (!function_exists('dms_app_render_orders_monitor')) {
    function dms_app_render_orders_monitor() {
        ?>
        <h2><?php esc_html_e('مراقبة الطلبات', 'dms-ecom'); ?></h2>
        <p><?php esc_html_e('استخدم واجهة /wp-json/dms/v1/admin/orders للعرض التفصيلي.', 'dms-ecom'); ?></p>
        <?php
    }
}

if (!function_exists('dms_app_render_users')) {
    function dms_app_render_users() {
        ?>
        <h2><?php esc_html_e('المستخدمون والأدوار', 'dms-ecom'); ?></h2>
        <p><?php esc_html_e('الوصول للمديرين فقط. استخدم واجهة /wp-json/dms/v1/admin/users للبحث.', 'dms-ecom'); ?></p>
        <?php
    }
}

if (!function_exists('dms_app_render_products')) {
    function dms_app_render_products() {
        ?>
        <h2><?php esc_html_e('المزامنة / التخزين المؤقت', 'dms-ecom'); ?></h2>
        <p><?php esc_html_e('أعد بناء التخزين المؤقت للتطبيق أو تحقق من آخر مزامنة عبر واجهة الإدارة.', 'dms-ecom'); ?></p>
        <?php
    }
}

if (!function_exists('dms_app_render_push')) {
    function dms_app_render_push($settings) {
        if (!current_user_can('manage_options')) {
            wp_die(__('ليس لديك صلاحية', 'dms-ecom'), 403);
        }
        
        $notice = '';
        if (isset($_POST['dms_push_nonce']) && wp_verify_nonce($_POST['dms_push_nonce'], 'dms_push_action')) {
            $payload = array(
                'title' => sanitize_text_field($_POST['push_title'] ?? ''),
                'body' => sanitize_text_field($_POST['push_body'] ?? ''),
                'image' => esc_url_raw($_POST['push_image'] ?? ''),
                'deep_link' => sanitize_text_field($_POST['push_deep_link'] ?? ''),
                'audience' => sanitize_text_field($_POST['push_audience'] ?? 'all')
            );
            
            if (function_exists('dms_app_send_push_from_admin')) {
                $result = dms_app_send_push_from_admin($settings, $payload);
                if (is_wp_error($result)) {
                    $notice = '<div class="notice notice-error"><p>' . esc_html($result->get_error_message()) . '</p></div>';
                } else {
                    $sent = intval($result['sent'] ?? 0);
                    $failed = intval($result['failed'] ?? 0);
                    $notice = '<div class="notice notice-success"><p>' . sprintf(__('تم الإرسال: %d / فشل: %d', 'dms-ecom'), $sent, $failed) . '</p></div>';
                }
            } else {
                $notice = '<div class="notice notice-error"><p>' . esc_html__('دالة إرسال التنبيهات غير موجودة', 'dms-ecom') . '</p></div>';
            }
        }
        ?>
        <h2><?php esc_html_e('إرسال إشعار Push', 'dms-ecom'); ?></h2>
        <?php echo $notice; ?>
        <form method="post">
            <?php wp_nonce_field('dms_push_action', 'dms_push_nonce'); ?>
            <table class="form-table dms-form-table">
                <tr>
                    <th scope="row"><label for="push_title"><?php esc_html_e('العنوان', 'dms-ecom'); ?></label></th>
                    <td><input name="push_title" id="push_title" type="text" class="regular-text" required></td>
                </tr>
                <tr>
                    <th scope="row"><label for="push_body"><?php esc_html_e('المحتوى', 'dms-ecom'); ?></label></th>
                    <td><textarea name="push_body" id="push_body" rows="3" class="large-text" required></textarea></td>
                </tr>
                <tr>
                    <th scope="row"><label for="push_image"><?php esc_html_e('رابط صورة (اختياري)', 'dms-ecom'); ?></label></th>
                    <td><input name="push_image" id="push_image" type="text" class="regular-text" placeholder="https://..."></td>
                </tr>
                <tr>
                    <th scope="row"><label for="push_deep_link"><?php esc_html_e('رابط داخلي / Deep link', 'dms-ecom'); ?></label></th>
                    <td><input name="push_deep_link" id="push_deep_link" type="text" class="regular-text" placeholder="product:123 أو category:5"></td>
                </tr>
                <tr>
                    <th scope="row"><?php esc_html_e('الجمهور', 'dms-ecom'); ?></th>
                    <td>
                        <select name="push_audience">
                            <option value="all"><?php esc_html_e('كل الأجهزة', 'dms-ecom'); ?></option>
                            <option value="logged_in"><?php esc_html_e('المستخدمون المسجلون', 'dms-ecom'); ?></option>
                            <option value="guests"><?php esc_html_e('الضيوف فقط', 'dms-ecom'); ?></option>
                        </select>
                    </td>
                </tr>
            </table>
            <?php submit_button(__('إرسال الإشعار الآن', 'dms-ecom')); ?>
        </form>
        <?php
    }
}

if (!function_exists('dms_app_render_settings_form')) {
    function dms_app_render_settings_form($settings) {
        ?>
        <h2><?php esc_html_e('إعدادات التطبيق', 'dms-ecom'); ?></h2>
        <form method="post">
            <?php wp_nonce_field('dms_app_settings_action', 'dms_app_settings_nonce'); ?>
            <table class="form-table dms-form-table">
                <tr>
                    <th scope="row"><label for="exchange_rate_usd_syp"><?php esc_html_e('سعر الصرف USD/SYP', 'dms-ecom'); ?></label></th>
                    <td><input name="exchange_rate_usd_syp" id="exchange_rate_usd_syp" type="number" step="0.0001" value="<?php echo esc_attr($settings['exchange_rate_usd_syp']); ?>" class="regular-text" /></td>
                </tr>
                <tr>
                    <th scope="row"><label for="default_currency"><?php esc_html_e('العملة الافتراضية', 'dms-ecom'); ?></label></th>
                    <td><input name="default_currency" id="default_currency" type="text" value="<?php echo esc_attr($settings['default_currency']); ?>" class="regular-text" /></td>
                </tr>
                <tr>
                    <th scope="row"><?php esc_html_e('السماح للزوار بالدفع', 'dms-ecom'); ?></th>
                    <td><label><input type="checkbox" name="allow_guest_checkout" value="1" <?php checked($settings['allow_guest_checkout'], true); ?> /> <?php esc_html_e('تمكين', 'dms-ecom'); ?></label></td>
                </tr>
                <tr>
                    <th scope="row"><?php esc_html_e('تفعيل سجلات التصحيح', 'dms-ecom'); ?></th>
                    <td><label><input type="checkbox" name="enable_debug_logs" value="1" <?php checked($settings['enable_debug_logs'], true); ?> /> <?php esc_html_e('تفعيل', 'dms-ecom'); ?></label></td>
                </tr>
                <tr>
                    <th scope="row"><label for="cors_allowed_origins"><?php esc_html_e('نطاقات CORS المسموحة (سطر لكل نطاق)', 'dms-ecom'); ?></label></th>
                    <td><textarea name="cors_allowed_origins" id="cors_allowed_origins" rows="4" class="large-text code"><?php echo esc_textarea(implode("\n", $settings['cors_allowed_origins'])); ?></textarea></td>
                </tr>
                <tr>
                    <th scope="row"><label for="turnstile_site_key"><?php esc_html_e('Cloudflare Turnstile Site Key', 'dms-ecom'); ?></label></th>
                    <td><input name="turnstile_site_key" id="turnstile_site_key" type="text" value="<?php echo esc_attr($settings['turnstile_site_key']); ?>" class="regular-text" /></td>
                </tr>
                <tr>
                    <th scope="row"><label for="turnstile_secret_key"><?php esc_html_e('Cloudflare Turnstile Secret Key', 'dms-ecom'); ?></label></th>
                    <td><input name="turnstile_secret_key" id="turnstile_secret_key" type="password" value="<?php echo esc_attr($settings['turnstile_secret_key']); ?>" class="regular-text" /></td>
                </tr>
                <tr>
                    <th scope="row"><label for="recaptcha_site_key"><?php esc_html_e('reCAPTCHA Site Key', 'dms-ecom'); ?></label></th>
                    <td><input name="recaptcha_site_key" id="recaptcha_site_key" type="text" value="<?php echo esc_attr($settings['recaptcha_site_key']); ?>" class="regular-text" /></td>
                </tr>
                <tr>
                    <th scope="row"><label for="recaptcha_secret_key"><?php esc_html_e('reCAPTCHA Secret Key', 'dms-ecom'); ?></label></th>
                    <td><input name="recaptcha_secret_key" id="recaptcha_secret_key" type="password" value="<?php echo esc_attr($settings['recaptcha_secret_key']); ?>" class="regular-text" /></td>
                </tr>
            </table>
            <?php submit_button(__('حفظ الإعدادات', 'dms-ecom')); ?>
        </form>
        <?php
    }
}

if (!function_exists('dms_app_render_logs_diag')) {
    function dms_app_render_logs_diag($settings) {
        ?>
        <h2><?php esc_html_e('السجلات والتشخيص', 'dms-ecom'); ?></h2>
        <ul>
            <li><?php echo esc_html__('السجلات قيد التشغيل: ', 'dms-ecom') . ( !empty($settings['enable_debug_logs']) ? 'نعم' : 'لا'); ?></li>
            <li><?php echo esc_html__('CORS Origins: ', 'dms-ecom') . esc_html(implode(', ', $settings['cors_allowed_origins'])); ?></li>
            <li><?php echo esc_html__('وضع JWT: مفعّل', 'dms-ecom'); ?></li>
        </ul>
        <?php
    }
}

/**
 * Save settings
 */
if (!function_exists('dms_app_save_settings')) {
    function dms_app_save_settings() {
        $settings = dms_app_get_settings();
        $settings['exchange_rate_usd_syp'] = isset($_POST['exchange_rate_usd_syp']) ? floatval($_POST['exchange_rate_usd_syp']) : $settings['exchange_rate_usd_syp'];
        $settings['default_currency'] = isset($_POST['default_currency']) ? sanitize_text_field(wp_unslash($_POST['default_currency'])) : $settings['default_currency'];
        $settings['allow_guest_checkout'] = !empty($_POST['allow_guest_checkout']);
        $settings['enable_debug_logs'] = !empty($_POST['enable_debug_logs']);
        $origins_raw = isset($_POST['cors_allowed_origins']) ? explode("\n", wp_unslash($_POST['cors_allowed_origins'])) : array();
        $settings['cors_allowed_origins'] = array_filter(array_map('sanitize_text_field', array_map('trim', $origins_raw)));
        $settings['turnstile_site_key'] = isset($_POST['turnstile_site_key']) ? sanitize_text_field(wp_unslash($_POST['turnstile_site_key'])) : '';
        $settings['turnstile_secret_key'] = isset($_POST['turnstile_secret_key']) ? sanitize_text_field(wp_unslash($_POST['turnstile_secret_key'])) : '';
        $settings['recaptcha_site_key'] = isset($_POST['recaptcha_site_key']) ? sanitize_text_field(wp_unslash($_POST['recaptcha_site_key'])) : '';
        $settings['recaptcha_secret_key'] = isset($_POST['recaptcha_secret_key']) ? sanitize_text_field(wp_unslash($_POST['recaptcha_secret_key'])) : '';

        update_option('dms_app_settings', $settings, false);
    }
}

/**
 * Get settings with defaults
 */
if (!function_exists('dms_app_get_settings')) {
    function dms_app_get_settings() {
        $defaults = array(
            'exchange_rate_usd_syp' => 0,
            'default_currency' => 'syp',
            'allow_guest_checkout' => false,
            'enable_debug_logs' => false,
            'cors_allowed_origins' => array(),
            'turnstile_site_key' => '',
            'turnstile_secret_key' => '',
            'recaptcha_site_key' => '',
            'recaptcha_secret_key' => '',
        );
        $stored = get_option('dms_app_settings', array());
        return wp_parse_args($stored, $defaults);
    }
}

/**
 * Fetch push tokens from the new notifications tables as a fallback when the legacy device list is empty.
 */
if (!function_exists('dms_app_fetch_push_tokens')) {
    function dms_app_fetch_push_tokens($audience = 'all') {
        if (!function_exists('dms_notifications_tables')) {
            return array();
        }
        global $wpdb;
        $tables = dms_notifications_tables();
        $where = '1=1';
        if ($audience === 'logged_in') {
            $where = 'is_guest = 0 AND user_id IS NOT NULL';
        } elseif ($audience === 'guests') {
            $where = 'is_guest = 1';
        }
        $tokens = $wpdb->get_col("SELECT token FROM {$tables['tokens']} WHERE {$where} ORDER BY id DESC");
        return is_array($tokens) ? array_filter($tokens) : array();
    }
}

/**
 * Send push notification via FCM HTTP v1 (delegates to notifications module)
 */
if (!function_exists('dms_app_send_push_from_admin')) {
    function dms_app_send_push_from_admin($settings, $payload) {
        $audience = $payload['audience'] ?? 'all';
        if (!function_exists('dms_fcm_is_configured') || !dms_fcm_is_configured()) {
            return new WP_Error('missing_key', __('يرجى إضافة إعدادات FCM HTTP v1 من صفحة إعدادات إشعارات FCM', 'dms-ecom'));
        }

        if (!function_exists('dms_notifications_send')) {
            return new WP_Error('missing_module', __('وحدة التنبيهات غير مفعلة', 'dms-ecom'));
        }

        $result = dms_notifications_send(
            $payload['title'],
            $payload['body'],
            $payload['image'],
            $payload['deep_link'],
            $audience,
            0
        );

        if (is_wp_error($result)) {
            return $result;
        }

        $total = intval($result['total'] ?? 0);
        $sent = intval($result['sent'] ?? 0);
        $failed = max(0, $total - $sent);

        return array(
            'success' => true,
            'sent' => $sent,
            'failed' => $failed
        );
    }
}
