<?php
/**
 * Security Module - DMS Ecom
 * مركز الأمان الموحد
 */

if (!defined('ABSPATH')) {
    exit;
}

namespace DMS\Ecom;

class Security {
    /**
     * Get JWT token from Authorization header
     */
    public static function get_jwt_token() {
        $token = '';
        
        if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $token = trim($_SERVER['HTTP_AUTHORIZATION']);
        } elseif (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $token = trim($_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
        } elseif (function_exists('apache_request_headers')) {
            $headers = apache_request_headers();
            if (isset($headers['Authorization'])) {
                $token = trim($headers['Authorization']);
            }
        }
        
        // Remove 'Bearer ' prefix if present
        if (strpos($token, 'Bearer ') === 0) {
            $token = substr($token, 7);
        }
        
        return $token;
    }
    
    /**
     * Decode JWT token
     */
    public static function decode_jwt($token) {
        $parts = explode('.', $token);
        
        if (count($parts) !== 3) {
            return false;
        }
        
        try {
            $payload = self::base64url_decode($parts[1]);
            return json_decode($payload, true);
        } catch (Exception $e) {
            \dms_ecom_log('JWT decode error: ' . $e->getMessage(), 'error');
            return false;
        }
    }
    
    /**
     * Base64url decode
     */
    public static function base64url_decode($data) {
        $remainder = strlen($data) % 4;
        if ($remainder) {
            $padlen = 4 - $remainder;
            $data .= str_repeat('=', $padlen);
        }
        return base64_decode(strtr($data, '-_', '+/'));
    }
    
    /**
     * Base64url encode
     */
    public static function base64url_encode($data) {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
    
    /**
     * Get client IP
     */
    public static function get_client_ip() {
        $ip_keys = ['HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'];
        foreach ($ip_keys as $key) {
            if (!empty($_SERVER[$key])) {
                $ips = explode(',', $_SERVER[$key]);
                $ip = trim($ips[0]);
                if (filter_var($ip, FILTER_VALIDATE_IP)) {
                    return $ip;
                }
            }
        }
        return '';
    }
    
    /**
     * Rate limiting
     */
    public static function check_rate_limit($action, $limit = 100, $window = 3600) {
        $ip = self::get_client_ip();
        
        if (empty($ip)) {
            return true;
        }
        
        $key = 'dms_rate_' . $action . '_' . md5($ip);
        $bucket = get_transient($key);
        
        if (!$bucket || !is_array($bucket)) {
            $bucket = ['count' => 0, 'start' => time()];
        }
        
        $elapsed = time() - intval($bucket['start']);
        if ($elapsed >= $window) {
            $bucket = ['count' => 0, 'start' => time()];
        }
        
        if ($bucket['count'] >= $limit) {
            \dms_ecom_log('Rate limit exceeded', 'warn', ['action' => $action, 'ip' => $ip]);
            return new \WP_Error(
                'rate_limited',
                'عدد طلبات كثير جداً، حاول لاحقاً',
                ['status' => 429]
            );
        }
        
        $bucket['count']++;
        set_transient($key, $bucket, max($window - $elapsed, 1));
        
        return true;
    }
    
    /**
     * Sanitize and validate input
     */
    public static function sanitize_input($data, $type = 'text') {
        switch ($type) {
            case 'email':
                return sanitize_email($data);
            case 'url':
                return esc_url_raw($data);
            case 'integer':
                return intval($data);
            case 'float':
                return floatval($data);
            case 'text':
            default:
                return sanitize_text_field($data);
        }
    }
    
    /**
     * Verify nonce
     */
    public static function verify_nonce($nonce, $action) {
        if (!isset($_REQUEST[$nonce]) || !wp_verify_nonce($_REQUEST[$nonce], $action)) {
            \dms_ecom_log('Nonce verification failed', 'warn', ['action' => $action]);
            return false;
        }
        return true;
    }
    
    /**
     * Check user permissions
     */
    public static function check_permission($capability = 'manage_woocommerce') {
        if (!is_user_logged_in()) {
            return new \WP_Error('not_authenticated', 'يجب تسجيل الدخول', ['status' => 401]);
        }
        
        if (!current_user_can($capability)) {
            \dms_ecom_log('Permission denied for user', 'warn', ['user_id' => get_current_user_id(), 'capability' => $capability]);
            return new \WP_Error('forbidden', 'ليس لديك صلاحيات كافية', ['status' => 403]);
        }
        
        return true;
    }
    
    /**
     * Sanitize database query
     */
    public static function prepare_query($query, $args = []) {
        global $wpdb;
        
        if (empty($args)) {
            return $query;
        }
        
        return $wpdb->prepare($query, $args);
    }
    
    /**
     * Check HTTPS on production
     */
    public static function require_https() {
        if (!is_ssl() && defined('FORCE_SSL_ADMIN') && FORCE_SSL_ADMIN) {
            die('HTTPS مطلوب');
        }
    }
    
    /**
     * Escape output safely
     */
    public static function safe_output($data, $type = 'text') {
        switch ($type) {
            case 'html':
                return wp_kses_post($data);
            case 'url':
                return esc_url($data);
            case 'attr':
                return esc_attr($data);
            case 'text':
            default:
                return esc_html($data);
        }
    }
}
