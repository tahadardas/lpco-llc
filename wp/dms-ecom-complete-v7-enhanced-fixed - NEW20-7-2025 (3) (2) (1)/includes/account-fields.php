<?php
// ✅ عرض نفس الحقول الموجودة في صفحة التسجيل داخل "حسابي"
add_action('woocommerce_edit_account_form', function() {
    $user_id = get_current_user_id();
    $company_name = get_user_meta($user_id, 'account_company_name', true);
    $whatsapp = get_user_meta($user_id, 'account_whatsapp', true);
    ?>
    <fieldset>
        <legend>معلومات إضافية</legend>

        <p class="form-row form-row-wide">
            <label for="account_company_name">الاسم التجاري <span class="required">*</span></label>
            <input type="text" class="input-text" name="account_company_name" id="account_company_name" value="<?php echo esc_attr($company_name); ?>" />
            <small>يرجى كتابة الاسم التجاري بشكل واضح.</small>
        </p>

        <p class="form-row form-row-wide">
            <label for="account_whatsapp">رقم الواتساب <span class="required">*</span></label>
            <input type="text" class="input-text" name="account_whatsapp" id="account_whatsapp" value="<?php echo esc_attr($whatsapp); ?>" />
            <small>يرجى كتابة رقم الواتساب الفعّال للتواصل.</small>
        </p>
    </fieldset>
    <?php
});

// ✅ حفظ البيانات عند الضغط على زر حفظ الحساب
add_action('woocommerce_save_account_details', function($user_id) {
    if (isset($_POST['account_company_name'])) {
        update_user_meta($user_id, 'account_company_name', sanitize_text_field($_POST['account_company_name']));
    }
    if (isset($_POST['account_whatsapp'])) {
        update_user_meta($user_id, 'account_whatsapp', sanitize_text_field($_POST['account_whatsapp']));
    }
});

// ✅ عرض رسالة تنبيه إن لم تكتمل الحقول في حسابي
add_action('woocommerce_before_my_account', function() {
    if (!is_user_logged_in()) return;
    $user_id = get_current_user_id();

    $fields = [
        'account_company_name',
        'account_whatsapp',
    ];

    $missing = [];
    foreach ($fields as $field) {
        $value = get_user_meta($user_id, $field, true);
        if (empty($value)) {
            $missing[] = $field;
        }
    }

    if (!empty($missing)) {
        echo '<div class="woocommerce-message" style="border-left: 4px solid red; background: #fff0f0; color: #900; padding: 10px; margin-bottom: 20px;">';
        echo '🚨 يرجى <strong>استكمال بيانات حسابك</strong> لإتمام عملية استخدام الموقع بشكل كامل.';
        echo ' <a href="' . esc_url(wc_get_account_endpoint_url('edit-account')) . '">اضغط هنا للتعديل</a>';
        echo '</div>';
    }
});

// ✅ حفظ الحقول عند إنشاء حساب جديد (تم نقل هذا الإجراء إلى registration-fields.php لتجنب التكرار)
// هنا لا نحتاج لإعادة تعريف woocommerce_created_customer لأنه يتم التعامل معه في registration-fields.php
// add_action('woocommerce_created_customer', function($customer_id) {
//     if (isset($_POST['account_company_name'])) {
//         update_user_meta($customer_id, 'account_company_name', sanitize_text_field($_POST['account_company_name']));
//     }
//     if (isset($_POST['account_whatsapp'])) {
//         update_user_meta($customer_id, 'account_whatsapp', sanitize_text_field($_POST['account_whatsapp']));
//     }
// });