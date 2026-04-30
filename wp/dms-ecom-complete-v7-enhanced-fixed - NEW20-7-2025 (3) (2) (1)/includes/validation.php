<?php
/**
 * Validation Module - DMS Ecom
 * التحقق من البيانات المدخلة
 */

if (!defined('ABSPATH')) {
    exit;
}

namespace DMS\Ecom;

class Validator {
    /**
     * Validate email
     */
    public static function validate_email($email) {
        if (empty($email)) {
            return new \WP_Error('empty_email', 'البريد الإلكتروني مطلوب');
        }
        
        if (!is_email($email)) {
            return new \WP_Error('invalid_email', 'البريد الإلكتروني غير صحيح');
        }
        
        return true;
    }
    
    /**
     * Validate username
     */
    public static function validate_username($username) {
        if (empty($username)) {
            return new \WP_Error('empty_username', 'اسم المستخدم مطلوب');
        }
        
        if (strlen($username) < 3) {
            return new \WP_Error('short_username', 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل');
        }
        
        if (username_exists($username)) {
            return new \WP_Error('duplicate_username', 'اسم المستخدم موجود بالفعل');
        }
        
        return true;
    }
    
    /**
     * Validate password
     */
    public static function validate_password($password) {
        if (empty($password)) {
            return new \WP_Error('empty_password', 'كلمة المرور مطلوبة');
        }
        
        if (strlen($password) < 8) {
            return new \WP_Error('weak_password', 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
        }
        
        return true;
    }
    
    /**
     * Validate phone number
     */
    public static function validate_phone($phone) {
        if (empty($phone)) {
            return new \WP_Error('empty_phone', 'رقم الهاتف مطلوب');
        }
        
        // Simple phone validation - can be extended
        $phone = preg_replace('/[^0-9+]/', '', $phone);
        
        if (strlen($phone) < 7) {
            return new \WP_Error('invalid_phone', 'رقم الهاتف غير صحيح');
        }
        
        return $phone;
    }
    
    /**
     * Validate URL
     */
    public static function validate_url($url) {
        if (empty($url)) {
            return new \WP_Error('empty_url', 'الرابط مطلوب');
        }
        
        if (!filter_var($url, FILTER_VALIDATE_URL)) {
            return new \WP_Error('invalid_url', 'الرابط غير صحيح');
        }
        
        return true;
    }
    
    /**
     * Validate integer
     */
    public static function validate_integer($value, $min = 0, $max = null) {
        if (!is_numeric($value) || intval($value) != $value) {
            return new \WP_Error('not_integer', 'يجب أن تكون قيمة رقمية');
        }
        
        $int_value = intval($value);
        
        if ($int_value < $min) {
            return new \WP_Error('too_small', 'القيمة أصغر من المسموح');
        }
        
        if ($max !== null && $int_value > $max) {
            return new \WP_Error('too_large', 'القيمة أكبر من المسموح');
        }
        
        return $int_value;
    }
    
    /**
     * Validate float
     */
    public static function validate_float($value, $min = 0, $max = null) {
        if (!is_numeric($value)) {
            return new \WP_Error('not_float', 'يجب أن تكون قيمة رقمية');
        }
        
        $float_value = floatval($value);
        
        if ($float_value < $min) {
            return new \WP_Error('too_small', 'القيمة أصغر من المسموح');
        }
        
        if ($max !== null && $float_value > $max) {
            return new \WP_Error('too_large', 'القيمة أكبر من المسموح');
        }
        
        return $float_value;
    }
    
    /**
     * Validate array of required fields
     */
    public static function validate_required_fields($data, $required_fields) {
        $missing = [];
        
        foreach ($required_fields as $field) {
            if (empty($data[$field])) {
                $missing[] = $field;
            }
        }
        
        if (!empty($missing)) {
            return new \WP_Error(
                'missing_fields',
                'الحقول المطلوبة: ' . implode(', ', $missing)
            );
        }
        
        return true;
    }
    
    /**
     * Validate user role
     */
    public static function validate_user_role($role) {
        $wp_roles = wp_roles();
        
        if (!isset($wp_roles->roles[$role])) {
            return new \WP_Error('invalid_role', 'الدور غير صحيح');
        }
        
        return true;
    }
    
    /**
     * Validate JSON
     */
    public static function validate_json($data) {
        $decoded = json_decode($data, true);
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            return new \WP_Error('invalid_json', 'JSON غير صحيح');
        }
        
        return $decoded;
    }
    
    /**
     * Validate file upload
     */
    public static function validate_file_upload($file_array, $allowed_types = [], $max_size = 10485760) {
        if (empty($file_array['name'])) {
            return new \WP_Error('empty_file', 'يجب اختيار ملف');
        }
        
        if ($file_array['error'] !== UPLOAD_ERR_OK) {
            return new \WP_Error('upload_error', 'حدث خطأ في الرفع');
        }
        
        if ($file_array['size'] > $max_size) {
            return new \WP_Error('file_too_large', 'حجم الملف أكبر من المسموح');
        }
        
        if (!empty($allowed_types)) {
            $file_type = wp_check_filetype($file_array['name']);
            if (!in_array($file_type['ext'], $allowed_types)) {
                return new \WP_Error('invalid_file_type', 'نوع الملف غير مسموح');
            }
        }
        
        return true;
    }
    
    /**
     * Validate data range
     */
    public static function validate_range($value, $min, $max) {
        if ($value < $min || $value > $max) {
            return new \WP_Error(
                'out_of_range',
                sprintf('القيمة يجب أن تكون بين %s و %s', $min, $max)
            );
        }
        
        return true;
    }
}
