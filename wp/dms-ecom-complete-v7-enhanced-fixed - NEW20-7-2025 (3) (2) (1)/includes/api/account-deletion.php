<?php
/**
 * Self-service account deletion for the mobile app.
 * Financial WooCommerce records are retained after direct identifiers are removed.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/account', array(
        'methods' => WP_REST_Server::DELETABLE,
        'callback' => 'dms_delete_current_account',
        'permission_callback' => 'dms_permission_jwt',
    ));
});

function dms_delete_current_account(WP_REST_Request $request) {
    $user_id = get_current_user_id();
    $user = $user_id > 0 ? get_userdata($user_id) : false;
    if (!$user) {
        return new WP_Error('account_not_found', 'الحساب غير موجود أو تم حذفه مسبقاً.', array('status' => 404));
    }
    if (user_can($user_id, 'manage_options')) {
        return new WP_Error('administrator_deletion_forbidden', 'لا يمكن حذف حساب مسؤول الموقع من التطبيق.', array('status' => 403));
    }

    $body = $request->get_json_params();
    $password = is_array($body) ? (string) ($body['password'] ?? '') : '';
    if ($password === '' || !wp_check_password($password, $user->user_pass, $user_id)) {
        return new WP_Error('invalid_password', 'كلمة المرور غير صحيحة.', array('status' => 403));
    }

    global $wpdb;
    $wpdb->query('START TRANSACTION');

    try {
        $deletion_reference = wp_generate_uuid4();
        $orders_anonymized = dms_anonymize_customer_orders($user_id, $deletion_reference);
        dms_delete_customer_notification_links($user_id);

        if (function_exists('WC') && WC()->session && method_exists(WC()->session, 'destroy_session')) {
            WC()->session->destroy_session();
        }
        if (class_exists('WP_Session_Tokens')) {
            WP_Session_Tokens::get_instance($user_id)->destroy_all();
        }

        require_once ABSPATH . 'wp-admin/includes/user.php';
        if (!wp_delete_user($user_id)) {
            throw new RuntimeException('WordPress failed to delete the user.');
        }

        $wpdb->query('COMMIT');
        do_action('dms_account_deleted', $deletion_reference, $orders_anonymized);

        return new WP_REST_Response(array(
            'success' => true,
            'message' => 'تم حذف الحساب بنجاح.',
            'orders_anonymized' => $orders_anonymized,
        ), 200);
    } catch (Throwable $error) {
        $wpdb->query('ROLLBACK');
        if (defined('DMS_ECOM_DEBUG') && DMS_ECOM_DEBUG) {
            error_log('[DMS_ACCOUNT_DELETE] ' . $error->getMessage());
        }
        return new WP_Error('account_delete_failed', 'تعذر حذف الحساب حالياً. يرجى إعادة المحاولة.', array('status' => 500));
    }
}

function dms_anonymize_customer_orders($user_id, $deletion_reference) {
    if (!function_exists('wc_get_orders')) {
        return 0;
    }

    $count = 0;
    $anonymous_email = 'deleted+' . substr(hash('sha256', $deletion_reference), 0, 20) . '@invalid.local';
    do {
        $orders = wc_get_orders(array(
            'customer_id' => $user_id,
            'limit' => 100,
            'page' => 1,
            'orderby' => 'ID',
            'order' => 'ASC',
            'return' => 'objects',
        ));
        if (empty($orders)) {
            break;
        }

        foreach ($orders as $order) {
            $order->set_customer_id(0);
            $order->set_billing_first_name('Deleted');
            $order->set_billing_last_name('Customer');
            $order->set_billing_company('');
            $order->set_billing_address_1('');
            $order->set_billing_address_2('');
            $order->set_billing_city('');
            $order->set_billing_state('');
            $order->set_billing_postcode('');
            $order->set_billing_country('');
            $order->set_billing_email($anonymous_email);
            $order->set_billing_phone('');
            $order->set_shipping_first_name('Deleted');
            $order->set_shipping_last_name('Customer');
            $order->set_shipping_company('');
            $order->set_shipping_address_1('');
            $order->set_shipping_address_2('');
            $order->set_shipping_city('');
            $order->set_shipping_state('');
            $order->set_shipping_postcode('');
            $order->set_shipping_country('');
            foreach (array('order_contact_name', 'order_phone', 'order_address', 'order_city', 'order_state', 'order_company', 'shipping_phone') as $meta_key) {
                $order->delete_meta_data($meta_key);
            }
            $order->update_meta_data('_dms_customer_anonymized', gmdate('c'));
            $order->save();
            $count++;
        }
    } while (count($orders) === 100);

    return $count;
}

function dms_delete_customer_notification_links($user_id) {
    if (!function_exists('dms_notifications_tables')) {
        return;
    }

    global $wpdb;
    $tables = dms_notifications_tables();
    $tokens_table_exists = $wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $tables['tokens']));
    if ($tokens_table_exists !== $tables['tokens']) {
        return;
    }

    $token_ids = $wpdb->get_col($wpdb->prepare("SELECT id FROM {$tables['tokens']} WHERE user_id = %d", $user_id));
    if (!empty($token_ids)) {
        $safe_ids = implode(',', array_map('absint', $token_ids));
        $wpdb->query("DELETE FROM {$tables['receipts']} WHERE token_id IN ({$safe_ids})");
    }
    $wpdb->delete($tables['receipts'], array('user_id' => $user_id), array('%d'));
    $wpdb->delete($tables['tokens'], array('user_id' => $user_id), array('%d'));
    $wpdb->update($tables['notifications'], array('target_user_id' => null), array('target_user_id' => $user_id), array('%d'), array('%d'));
    $wpdb->update($tables['notifications'], array('created_by' => null), array('created_by' => $user_id), array('%d'), array('%d'));
}
