<?php
if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/user/(?P<id>\d+)', array(
        'methods' => 'GET',
        'callback' => 'dms_get_user_with_meta',
        'permission_callback' => 'dms_permission_jwt',
    ));
    
    register_rest_route('dms/v1', '/user/(?P<id>\d+)', array(
        'methods' => 'POST',
        'callback' => 'dms_update_user_profile',
        'permission_callback' => 'dms_permission_jwt',
    ));

    register_rest_route('dms/v1', '/register', array(
        'methods' => 'POST',
        'callback' => 'dms_register_user',
        'permission_callback' => '__return_true',
    ));

    register_rest_route('dms/v1', '/job-application', array(
        'methods' => 'POST',
        'callback' => 'dms_submit_job_application',
        'permission_callback' => '__return_true',
    ));
});
