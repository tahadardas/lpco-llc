<?php
if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/user/(?P<user_id>\d+)/orders', array(
        'methods' => 'GET',
        'callback' => 'dms_get_user_orders',
        'permission_callback' => 'dms_permission_jwt',
    ));

    register_rest_route('dms/v1', '/orders', array(
        'methods' => 'POST',
        'callback' => 'dms_create_order',
        'permission_callback' => 'dms_permission_jwt',
    ));

    register_rest_route('dms/v1', '/orders/(?P<id>\d+)/sham-cash-confirm', array(
        'methods' => 'POST',
        'callback' => 'dms_confirm_sham_cash_transfer',
        'permission_callback' => 'dms_permission_jwt',
    ));
});
