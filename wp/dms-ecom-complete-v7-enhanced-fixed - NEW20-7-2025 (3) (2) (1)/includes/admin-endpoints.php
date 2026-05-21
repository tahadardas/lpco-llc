<?php
/**
 * Admin-only REST endpoints
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1/admin', '/capabilities', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_capabilities',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/stats', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_stats',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/orders', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_orders',
        'permission_callback' => 'dms_admin_permissions',
        'args' => array(
            'search' => array('sanitize_callback' => 'sanitize_text_field'),
            'status' => array('sanitize_callback' => 'sanitize_text_field'),
            'date_from' => array('sanitize_callback' => 'sanitize_text_field'),
            'date_to' => array('sanitize_callback' => 'sanitize_text_field'),
            'sort' => array('sanitize_callback' => 'sanitize_text_field'),
            'page' => array('sanitize_callback' => 'absint', 'default' => 1),
            'per_page' => array('sanitize_callback' => 'absint', 'default' => 25),
        ),
    ));

    register_rest_route('dms/v1/admin', '/users', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_users',
        'permission_callback' => 'dms_admin_permissions',
        'args' => array(
            'search' => array('sanitize_callback' => 'sanitize_text_field'),
            'role' => array('sanitize_callback' => 'sanitize_text_field'),
            'group' => array('sanitize_callback' => 'sanitize_text_field'),
            'status' => array('sanitize_callback' => 'sanitize_text_field'),
            'page' => array('sanitize_callback' => 'absint', 'default' => 1),
            'per_page' => array('sanitize_callback' => 'absint', 'default' => 25),
        ),
    ));

    register_rest_route('dms/v1/admin', '/users/(?P<id>\d+)', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_user_details',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/members', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_members_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_create_member_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/members/(?P<id>\d+)', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_member_details_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => 'dms_admin_update_member_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::DELETABLE,
            'callback' => 'dms_admin_delete_member_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/orders/(?P<id>\d+)', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_order_details',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/orders/(?P<id>\d+)/status', array(
        'methods' => WP_REST_Server::CREATABLE,
        'callback' => 'dms_admin_update_order_status',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/settings', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_settings_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_settings_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/diagnostics', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_diagnostics_v2',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/products', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_products_v2',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/products/(?P<id>\d+)', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_product_details_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => 'dms_admin_update_product_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/reviews', array(
        'methods' => WP_REST_Server::READABLE,
        'callback' => 'dms_admin_get_reviews_v2',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/reviews/(?P<id>\d+)/status', array(
        'methods' => WP_REST_Server::CREATABLE,
        'callback' => 'dms_admin_update_review_status_v2',
        'permission_callback' => 'dms_admin_permissions',
    ));

    register_rest_route('dms/v1/admin', '/notifications/emails', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_notification_emails_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_notification_emails_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/home-banner', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_home_banner_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_home_banner_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/home-layout', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_home_layout_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_home_layout_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/theme', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_app_theme_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_app_theme_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/popup', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_popup_config_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_popup_config_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));

    register_rest_route('dms/v1/admin', '/ordering', array(
        array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => 'dms_admin_get_ordering_config_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
        array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => 'dms_admin_save_ordering_config_v2',
            'permission_callback' => 'dms_admin_permissions',
        ),
    ));
});

if (!function_exists('dms_admin_permissions')) {
    function dms_admin_permissions($request = null) {
        if (!is_user_logged_in() && function_exists('dms_validate_jwt_request')) {
            $jwt_result = dms_validate_jwt_request($request instanceof WP_REST_Request ? $request : null);
            if (is_wp_error($jwt_result)) {
                return $jwt_result;
            }
        }
        if (!is_user_logged_in()) {
            return new WP_Error('rest_forbidden', __('يجب تسجيل الدخول', 'dms-ecom'), array('status' => 401));
        }
        $allowed = current_user_can('manage_woocommerce') || current_user_can('manage_options');
        $allowed = (bool) apply_filters('dms_admin_rest_allowed', $allowed, get_current_user_id());
        if (!$allowed) {
            return new WP_Error('rest_forbidden', __('ليس لديك صلاحية للوصول', 'dms-ecom'), array('status' => 403));
        }
        return true;
    }
}

if (!function_exists('dms_admin_list_response')) {
    function dms_admin_list_response($items, $page, $per_page, $total, $total_pages = null, $status = 200) {
        if (function_exists('dms_api_list_response') && function_exists('dms_api_pagination_meta')) {
            return dms_api_list_response(
                $items,
                dms_api_pagination_meta($page, $per_page, $total, $total_pages),
                $status
            );
        }

        return new WP_REST_Response(array(
            'items' => array_values(is_array($items) ? $items : array()),
            'meta' => array(
                'page' => max(1, intval($page)),
                'per_page' => max(1, intval($per_page)),
                'total' => max(0, intval($total)),
                'total_pages' => max(1, intval($total_pages === null ? ceil(max(0, intval($total)) / max(1, intval($per_page))) : $total_pages)),
            ),
        ), $status);
    }
}

if (!function_exists('dms_admin_detail_response')) {
    function dms_admin_detail_response($data, $status = 200) {
        if (function_exists('dms_api_detail_response')) {
            return dms_api_detail_response(is_array($data) ? $data : array(), $status);
        }

        return new WP_REST_Response(array('data' => is_array($data) ? $data : array()), $status);
    }
}

if (!function_exists('dms_admin_action_response')) {
    function dms_admin_action_response($message, $data = array(), $status = 200) {
        if (function_exists('dms_api_action_response')) {
            return dms_api_action_response($message, is_array($data) ? $data : array(), $status);
        }

        return new WP_REST_Response(array(
            'success' => true,
            'message' => (string) $message,
            'data' => is_array($data) ? $data : array(),
        ), $status);
    }
}

if (!function_exists('dms_admin_safe_string')) {
    function dms_admin_safe_string($value) {
        return is_scalar($value) ? trim((string) $value) : '';
    }
}

if (!function_exists('dms_admin_string_contains')) {
    function dms_admin_string_contains($haystack, $needle) {
        $haystack = dms_admin_safe_string($haystack);
        $needle = dms_admin_safe_string($needle);
        if ($needle === '') {
            return true;
        }
        if ($haystack === '') {
            return false;
        }
        if (function_exists('mb_stripos')) {
            return mb_stripos($haystack, $needle) !== false;
        }
        return stripos($haystack, $needle) !== false;
    }
}

if (!function_exists('dms_admin_normalize_phone')) {
    function dms_admin_normalize_phone($value) {
        return preg_replace('/\D+/', '', dms_admin_safe_string($value));
    }
}

if (!function_exists('dms_admin_allowed_warehouses_for_current_user')) {
    function dms_admin_allowed_warehouses_for_current_user() {
        $values = apply_filters('dms_admin_allowed_warehouses_for_user', array(), get_current_user_id());
        $allowed = array();
        foreach ((array) $values as $value) {
            $value = trim((string) $value);
            if ($value !== '') {
                $allowed[$value] = true;
            }
        }
        return array_keys($allowed);
    }
}

if (!function_exists('dms_admin_parse_id_list')) {
    function dms_admin_parse_id_list($value) {
        if (is_array($value)) {
            return array_values(array_filter(array_map('intval', $value)));
        }

        $value = dms_admin_safe_string($value);
        if ($value === '') {
            return array();
        }

        return array_values(array_filter(array_map('intval', array_map('trim', explode(',', $value)))));
    }
}

if (!function_exists('dms_admin_meta_value')) {
    function dms_admin_meta_value($user_id, $keys, $default = '') {
        foreach ((array) $keys as $key) {
            $value = get_user_meta($user_id, $key, true);
            if ($value !== '' && $value !== null) {
                return is_scalar($value) ? (string) $value : $value;
            }
        }
        return $default;
    }
}

if (!function_exists('dms_admin_default_account_status')) {
    function dms_admin_default_account_status() {
        if (function_exists('dms_get_default_account_status')) {
            return (string) dms_get_default_account_status();
        }
        return 'pending';
    }
}

if (!function_exists('dms_admin_module_capability_rows')) {
    function dms_admin_module_capability_rows() {
        return array(
            array('id' => 'orders', 'title' => 'إدارة الطلبات', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'users', 'title' => 'إدارة المستخدمين', 'support' => 'read_only', 'can_read' => true, 'can_write' => false),
            array('id' => 'members', 'title' => 'إدارة الأعضاء', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'settings', 'title' => 'إعدادات التطبيق', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'diagnostics', 'title' => 'التشخيص', 'support' => 'read_only', 'can_read' => true, 'can_write' => false),
            array('id' => 'notifications', 'title' => 'مركز الإشعارات', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'home-banner', 'title' => 'بانر الرئيسية', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'home-layout', 'title' => 'تخطيط الرئيسية', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'app-theme', 'title' => 'ثيم التطبيق', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'popup-config', 'title' => 'الإعلان المنبثق', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'products', 'title' => 'إدارة المنتجات', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'reviews', 'title' => 'مراجعة التقييمات', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
            array('id' => 'ordering', 'title' => 'ترتيب الواجهة', 'support' => 'full_control', 'can_read' => true, 'can_write' => true),
        );
    }
}

if (!function_exists('dms_admin_get_capabilities')) {
    function dms_admin_get_capabilities(WP_REST_Request $request) {
        return dms_admin_detail_response(array(
            'generated_at' => current_time('c'),
            'modules' => dms_admin_module_capability_rows(),
        ));
    }
}

if (!function_exists('dms_admin_calculate_stats')) {
    /**
     * Helper to calculate dashboard statistics - Optimized for high performance and low memory
     */
    function dms_admin_calculate_stats() {
        $cache_key = 'dms_admin_stats_cache';
        $cached = get_transient($cache_key);
        if ($cached !== false && is_array($cached)) {
            return $cached;
        }

        try {
            global $wpdb;
            $statuses = array_map(function ($status) {
                return 'wc-' . str_replace('wc-', '', $status);
            }, array_keys(wc_get_order_statuses()));
            
            // Limit to common active statuses for stats if needed, or use all
            $active_statuses = array('wc-completed', 'wc-processing', 'wc-pending', 'wc-on-hold');

            $today = current_time('Y-m-d');
            $month_start = current_time('Y-m-01');

            // 1. Efficient Counts using built-in WC counts (cached)
            $pending_count = function_exists('wc_orders_count') ? intval(wc_orders_count('pending')) : 0;
            $completed_count = function_exists('wc_orders_count') ? intval(wc_orders_count('completed')) : 0;
            $total_customers = count_users()['avail_roles']['customer'] ?? 0;

            // 2. Today's Orders (Count only IDs - very light)
            $today_orders_count = count(wc_get_orders(array(
                'limit' => 1000, // Safety limit
                'status' => $statuses,
                'return' => 'ids',
                'date_created' => $today . '...' . $today,
            )));

            // 3. Status list for SQL
            $status_list = "'" . implode("','", $statuses) . "'";
            
            // 4. Monthly Statistics (Handles both Legacy and HPOS storage)
            // SQL works for legacy posts table. For HPOS, we'd need wc_orders table.
            // But we can use wc_get_orders with 'return' => 'ids' for count, and a light loop for revenue if legacy.
            // Optimized Revenue Query:
            $revenue_month = 0;
            $orders_month = 0;

            // Check if HPOS is active (High Performance Order Storage)
            $hpos_enabled = false;
            if (class_exists('Automattic\WooCommerce\Utilities\OrderUtil') && method_exists('Automattic\WooCommerce\Utilities\OrderUtil', 'custom_orders_table_usage_is_enabled')) {
                $hpos_enabled = \Automattic\WooCommerce\Utilities\OrderUtil::custom_orders_table_usage_is_enabled();
            }

            if ($hpos_enabled) {
                // HPOS Query (using wc_orders table)
                $order_table = $wpdb->prefix . 'wc_orders';
                $rev_data = $wpdb->get_row($wpdb->prepare("
                    SELECT COUNT(id) as count, SUM(total_amount) as revenue
                    FROM $order_table
                    WHERE status IN ($status_list)
                    AND date_created_gmt >= %s
                ", $month_start));
                $orders_month = intval($rev_data->count ?? 0);
                $revenue_month = floatval($rev_data->revenue ?? 0);
            } else {
                // Legacy Posts Query
                $rev_data = $wpdb->get_row($wpdb->prepare("
                    SELECT COUNT(posts.ID) as count, SUM(CAST(meta.meta_value AS DECIMAL(15,2))) as revenue
                    FROM {$wpdb->posts} as posts
                    INNER JOIN {$wpdb->postmeta} as meta ON posts.ID = meta.post_id
                    WHERE posts.post_type = 'shop_order'
                    AND posts.post_status IN ($status_list)
                    AND posts.post_date >= %s
                    AND meta.meta_key = '_order_total'
                ", $month_start));
                $orders_month = intval($rev_data->count ?? 0);
                $revenue_month = floatval($rev_data->revenue ?? 0);
            }

            // 4. Latest data (Limited to small numbers)
            $latest_orders = array();
            foreach (wc_get_orders(array(
                'limit' => 5,
                'status' => $statuses,
                'orderby' => 'date',
                'order' => 'DESC',
                'return' => 'objects',
            )) as $order) {
                $latest_orders[] = dms_admin_order_summary_payload($order);
            }

            $latest_members = array();
            $member_query = new WP_User_Query(array(
                'number' => 5,
                'orderby' => 'registered',
                'order' => 'DESC',
                'role__in' => array('customer'),
                'count_total' => false,
            ));
            foreach ($member_query->get_results() as $user) {
                $latest_members[] = dms_admin_member_payload($user);
            }

            // 5. External components
            $notifications = function_exists('dms_admin_notifications_counters')
                ? dms_admin_notifications_counters()
                : array('unread_notifications_count' => 0, 'device_tokens_count' => 0, 'latest_notifications' => array());
            
            $diagnostics = function_exists('dms_admin_diagnostics_payload')
                ? dms_admin_diagnostics_payload()
                : array('warnings' => array());

            $stats = array(
                'orders_today' => $today_orders_count,
                'orders_month' => $orders_month,
                'revenue_month' => $revenue_month,
                'total_members' => (int)$total_customers,
                'pending_orders' => $pending_count,
                'completed_orders' => $completed_count,
                'unread_notifications_count' => intval($notifications['unread_notifications_count'] ?? 0),
                'device_tokens_count' => intval($notifications['device_tokens_count'] ?? 0),
                'low_stock_products_count' => function_exists('dms_admin_low_stock_products_count') ? dms_admin_low_stock_products_count() : 0,
                'latest_orders' => $latest_orders,
                'latest_members' => $latest_members,
                'latest_notifications' => $notifications['latest_notifications'] ?? array(),
                'warnings' => $diagnostics['warnings'] ?? array(),
            );

            set_transient($cache_key, $stats, 600); // 10 minutes cache
            return $stats;
        } catch (Throwable $e) {
            error_log('Admin Stats Error: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
            return array(
                'orders_today' => 0,
                'orders_month' => 0,
                'revenue_month' => 0,
                'total_members' => 0,
                'pending_orders' => 0,
                'completed_orders' => 0,
                'unread_notifications_count' => 0,
                'device_tokens_count' => 0,
                'low_stock_products_count' => 0,
                'latest_orders' => array(),
                'latest_members' => array(),
                'latest_notifications' => array(),
                'warnings' => array('Error calculating stats: ' . $e->getMessage()),
            );
        }
    }
}

if (!function_exists('dms_admin_member_payload')) {
    /**
     * Standardizes user/member data for the admin dashboard.
     */
    function dms_admin_member_payload($user) {
        if (!$user instanceof WP_User) {
            $user = get_userdata($user);
        }
        if (!$user) return array();

        $first_name = get_user_meta($user->ID, 'first_name', true);
        $last_name = get_user_meta($user->ID, 'last_name', true);
        $full_name = trim($first_name . ' ' . $last_name);
        if (empty($full_name)) $full_name = $user->display_name;

        return array(
            'id' => (int) $user->ID,
            'name' => $full_name,
            'username' => $user->user_login,
            'email' => $user->user_email,
            'phone' => get_user_meta($user->ID, 'billing_phone', true) ?: get_user_meta($user->ID, 'account_whatsapp', true),
            'group' => get_user_meta($user->ID, 'dms_user_group', true) ?: 'default',
            'account_status' => get_user_meta($user->ID, 'dms_account_status', true) ?: 'جديد',
            'registered_at' => $user->user_registered,
        );
    }
}

if (!function_exists('dms_admin_notifications_counters')) {
    /**
     * Fetches notification-related counters and recent history.
     */
    function dms_admin_notifications_counters() {
        global $wpdb;
        $table = $wpdb->prefix . 'dms_notifications';
        
        $unread = 0;
        if ($wpdb->get_var("SHOW TABLES LIKE '$table'")) {
            $unread = (int) $wpdb->get_var("SELECT COUNT(*) FROM $table WHERE is_read = 0");
        }

        $tokens = 0;
        $token_table = $wpdb->prefix . 'dms_device_tokens';
        if ($wpdb->get_var("SHOW TABLES LIKE '$token_table'")) {
            $tokens = (int) $wpdb->get_var("SELECT COUNT(*) FROM $token_table");
        }

        return array(
            'unread_notifications_count' => $unread,
            'device_tokens_count' => $tokens,
            'latest_notifications' => array(), // Can be expanded if needed
        );
    }
}

if (!function_exists('dms_admin_diagnostics_payload')) {
    /**
     * Gathers system diagnostic information.
     */
    function dms_admin_diagnostics_payload() {
        return array(
            'warnings' => array(),
            'sections' => array(
                array(
                    'title' => 'الخادم',
                    'items' => array(
                        array('label' => 'PHP Version', 'value' => PHP_VERSION, 'status' => 'ok'),
                        array('label' => 'Memory Limit', 'value' => ini_get('memory_limit'), 'status' => 'ok'),
                    )
                )
            )
        );
    }
}

if (!function_exists('dms_admin_low_stock_products_count')) {
    /**
     * Counts products with low stock.
     */
    function dms_admin_low_stock_products_count() {
        $threshold = get_option('woocommerce_notify_low_stock_amount', 2);
        return count(wc_get_products(array(
            'status' => 'publish',
            'stock_status' => 'instock',
            'low_stock_amount' => $threshold,
            'return' => 'ids',
        )));
    }
}


if (!function_exists('dms_admin_get_stats')) {
    function dms_admin_get_stats(WP_REST_Request $request) {
        return dms_admin_detail_response(dms_admin_calculate_stats());
    }
}

if (!function_exists('dms_admin_order_matches_search')) {
    function dms_admin_order_matches_search($order, $search) {
        if (!$order instanceof WC_Order) {
            return false;
        }

        $search = dms_admin_safe_string($search);
        if ($search === '') {
            return true;
        }

        foreach (array(
            $order->get_order_number(),
            '#' . $order->get_order_number(),
            $order->get_formatted_billing_full_name(),
            $order->get_billing_phone(),
            $order->get_billing_company(),
            $order->get_billing_email(),
        ) as $field) {
            if (dms_admin_string_contains($field, $search)) {
                return true;
            }
        }

        $search_phone = dms_admin_normalize_phone($search);
        return $search_phone !== '' && strpos(dms_admin_normalize_phone($order->get_billing_phone()), $search_phone) !== false;
    }
}

if (!function_exists('dms_admin_order_matches_warehouse')) {
    function dms_admin_order_matches_warehouse($order, $requested_warehouse = '') {
        if (!$order instanceof WC_Order) {
            return false;
        }

        $requested_warehouse = dms_admin_safe_string($requested_warehouse);
        $payload = function_exists('dms_ecom_get_order_warehouse_payload')
            ? dms_ecom_get_order_warehouse_payload($order)
            : array('code' => '', 'codes' => array());
        $codes = array();
        foreach ((array) ($payload['codes'] ?? array()) as $code) {
            $code = trim((string) $code);
            if ($code !== '') {
                $codes[$code] = true;
            }
        }
        $primary_code = trim((string) ($payload['code'] ?? ''));
        if ($primary_code !== '' && $primary_code !== 'mixed') {
            $codes[$primary_code] = true;
        }

        $allowed = function_exists('dms_admin_allowed_warehouses_for_current_user')
            ? dms_admin_allowed_warehouses_for_current_user()
            : array();
        if (!empty($allowed)) {
            $allowed_map = array_fill_keys($allowed, true);
            $has_allowed = false;
            foreach (array_keys($codes) as $code) {
                if (isset($allowed_map[$code])) {
                    $has_allowed = true;
                    break;
                }
            }
            if (!$has_allowed) {
                return false;
            }
        }

        if ($requested_warehouse === '') {
            return true;
        }
        if ($requested_warehouse === 'mixed') {
            return count($codes) > 1 || $primary_code === 'mixed';
        }
        return isset($codes[$requested_warehouse]);
    }
}

if (!function_exists('dms_admin_sort_orders')) {
    function dms_admin_sort_orders(&$orders, $sort) {
        $sort = dms_admin_safe_string($sort);
        usort($orders, function ($a, $b) use ($sort) {
            switch ($sort) {
                case 'date_asc':
                    return strtotime((string) $a->get_date_created()) <=> strtotime((string) $b->get_date_created());
                case 'total_asc':
                    $cmp = floatval($a->get_total()) <=> floatval($b->get_total());
                    return $cmp === 0 ? ($a->get_id() <=> $b->get_id()) : $cmp;
                case 'total_desc':
                    $cmp = floatval($b->get_total()) <=> floatval($a->get_total());
                    return $cmp === 0 ? ($b->get_id() <=> $a->get_id()) : $cmp;
                case 'date_desc':
                default:
                    return strtotime((string) $b->get_date_created()) <=> strtotime((string) $a->get_date_created());
            }
        });
    }
}

if (!function_exists('dms_admin_order_summary_payload')) {
    function dms_admin_order_summary_payload($order) {
        $warehouse = function_exists('dms_ecom_get_order_warehouse_payload')
            ? dms_ecom_get_order_warehouse_payload($order)
            : array('code' => '', 'label' => '', 'codes' => array());
        return array(
            'id' => $order->get_id(),
            'number' => $order->get_order_number(),
            'status' => $order->get_status(),
            'status_label' => wc_get_order_status_name($order->get_status()),
            'total' => $order->get_total(),
            'currency' => $order->get_currency(),
            'date' => $order->get_date_created() ? $order->get_date_created()->date_i18n('Y-m-d H:i:s') : '',
            'customer' => $order->get_formatted_billing_full_name(),
            'phone' => $order->get_billing_phone(),
            'customer_id' => (int) $order->get_customer_id(),
            'invoice_url' => dms_admin_order_invoice_url($order->get_id()),
            'warehouse_code' => (string) ($warehouse['code'] ?? ''),
            'warehouse_label' => (string) ($warehouse['label'] ?? ''),
            'warehouse_codes' => array_values((array) ($warehouse['codes'] ?? array())),
        );
    }
}

if (!function_exists('dms_admin_get_orders')) {
    function dms_admin_get_orders(WP_REST_Request $request) {
        $search = dms_admin_safe_string($request->get_param('search'));
        $status = dms_admin_safe_string($request->get_param('status'));
        $sort = dms_admin_safe_string($request->get_param('sort'));
        $date_from = dms_admin_safe_string($request->get_param('date_from'));
        $date_to = dms_admin_safe_string($request->get_param('date_to'));
        $warehouse = dms_admin_safe_string($request->get_param('warehouse'));
        $page = max(1, intval($request->get_param('page')));
        $per_page = max(1, min(100, intval($request->get_param('per_page') ?: 25)));

        $statuses = array_map(function ($value) {
            return str_replace('wc-', '', $value);
        }, array_keys(wc_get_order_statuses()));
        if ($status !== '') {
            $status = str_replace('wc-', '', strtolower($status));
            $statuses = in_array($status, $statuses, true) ? array($status) : $statuses;
        }

        $date_range = '';
        if ($date_from !== '' || $date_to !== '') {
            $date_range = ($date_from !== '' ? $date_from : '1970-01-01') . '...' . ($date_to !== '' ? $date_to : current_time('Y-m-d'));
        }

        $allowed_warehouses = function_exists('dms_admin_allowed_warehouses_for_current_user')
            ? dms_admin_allowed_warehouses_for_current_user()
            : array();
        $needs_manual = $search !== '' || !in_array($sort, array('', 'date_desc', 'date_asc'), true) || $warehouse !== '' || !empty($allowed_warehouses);
        if ($needs_manual) {
            $orders = wc_get_orders(array(
                'limit' => 500, // Hard limit for manual processing to prevent DB exhaustion
                'status' => $statuses,
                'return' => 'objects',
                'orderby' => 'date',
                'order' => 'DESC',
                'date_created' => $date_range,
            ));

            $orders = array_values(array_filter($orders, function ($order) use ($search, $warehouse) {
                if (!dms_admin_order_matches_search($order, $search)) {
                    return false;
                }
                return function_exists('dms_admin_order_matches_warehouse')
                    ? dms_admin_order_matches_warehouse($order, $warehouse)
                    : true;
            }));
            dms_admin_sort_orders($orders, $sort === '' ? 'date_desc' : $sort);

            $total = count($orders);
            $orders = array_slice($orders, ($page - 1) * $per_page, $per_page);
            return dms_admin_list_response(array_map('dms_admin_order_summary_payload', $orders), $page, $per_page, $total);
        }

        $query_args = array(
            'limit' => $per_page,
            'page' => $page,
            'paginate' => true,
            'status' => $statuses,
            'return' => 'objects',
            'orderby' => 'date',
            'order' => $sort === 'date_asc' ? 'ASC' : 'DESC',
        );
        if ($date_range !== '') {
            $query_args['date_created'] = $date_range;
        }

        $result = wc_get_orders($query_args);
        $orders = is_object($result) && isset($result->orders) ? $result->orders : array();
        $total = is_object($result) && isset($result->total) ? intval($result->total) : count($orders);
        $total_pages = is_object($result) && isset($result->max_num_pages) ? intval($result->max_num_pages) : null;

        return dms_admin_list_response(array_map('dms_admin_order_summary_payload', $orders), $page, $per_page, $total, $total_pages);
    }
}

if (!function_exists('dms_admin_order_invoice_url')) {
    function dms_admin_order_invoice_url($order_id) {
        if (!function_exists('dms_invoice_issue_token') || !function_exists('dms_invoice_get_download_url')) {
            return '';
        }
        $token = dms_invoice_issue_token((int) $order_id, DAY_IN_SECONDS);
        if (empty($token)) {
            return '';
        }
        return dms_invoice_get_download_url((int) $order_id, $token);
    }
}

if (!function_exists('dms_admin_get_order_details')) {
    function dms_admin_get_order_details(WP_REST_Request $request) {
        $order_id = (int) $request['id'];
        $order = wc_get_order($order_id);
        if (!$order) {
            return new WP_Error('order_not_found', __('Order not found', 'dms-ecom'), array('status' => 404));
        }
        if (function_exists('dms_admin_order_matches_warehouse') && !dms_admin_order_matches_warehouse($order, '')) {
            return new WP_Error('rest_forbidden', __('Ù„ÙŠØ³ Ù„Ø¯ÙŠÙƒ ØµÙ„Ø§Ø­ÙŠØ© Ù„Ù„ÙˆØµÙˆÙ„', 'dms-ecom'), array('status' => 403));
        }

        $items = array();
        foreach ($order->get_items() as $item) {
            $attrs = array();
            foreach ($item->get_meta_data() as $meta) {
                $meta_key = (string) $meta->key;
                if (strpos($meta_key, 'attribute_') === 0) {
                    $attrs[] = array(
                        'key' => wc_attribute_label(substr($meta_key, 10)),
                        'value' => (string) $meta->value,
                    );
                }
            }

            $image_url = trim((string) ($item->get_meta('image_url') ?: $item->get_meta('product_image')));
            if ($image_url === '' && function_exists('dms_ecom_resolve_product_image_url')) {
                $image_url = (string) dms_ecom_resolve_product_image_url(
                    $item->get_product(),
                    $item->get_product_id(),
                    $item->get_variation_id(),
                    'thumbnail'
                );
            }
            if ($image_url === '') {
                $product = $item->get_product();
                if ($product) {
                    $image_id = $product->get_image_id();
                    if ($image_id) {
                        $image_url = (string) wp_get_attachment_image_url($image_id, 'thumbnail');
                    }
                }
            }
            $warehouse_code = trim((string) ($item->get_meta('warehouse_code') ?: $item->get_meta('dms_warehouse_code')));
            $warehouse_label = trim((string) ($item->get_meta('warehouse_label') ?: $item->get_meta('dms_warehouse_label')));

            $items[] = array(
                'id' => $item->get_id(),
                'product_id' => $item->get_product_id(),
                'variation_id' => $item->get_variation_id(),
                'name' => $item->get_name(),
                'quantity' => (int) $item->get_quantity(),
                'subtotal' => (float) $item->get_subtotal(),
                'total' => (float) $item->get_total(),
                'attributes' => $attrs,
                'unit_name' => (string) ($item->get_meta('unit_name') ?: $item->get_meta('dms_unit_name')),
                'unit_type' => (string) ($item->get_meta('unit_type') ?: $item->get_meta('dms_unit_type')),
                'unit_pieces' => (string) ($item->get_meta('unit_pieces') ?: $item->get_meta('dms_unit_pieces_count')),
                'image_url' => $image_url,
                'warehouse_code' => $warehouse_code,
                'warehouse_label' => $warehouse_label,
            );
        }

        $warehouse = function_exists('dms_ecom_get_order_warehouse_payload')
            ? dms_ecom_get_order_warehouse_payload($order)
            : array('code' => '', 'label' => '', 'codes' => array());

        return dms_admin_detail_response(array(
            'id' => $order->get_id(),
            'number' => $order->get_order_number(),
            'status' => $order->get_status(),
            'status_label' => wc_get_order_status_name($order->get_status()),
            'currency' => $order->get_currency(),
            'date_created' => $order->get_date_created() ? $order->get_date_created()->date_i18n('Y-m-d H:i:s') : '',
            'payment_method' => $order->get_payment_method_title(),
            'customer_id' => (int) $order->get_customer_id(),
            'customer' => array(
                'name' => $order->get_formatted_billing_full_name(),
                'email' => $order->get_billing_email(),
                'phone' => $order->get_billing_phone(),
                'company' => $order->get_billing_company(),
                'address' => trim($order->get_billing_address_1() . ' ' . $order->get_billing_address_2()),
                'city' => $order->get_billing_city(),
                'state' => $order->get_billing_state(),
                'country' => $order->get_billing_country(),
            ),
            'totals' => array(
                'subtotal' => (float) $order->get_subtotal(),
                'shipping_total' => (float) $order->get_shipping_total(),
                'tax_total' => (float) $order->get_total_tax(),
                'discount_total' => (float) $order->get_discount_total(),
                'total' => (float) $order->get_total(),
            ),
            'items' => $items,
            'invoice_url' => dms_admin_order_invoice_url($order->get_id()),
            'warehouse_code' => (string) ($warehouse['code'] ?? ''),
            'warehouse_label' => (string) ($warehouse['label'] ?? ''),
            'warehouse_codes' => array_values((array) ($warehouse['codes'] ?? array())),
        ));
    }
}

if (!function_exists('dms_admin_update_order_status')) {
    function dms_admin_update_order_status(WP_REST_Request $request) {
        $order_id = (int) $request['id'];
        $order = wc_get_order($order_id);
        if (!$order) {
            return new WP_Error('order_not_found', __('Order not found', 'dms-ecom'), array('status' => 404));
        }

        $body = $request->get_json_params();
        $status = sanitize_text_field((string) ($body['status'] ?? $request->get_param('status') ?? ''));
        $status = str_replace('wc-', '', strtolower($status));
        $valid = array_map(function ($value) {
            return str_replace('wc-', '', $value);
        }, array_keys(wc_get_order_statuses()));
        if (empty($status) || !in_array($status, $valid, true)) {
            return new WP_Error('invalid_status', __('Invalid order status', 'dms-ecom'), array('status' => 400));
        }

        $order->set_status($status);
        $order->save();

        return dms_admin_action_response('تم تحديث حالة الطلب بنجاح.', array(
            'id' => $order->get_id(),
            'status' => $order->get_status(),
            'status_label' => wc_get_order_status_name($order->get_status()),
        ));
    }
}

if (!function_exists('dms_admin_user_payload')) {
    function dms_admin_user_payload($user) {
        return array(
            'id' => (int) $user->ID,
            'username' => (string) $user->user_login,
            'email' => (string) $user->user_email,
            'display_name' => (string) $user->display_name,
            'roles' => array_values(array_map('strval', (array) $user->roles)),
            'registered_at' => !empty($user->user_registered) ? mysql2date('c', $user->user_registered, false) : '',
            'dms_user_group' => (string) dms_admin_meta_value($user->ID, array('dms_user_group'), 'default'),
            'account_status' => (string) dms_admin_meta_value($user->ID, array('dms_account_status'), dms_admin_default_account_status()),
            'phone' => (string) dms_admin_meta_value($user->ID, array('account_whatsapp', 'billing_phone'), ''),
            'governorate' => (string) dms_admin_meta_value($user->ID, array('account_governorate', 'billing_state'), ''),
        );
    }
}

if (!function_exists('dms_admin_get_users')) {
    function dms_admin_get_users(WP_REST_Request $request) {
        $search = dms_admin_safe_string($request->get_param('search'));
        $role = dms_admin_safe_string($request->get_param('role'));
        $group = dms_admin_safe_string($request->get_param('group'));
        $status = dms_admin_safe_string($request->get_param('status'));
        $page = max(1, intval($request->get_param('page')));
        $per_page = max(1, min(100, intval($request->get_param('per_page') ?: 25)));
        $args = array(
            'number' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'registered',
            'order' => 'DESC',
            'count_total' => true,
        );
        if ($search !== '') {
            $args['search'] = '*' . esc_attr($search) . '*';
            $args['search_columns'] = array('user_login', 'user_email', 'display_name');
        }
        if ($role !== '') {
            $args['role__in'] = array($role);
        }

        $meta_query = array('relation' => 'AND');
        if ($group !== '') {
            $meta_query[] = array(
                'key' => 'dms_user_group',
                'value' => $group,
                'compare' => '=',
            );
        }
        if ($status !== '') {
            $meta_query[] = array(
                'key' => 'dms_account_status',
                'value' => $status,
                'compare' => '=',
            );
        }
        if (count($meta_query) > 1) {
            $args['meta_query'] = $meta_query;
        }

        $query = new WP_User_Query($args);
        $data = array_map('dms_admin_user_payload', $query->get_results());
        return dms_admin_list_response($data, $page, $per_page, (int) $query->get_total());
    }
}

if (!function_exists('dms_admin_get_user_details')) {
    function dms_admin_get_user_details(WP_REST_Request $request) {
        $user = get_userdata((int) $request['id']);
        if (!$user) {
            return new WP_Error('user_not_found', __('المستخدم غير موجود', 'dms-ecom'), array('status' => 404));
        }

        $payload = dms_admin_user_payload($user);
        $payload['member_profile'] = function_exists('dms_admin_member_payload')
            ? dms_admin_member_payload($user)
            : array();
        return dms_admin_detail_response($payload);
    }
}

if (!function_exists('dms_admin_get_members')) {
    function dms_admin_get_members(WP_REST_Request $request) {
        $search = sanitize_text_field((string) $request->get_param('search'));
        $group = sanitize_text_field((string) $request->get_param('group'));
        $currency = strtolower(sanitize_text_field((string) $request->get_param('currency')));
        $status = sanitize_text_field((string) $request->get_param('status'));

        $page = max(1, intval($request->get_param('page')));
        $per_page = intval($request->get_param('per_page'));
        if ($per_page <= 0) {
            $per_page = 25;
        }
        $per_page = min(100, $per_page);

        $meta_query = array('relation' => 'AND');
        if ($group !== '') {
            $meta_query[] = array(
                'key' => 'dms_user_group',
                'value' => $group,
                'compare' => '=',
            );
        }
        if ($currency !== '') {
            $meta_query[] = array(
                'key' => 'dms_user_currency',
                'value' => $currency,
                'compare' => '=',
            );
        }
        if ($status !== '') {
            $meta_query[] = array(
                'key' => 'dms_account_status',
                'value' => $status,
                'compare' => '=',
            );
        }

        $args = array(
            'number' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'ID',
            'order' => 'DESC',
            'role__in' => array('customer'),
        );

        if ($search !== '') {
            $args['search'] = '*' . $search . '*';
            $args['search_columns'] = array('user_login', 'user_email', 'display_name');
        }

        if (count($meta_query) > 1) {
            $args['meta_query'] = $meta_query;
        }

        $users = get_users($args);
        $default_status = function_exists('dms_get_default_account_status')
            ? dms_get_default_account_status()
            : 'جديد';

        $data = array_map(function ($user) use ($default_status) {
            $full_name = trim($user->first_name . ' ' . $user->last_name);
            if ($full_name === '') {
                $full_name = trim((string) $user->display_name);
            }
            if ($full_name === '') {
                $full_name = (string) $user->user_login;
            }

            $company = (string) get_user_meta($user->ID, 'account_company_name', true);
            if ($company === '') {
                $company = (string) get_user_meta($user->ID, 'billing_company', true);
            }

            $phone = (string) get_user_meta($user->ID, 'account_whatsapp', true);
            if ($phone === '') {
                $phone = (string) get_user_meta($user->ID, 'billing_phone', true);
            }

            $governorate = (string) get_user_meta($user->ID, 'account_governorate', true);
            if ($governorate === '') {
                $governorate = (string) get_user_meta($user->ID, 'billing_state', true);
            }

            $address = (string) get_user_meta($user->ID, 'billing_address_1', true);
            if ($address === '') {
                $address = (string) get_user_meta($user->ID, 'address', true);
            }

            $group = (string) get_user_meta($user->ID, 'dms_user_group', true);
            if ($group === '') {
                $group = 'default';
            }

            $currency = strtolower((string) get_user_meta($user->ID, 'dms_user_currency', true));
            if ($currency === '') {
                $currency = 'syp';
            }

            $status = (string) get_user_meta($user->ID, 'dms_account_status', true);
            if ($status === '') {
                $status = $default_status;
            }

            return array(
                'id' => (int) $user->ID,
                'name' => $full_name,
                'username' => (string) $user->user_login,
                'email' => (string) $user->user_email,
                'company' => $company,
                'phone' => $phone,
                'governorate' => $governorate,
                'address' => $address,
                'group' => $group,
                'currency' => $currency,
                'account_status' => $status,
                'roles' => $user->roles,
            );
        }, $users);

        return new WP_REST_Response($data, 200);
    }
}

if (!function_exists('dms_admin_save_settings')) {
    function dms_admin_save_settings(WP_REST_Request $request) {
        $body = $request->get_json_params();
        $current = dms_app_get_settings();

        $fields = array(
            'exchange_rate_usd_syp' => 'float',
            'default_currency' => 'text',
            'allow_guest_checkout' => 'bool',
            'enable_debug_logs' => 'bool',
            'cors_allowed_origins' => 'array',
            'turnstile_site_key' => 'text',
            'turnstile_secret_key' => 'text',
            'recaptcha_site_key' => 'text',
            'recaptcha_secret_key' => 'text',
            'notification_emails' => 'text',
        );

        foreach ($fields as $key => $type) {
            if (!isset($body[$key])) {
                continue;
            }
            switch ($type) {
                case 'float':
                    $current[$key] = floatval($body[$key]);
                    break;
                case 'bool':
                    $current[$key] = (bool) $body[$key];
                    break;
                case 'array':
                    if (is_array($body[$key])) {
                        $current[$key] = array_filter(array_map('sanitize_text_field', $body[$key]));
                    }
                    break;
                default:
                    $current[$key] = sanitize_text_field($body[$key]);
            }
        }

        update_option('dms_app_settings', $current, false);

        // Also update dms_notification_emails separately for compatibility with dms_ecom_send_admin_email
        if (isset($body['notification_emails'])) {
            update_option('dms_notification_emails', sanitize_text_field($body['notification_emails']), false);
        }

        return new WP_REST_Response(array('success' => true, 'settings' => $current), 200);
    }
}

if (!function_exists('dms_admin_get_settings')) {
    function dms_admin_get_settings(WP_REST_Request $request) {
        return new WP_REST_Response(dms_app_get_settings(), 200);
    }
}

if (!function_exists('dms_admin_create_member')) {
    function dms_admin_create_member(WP_REST_Request $request) {
        $params = $request->get_json_params();
        $username = sanitize_text_field($params['username'] ?? '');
        $email = sanitize_email($params['email'] ?? '');
        $password = $params['password'] ?? wp_generate_password();

        if (empty($username) || empty($email)) {
            return new WP_Error('missing_fields', __('الاسم والبريد مطلوبان', 'dms-ecom'), array('status' => 400));
        }

        $user_id = wp_create_user($username, $password, $email);
        if (is_wp_error($user_id)) {
            return $user_id;
        }

        // Default meta
        update_user_meta($user_id, 'dms_user_group', sanitize_text_field($params['group'] ?? 'default'));
        update_user_meta($user_id, 'dms_account_status', sanitize_text_field($params['account_status'] ?? 'pending'));
        update_user_meta($user_id, 'billing_phone', sanitize_text_field($params['phone'] ?? ''));

        return new WP_REST_Response(array('success' => true, 'id' => $user_id), 201);
    }
}

if (!function_exists('dms_admin_update_member')) {
    function dms_admin_update_member(WP_REST_Request $request) {
        $id = $request->get_param('id');
        $params = $request->get_json_params();

        $user = get_userdata($id);
        if (!$user) {
            return new WP_Error('not_found', __('المستخدم غير موجود', 'dms-ecom'), array('status' => 404));
        }

        if (isset($params['email'])) {
            wp_update_user(array('ID' => $id, 'user_email' => sanitize_email($params['email'])));
        }

        if (isset($params['group'])) {
            update_user_meta($id, 'dms_user_group', sanitize_text_field($params['group']));
        }
        if (isset($params['account_status'])) {
            update_user_meta($id, 'dms_account_status', sanitize_text_field($params['account_status']));
        }
        if (isset($params['phone'])) {
            update_user_meta($id, 'billing_phone', sanitize_text_field($params['phone']));
        }
        if (isset($params['governorate'])) {
            update_user_meta($id, 'account_governorate', sanitize_text_field($params['governorate']));
            update_user_meta($id, 'billing_state', sanitize_text_field($params['governorate']));
        }

        return new WP_REST_Response(array('success' => true), 200);
    }
}

if (!function_exists('dms_admin_delete_member')) {
    function dms_admin_delete_member(WP_REST_Request $request) {
        $id = $request->get_param('id');
        if (get_current_user_id() == $id) {
            return new WP_Error('self_delete', __('لا يمكنك حذف نفسك', 'dms-ecom'), array('status' => 400));
        }
        
        require_once(ABSPATH . 'wp-admin/includes/user.php');
        if (wp_delete_user($id)) {
            return new WP_REST_Response(array('success' => true), 200);
        }
        return new WP_Error('delete_failed', __('فشل الحذف', 'dms-ecom'), array('status' => 500));
    }
}

if (!function_exists('dms_admin_get_member_details')) {
    function dms_admin_get_member_details(WP_REST_Request $request) {
        $id = $request->get_param('id');
        $user = get_userdata($id);
        if (!$user) {
            return new WP_Error('not_found', __('المستخدم غير موجود', 'dms-ecom'), array('status' => 404));
        }

        $data = array(
            'id' => $user->ID,
            'username' => $user->user_login,
            'email' => $user->user_email,
            'group' => get_user_meta($user->ID, 'dms_user_group', true) ?: 'default',
            'account_status' => get_user_meta($user->ID, 'dms_account_status', true),
            'phone' => get_user_meta($user->ID, 'billing_phone', true),
            'governorate' => get_user_meta($user->ID, 'account_governorate', true) ?: get_user_meta($user->ID, 'billing_state', true),
        );

        return new WP_REST_Response($data, 200);
    }
}

if (!function_exists('dms_admin_get_notification_emails')) {
    function dms_admin_get_notification_emails(WP_REST_Request $request) {
        $emails = get_option('dms_notification_emails', '');
        return new WP_REST_Response(array('emails' => $emails), 200);
    }
}

if (!function_exists('dms_admin_save_notification_emails')) {
    function dms_admin_save_notification_emails(WP_REST_Request $request) {
        $params = $request->get_json_params();
        $emails = sanitize_text_field($params['emails'] ?? '');
        update_option('dms_notification_emails', $emails, false);
        return new WP_REST_Response(array('success' => true), 200);
    }
}
if (!function_exists('dms_admin_diagnostics')) {
    function dms_admin_diagnostics(WP_REST_Request $request) {
        return new WP_REST_Response(array(
            'php_version' => PHP_VERSION,
            'wp_version'  => get_bloginfo('version'),
            'wc_version'  => class_exists('WooCommerce') ? WC()->version : 'Not Active',
            'dms_version' => '7.0',
            'jwt_ready'   => defined('JWT_AUTH_SECRET_KEY'),
            'debug_mode'  => defined('DMS_ECOM_DEBUG') && DMS_ECOM_DEBUG,
        ), 200);
    }
}

if (!function_exists('dms_admin_get_products')) {
    function dms_admin_get_products(WP_REST_Request $request) {
        // Basic product list for admin
        $args = array(
            'limit'   => 50,
            'status'  => 'publish',
            'orderby' => 'date',
            'order'   => 'DESC',
        );
        $products = wc_get_products($args);
        $response = array_map(function($product) {
            return array(
                'id'    => $product->get_id(),
                'name'  => $product->get_name(),
                'price' => $product->get_price(),
                'sku'   => $product->get_sku(),
                'stock' => $product->get_stock_quantity(),
            );
        }, $products);
        return new WP_REST_Response($response, 200);
    }
}

if (!function_exists('dms_admin_get_reviews')) {
    function dms_admin_get_reviews(WP_REST_Request $request) {
        $comments = get_comments(array('post_type' => 'product', 'number' => 50));
        $response = array_map(function($comment) {
            return array(
                'id'      => $comment->comment_ID,
                'user'    => $comment->comment_author,
                'rating'  => get_comment_meta($comment->comment_ID, 'rating', true),
                'content' => $comment->comment_content,
                'date'    => $comment->comment_date,
            );
        }, $comments);
        return new WP_REST_Response($response, 200);
    }
}

if (!function_exists('dms_admin_member_payload_v2')) {
    function dms_admin_member_payload_v2($user) {
        return array(
            'id' => (int) $user->ID,
            'name' => trim(($user->first_name ?: '') . ' ' . ($user->last_name ?: '')) ?: ((string) $user->display_name ?: (string) $user->user_login),
            'username' => (string) $user->user_login,
            'email' => (string) $user->user_email,
            'company' => (string) dms_admin_meta_value($user->ID, array('account_company_name', 'billing_company'), ''),
            'phone' => (string) dms_admin_meta_value($user->ID, array('account_whatsapp', 'billing_phone'), ''),
            'governorate' => (string) dms_admin_meta_value($user->ID, array('account_governorate', 'billing_state'), ''),
            'address' => (string) dms_admin_meta_value($user->ID, array('billing_address_1', 'address'), ''),
            'group' => (string) dms_admin_meta_value($user->ID, array('dms_user_group'), 'default'),
            'currency' => strtolower((string) dms_admin_meta_value($user->ID, array('dms_user_currency'), 'syp')),
            'account_status' => (string) dms_admin_meta_value($user->ID, array('dms_account_status'), dms_admin_default_account_status()),
            'roles' => array_values(array_map('strval', (array) $user->roles)),
            'registered_at' => !empty($user->user_registered) ? mysql2date('c', $user->user_registered, false) : '',
        );
    }
}

if (!function_exists('dms_admin_settings_payload_v2')) {
    function dms_admin_settings_payload_v2() {
        $settings = dms_app_get_settings();
        return array(
            'exchange_rate_usd_syp' => (float) ($settings['exchange_rate_usd_syp'] ?? 0),
            'default_currency' => (string) ($settings['default_currency'] ?? 'syp'),
            'allow_guest_checkout' => !empty($settings['allow_guest_checkout']),
            'enable_debug_logs' => !empty($settings['enable_debug_logs']),
            'cors_allowed_origins' => array_values((array) ($settings['cors_allowed_origins'] ?? array())),
            'turnstile_site_key' => (string) ($settings['turnstile_site_key'] ?? ''),
            'turnstile_secret_key' => (string) ($settings['turnstile_secret_key'] ?? ''),
            'recaptcha_site_key' => (string) ($settings['recaptcha_site_key'] ?? ''),
            'recaptcha_secret_key' => (string) ($settings['recaptcha_secret_key'] ?? ''),
            'notification_emails' => (string) get_option('dms_notification_emails', ''),
        );
    }
}

if (!function_exists('dms_admin_term_payload_v2')) {
    function dms_admin_term_payload_v2($term) {
        if (!$term || !isset($term->term_id)) {
            return array();
        }

        $image_url = '';
        $thumbnail_id = (int) get_term_meta($term->term_id, 'thumbnail_id', true);
        if ($thumbnail_id > 0) {
            $image_url = (string) wp_get_attachment_image_url($thumbnail_id, 'thumbnail');
        }
        if ($image_url === '' && function_exists('dms_ecom_resolve_brand_image_url')) {
            $image_url = (string) dms_ecom_resolve_brand_image_url($term);
        }
        if ($image_url === '') {
            $image_url = (string) get_term_meta($term->term_id, 'image', true);
        }

        $is_hidden = false;
        if (function_exists('dms_ecom_is_hidden_term_for_app')) {
            $is_hidden = (bool) dms_ecom_is_hidden_term_for_app($term, $term->taxonomy ?? 'product_cat');
        } elseif (function_exists('lpco_app_layout_is_term_hidden')) {
            $is_hidden = (bool) lpco_app_layout_is_term_hidden($term->term_id, $term->taxonomy ?? 'product_cat');
        }

        return array(
            'id' => (int) $term->term_id,
            'name' => (string) $term->name,
            'slug' => (string) $term->slug,
            'image_url' => $image_url,
            'show_in_app' => !$is_hidden,
            'hidden' => $is_hidden,
        );
    }
}

if (!function_exists('dms_admin_product_brand_taxonomy_v2')) {
    function dms_admin_product_brand_taxonomy_v2() {
        if (taxonomy_exists('product_brand')) {
            return 'product_brand';
        }
        if (taxonomy_exists('product_tag')) {
            return 'product_tag';
        }
        return '';
    }
}

if (!function_exists('dms_admin_product_payload_v2')) {
    function dms_admin_product_payload_v2($product) {
        $product_id = $product->get_id();
        $image_url = '';
        if ($product->get_image_id()) {
            $image_url = (string) wp_get_attachment_image_url($product->get_image_id(), 'thumbnail');
        }
        if ($image_url === '' && function_exists('wc_placeholder_img_src')) {
            $image_url = (string) wc_placeholder_img_src('thumbnail');
        }

        $categories = array();
        foreach ((array) get_the_terms($product_id, 'product_cat') as $term) {
            if (!is_wp_error($term)) {
                $categories[] = dms_admin_term_payload_v2($term);
            }
        }

        $brands = array();
        $brand_taxonomy = dms_admin_product_brand_taxonomy_v2();
        if ($brand_taxonomy !== '') {
            foreach ((array) get_the_terms($product_id, $brand_taxonomy) as $term) {
                if (!is_wp_error($term)) {
                    $brands[] = dms_admin_term_payload_v2($term);
                }
            }
        }

        return array(
            'id' => $product_id,
            'name' => (string) $product->get_name(),
            'sku' => (string) $product->get_sku(),
            'regular_price' => (string) $product->get_regular_price(),
            'sale_price' => (string) $product->get_sale_price(),
            'effective_price' => (string) $product->get_price(),
            'stock_quantity' => $product->get_stock_quantity() === null ? null : (int) $product->get_stock_quantity(),
            'stock_status' => (string) $product->get_stock_status(),
            'image_url' => $image_url,
            'categories' => $categories,
            'brands' => $brands,
            'status' => (string) $product->get_status(),
            'featured' => (bool) $product->get_featured(),
            'description' => (string) $product->get_description(),
            'short_description' => (string) $product->get_short_description(),
            'permalink' => (string) get_permalink($product_id),
            'home_order' => (int) get_post_meta($product_id, '_dms_app_order_home', true),
        );
    }
}

if (!function_exists('dms_admin_low_stock_products_count')) {
    function dms_admin_low_stock_products_count() {
        $query = new WP_Query(array(
            'post_type' => 'product',
            'post_status' => array('publish', 'draft', 'pending', 'private'),
            'posts_per_page' => 1,
            'fields' => 'ids',
            'meta_query' => array(
                'relation' => 'AND',
                array('key' => '_manage_stock', 'value' => 'yes', 'compare' => '='),
                array('key' => '_stock', 'value' => 5, 'compare' => '<=', 'type' => 'NUMERIC'),
                array('key' => '_stock_status', 'value' => array('instock', 'onbackorder'), 'compare' => 'IN'),
            ),
        ));
        return (int) $query->found_posts;
    }
}

if (!function_exists('dms_admin_notifications_counters')) {
    function dms_admin_notifications_counters() {
        $payload = array(
            'unread_notifications_count' => 0,
            'device_tokens_count' => 0,
            'latest_notifications' => array(),
        );

        if (!function_exists('dms_notifications_tables')) {
            return $payload;
        }

        global $wpdb;
        $tables = dms_notifications_tables();
        $payload['device_tokens_count'] = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$tables['tokens']}");
        $payload['unread_notifications_count'] = (int) $wpdb->get_var(
            "SELECT COUNT(DISTINCT r.notification_id)
             FROM {$tables['receipts']} r
             INNER JOIN {$tables['notifications']} n ON n.id = r.notification_id
             WHERE r.is_read = 0 AND (r.deleted_at IS NULL OR r.deleted_at = '0000-00-00 00:00:00') AND (n.is_deleted = 0 OR n.is_deleted IS NULL)"
        );

        $rows = $wpdb->get_results(
            "SELECT n.id, n.title, n.audience, n.created_at,
                    SUM(CASE WHEN r.deleted_at IS NULL AND r.is_read = 1 THEN 1 ELSE 0 END) AS read_count,
                    SUM(CASE WHEN r.deleted_at IS NULL AND r.is_read = 0 THEN 1 ELSE 0 END) AS unread_count
             FROM {$tables['notifications']} n
             LEFT JOIN {$tables['receipts']} r ON r.notification_id = n.id
             GROUP BY n.id, n.title, n.audience, n.created_at
             ORDER BY n.id DESC
             LIMIT 5",
            ARRAY_A
        );
        foreach ($rows ?: array() as $row) {
            $payload['latest_notifications'][] = array(
                'id' => (int) $row['id'],
                'title' => (string) $row['title'],
                'audience' => (string) ($row['audience'] ?? 'all'),
                'created_at' => (string) ($row['created_at'] ?? ''),
                'read_count' => (int) ($row['read_count'] ?? 0),
                'unread_count' => (int) ($row['unread_count'] ?? 0),
            );
        }
        return $payload;
    }
}

if (!function_exists('dms_admin_diagnostics_payload')) {
    function dms_admin_diagnostics_payload() {
        $settings = dms_app_get_settings();
        $notifications = dms_admin_notifications_counters();
        $woocommerce_active = class_exists('WooCommerce');
        $jwt_ready = defined('JWT_AUTH_SECRET_KEY') && (string) JWT_AUTH_SECRET_KEY !== '';
        $fcm_ready = function_exists('dms_fcm_is_configured') ? (bool) dms_fcm_is_configured() : false;
        $invoice_ready = function_exists('dms_invoice_generate_pdf');

        $warnings = array();
        if (!$jwt_ready) {
            $warnings[] = 'مسار JWT غير جاهز.';
        }
        if (!$woocommerce_active) {
            $warnings[] = 'WooCommerce غير مفعّل.';
        }
        if (!$fcm_ready) {
            $warnings[] = 'إعدادات FCM غير مكتملة.';
        }
        if (!empty($settings['enable_debug_logs'])) {
            $warnings[] = 'وضع سجلات التصحيح مفعّل.';
        }

        return array(
            'generated_at' => current_time('c'),
            'sections' => array(
                array(
                    'id' => 'environment',
                    'title' => 'البيئة',
                    'items' => array(
                        array('id' => 'php', 'label' => 'PHP', 'status' => 'ok', 'value' => PHP_VERSION, 'details' => ''),
                        array('id' => 'wp', 'label' => 'WordPress', 'status' => 'ok', 'value' => get_bloginfo('version'), 'details' => ''),
                        array('id' => 'wc', 'label' => 'WooCommerce', 'status' => $woocommerce_active ? 'ok' : 'error', 'value' => $woocommerce_active ? WC()->version : 'غير مفعّل', 'details' => ''),
                    ),
                ),
                array(
                    'id' => 'auth',
                    'title' => 'المصادقة',
                    'items' => array(
                        array('id' => 'jwt', 'label' => 'JWT readiness', 'status' => $jwt_ready ? 'ok' : 'error', 'value' => $jwt_ready ? 'جاهز' : 'غير جاهز', 'details' => ''),
                        array('id' => 'guest_checkout', 'label' => 'Guest checkout', 'status' => !empty($settings['allow_guest_checkout']) ? 'warning' : 'ok', 'value' => !empty($settings['allow_guest_checkout']) ? 'مفعّل' : 'متوقف', 'details' => ''),
                    ),
                ),
                array(
                    'id' => 'notifications',
                    'title' => 'الإشعارات',
                    'items' => array(
                        array('id' => 'fcm', 'label' => 'FCM configured', 'status' => $fcm_ready ? 'ok' : 'warning', 'value' => $fcm_ready ? 'جاهز' : 'غير مكتمل', 'details' => ''),
                        array('id' => 'tokens', 'label' => 'Registered device tokens', 'status' => ($notifications['device_tokens_count'] ?? 0) > 0 ? 'ok' : 'warning', 'value' => (string) ($notifications['device_tokens_count'] ?? 0), 'details' => ''),
                    ),
                ),
                array(
                    'id' => 'invoices',
                    'title' => 'الفواتير',
                    'items' => array(
                        array('id' => 'invoice_pdf', 'label' => 'Invoice PDF system', 'status' => $invoice_ready ? 'ok' : 'warning', 'value' => $invoice_ready ? 'جاهز' : 'غير مكتمل', 'details' => ''),
                    ),
                ),
            ),
            'warnings' => $warnings,
            'latest_notifications' => $notifications['latest_notifications'] ?? array(),
        );
    }
}

if (!function_exists('dms_admin_request_body_v2')) {
    function dms_admin_request_body_v2(WP_REST_Request $request) {
        $body = $request->get_json_params();
        if (!is_array($body)) {
            $body = $request->get_params();
        }
        return is_array($body) ? $body : array();
    }
}

if (!function_exists('dms_admin_parse_bool_v2')) {
    function dms_admin_parse_bool_v2($value, $default = false) {
        if ($value === null || $value === '') {
            return (bool) $default;
        }

        if (is_bool($value)) {
            return $value;
        }

        if (is_numeric($value)) {
            return intval($value) === 1;
        }

        $normalized = strtolower(trim((string) $value));
        return in_array($normalized, array('1', 'true', 'yes', 'on'), true);
    }
}

if (!function_exists('dms_admin_validate_email_list_v2')) {
    function dms_admin_validate_email_list_v2($value) {
        $emails = array();

        if (is_array($value)) {
            $candidates = $value;
        } else {
            $candidates = preg_split('/[\r\n,;]+/', (string) $value);
        }

        foreach ((array) $candidates as $candidate) {
            $email = sanitize_email(trim((string) $candidate));
            if ($email !== '') {
                $emails[] = $email;
            }
        }

        $emails = array_values(array_unique($emails));
        return array(
            'list' => $emails,
            'raw' => implode(', ', $emails),
        );
    }
}

if (!function_exists('dms_admin_get_members_v2')) {
    function dms_admin_get_members_v2(WP_REST_Request $request) {
        $search = dms_admin_safe_string($request->get_param('search'));
        $group = dms_admin_safe_string($request->get_param('group'));
        $status = dms_admin_safe_string($request->get_param('status'));
        $governorate = dms_admin_safe_string($request->get_param('governorate'));
        $page = max(1, intval($request->get_param('page') ?: 1));
        $per_page = max(1, min(100, intval($request->get_param('per_page') ?: 25)));

        $args = array(
            'number' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'registered',
            'order' => 'DESC',
            'count_total' => true,
            'role__in' => array('customer'),
        );

        if ($search !== '') {
            $args['search'] = '*' . esc_attr($search) . '*';
            $args['search_columns'] = array('user_login', 'user_email', 'display_name');
        }

        $meta_query = array('relation' => 'AND');
        if ($group !== '') {
            $meta_query[] = array(
                'key' => 'dms_user_group',
                'value' => $group,
                'compare' => '=',
            );
        }
        if ($status !== '') {
            $meta_query[] = array(
                'key' => 'dms_account_status',
                'value' => $status,
                'compare' => '=',
            );
        }
        if ($governorate !== '') {
            $meta_query[] = array(
                'relation' => 'OR',
                array(
                    'key' => 'account_governorate',
                    'value' => $governorate,
                    'compare' => '=',
                ),
                array(
                    'key' => 'billing_state',
                    'value' => $governorate,
                    'compare' => '=',
                ),
            );
        }
        if (count($meta_query) > 1) {
            $args['meta_query'] = $meta_query;
        }

        $query = new WP_User_Query($args);
        $items = array_map('dms_admin_member_payload_v2', $query->get_results());
        return dms_admin_list_response($items, $page, $per_page, intval($query->get_total()));
    }
}

if (!function_exists('dms_admin_get_member_details_v2')) {
    function dms_admin_get_member_details_v2(WP_REST_Request $request) {
        $user = get_userdata((int) $request['id']);
        if (!$user) {
            return new WP_Error('member_not_found', __('العضو غير موجود', 'dms-ecom'), array('status' => 404));
        }

        return dms_admin_detail_response(dms_admin_member_payload_v2($user));
    }
}

if (!function_exists('dms_admin_create_member_v2')) {
    function dms_admin_create_member_v2(WP_REST_Request $request) {
        $body = dms_admin_request_body_v2($request);
        $username = sanitize_user((string) ($body['username'] ?? $body['user_login'] ?? ''));
        $email = sanitize_email((string) ($body['email'] ?? $body['user_email'] ?? ''));
        $password = (string) ($body['password'] ?? wp_generate_password(12, true, true));
        $group = dms_admin_safe_string($body['group'] ?? 'default');
        $account_status = dms_admin_safe_string($body['account_status'] ?? dms_admin_default_account_status());

        if ($username === '' || $email === '') {
            return new WP_Error('missing_fields', __('اسم المستخدم والبريد الإلكتروني مطلوبان', 'dms-ecom'), array('status' => 400));
        }
        if (username_exists($username)) {
            return new WP_Error('username_exists', __('اسم المستخدم مستخدم بالفعل', 'dms-ecom'), array('status' => 409));
        }
        if (email_exists($email)) {
            return new WP_Error('email_exists', __('البريد الإلكتروني مستخدم بالفعل', 'dms-ecom'), array('status' => 409));
        }
        if (!is_email($email)) {
            return new WP_Error('invalid_email', __('البريد الإلكتروني غير صالح', 'dms-ecom'), array('status' => 400));
        }

        $user_id = wp_create_user($username, $password, $email);
        if (is_wp_error($user_id)) {
            return $user_id;
        }

        $update_data = array(
            'ID' => $user_id,
            'display_name' => sanitize_text_field((string) ($body['name'] ?? $body['display_name'] ?? $username)),
            'first_name' => sanitize_text_field((string) ($body['first_name'] ?? '')),
            'last_name' => sanitize_text_field((string) ($body['last_name'] ?? '')),
        );
        wp_update_user($update_data);

        update_user_meta($user_id, 'dms_user_group', $group === '' ? 'default' : $group);
        update_user_meta($user_id, 'dms_account_status', $account_status);
        update_user_meta($user_id, 'dms_user_currency', strtolower(sanitize_text_field((string) ($body['currency'] ?? 'syp'))));
        update_user_meta($user_id, 'billing_phone', sanitize_text_field((string) ($body['phone'] ?? '')));
        update_user_meta($user_id, 'account_whatsapp', sanitize_text_field((string) ($body['phone'] ?? '')));
        update_user_meta($user_id, 'account_governorate', sanitize_text_field((string) ($body['governorate'] ?? '')));
        update_user_meta($user_id, 'billing_state', sanitize_text_field((string) ($body['governorate'] ?? '')));
        update_user_meta($user_id, 'billing_address_1', sanitize_text_field((string) ($body['address'] ?? '')));
        update_user_meta($user_id, 'account_company_name', sanitize_text_field((string) ($body['company'] ?? '')));
        update_user_meta($user_id, 'billing_company', sanitize_text_field((string) ($body['company'] ?? '')));

        $user = get_userdata($user_id);
        return dms_admin_action_response(
            'تم إنشاء العضو بنجاح.',
            array(
                'member' => $user ? dms_admin_member_payload_v2($user) : array('id' => intval($user_id)),
                'generated_password' => $body['password'] ?? '',
            ),
            201
        );
    }
}

if (!function_exists('dms_admin_update_member_v2')) {
    function dms_admin_update_member_v2(WP_REST_Request $request) {
        $user_id = (int) $request['id'];
        $user = get_userdata($user_id);
        if (!$user) {
            return new WP_Error('member_not_found', __('العضو غير موجود', 'dms-ecom'), array('status' => 404));
        }

        $body = dms_admin_request_body_v2($request);
        $update_data = array('ID' => $user_id);

        if (array_key_exists('email', $body) || array_key_exists('user_email', $body)) {
            $email = sanitize_email((string) ($body['email'] ?? $body['user_email']));
            if ($email === '' || !is_email($email)) {
                return new WP_Error('invalid_email', __('البريد الإلكتروني غير صالح', 'dms-ecom'), array('status' => 400));
            }
            $owner_id = email_exists($email);
            if ($owner_id && intval($owner_id) !== $user_id) {
                return new WP_Error('email_exists', __('البريد الإلكتروني مستخدم بالفعل', 'dms-ecom'), array('status' => 409));
            }
            $update_data['user_email'] = $email;
        }

        if (array_key_exists('name', $body) || array_key_exists('display_name', $body)) {
            $update_data['display_name'] = sanitize_text_field((string) ($body['name'] ?? $body['display_name']));
        }
        if (array_key_exists('first_name', $body)) {
            $update_data['first_name'] = sanitize_text_field((string) $body['first_name']);
        }
        if (array_key_exists('last_name', $body)) {
            $update_data['last_name'] = sanitize_text_field((string) $body['last_name']);
        }

        if (count($update_data) > 1) {
            $result = wp_update_user($update_data);
            if (is_wp_error($result)) {
                return $result;
            }
        }

        $meta_fields = array(
            'group' => array('dms_user_group'),
            'account_status' => array('dms_account_status'),
            'currency' => array('dms_user_currency'),
            'phone' => array('billing_phone', 'account_whatsapp'),
            'governorate' => array('account_governorate', 'billing_state'),
            'address' => array('billing_address_1', 'address'),
            'company' => array('account_company_name', 'billing_company'),
        );

        foreach ($meta_fields as $payload_key => $meta_keys) {
            if (!array_key_exists($payload_key, $body)) {
                continue;
            }
            $value = sanitize_text_field((string) $body[$payload_key]);
            foreach ($meta_keys as $meta_key) {
                update_user_meta($user_id, $meta_key, $value);
            }
        }

        $fresh = get_userdata($user_id);
        return dms_admin_action_response(
            'تم تحديث العضو بنجاح.',
            array('member' => $fresh ? dms_admin_member_payload_v2($fresh) : array('id' => $user_id))
        );
    }
}

if (!function_exists('dms_admin_delete_member_v2')) {
    function dms_admin_delete_member_v2(WP_REST_Request $request) {
        $user_id = (int) $request['id'];
        if ($user_id <= 0 || !get_userdata($user_id)) {
            return new WP_Error('member_not_found', __('العضو غير موجود', 'dms-ecom'), array('status' => 404));
        }
        if (get_current_user_id() === $user_id) {
            return new WP_Error('self_delete', __('لا يمكنك حذف حسابك الحالي من هنا', 'dms-ecom'), array('status' => 400));
        }

        require_once ABSPATH . 'wp-admin/includes/user.php';
        $deleted = wp_delete_user($user_id);
        if (!$deleted) {
            return new WP_Error('delete_failed', __('فشل حذف العضو', 'dms-ecom'), array('status' => 500));
        }

        return dms_admin_action_response('تم حذف العضو بنجاح.', array('id' => $user_id));
    }
}

if (!function_exists('dms_admin_get_settings_v2')) {
    function dms_admin_get_settings_v2(WP_REST_Request $request) {
        return dms_admin_detail_response(dms_admin_settings_payload_v2());
    }
}

if (!function_exists('dms_admin_save_settings_v2')) {
    function dms_admin_save_settings_v2(WP_REST_Request $request) {
        $body = dms_admin_request_body_v2($request);
        $current = dms_app_get_settings();

        if (array_key_exists('exchange_rate_usd_syp', $body)) {
            $current['exchange_rate_usd_syp'] = max(0, floatval($body['exchange_rate_usd_syp']));
        }

        if (array_key_exists('default_currency', $body)) {
            $currency = strtolower(sanitize_text_field((string) $body['default_currency']));
            $current['default_currency'] = in_array($currency, array('syp', 'usd'), true) ? $currency : 'syp';
        }

        foreach (array('allow_guest_checkout', 'enable_debug_logs') as $bool_key) {
            if (array_key_exists($bool_key, $body)) {
                $current[$bool_key] = dms_admin_parse_bool_v2($body[$bool_key]);
            }
        }

        if (array_key_exists('cors_allowed_origins', $body)) {
            $origins = $body['cors_allowed_origins'];
            if (!is_array($origins)) {
                $origins = preg_split('/[\r\n,]+/', (string) $origins);
            }
            $current['cors_allowed_origins'] = array_values(array_filter(array_map(function ($origin) {
                return esc_url_raw(trim((string) $origin));
            }, (array) $origins)));
        }

        foreach (array(
            'turnstile_site_key',
            'turnstile_secret_key',
            'recaptcha_site_key',
            'recaptcha_secret_key',
        ) as $text_key) {
            if (array_key_exists($text_key, $body)) {
                $current[$text_key] = sanitize_text_field((string) $body[$text_key]);
            }
        }

        update_option('dms_app_settings', $current, false);

        if (array_key_exists('notification_emails', $body)) {
            $emails = dms_admin_validate_email_list_v2($body['notification_emails']);
            update_option('dms_notification_emails', $emails['raw'], false);
        }

        return dms_admin_action_response(
            'تم حفظ إعدادات التطبيق بنجاح.',
            array('settings' => dms_admin_settings_payload_v2())
        );
    }
}

if (!function_exists('dms_admin_get_notification_emails_v2')) {
    function dms_admin_get_notification_emails_v2(WP_REST_Request $request) {
        $emails = dms_admin_validate_email_list_v2(get_option('dms_notification_emails', ''));
        return dms_admin_detail_response(array(
            'emails' => $emails['raw'],
            'emails_list' => $emails['list'],
        ));
    }
}

if (!function_exists('dms_admin_save_notification_emails_v2')) {
    function dms_admin_save_notification_emails_v2(WP_REST_Request $request) {
        $body = dms_admin_request_body_v2($request);
        $emails = dms_admin_validate_email_list_v2($body['emails'] ?? $body['notification_emails'] ?? '');
        update_option('dms_notification_emails', $emails['raw'], false);

        return dms_admin_action_response(
            'تم تحديث بريد التنبيهات بنجاح.',
            array(
                'emails' => $emails['raw'],
                'emails_list' => $emails['list'],
            )
        );
    }
}

if (!function_exists('dms_admin_diagnostics_v2')) {
    function dms_admin_diagnostics_v2(WP_REST_Request $request) {
        return dms_admin_detail_response(dms_admin_diagnostics_payload());
    }
}

if (!function_exists('dms_admin_build_tax_query_v2')) {
    function dms_admin_build_tax_query_v2($category, $brand) {
        $tax_query = array();

        if ($category !== '') {
            $category_id = intval($category);
            $tax_query[] = array(
                'taxonomy' => 'product_cat',
                'field' => $category_id > 0 ? 'term_id' : 'slug',
                'terms' => $category_id > 0 ? array($category_id) : array($category),
            );
        }

        $brand_taxonomy = dms_admin_product_brand_taxonomy_v2();
        if ($brand !== '' && $brand_taxonomy !== '') {
            $brand_id = intval($brand);
            $tax_query[] = array(
                'taxonomy' => $brand_taxonomy,
                'field' => $brand_id > 0 ? 'term_id' : 'slug',
                'terms' => $brand_id > 0 ? array($brand_id) : array($brand),
            );
        }

        if (count($tax_query) > 1) {
            $tax_query['relation'] = 'AND';
        }

        return $tax_query;
    }
}

if (!function_exists('dms_admin_get_products_v2')) {
    function dms_admin_get_products_v2(WP_REST_Request $request) {
        $search = dms_admin_safe_string($request->get_param('search'));
        $category = dms_admin_safe_string($request->get_param('category'));
        $brand = dms_admin_safe_string($request->get_param('brand'));
        $stock_status = dms_admin_safe_string($request->get_param('stock_status'));
        $status = dms_admin_safe_string($request->get_param('status'));
        $featured = $request->get_param('featured');
        $page = max(1, intval($request->get_param('page') ?: 1));
        $per_page = max(1, min(100, intval($request->get_param('per_page') ?: 25)));
        $sort = dms_admin_safe_string($request->get_param('sort'));

        $post_status = $status !== '' ? array($status) : array('publish', 'draft', 'pending', 'private');
        $query_args = array(
            'post_type' => 'product',
            'post_status' => $post_status,
            'posts_per_page' => $per_page,
            'paged' => $page,
            'orderby' => 'date',
            'order' => 'DESC',
            's' => $search,
            'fields' => 'ids',
        );

        $tax_query = dms_admin_build_tax_query_v2($category, $brand);
        if (!empty($tax_query)) {
            $query_args['tax_query'] = $tax_query;
        }

        $meta_query = array();
        if ($stock_status !== '') {
            $meta_query[] = array(
                'key' => '_stock_status',
                'value' => $stock_status,
                'compare' => '=',
            );
        }
        if ($featured !== null && $featured !== '') {
            $meta_query[] = array(
                'key' => '_featured',
                'value' => dms_admin_parse_bool_v2($featured) ? 'yes' : 'no',
                'compare' => '=',
            );
        }
        if (count($meta_query) > 1) {
            $meta_query['relation'] = 'AND';
        }
        if (!empty($meta_query)) {
            $query_args['meta_query'] = $meta_query;
        }

        if ($sort === 'price_asc' || $sort === 'price_desc') {
            $query_args['meta_key'] = '_price';
            $query_args['orderby'] = 'meta_value_num';
            $query_args['order'] = $sort === 'price_asc' ? 'ASC' : 'DESC';
        } elseif ($sort === 'name_asc' || $sort === 'name_desc') {
            $query_args['orderby'] = 'title';
            $query_args['order'] = $sort === 'name_asc' ? 'ASC' : 'DESC';
        }

        $query = new WP_Query($query_args);
        $items = array();
        foreach ((array) $query->posts as $product_id) {
            $product = wc_get_product($product_id);
            if ($product) {
                $items[] = dms_admin_product_payload_v2($product);
            }
        }

        return dms_admin_list_response($items, $page, $per_page, intval($query->found_posts), intval($query->max_num_pages));
    }
}

if (!function_exists('dms_admin_get_product_details_v2')) {
    function dms_admin_get_product_details_v2(WP_REST_Request $request) {
        $product = wc_get_product((int) $request['id']);
        if (!$product) {
            return new WP_Error('product_not_found', __('المنتج غير موجود', 'dms-ecom'), array('status' => 404));
        }

        return dms_admin_detail_response(dms_admin_product_payload_v2($product));
    }
}

if (!function_exists('dms_admin_update_product_v2')) {
    function dms_admin_update_product_v2(WP_REST_Request $request) {
        $product = wc_get_product((int) $request['id']);
        if (!$product) {
            return new WP_Error('product_not_found', __('المنتج غير موجود', 'dms-ecom'), array('status' => 404));
        }

        $body = dms_admin_request_body_v2($request);

        if (array_key_exists('name', $body)) {
            $product->set_name(wp_strip_all_tags((string) $body['name']));
        }
        if (array_key_exists('sku', $body)) {
            $sku = wc_clean(wp_unslash((string) $body['sku']));
            $existing_id = wc_get_product_id_by_sku($sku);
            if ($sku !== '' && $existing_id && intval($existing_id) !== $product->get_id()) {
                return new WP_Error('sku_exists', __('رمز SKU مستخدم بالفعل', 'dms-ecom'), array('status' => 409));
            }
            $product->set_sku($sku);
        }
        if (array_key_exists('regular_price', $body)) {
            $product->set_regular_price(wc_format_decimal($body['regular_price']));
        }
        if (array_key_exists('sale_price', $body)) {
            $product->set_sale_price($body['sale_price'] === '' ? '' : wc_format_decimal($body['sale_price']));
        }
        if (array_key_exists('status', $body)) {
            $status = sanitize_key((string) $body['status']);
            if (in_array($status, array('publish', 'draft', 'pending', 'private'), true)) {
                $product->set_status($status);
            }
        }
        if (array_key_exists('featured', $body)) {
            $product->set_featured(dms_admin_parse_bool_v2($body['featured']));
        }
        if (array_key_exists('stock_quantity', $body) || array_key_exists('stock', $body)) {
            $stock_quantity = intval($body['stock_quantity'] ?? $body['stock']);
            $product->set_manage_stock(true);
            $product->set_stock_quantity($stock_quantity);
            $product->set_stock_status($stock_quantity > 0 ? 'instock' : 'outofstock');
        }

        $product->save();

        if (array_key_exists('home_order', $body)) {
            update_post_meta($product->get_id(), '_dms_app_order_home', intval($body['home_order']));
        }

        return dms_admin_action_response(
            'تم تحديث المنتج بنجاح.',
            array('product' => dms_admin_product_payload_v2(wc_get_product($product->get_id())))
        );
    }
}

if (!function_exists('dms_admin_review_payload_v2')) {
    function dms_admin_review_payload_v2($comment) {
        $product_id = intval($comment->comment_post_ID);
        return array(
            'id' => intval($comment->comment_ID),
            'user' => (string) $comment->comment_author,
            'rating' => intval(get_comment_meta($comment->comment_ID, 'rating', true)),
            'content' => (string) $comment->comment_content,
            'date' => mysql2date('c', $comment->comment_date, false),
            'status' => $comment->comment_approved === '1' ? 'approved' : (string) $comment->comment_approved,
            'product' => array(
                'id' => $product_id,
                'name' => get_the_title($product_id),
            ),
        );
    }
}

if (!function_exists('dms_admin_get_reviews_v2')) {
    function dms_admin_get_reviews_v2(WP_REST_Request $request) {
        $search = dms_admin_safe_string($request->get_param('search'));
        $status = dms_admin_safe_string($request->get_param('status'));
        $rating = intval($request->get_param('rating') ?: 0);
        $page = max(1, intval($request->get_param('page') ?: 1));
        $per_page = max(1, min(100, intval($request->get_param('per_page') ?: 25)));

        $query_args = array(
            'post_type' => 'product',
            'number' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'comment_date_gmt',
            'order' => 'DESC',
            'search' => $search,
            'status' => $status !== '' ? $status : 'all',
            'count' => false,
        );

        $comments = get_comments($query_args);
        $filtered = array();
        foreach ((array) $comments as $comment) {
            if ($rating > 0 && intval(get_comment_meta($comment->comment_ID, 'rating', true)) !== $rating) {
                continue;
            }
            $filtered[] = dms_admin_review_payload_v2($comment);
        }

        $count_args = $query_args;
        $count_args['count'] = true;
        unset($count_args['number'], $count_args['offset'], $count_args['orderby'], $count_args['order']);
        $total = intval(get_comments($count_args));

        return dms_admin_list_response($filtered, $page, $per_page, $total);
    }
}

if (!function_exists('dms_admin_update_review_status_v2')) {
    function dms_admin_update_review_status_v2(WP_REST_Request $request) {
        $comment_id = (int) $request['id'];
        $comment = get_comment($comment_id);
        if (!$comment) {
            return new WP_Error('review_not_found', __('التقييم غير موجود', 'dms-ecom'), array('status' => 404));
        }

        $body = dms_admin_request_body_v2($request);
        $status = sanitize_key((string) ($body['status'] ?? $body['action'] ?? ''));
        if ($status === 'approve' || $status === 'approved') {
            wp_set_comment_status($comment_id, 'approve');
        } elseif ($status === 'unapprove' || $status === 'hold') {
            wp_set_comment_status($comment_id, 'hold');
        } elseif ($status === 'spam') {
            wp_spam_comment($comment_id);
        } elseif ($status === 'trash' || $status === 'delete') {
            wp_trash_comment($comment_id);
        } else {
            return new WP_Error('invalid_status', __('إجراء التقييم غير صالح', 'dms-ecom'), array('status' => 400));
        }

        $fresh = get_comment($comment_id);
        return dms_admin_action_response(
            'تم تحديث حالة التقييم بنجاح.',
            array('review' => $fresh ? dms_admin_review_payload_v2($fresh) : array('id' => $comment_id))
        );
    }
}

if (!function_exists('dms_admin_get_home_banner_v2')) {
    function dms_admin_get_home_banner_v2(WP_REST_Request $request) {
        return dms_admin_detail_response(function_exists('dms_app_home_banner_admin_payload') ? dms_app_home_banner_admin_payload() : array());
    }
}

if (!function_exists('dms_admin_save_home_banner_v2')) {
    function dms_admin_save_home_banner_v2(WP_REST_Request $request) {
        $body = dms_admin_request_body_v2($request);
        if (isset($body['product_ids']) && is_array($body['product_ids'])) {
            $body['product_ids'] = implode(',', array_map('intval', $body['product_ids']));
        }
        $saved = function_exists('dms_app_home_banner_save') ? dms_app_home_banner_save($body) : array();
        $payload = function_exists('dms_app_home_banner_admin_payload') ? dms_app_home_banner_admin_payload() : $saved;
        return dms_admin_action_response('تم حفظ بانر الرئيسية بنجاح.', array('banner' => $payload));
    }
}

if (!function_exists('dms_admin_get_home_layout_v2')) {
    function dms_admin_get_home_layout_v2(WP_REST_Request $request) {
        return dms_admin_detail_response(function_exists('dms_app_home_layout_get') ? dms_app_home_layout_get() : array());
    }
}

if (!function_exists('dms_admin_save_home_layout_v2')) {
    function dms_admin_save_home_layout_v2(WP_REST_Request $request) {
        $saved = function_exists('dms_app_home_layout_save')
            ? dms_app_home_layout_save(dms_admin_request_body_v2($request))
            : array();
        return dms_admin_action_response('تم حفظ تخطيط الصفحة الرئيسية بنجاح.', array('layout' => $saved));
    }
}

if (!function_exists('dms_admin_get_app_theme_v2')) {
    function dms_admin_get_app_theme_v2(WP_REST_Request $request) {
        return dms_admin_detail_response(function_exists('dms_app_theme_get') ? dms_app_theme_get() : array());
    }
}

if (!function_exists('dms_admin_save_app_theme_v2')) {
    function dms_admin_save_app_theme_v2(WP_REST_Request $request) {
        $saved = function_exists('dms_app_theme_save')
            ? dms_app_theme_save(dms_admin_request_body_v2($request))
            : array();
        return dms_admin_action_response('تم حفظ ثيم التطبيق بنجاح.', array('theme' => $saved));
    }
}

if (!function_exists('dms_admin_get_popup_config_v2')) {
    function dms_admin_get_popup_config_v2(WP_REST_Request $request) {
        return dms_admin_detail_response(function_exists('dms_get_app_popup_config') ? dms_get_app_popup_config() : array());
    }
}

if (!function_exists('dms_admin_save_popup_config_v2')) {
    function dms_admin_save_popup_config_v2(WP_REST_Request $request) {
        $saved = function_exists('dms_save_app_popup_config')
            ? dms_save_app_popup_config(dms_admin_request_body_v2($request))
            : array();
        return dms_admin_action_response('تم حفظ إعدادات النافذة المنبثقة بنجاح.', array('popup' => $saved));
    }
}

if (!function_exists('dms_admin_ordering_term_list_v2')) {
    function dms_admin_ordering_term_list_v2($taxonomy) {
        if ($taxonomy === '' || !taxonomy_exists($taxonomy)) {
            return array();
        }

        $terms = get_terms(array(
            'taxonomy' => $taxonomy,
            'hide_empty' => false,
        ));

        $items = array();
        foreach ((array) $terms as $term) {
            if ($term instanceof WP_Term) {
                $items[] = dms_admin_term_payload_v2($term);
            }
        }
        return $items;
    }
}

if (!function_exists('dms_admin_ordering_products_v2')) {
    function dms_admin_ordering_products_v2() {
        $products = wc_get_products(array(
            'limit' => 200,
            'status' => array('publish', 'draft', 'pending', 'private'),
            'orderby' => 'title',
            'order' => 'ASC',
        ));
        $items = array();
        foreach ((array) $products as $product) {
            if ($product) {
                $items[] = array(
                    'id' => $product->get_id(),
                    'name' => $product->get_name(),
                    'image_url' => $product->get_image_id() ? (string) wp_get_attachment_image_url($product->get_image_id(), 'thumbnail') : '',
                );
            }
        }
        return $items;
    }
}

if (!function_exists('dms_admin_get_ordering_config_v2')) {
    function dms_admin_get_ordering_config_v2(WP_REST_Request $request) {
        $config = function_exists('lpco_app_layout_config_get') ? lpco_app_layout_config_get() : array();
        return dms_admin_detail_response(array(
            'config' => $config,
            'available' => array(
                'categories' => dms_admin_ordering_term_list_v2('product_cat'),
                'brands' => dms_admin_ordering_term_list_v2(dms_admin_product_brand_taxonomy_v2()),
                'featured_products' => dms_admin_ordering_products_v2(),
            ),
        ));
    }
}

if (!function_exists('dms_admin_save_ordering_config_v2')) {
    function dms_admin_save_ordering_config_v2(WP_REST_Request $request) {
        $body = dms_admin_request_body_v2($request);
        $input = array(
            'categories' => dms_admin_parse_id_list($body['categories'] ?? array()),
            'brands' => dms_admin_parse_id_list($body['brands'] ?? array()),
            'hidden_categories' => dms_admin_parse_id_list($body['hidden_categories'] ?? array()),
            'hidden_brands' => dms_admin_parse_id_list($body['hidden_brands'] ?? array()),
            'featured_products' => dms_admin_parse_id_list($body['featured_products'] ?? $body['products'] ?? array()),
        );
        $saved = function_exists('lpco_app_layout_config_save') ? lpco_app_layout_config_save($input) : $input;
        return dms_admin_action_response('تم حفظ ترتيب الواجهة بنجاح.', array('ordering' => $saved));
    }
}
