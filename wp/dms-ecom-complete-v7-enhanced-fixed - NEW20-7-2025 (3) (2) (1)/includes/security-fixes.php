<?php
/**
 * Security Fixes for DMS Ecom Plugin
 * إصلاحات الأمان لمتجر DMS
 * 
 * This file contains security enhancements:
 * ✅ Input validation and sanitization
 * ✅ Output escaping
 * ✅ Nonce verification
 * ✅ Database prepared statements
 * ✅ Rate limiting
 */

if (!defined('ABSPATH')) exit;

// ============================================================================
// 1️⃣ NONCE VERIFICATION - التحقق من Nonce
// ============================================================================

/**
 * ✅ التحقق من Nonce لـ REST requests
 * Verify nonce for REST API requests
 */
function dms_verify_rest_nonce($request) {
    if (!$request instanceof WP_REST_Request) {
        return false;
    }
    
    // احصل على الـ nonce من headers أو params
    $nonce = $request->get_header('X-WP-Nonce') ?: $request->get_param('_wpnonce');
    
    if (empty($nonce)) {
        return false;
    }
    
    // تحقق من صحة الـ nonce
    return wp_verify_nonce($nonce, 'wp_rest');
}

/**
 * ✅ الحصول على Nonce token للـ client
 * Get nonce token for client-side usage
 */
function dms_get_rest_nonce() {
    return wp_create_nonce('wp_rest');
}

// إضافة rest_api_init hook لـ expose الـ nonce
add_action('rest_api_init', function() {
    register_rest_route('dms/v1', '/nonce', array(
        'methods' => 'GET',
        'callback' => function() {
            return array(
                'nonce' => dms_get_rest_nonce(),
                'timestamp' => current_time('mysql'),
            );
        },
        'permission_callback' => '__return_true',
    ));
});

// ============================================================================
// 2️⃣ INPUT SANITIZATION - تنظيف المدخلات
// ============================================================================

/**
 * ✅ تنظيف وتحقق من صحة البيانات المدخلة
 * Sanitize and validate input data
 */
class DMS_Input_Sanitizer {
    
    /**
     * تنظيف البريد الإلكتروني
     */
    public static function sanitize_email($email) {
        $email = sanitize_email($email);
        if (!is_email($email)) {
            return new WP_Error('invalid_email', 'البريد الإلكتروني غير صحيح');
        }
        return $email;
    }
    
    /**
     * تنظيف النص
     */
    public static function sanitize_text($text) {
        return sanitize_text_field($text);
    }
    
    /**
     * تنظيف الـ URL
     */
    public static function sanitize_url($url) {
        $url = esc_url_raw($url);
        if (empty($url)) {
            return new WP_Error('invalid_url', 'الـ URL غير صحيح');
        }
        return $url;
    }
    
    /**
     * تنظيف الأرقام
     */
    public static function sanitize_int($value) {
        return intval($value);
    }
    
    /**
     * تنظيف الأرقام العشرية
     */
    public static function sanitize_float($value) {
        return floatval($value);
    }
    
    /**
     * تنظيف الـ JSON
     */
    public static function sanitize_json($json) {
        $data = json_decode($json, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            return new WP_Error('invalid_json', 'بيانات JSON غير صحيحة');
        }
        return $data;
    }
    
    /**
     * تنظيف المصفوفات
     */
    public static function sanitize_array($array, $allowed_keys = array()) {
        if (!is_array($array)) {
            return array();
        }
        
        $sanitized = array();
        foreach ($array as $key => $value) {
            if (!empty($allowed_keys) && !in_array($key, $allowed_keys)) {
                continue;
            }
            $sanitized[$key] = is_array($value) ? self::sanitize_array($value) : sanitize_text_field($value);
        }
        return $sanitized;
    }
}

// ============================================================================
// 3️⃣ OUTPUT ESCAPING - هروب البيانات المخرجة
// ============================================================================

/**
 * ✅ هروب آمن للبيانات المخرجة
 * Safe output escaping
 */
class DMS_Output_Escaper {
    
    /**
     * هروب الـ HTML
     */
    public static function escape_html($text) {
        return wp_kses_post($text);
    }
    
    /**
     * هروب الـ attribute
     */
    public static function escape_attr($text) {
        return esc_attr($text);
    }
    
    /**
     * هروب الـ URL
     */
    public static function escape_url($url) {
        return esc_url($url);
    }
    
    /**
     * هروب الـ JavaScript
     */
    public static function escape_js($text) {
        return esc_js($text);
    }
    
    /**
     * هروب JSON
     */
    public static function escape_json($data) {
        return wp_json_encode($data);
    }
}

// ============================================================================
// 4️⃣ DATABASE SECURITY - أمان قاعدة البيانات
// ============================================================================

/**
 * ✅ بناء استعلامات آمنة
 * Build safe database queries
 */
class DMS_DB_Query {
    
    /**
     * اختيار مع prepared statement
     */
    public static function get_results($query, $args = array()) {
        global $wpdb;
        
        if (empty($args)) {
            return $wpdb->get_results($query);
        }
        
        $prepared = $wpdb->prepare($query, $args);
        return $wpdb->get_results($prepared);
    }
    
    /**
     * اختيار صف واحد مع prepared statement
     */
    public static function get_row($query, $args = array()) {
        global $wpdb;
        
        if (empty($args)) {
            return $wpdb->get_row($query);
        }
        
        $prepared = $wpdb->prepare($query, $args);
        return $wpdb->get_row($prepared);
    }
    
    /**
     * اختيار قيمة مع prepared statement
     */
    public static function get_var($query, $args = array()) {
        global $wpdb;
        
        if (empty($args)) {
            return $wpdb->get_var($query);
        }
        
        $prepared = $wpdb->prepare($query, $args);
        return $wpdb->get_var($prepared);
    }
    
    /**
     * إدراج مع prepared statement
     */
    public static function insert($table, $data) {
        global $wpdb;
        
        $format = array();
        foreach ($data as $value) {
            if (is_int($value)) {
                $format[] = '%d';
            } elseif (is_float($value)) {
                $format[] = '%f';
            } else {
                $format[] = '%s';
            }
        }
        
        return $wpdb->insert($table, $data, $format);
    }
    
    /**
     * تحديث مع prepared statement
     */
    public static function update($table, $data, $where) {
        global $wpdb;
        
        $format = array();
        foreach ($data as $value) {
            if (is_int($value)) {
                $format[] = '%d';
            } elseif (is_float($value)) {
                $format[] = '%f';
            } else {
                $format[] = '%s';
            }
        }
        
        $where_format = array();
        foreach ($where as $value) {
            if (is_int($value)) {
                $where_format[] = '%d';
            } elseif (is_float($value)) {
                $where_format[] = '%f';
            } else {
                $where_format[] = '%s';
            }
        }
        
        return $wpdb->update($table, $data, $where, $format, $where_format);
    }
    
    /**
     * حذف مع prepared statement
     */
    public static function delete($table, $where) {
        global $wpdb;
        
        $where_format = array();
        foreach ($where as $value) {
            if (is_int($value)) {
                $where_format[] = '%d';
            } elseif (is_float($value)) {
                $where_format[] = '%f';
            } else {
                $where_format[] = '%s';
            }
        }
        
        return $wpdb->delete($table, $where, $where_format);
    }
}

// ============================================================================
// 5️⃣ RATE LIMITING - تحديد معدل الطلبات
// ============================================================================

/**
 * ✅ تحديد معدل الطلبات لـ IP
 * Rate limiting per IP address
 */
class DMS_Rate_Limiter {
    
    /**
     * الحصول على عنوان IP الحقيقي
     */
    public static function get_client_ip() {
        $ip_keys = array('HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR', 'HTTP_CLIENT_IP', 'REMOTE_ADDR');
        
        foreach ($ip_keys as $key) {
            if (array_key_exists($key, $_SERVER) === true) {
                $ips = explode(',', $_SERVER[$key]);
                $ip = trim($ips[0]);
                
                if (filter_var($ip, FILTER_VALIDATE_IP) !== false) {
                    return $ip;
                }
            }
        }
        
        return '0.0.0.0';
    }
    
    /**
     * فحص تحديد المعدل
     */
    public static function check_limit($action, $limit = 100, $window = 3600) {
        $ip = self::get_client_ip();
        $key = 'dms_rate_' . $action . '_' . md5($ip);
        
        // احصل على عدد الطلبات
        $count = get_transient($key);
        $count = $count ? intval($count) + 1 : 1;
        
        // اذا تجاوز الحد
        if ($count > $limit) {
            dms_ecom_log('warning', "Rate limit exceeded: $action from $ip");
            return new WP_Error(
                'rate_limit_exceeded',
                'لقد تجاوزت حد الطلبات. حاول لاحقاً.',
                array('status' => 429)
            );
        }
        
        // حفظ العد
        set_transient($key, $count, $window);
        
        return true;
    }
    
    /**
     * مسح حد المعدل
     */
    public static function reset_limit($action) {
        $ip = self::get_client_ip();
        $key = 'dms_rate_' . $action . '_' . md5($ip);
        delete_transient($key);
    }
}

// ============================================================================
// 6️⃣ REQUEST VALIDATION - التحقق من الطلب
// ============================================================================

/**
 * ✅ التحقق الشامل من الطلب
 * Comprehensive request validation
 */
class DMS_Request_Validator {
    
    /**
     * التحقق من الطلب
     */
    public static function validate($request, $rules = array()) {
        if (!$request instanceof WP_REST_Request) {
            return new WP_Error('invalid_request', 'طلب غير صحيح');
        }
        
        $errors = array();
        
        foreach ($rules as $field => $rule) {
            $value = $request->get_param($field);
            
            // required
            if (!empty($rule['required']) && empty($value)) {
                $errors[$field] = $rule['required_message'] ?? "الحقل $field مطلوب";
            }
            
            // type
            if (!empty($rule['type']) && !empty($value)) {
                $type = $rule['type'];
                $valid = false;
                
                switch ($type) {
                    case 'email':
                        $valid = is_email($value);
                        break;
                    case 'url':
                        $valid = filter_var($value, FILTER_VALIDATE_URL) !== false;
                        break;
                    case 'int':
                        $valid = is_numeric($value) && intval($value) == $value;
                        break;
                    case 'float':
                        $valid = is_numeric($value);
                        break;
                    case 'array':
                        $valid = is_array($value);
                        break;
                    case 'string':
                        $valid = is_string($value);
                        break;
                }
                
                if (!$valid) {
                    $errors[$field] = $rule['type_message'] ?? "الحقل $field نوع البيانات غير صحيح";
                }
            }
            
            // min length
            if (!empty($rule['min_length']) && !empty($value)) {
                if (strlen($value) < intval($rule['min_length'])) {
                    $errors[$field] = $rule['min_message'] ?? "الحقل $field أقصر من اللازم";
                }
            }
            
            // max length
            if (!empty($rule['max_length']) && !empty($value)) {
                if (strlen($value) > intval($rule['max_length'])) {
                    $errors[$field] = $rule['max_message'] ?? "الحقل $field أطول من اللازم";
                }
            }
        }
        
        if (!empty($errors)) {
            return new WP_Error('validation_failed', 'فشل التحقق من البيانات', $errors);
        }
        
        return true;
    }
}

// ============================================================================
// 7️⃣ LOGGING - تسجيل الأحداث
// ============================================================================

/**
 * ✅ تسجيل الأحداث الأمنية
 * Security event logging
 */
function dms_security_log($event, $data = array()) {
    if (!defined('DMS_ECOM_DEBUG') || !DMS_ECOM_DEBUG) {
        return;
    }
    
    $log_dir = WP_CONTENT_DIR . '/logs';
    if (!is_dir($log_dir)) {
        mkdir($log_dir, 0755, true);
    }
    
    $timestamp = current_time('Y-m-d H:i:s');
    $user_id = get_current_user_id() ?: 'guest';
    $ip = DMS_Rate_Limiter::get_client_ip();
    
    $log_entry = "[$timestamp] [SECURITY] Event: $event | User: $user_id | IP: $ip";
    
    if (!empty($data)) {
        $log_entry .= ' | Data: ' . wp_json_encode($data);
    }
    
    $log_entry .= "\n";
    
    error_log($log_entry, 3, $log_dir . '/dms-security.log');
}

// ============================================================================
// 8️⃣ HOOKS & ACTIONS - الـ Hooks والإجراءات
// ============================================================================

// تسجيل محاولات تسجيل دخول فاشلة
add_action('wp_login_failed', function($username) {
    dms_security_log('failed_login', array('username' => $username));
});

// تسجيل عمليات حذف
add_action('delete_post', function($post_id) {
    dms_security_log('post_deleted', array('post_id' => $post_id));
});

// تسجيل تحديثات المستخدمين
add_action('profile_update', function($user_id, $old_user_data) {
    dms_security_log('user_updated', array('user_id' => $user_id));
}, 10, 2);
