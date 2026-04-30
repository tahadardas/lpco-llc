<?php
if (!function_exists('dms_get_syrian_governorates')) {
function dms_get_syrian_governorates() {
    return [
        'دمشق',
        'ريف دمشق',
        'حلب',
        'حمص',
        'حماة',
        'اللاذقية',
        'طرطوس',
        'دير الزور',
        'الرقة',
        'الحسكة',
        'درعا',
        'السويداء',
        'القنيطرة',
        'إدلب'
    ];
}
}

// ✅ عرض الحقول في صفحة تسجيل ووكومرس
add_action('woocommerce_register_form_start', function() {
    $governorates = dms_get_syrian_governorates();
    ?>
    <p class="form-row form-row-wide">
        <label for="account_company_name">الاسم التجاري <span class="required">*</span></label>
        <input type="text" class="input-text" name="account_company_name" id="account_company_name" value="<?php echo isset($_POST['account_company_name']) ? esc_attr($_POST['account_company_name']) : ''; ?>" required />
        <small>يرجى كتابة الاسم التجاري بشكل واضح.</small>
    </p>

    <p class="form-row form-row-wide">
        <label for="account_governorate">المحافظة <span class="required">*</span></label>
        <select name="account_governorate" id="account_governorate" class="input-text" required>
            <option value="">-- اختر محافظتك --</option>
            <?php
            foreach ($governorates as $gov) {
                echo '<option value="' . esc_attr($gov) . '"' . selected(isset($_POST['account_governorate']) ? $_POST['account_governorate'] : '', $gov, false) . '>' . esc_html($gov) . '</option>';
            }
            ?>
        </select>
        <small>يرجى اختيار محافظتك.</small>
    </p>

    <p class="form-row form-row-first" style="width: 25%; float: right; margin-right: 0%;">
        <label for="account_whatsapp_country_code">رمز الدولة <span class="required">*</span></label>
        <input type="text" class="input-text" name="account_whatsapp_country_code" id="account_whatsapp_country_code" value="<?php echo isset($_POST['account_whatsapp_country_code']) ? esc_attr($_POST['account_whatsapp_country_code']) : '+'; ?>" placeholder="+XXX" required />
        <small>مثال: +963</small>
    </p>
    <p class="form-row form-row-last" style="width: 73%; float: left; margin-left: 2%;">
        <label for="account_whatsapp">رقم الواتساب <span class="required">*</span></label>
        <input type="text" class="input-text" name="account_whatsapp" id="account_whatsapp" value="<?php echo isset($_POST['account_whatsapp']) ? esc_attr($_POST['account_whatsapp']) : ''; ?>" required />
        <small>يرجى كتابة رقم الواتساب الفعّال للتواصل.</small>
    </p>
    <div class="clear"></div>
    <?php
});

// ✅ التحقق من صحة الحقول قبل التسجيل (الاسم التجاري، رقم الواتساب، رمز الدولة، المحافظة)
add_action('woocommerce_register_post', function($username, $email, $validation_errors) {
    if (empty($_POST['account_company_name'])) {
        $validation_errors->add('account_company_name_error', 'الرجاء إدخال الاسم التجاري.');
    }
    if (empty($_POST['account_whatsapp'])) {
        $validation_errors->add('account_whatsapp_error', 'الرجاء إدخال رقم الواتساب.');
    }
    $country_code = isset($_POST['account_whatsapp_country_code']) ? sanitize_text_field($_POST['account_whatsapp_country_code']) : '';
    if (empty($country_code)) {
        $validation_errors->add('account_whatsapp_country_code_error', 'الرجاء إدخال رمز الدولة للواتساب.');
    } elseif (!preg_match('/^\+\d+$/', $country_code)) {
        $validation_errors->add('account_whatsapp_country_code_format_error', 'صيغة رمز الدولة غير صحيحة. يجب أن تبدأ بـ "+" وتتبعها أرقام فقط (مثال: +963).');
    }
    if (empty($_POST['account_governorate'])) {
        $validation_errors->add('account_governorate_error', 'الرجاء اختيار المحافظة.');
    }
    return $validation_errors;
}, 10, 3);

// Enforce at least "medium" password strength for registration.
add_filter('woocommerce_min_password_strength', function ($strength) {
    $current = is_numeric($strength) ? intval($strength) : 2;
    return max(2, $current);
});

// ✅ حفظ القيم في بيانات المستخدم
add_action('woocommerce_created_customer', function($customer_id) {
    if (!empty($_POST['account_company_name'])) {
        update_user_meta($customer_id, 'account_company_name', sanitize_text_field($_POST['account_company_name']));
    }
    if (!empty($_POST['account_whatsapp'])) {
        update_user_meta($customer_id, 'account_whatsapp', sanitize_text_field($_POST['account_whatsapp']));
    }
    if (!empty($_POST['account_whatsapp_country_code'])) {
        update_user_meta($customer_id, 'account_whatsapp_country_code', sanitize_text_field($_POST['account_whatsapp_country_code']));
    }
    if (!empty($_POST['account_governorate'])) {
        update_user_meta($customer_id, 'account_governorate', sanitize_text_field($_POST['account_governorate']));
    }
    // تعيين حالة "جديد" للعميل الجديد
    update_user_meta($customer_id, 'dms_account_status', 'جديد');
});

// ✅ تجاوز التحقق من كلمة المرور عند تسجيل الدخول (للسماح بكلمات المرور الضعيفة)
add_filter('authenticate', function($user, $username, $password) {
    // إذا كان المستخدم قد تم مصادقته بالفعل أو كان هناك خطأ، أعد المستخدم/الخطأ
    if (is_a($user, 'WP_User') || is_wp_error($user)) {
        return $user;
    }

    // إذا لم يتم توفير اسم مستخدم أو كلمة مرور، فلا تفعل شيئاً
    if (empty($username) || empty($password)) {
        return $user;
    }

    // محاولة العثور على المستخدم
    $user_obj = get_user_by('login', $username);
    if (!$user_obj) {
        $user_obj = get_user_by('email', $username);
    }

    // إذا تم العثور على المستخدم وتطابقت كلمة المرور، قم بتسجيل الدخول
    if ($user_obj && wp_check_password($password, $user_obj->user_pass, $user_obj->ID)) {
        return $user_obj; // مصادقة ناجحة
    }

    // بخلاف ذلك، أعد الخطأ الافتراضي
    return new WP_Error('invalid_username_or_password', '<strong>خطأ:</strong> اسم المستخدم أو كلمة المرور الذي أدخلته غير صحيح.');
}, 20, 3); // قيمة الأولوية 20 لتعمل بعد فلاتر authenticate الأخرى
