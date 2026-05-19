<?php
if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/products', array(
        'methods' => 'GET',
        'callback' => 'dms_get_products_with_prices',
        'permission_callback' => 'dms_permission_guest_or_auth',
    ));

    register_rest_route('dms/v1', '/products-plus', array(
        'methods' => 'GET',
        'callback' => 'dms_get_products_plus',
        'permission_callback' => 'dms_permission_guest_or_auth',
    ));

    register_rest_route('dms/v1', '/catalog-version', array(
        'methods' => 'GET',
        'callback' => 'dms_get_catalog_version',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('dms/v1', '/admin/product-diagnostics', array(
        'methods' => 'GET',
        'callback' => 'dms_get_product_diagnostics',
        'permission_callback' => function () {
            return current_user_can('manage_woocommerce');
        },
    ));

    register_rest_route('dms/v1', '/products-guest', array(
        'methods' => 'GET',
        'callback' => 'dms_get_products_guest',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('dms/v1', '/categories-guest', array(
        'methods' => 'GET',
        'callback' => 'dms_get_categories_guest',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('dms/v1', '/categories', array(
        'methods' => 'GET',
        'callback' => 'dms_get_categories_auth',
        'permission_callback' => 'dms_permission_guest_or_auth',
    ));

    register_rest_route('dms/v1', '/brands-guest', array(
        'methods' => 'GET',
        'callback' => 'dms_get_brands_guest',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('dms/v1', '/brands', array(
        'methods' => 'GET',
        'callback' => 'dms_get_brands_auth',
        'permission_callback' => 'dms_permission_guest_or_auth',
    ));

    register_rest_route('dms/v1', '/home-by-category', array(
        'methods' => 'GET',
        'callback' => 'dms_home_by_category',
        'permission_callback' => 'dms_permission_guest_or_auth',
    ));
});
