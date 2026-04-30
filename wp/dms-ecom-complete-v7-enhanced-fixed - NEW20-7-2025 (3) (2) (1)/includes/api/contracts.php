<?php
if (!defined('ABSPATH')) {
    exit;
}

function dms_api_success($data = array(), $meta = array(), $status = 200) {
    $payload = array(
        'success' => true,
        'data' => $data,
    );

    if (!empty($meta)) {
        $payload['meta'] = $meta;
    }

    $response = new WP_REST_Response($payload);
    $response->set_status(intval($status));
    return $response;
}

function dms_api_list_response($items = array(), $meta = array(), $status = 200) {
    $payload = array(
        'items' => is_array($items) ? array_values($items) : array(),
        'meta' => is_array($meta) ? $meta : array(),
    );

    $response = new WP_REST_Response($payload);
    $response->set_status(intval($status));
    return $response;
}

function dms_api_detail_response($data = array(), $status = 200) {
    $payload = array(
        'data' => is_array($data) ? $data : array(),
    );

    $response = new WP_REST_Response($payload);
    $response->set_status(intval($status));
    return $response;
}

function dms_api_action_response($message = '', $data = array(), $status = 200) {
    $payload = array(
        'success' => true,
        'message' => is_string($message) ? $message : '',
        'data' => is_array($data) ? $data : array(),
    );

    $response = new WP_REST_Response($payload);
    $response->set_status(intval($status));
    return $response;
}

function dms_api_pagination_meta($page, $per_page, $total, $total_pages = null) {
    $page = max(1, intval($page));
    $per_page = max(1, intval($per_page));
    $total = max(0, intval($total));
    if ($total_pages === null) {
        $total_pages = $per_page > 0 ? (int) ceil($total / $per_page) : 1;
    }

    return array(
        'page' => $page,
        'per_page' => $per_page,
        'total' => $total,
        'total_pages' => max(1, intval($total_pages)),
    );
}

function dms_api_error($code, $message, $status = 400, $details = array()) {
    $data = array('status' => intval($status));
    if (!empty($details)) {
        $data['details'] = $details;
    }
    return new WP_Error($code, $message, $data);
}
