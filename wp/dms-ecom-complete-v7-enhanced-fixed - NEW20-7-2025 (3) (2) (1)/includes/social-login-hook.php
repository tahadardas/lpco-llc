<?php
// ✅ تعيين الدور الافتراضي لمستخدم السوشيال إلى "زبون"
add_action('heateor_sss_after_user_register', function($user_id) {
    $user = new WP_User($user_id);
    $user->set_role('customer');
}, 10);

// ✅ التحقق من اكتمال البيانات وإجبار المستخدم على إكمالها بعد تسجيل الدخول
add_action('template_redirect', function() {
    if (is_user_logged_in() && is_account_page() === false && !is_admin()) {
        $user_id = get_current_user_id();
        $company_name = get_user_meta($user_id, 'account_company_name', true);
        $phone = get_user_meta($user_id, 'account_phone', true);
        $whatsapp = get_user_meta($user_id, 'account_whatsapp', true);
        $account_type = get_user_meta($user_id, 'account_type', true);

        if (empty($company_name) || empty($phone) || empty($whatsapp) || empty($account_type)) {
            wc_add_notice('يرجى استكمال بيانات حسابك قبل المتابعة.', 'error');
            wp_redirect(get_permalink(get_option('woocommerce_myaccount_page_id')));
            exit;
        }
    }
});
