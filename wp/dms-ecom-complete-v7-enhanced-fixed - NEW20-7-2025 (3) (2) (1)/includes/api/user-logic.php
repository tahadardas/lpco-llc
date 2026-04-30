<?php
/**
 * LPCO E-Commerce API User Logic
 * Handles user profiles, registration, and authentication validation.
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * JWT Validation logic.
 */
function dms_manual_jwt_validate($token) {
    if (empty($token)) {
        return new WP_Error('jwt_auth_invalid_token', 'No token provided', array('status' => 403));
    }
    
    $parts = explode('.', $token);
    if (count($parts) !== 3) {
        return new WP_Error('jwt_auth_invalid_token', 'رمز الدخول غير صالح', array('status' => 403));
    }
    
    list($header_b64, $payload_b64, $signature_b64) = $parts;
    $header = json_decode(dms_base64url_decode($header_b64));
    $payload = json_decode(dms_base64url_decode($payload_b64));
    $signature = dms_base64url_decode($signature_b64);
    
    if (!$header || !$payload || !$signature) {
        return new WP_Error('jwt_auth_invalid_token', 'رمز الدخول غير صالح', array('status' => 403));
    }
    
    $alg = isset($header->alg) ? $header->alg : 'HS256';
    if ($alg !== 'HS256') {
        return new WP_Error('jwt_auth_invalid_token', 'خوارزمية توقيع غير مدعومة', array('status' => 403));
    }
    
    if (!defined('JWT_AUTH_SECRET_KEY')) {
        return new WP_Error('jwt_auth_bad_config', 'مفتاح JWT غير مُعرّف في الإعدادات', array('status' => 403));
    }
    
    $expected = hash_hmac('sha256', $header_b64 . '.' . $payload_b64, JWT_AUTH_SECRET_KEY, true);
    if (!hash_equals($expected, $signature)) {
        return new WP_Error('jwt_auth_invalid_token', 'رمز الدخول غير صالح', array('status' => 403));
    }
    
    if (isset($payload->exp) && time() >= $payload->exp) {
        return new WP_Error('jwt_auth_invalid_token', 'انتهت صلاحية الرمز', array('status' => 403));
    }
    
    $user_id = null;
    if (isset($payload->data->user->id)) {
        $user_id = intval($payload->data->user->id);
    } elseif (isset($payload->sub)) {
        $user_id = intval($payload->sub);
    }
    
    if ($user_id) {
        return (object) array(
            'data' => (object) array(
                'user' => (object) array('id' => $user_id)
            )
        );
    }
    
    return new WP_Error('jwt_auth_invalid_token', 'تعذر تحديد هوية المستخدم من الرمز', array('status' => 403));
}

function dms_validate_jwt_request($request = null) {
    if (!function_exists('dms_get_auth_header')) {
        return new WP_Error('jwt_plugin_missing', 'Auth helpers missing', array('status' => 500));
    }
    
    $auth_header = dms_get_auth_header();
    if (empty($auth_header)) {
        return new WP_Error('jwt_missing_token', 'الرجاء إرسال رمز الدخول (Authorization: Bearer <token>)', array('status' => 401));
    }
    
    $token = preg_replace('/^Bearer\\s+/i', '', $auth_header);
    $validation = null;
    
    if (function_exists('jwt_auth_validate_token')) {
        $validation = jwt_auth_validate_token($token);
    } else {
        $validation = dms_manual_jwt_validate($token);
    }
    
    if (is_wp_error($validation)) {
        $message = $validation->get_error_message();
        if ($validation->get_error_code() === 'jwt_auth_bad_config') {
            $message = 'خطأ في إعدادات الدخول، يرجى التواصل مع الإدارة';
        } elseif ($validation->get_error_code() === 'jwt_auth_invalid_token') {
            $message = 'رمز الدخول غير صالح، يرجى تسجيل الدخول مجدداً';
        } elseif ($validation->get_error_code() === 'jwt_plugin_missing') {
            $message = 'إضافة JWT غير مفعّلة أو غير مُثبتة';
        }
        
        $status = 403;
        $data = $validation->get_error_data();
        if (is_array($data) && isset($data['status'])) {
            $status = $data['status'];
        }
        return new WP_Error($validation->get_error_code(), $message, array('status' => $status));
    }
    
    if (isset($validation->data->user->id)) {
        wp_set_current_user($validation->data->user->id);
    }
    
    return true;
}

/**
 * User Profile retrieval.
 */
function dms_get_user_with_meta($request) {
    $user_id = $request['id'];
    $current_user_id = get_current_user_id();
    
    if ($current_user_id && intval($current_user_id) !== intval($user_id)) {
        return new WP_Error('forbidden_user', 'ليس لديك صلاحية للوصول إلى هذا المستخدم', array('status' => 403));
    }
    
    $user = get_userdata($user_id);
    if (!$user) {
        return new WP_Error('user_not_found', 'المستخدم غير موجود', array('status' => 404));
    }
    
    $all_user_meta = get_user_meta($user_id);
    $read_user_meta = static function ($key) use ($all_user_meta) {
        return isset($all_user_meta[$key][0]) ? $all_user_meta[$key][0] : '';
    };

    $user_group = $read_user_meta('dms_user_group');
    $user_currency = $read_user_meta('dms_user_currency');
    $account_status = $read_user_meta('dms_account_status');
    $company_name = $read_user_meta('account_company_name');

    $phone = $read_user_meta('account_whatsapp') ?: ($read_user_meta('billing_phone') ?: $read_user_meta('phone'));
    $address = $read_user_meta('billing_address_1') ?: $read_user_meta('address');
    $city = $read_user_meta('billing_city') ?: $read_user_meta('city');
    $governorate = $read_user_meta('account_governorate') ?: ($read_user_meta('billing_state') ?: $read_user_meta('province'));
    $country_code = $read_user_meta('account_whatsapp_country_code');
    
    $final_group = !empty($user_group) ? $user_group : 'default';
    $final_currency = !empty($user_currency) ? $user_currency : 'syp';
    
    return array(
        'id' => $user->ID,
        'username' => $user->user_login,
        'email' => $user->user_email,
        'display_name' => $user->display_name,
        'first_name' => $user->first_name,
        'last_name' => $user->last_name,
        'roles' => $user->roles,
        'phone' => (string) $phone,
        'address' => (string) $address,
        'city' => (string) ($city ?: $governorate),
        'governorate' => (string) $governorate,
        'meta' => array(
            'dms_user_group' => $final_group,
            'dms_user_currency' => $final_currency,
            'dms_account_status' => $account_status ?: 'جديد',
            'account_company_name' => $company_name ?: '',
            'account_whatsapp_country_code' => $country_code ?: '',
            'account_whatsapp' => $phone ?: '',
            'account_governorate' => $governorate ?: '',
            'billing_phone' => $phone ?: '',
            'billing_address_1' => $address ?: '',
            'billing_city' => $city ?: '',
            'billing_state' => $governorate ?: '',
            'address' => $address ?: '',
            'city' => ($city ?: $governorate) ?: ''
        )
    );
}

/**
 * User Profile update.
 */
function dms_update_user_profile($request) {
    if (!function_exists('get_current_user_id')) {
        return new WP_Error('internal_error', 'Internal server error', array('status' => 500));
    }

    $user_id = $request['id'];
    $current_user_id = get_current_user_id();
    
    if (!$current_user_id || intval($current_user_id) !== intval($user_id)) {
        return new WP_Error('forbidden_update', 'ليس لديك صلاحية لتحديث بيانات هذا المستخدم', array('status' => 403));
    }
    
    $params = $request->get_json_params();
    if (!is_array($params)) {
        return new WP_Error('invalid_json', 'بيانات غير صالحة', array('status' => 400));
    }
    
    $company = sanitize_text_field($params['company'] ?? ($params['company_name'] ?? ''));
    $province = sanitize_text_field($params['province'] ?? ($params['governorate'] ?? ($params['billing_state'] ?? '')));
    $phone = sanitize_text_field($params['phone'] ?? '');
    $address = sanitize_text_field($params['address'] ?? ($params['billing_address_1'] ?? ''));
    
    if (!empty($company)) {
        update_user_meta($user_id, 'account_company_name', $company);
        update_user_meta($user_id, 'billing_company', $company);
        update_user_meta($user_id, 'company', $company);
    }
    
    if (!empty($province)) {
        update_user_meta($user_id, 'account_governorate', $province);
        update_user_meta($user_id, 'billing_state', $province);
        update_user_meta($user_id, 'province', $province);
    }
    
    if (!empty($phone)) {
        update_user_meta($user_id, 'account_whatsapp', $phone);
        update_user_meta($user_id, 'billing_phone', $phone);
        update_user_meta($user_id, 'phone', $phone);
    }
    
    if (!empty($address)) {
        update_user_meta($user_id, 'address', $address);
        update_user_meta($user_id, 'billing_address_1', $address);
    }
    
    if (function_exists('dms_sync_member_record')) {
        dms_sync_member_record($user_id, array(
            'company' => $company,
            'governorate' => $province,
            'phone' => $phone,
            'address' => $address
        ));
    }
    
    return array(
        'success' => true,
        'message' => 'تم تحديث البيانات بنجاح',
        'id' => $user_id
    );
}

/**
 * User Registration.
 */
function dms_register_user($request) {
    $params = $request->get_json_params();
    $ip = dms_ecom_get_client_ip();
    
    if (function_exists('dms_ecom_rate_limit')) {
        $rate_check = dms_ecom_rate_limit('register', $ip);
        if (is_wp_error($rate_check)) return $rate_check;
    }
    
    if (function_exists('dms_ecom_validate_captcha_if_required')) {
        $captcha_check = dms_ecom_validate_captcha_if_required($params['captcha_token'] ?? '', $ip);
        if (is_wp_error($captcha_check)) return $captcha_check;
    }
    
    if (empty($params['password']) || empty($params['email'])) {
        return new WP_Error('invalid_params', 'يرجى إدخال اسم المستخدم وكلمة المرور والبريد الإلكتروني.', array('status' => 400));
    }
    
    $requested_username = sanitize_user($params['username'] ?? '', true);
    $email = sanitize_email($params['email']);
    $password = $params['password'];
    $first_name = sanitize_text_field($params['first_name'] ?? '');
    $last_name = sanitize_text_field($params['last_name'] ?? '');
    $company_name = sanitize_text_field($params['company'] ?? ($params['company_name'] ?? ''));
    $display_name = sanitize_text_field($params['display_name'] ?? ($params['name'] ?? ($first_name ?: $company_name)));
    $username = $requested_username;

    if ($username === '') {
        $username_seed = $display_name !== '' ? $display_name : ($company_name !== '' ? $company_name : 'user');
        $username = sanitize_user($username_seed, true);
    }
    if ($username === '') {
        $username = 'user';
    }

    if (strlen($username) < 3) {
        $username = str_pad($username, 3, '1');
    }

    if (!is_email($email)) {
        return new WP_Error('invalid_email', 'صيغة البريد الإلكتروني غير صحيحة.', array('status' => 400));
    }
    if (strlen($password) < 6) {
        return new WP_Error('weak_password', 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.', array('status' => 400));
    }

    if (username_exists($username)) {
        $suggested_usernames = array();
        $base = preg_replace('/\d+$/', '', $username);
        $base = sanitize_user($base, true);
        if ($base === '') {
            $base = 'user';
        }
        for ($i = 1; $i <= 50 && count($suggested_usernames) < 3; $i++) {
            $candidate = sanitize_user($base . $i, true);
            if ($candidate !== '' && !username_exists($candidate)) {
                $suggested_usernames[] = $candidate;
            }
        }
        return new WP_Error(
            'username_exists',
            'اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.',
            array(
                'status' => 400,
                'requested_username' => $username,
                'suggested_usernames' => $suggested_usernames,
            )
        );
    }
    if (email_exists($email)) {
        return new WP_Error('email_exists', 'البريد الإلكتروني مستخدم بالفعل.', array('status' => 400));
    }

    $user_id = wp_create_user($username, $password, $email);
    if (is_wp_error($user_id)) return new WP_Error('registration_failed', 'تعذر إكمال إنشاء الحساب حالياً.', array('status' => 500));

    if ($display_name === '') {
        $display_name = $first_name !== '' ? $first_name : $username;
    }

    wp_update_user(array('ID' => $user_id, 'first_name' => $first_name, 'last_name' => $last_name, 'display_name' => $display_name));
    
    update_user_meta($user_id, 'dms_user_group', 'default');
    update_user_meta($user_id, 'dms_user_currency', 'syp');
    $default_status = function_exists('dms_get_default_account_status') ? dms_get_default_account_status() : 'جديد';
    update_user_meta($user_id, 'dms_account_status', $default_status);
    
    $meta = (isset($params['meta']) && is_array($params['meta'])) ? $params['meta'] : array();
    $extra = array(
        'phone' => sanitize_text_field($params['phone'] ?? ($params['billing_phone'] ?? ($meta['phone'] ?? ''))),
        'company' => sanitize_text_field($params['company'] ?? ($params['billing_company'] ?? ($meta['company'] ?? ''))),
        'whatsapp' => sanitize_text_field($params['whatsapp'] ?? ($meta['whatsapp'] ?? '')),
        'whatsapp_country_code' => sanitize_text_field($params['whatsapp_country_code'] ?? ($meta['whatsapp_country_code'] ?? '')),
        'governorate' => sanitize_text_field($params['governorate'] ?? ($params['province'] ?? ($params['billing_state'] ?? ($meta['governorate'] ?? ($meta['province'] ?? ''))))),
        'address' => sanitize_text_field($params['address'] ?? ($params['billing_address_1'] ?? ($meta['address'] ?? ''))),
    );
    
    if ($extra['phone']) update_user_meta($user_id, 'phone', $extra['phone']);
    if ($extra['company']) update_user_meta($user_id, 'company', $extra['company']);
    if ($extra['governorate']) update_user_meta($user_id, 'province', $extra['governorate']);
    if ($extra['address']) update_user_meta($user_id, 'address', $extra['address']);

    if (function_exists('dms_sync_member_record')) {
        dms_sync_member_record($user_id, $extra);
    }

    $user = new WP_User($user_id);
    $user->set_role('customer');
    
    if (function_exists('dms_ecom_notify_admin_new_user')) {
        dms_ecom_notify_admin_new_user($user_id, $extra);
    }
    
    return array(
        'id' => $user_id,
        'username' => $username,
        'display_name' => $display_name,
        'email' => $email,
        'message' => 'تم إنشاء الحساب بنجاح'
    );
}

/**
 * Job Application submission.
 */
function dms_submit_job_application($request) {
    $params = $request->get_json_params();
    $ip = dms_ecom_get_client_ip();
    
    if (function_exists('dms_ecom_rate_limit')) {
        $rate_check = dms_ecom_rate_limit('job_application', $ip);
        if (is_wp_error($rate_check)) return $rate_check;
    }
    
    if (function_exists('dms_ecom_validate_captcha_if_required')) {
        $captcha_check = dms_ecom_validate_captcha_if_required($params['captcha_token'] ?? '', $ip);
        if (is_wp_error($captcha_check)) return $captcha_check;
    }
    
    $required_fields = ['full_name', 'email', 'phone', 'position'];
    foreach ($required_fields as $field) {
        if (empty($params[$field])) return new WP_Error('invalid_params', sprintf('Field %s is required.', $field), array('status' => 400));
    }
    
    if (!is_email($params['email'])) return new WP_Error('invalid_email', 'Email address is invalid.', array('status' => 400));
    
    $to = get_option('admin_email');
    $subject = 'New job application from mobile app';
    $message = sprintf(
        "Name: %s\nEmail: %s\nPhone: %s\nPosition: %s\nExperience: %s\nMessage: %s",
        sanitize_text_field($params['full_name']),
        sanitize_email($params['email']),
        sanitize_text_field($params['phone']),
        sanitize_text_field($params['position']),
        sanitize_text_field($params['experience'] ?? ''),
        sanitize_textarea_field($params['message'] ?? '')
    );
    
    $sent = wp_mail($to, $subject, $message);
    if (!$sent) return new WP_Error('email_failed', 'Unable to send job application email.', array('status' => 500));
    
    return array('success' => true, 'message' => 'Job application submitted successfully');
}
