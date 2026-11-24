<?php
/**
 * LPCO LLC Commerce - Direct Customer Password Management
 * إدارة وتعيين كلمات المرور للزبائن والتجار مباشرة من لوحة التحكم
 *
 * @package LPCO_Commerce
 * @version 7.1.0
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * دالة مركزية لتنفيذ تعيين كلمة المرور لحساب زبون مع كافة الضوابط الأمنية
 *
 * @param int    $target_user_id معرف المستخدم المستهدف
 * @param string $new_password   كلمة المرور الجديدة
 * @param string $source         المصدر (ajax, rest, admin)
 * @return true|WP_Error
 */
function dms_execute_password_set($target_user_id, $new_password, $source = 'ajax') {
    $target_user_id = absint($target_user_id);
    if ($target_user_id <= 0) {
        return new WP_Error('invalid_user_id', __('معرف المستخدم غير صالح.', 'dms-ecom'), array('status' => 400));
    }

    $target_user = get_userdata($target_user_id);
    if (!$target_user) {
        return new WP_Error('user_not_found', __('المستخدم المستهدف غير موجود.', 'dms-ecom'), array('status' => 404));
    }

    // التحقق من صلاحيات المستخدم الحالي لتعديل هذا المستخدم المستهدف
    if (!current_user_can('edit_user', $target_user_id)) {
        return new WP_Error('forbidden_edit', __('ليس لديك صلاحية لتعديل بيانات هذا المستخدم.', 'dms-ecom'), array('status' => 403));
    }

    // التحقق من دور الحساب المستهدف: منع استهداف المديرين أو المشرفين من شاشة إدارة الزبائن
    $disallowed_roles = array('administrator', 'shop_manager', 'editor');
    $user_roles = (array) $target_user->roles;
    $has_privileged_role = (bool) array_intersect($disallowed_roles, $user_roles);

    if ($has_privileged_role || user_can($target_user_id, 'manage_options')) {
        return new WP_Error(
            'forbidden_target_role',
            __('لا يمكن تعيين كلمة مرور لحسابات المديرين أو الموظفين من واجهة الزبائن لأسباب أمنية.', 'dms-ecom'),
            array('status' => 403)
        );
    }

    // التحقق من كلمة المرور
    $password_str = trim((string) $new_password);
    if ($password_str === '') {
        return new WP_Error('empty_password', __('كلمة المرور لا يمكن أن تكون فارغة.', 'dms-ecom'), array('status' => 400));
    }
    if (strlen($password_str) < 6) {
        return new WP_Error('short_password', __('كلمة المرور يجب أن تتكون من 6 أحرف على الأقل.', 'dms-ecom'), array('status' => 400));
    }

    // منع إرسال أي بريد إلكتروني تلقائي من ووردبريس أثناء عملية التعيين اليدوي
    add_filter('send_password_change_email', '__return_false', 9999);
    add_filter('password_change_email', '__return_empty_array', 9999);

    // استخدام نظام ووردبريس الأصلي لتعيين كلمة المرور
    // wp_set_password تقوم بتشفير كلمة المرور عبر wp_hash_password، وتحديث user_pass
    // وتستدعي تلقائياً wp_destroy_all_sessions لإبطال جلسات ووردبريس النشطة
    wp_set_password($password_str, $target_user_id);

    // التحقق الفعلي من نجاح تحديث كلمة المرور في قاعدة البيانات
    clean_user_cache($target_user_id);
    $refreshed_user = get_userdata($target_user_id);
    if (!$refreshed_user || !wp_check_password($password_str, $refreshed_user->user_pass, $target_user_id)) {
        return new WP_Error('save_verification_failed', __('فشل التحقق من حفظ كلمة المرور في قاعدة البيانات.', 'dms-ecom'), array('status' => 500));
    }

    // إبطال جميع جلسات JWT القديمة عبر تسجيل ختم زمني (Not-Before Timestamp)
    $revocation_time = time();
    update_user_meta($target_user_id, 'dms_jwt_not_before', $revocation_time);

    // إبطال وإزالة أي رموز أجهزة (Device Tokens) مسجلة للحساب لضمان تسجيل خروج كامل
    global $wpdb;
    $tokens_table = $wpdb->prefix . 'dms_device_tokens';
    if ($wpdb->get_var($wpdb->prepare("SHOW TABLES LIKE %s", $tokens_table)) === $tokens_table) {
        $wpdb->delete($tokens_table, array('user_id' => $target_user_id));
    }

    // تسجيل العملية في Audit Log دون تسجيل كلمة المرور إطلاقاً
    $admin_id = get_current_user_id();
    $admin_user = wp_get_current_user();
    $admin_login = $admin_user ? $admin_user->user_login : ('ID:' . $admin_id);

    update_user_meta($target_user_id, 'dms_last_password_reset_time', $revocation_time);
    update_user_meta($target_user_id, 'dms_last_password_reset_by', $admin_id);

    if (function_exists('dms_ecom_log')) {
        dms_ecom_log(
            sprintf(
                'Password directly reset for customer ID %d (username: %s) by admin ID %d (%s) via %s.',
                $target_user_id,
                $target_user->user_login,
                $admin_id,
                $admin_login,
                $source
            ),
            'info'
        );
    }

    return true;
}

/**
 * معالج AJAX لتوليد كلمة مرور عشوائية من الخادم
 */
add_action('wp_ajax_dms_admin_generate_password', 'dms_ajax_admin_generate_password');
function dms_ajax_admin_generate_password() {
    nocache_headers();

    // التحقق من Nonce
    check_ajax_referer('dms_admin_password_nonce', 'nonce');

    // التحقق من صلاحيات المدير أو الموظف المخول
    if (!current_user_can('manage_options') && !current_user_can('edit_users')) {
        wp_send_json_error(array('message' => __('ليس لديك صلاحية لتوليد كلمات المرور.', 'dms-ecom')), 403);
    }

    $length = isset($_POST['length']) ? max(12, min(64, intval($_POST['length']))) : 16;
    // توليد كلمة مرور قوية باستخدام wp_generate_password الافتراضية بـ 16 حرفاً
    $password = wp_generate_password($length, true, true);

    wp_send_json_success(array(
        'password' => $password,
        'length'   => strlen($password),
    ));
}

/**
 * معالج AJAX لحفظ وتعيين كلمة المرور للزبون
 */
add_action('wp_ajax_dms_admin_set_customer_password', 'dms_ajax_admin_set_customer_password');
function dms_ajax_admin_set_customer_password() {
    nocache_headers();

    // التحقق من Nonce
    check_ajax_referer('dms_admin_password_nonce', 'nonce');

    // التحقق من الصلاحيات الإدارية
    if (!current_user_can('manage_options') && !current_user_can('edit_users')) {
        wp_send_json_error(array('message' => __('ليس لديك صلاحية لإدارة كلمات مرور الزبائن.', 'dms-ecom')), 403);
    }

    $user_id = isset($_POST['user_id']) ? absint($_POST['user_id']) : 0;
    $password = isset($_POST['password']) ? (string) $_POST['password'] : '';

    $result = dms_execute_password_set($user_id, $password, 'ajax');

    if (is_wp_error($result)) {
        $status = $result->get_error_data() && isset($result->get_error_data()['status']) 
            ? (int) $result->get_error_data()['status'] 
            : 400;
        wp_send_json_error(array('message' => $result->get_error_message()), $status);
    }

    $user = get_userdata($user_id);
    wp_send_json_success(array(
        'message'      => __('تم تعيين كلمة المرور بنجاح وإبطال جميع الجلسات القديمة.', 'dms-ecom'),
        'user_id'      => $user_id,
        'user_login'   => $user ? $user->user_login : '',
        'display_name' => $user ? $user->display_name : '',
    ));
}

/**
 * إضافة خيار "تعيين كلمة المرور" في قائمة إجراءات المستخدم في صفحة Users القياسية
 */
add_filter('user_row_actions', function($actions, $user) {
    if (current_user_can('edit_user', $user->ID) && !user_can($user->ID, 'manage_options')) {
        $company_name = get_user_meta($user->ID, 'account_company_name', true);
        $whatsapp = get_user_meta($user->ID, 'account_whatsapp', true);
        $whatsapp_code = get_user_meta($user->ID, 'account_whatsapp_country_code', true);
        $phone = trim($whatsapp_code . ' ' . $whatsapp);

        $actions['dms_direct_password'] = sprintf(
            '<a href="#" class="dms-open-pwd-modal-btn" data-userid="%d" data-name="%s" data-company="%s" data-username="%s" data-phone="%s" style="color:#d63638;font-weight:600;">🔑 %s</a>',
            esc_attr($user->ID),
            esc_attr($user->display_name),
            esc_attr($company_name),
            esc_attr($user->user_login),
            esc_attr($phone),
            esc_html__('تعيين كلمة المرور', 'dms-ecom')
        );
    }
    return $actions;
}, 10, 2);

/**
 * فحص إبطال JWT Token عند المصادقة
 */
add_filter('jwt_auth_valid_token_response', function($response, $user, $token, $payload) {
    if ($user && isset($user->ID)) {
        $not_before = (int) get_user_meta($user->ID, 'dms_jwt_not_before', true);
        if ($not_before > 0) {
            $iat = is_array($payload) ? ($payload['iat'] ?? 0) : (isset($payload->iat) ? $payload->iat : 0);
            if ($iat && intval($iat) < $not_before) {
                return new WP_Error(
                    'jwt_token_revoked',
                    __('تم تغيير كلمة المرور، يرجى تسجيل الدخول مجدداً.', 'dms-ecom'),
                    array('status' => 401)
                );
            }
        }
    }
    return $response;
}, 10, 4);

/**
 * طباعة نافذة Modal المخصصة مع التنسيقات والأكواد البرمجية في تذييل صفحات لوحة التحكم
 */
add_action('admin_footer', 'dms_render_password_modal_html');
function dms_render_password_modal_html() {
    $screen = get_current_screen();
    if (!$screen) {
        return;
    }

    // العرض فقط في صفحات إدارة الأعضاء أو المستخدمين
    $allowed_screens = array('toplevel_page_dms_members', 'users', 'dms-app-dashboard_page_dms-app-dashboard-users');
    $is_allowed = in_array($screen->id, $allowed_screens, true) || strpos($screen->id, 'dms_members') !== false;

    if (!$is_allowed && !current_user_can('manage_options') && !current_user_can('edit_users')) {
        return;
    }

    $nonce = wp_create_nonce('dms_admin_password_nonce');
    ?>
    <!-- DMS Customer Password Management Modal -->
    <div id="dms-pwd-modal-backdrop" style="display:none;"></div>
    <div id="dms-pwd-modal" style="display:none;" role="dialog" aria-modal="true" aria-labelledby="dms-pwd-modal-title">
        <div class="dms-pwd-modal-header">
            <h3 id="dms-pwd-modal-title">
                <span class="dashicons dashicons-admin-network" style="font-size:22px;line-height:1.2;margin-left:6px;color:#2271b1;"></span>
                تعيين كلمة مرور جديدة للزبون
            </h3>
            <button type="button" class="dms-pwd-close-btn" id="dms-pwd-close-x" aria-label="إغلاق">&times;</button>
        </div>

        <div class="dms-pwd-modal-body">
            <!-- كروت معلومات الزبون والحساب -->
            <div class="dms-pwd-info-grid">
                <div class="dms-pwd-info-item">
                    <span class="dms-pwd-info-label">اسم الزبون:</span>
                    <strong id="dms-pwd-target-name" class="dms-pwd-info-value">-</strong>
                </div>
                <div class="dms-pwd-info-item">
                    <span class="dms-pwd-info-label">المحل / الشركة:</span>
                    <strong id="dms-pwd-target-company" class="dms-pwd-info-value">-</strong>
                </div>
                <div class="dms-pwd-info-item">
                    <span class="dms-pwd-info-label">اسم المستخدم للدخول:</span>
                    <code id="dms-pwd-target-username" class="dms-pwd-code-badge">-</code>
                </div>
                <div class="dms-pwd-info-item">
                    <span class="dms-pwd-info-label">رقم الهاتف:</span>
                    <strong id="dms-pwd-target-phone" class="dms-pwd-info-value" dir="ltr">-</strong>
                </div>
            </div>

            <div class="dms-pwd-notice-bar">
                ℹ️ لن يتم تغيير كلمة المرور الحالية حتى تضغط صراحةً على <strong>"حفظ وتعيين كلمة المرور"</strong> وتكتمل العملية بنجاح.
            </div>

            <!-- حقل كلمة المرور والأزرار المساعدة -->
            <div class="dms-pwd-field-group">
                <label for="dms-pwd-input">كلمة المرور الجديدة:</label>
                <div class="dms-pwd-input-wrap">
                    <input type="password" id="dms-pwd-input" autocomplete="new-password" spellcheck="false" placeholder="اضغط على توليد أو اكتب كلمة مرور جديدة..." />
                    <button type="button" class="button button-secondary dms-pwd-action-btn" id="dms-pwd-toggle-vis" title="إظهار / إخفاء كلمة المرور">
                        👁️
                    </button>
                    <button type="button" class="button button-secondary dms-pwd-action-btn" id="dms-pwd-copy-pwd" title="نسخ كلمة المرور فقط">
                        📋 نسخ
                    </button>
                    <button type="button" class="button button-secondary dms-pwd-gen-btn" id="dms-pwd-btn-generate">
                        ⚡ توليد عشوائي
                    </button>
                </div>
            </div>

            <!-- رسائل الحالة والأخطاء -->
            <div id="dms-pwd-status-msg" style="display:none;"></div>

            <!-- منطقة نسخ بيانات الدخول الكاملة بعد النجاح -->
            <div id="dms-pwd-success-section" style="display:none;">
                <div class="dms-pwd-success-card">
                    <div style="font-weight:bold;margin-bottom:8px;color:#155724;">
                        ✓ تم تحديث كلمة المرور للحساب بنجاح وإبطال جميع الجلسات القديمة!
                    </div>
                    <button type="button" class="button button-primary dms-pwd-copy-all-btn" id="dms-pwd-btn-copy-all">
                        📋 نسخ بيانات الدخول كاملة للزبون
                    </button>
                    <div id="dms-pwd-copy-feedback" style="display:none;margin-top:6px;font-size:12px;color:#0a58ca;font-weight:600;"></div>
                </div>
            </div>
        </div>

        <div class="dms-pwd-modal-footer">
            <button type="button" class="button button-primary button-large" id="dms-pwd-btn-save">
                💾 حفظ وتعيين كلمة المرور
            </button>
            <button type="button" class="button button-secondary button-large" id="dms-pwd-btn-cancel">
                إلغاء
            </button>
            <span id="dms-pwd-spinner" class="spinner" style="float:none;margin:0 10px;vertical-align:middle;"></span>
        </div>
    </div>

    <style>
        #dms-pwd-modal-backdrop {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.65);
            z-index: 100050;
            backdrop-filter: blur(2px);
        }
        #dms-pwd-modal {
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            width: 90%;
            max-width: 580px;
            background: #ffffff;
            border-radius: 8px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.3);
            z-index: 100051;
            direction: rtl;
            text-align: right;
            box-sizing: border-box;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
            overflow: hidden;
            animation: dmsPwdFadeIn 0.2s ease-out;
        }
        @keyframes dmsPwdFadeIn {
            from { opacity: 0; transform: translate(-50%, -46%); }
            to { opacity: 1; transform: translate(-50%, -50%); }
        }
        .dms-pwd-modal-header {
            padding: 16px 20px;
            background: #f0f6fc;
            border-bottom: 1px solid #d0d7de;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        .dms-pwd-modal-header h3 {
            margin: 0;
            font-size: 17px;
            color: #1d2327;
            display: flex;
            align-items: center;
        }
        .dms-pwd-close-btn {
            background: none;
            border: none;
            font-size: 24px;
            line-height: 1;
            color: #646970;
            cursor: pointer;
            padding: 0 4px;
        }
        .dms-pwd-close-btn:hover {
            color: #d63638;
        }
        .dms-pwd-modal-body {
            padding: 20px;
            max-height: calc(85vh - 120px);
            overflow-y: auto;
        }
        .dms-pwd-info-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            background: #f6f7f7;
            padding: 12px;
            border-radius: 6px;
            border: 1px solid #dcdcde;
            margin-bottom: 14px;
        }
        .dms-pwd-info-item {
            display: flex;
            flex-direction: column;
            gap: 2px;
            font-size: 13px;
        }
        .dms-pwd-info-label {
            color: #646970;
            font-size: 12px;
        }
        .dms-pwd-info-value {
            color: #1d2327;
            word-break: break-word;
        }
        .dms-pwd-code-badge {
            background: #e7e9eb;
            color: #0c5460;
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 13px;
            display: inline-block;
            width: fit-content;
        }
        .dms-pwd-notice-bar {
            background: #fff8e5;
            border-right: 4px solid #dba617;
            padding: 8px 12px;
            font-size: 12px;
            color: #614200;
            margin-bottom: 16px;
            border-radius: 2px;
        }
        .dms-pwd-field-group {
            margin-bottom: 16px;
        }
        .dms-pwd-field-group label {
            display: block;
            font-weight: 600;
            margin-bottom: 6px;
            color: #1d2327;
        }
        .dms-pwd-input-wrap {
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .dms-pwd-input-wrap input {
            flex: 1;
            padding: 7px 10px;
            font-family: monospace;
            font-size: 15px;
            direction: ltr;
            text-align: left;
            border: 1px solid #8c8f94;
            border-radius: 4px;
        }
        .dms-pwd-input-wrap input:focus {
            border-color: #2271b1;
            box-shadow: 0 0 0 1px #2271b1;
            outline: 2px solid transparent;
        }
        .dms-pwd-action-btn {
            padding: 0 10px !important;
            height: 36px !important;
            line-height: 34px !important;
        }
        .dms-pwd-gen-btn {
            font-weight: 600 !important;
            color: #2271b1 !important;
            border-color: #2271b1 !important;
            white-space: nowrap;
        }
        .dms-pwd-gen-btn:hover {
            background: #f0f6fc !important;
        }
        .dms-pwd-success-card {
            background: #d4edda;
            border: 1px solid #c3e6cb;
            border-radius: 6px;
            padding: 14px;
            text-align: center;
            margin-top: 14px;
        }
        .dms-pwd-copy-all-btn {
            background: #0073aa !important;
            border-color: #0073aa !important;
            color: #ffffff !important;
            font-size: 14px !important;
            font-weight: bold !important;
            padding: 8px 16px !important;
            height: auto !important;
            line-height: 1.4 !important;
            cursor: pointer;
            width: 100%;
        }
        .dms-pwd-copy-all-btn:hover {
            background: #005177 !important;
        }
        .dms-pwd-modal-footer {
            padding: 14px 20px;
            background: #f6f7f7;
            border-top: 1px solid #dcdcde;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .dms-pwd-msg-error {
            background: #f8d7da;
            border-right: 4px solid #d63638;
            color: #721c24;
            padding: 10px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 12px;
        }
        .dms-pwd-msg-success {
            background: #d4edda;
            border-right: 4px solid #00a32a;
            color: #155724;
            padding: 10px;
            border-radius: 4px;
            font-size: 13px;
            margin-bottom: 12px;
        }
    </style>

    <script type="text/javascript">
    (function($) {
        'use strict';

        const dmsPwdState = {
            userId: 0,
            name: '',
            company: '',
            username: '',
            phone: '',
            nonce: '<?php echo esc_js($nonce); ?>',
            savedPassword: '',
            isSaving: false
        };

        function showMessage(text, isError = false) {
            const $box = $('#dms-pwd-status-msg');
            $box.removeClass('dms-pwd-msg-error dms-pwd-msg-success');
            $box.addClass(isError ? 'dms-pwd-msg-error' : 'dms-pwd-msg-success');
            $box.html(text).show();
        }

        function clearMessage() {
            $('#dms-pwd-status-msg').hide().empty();
        }

        function openModal(data) {
            dmsPwdState.userId = parseInt(data.userid, 10) || 0;
            dmsPwdState.name = data.name || '-';
            dmsPwdState.company = data.company || '-';
            dmsPwdState.username = data.username || '-';
            dmsPwdState.phone = data.phone || '-';
            dmsPwdState.savedPassword = '';
            dmsPwdState.isSaving = false;

            $('#dms-pwd-target-name').text(dmsPwdState.name);
            $('#dms-pwd-target-company').text(dmsPwdState.company);
            $('#dms-pwd-target-username').text(dmsPwdState.username);
            $('#dms-pwd-target-phone').text(dmsPwdState.phone);

            $('#dms-pwd-input').val('').attr('type', 'password');
            $('#dms-pwd-toggle-vis').text('👁️');
            $('#dms-pwd-success-section').hide();
            $('#dms-pwd-copy-feedback').hide().empty();
            clearMessage();

            $('#dms-pwd-btn-save').prop('disabled', false).text('💾 حفظ وتعيين كلمة المرور');
            $('#dms-pwd-spinner').removeClass('is-active');

            $('#dms-pwd-modal-backdrop').fadeIn(150);
            $('#dms-pwd-modal').fadeIn(150);

            // توليد كلمة مرور أولية تلقائياً لتسهيل الاستخدام مع بقائها غير محفوظة
            generatePassword();
        }

        function closeModal() {
            // مسح كلمة المرور فوراً من الـ DOM لمنع استرجاعها
            $('#dms-pwd-input').val('');
            dmsPwdState.savedPassword = '';
            dmsPwdState.userId = 0;
            $('#dms-pwd-modal-backdrop').fadeOut(120);
            $('#dms-pwd-modal').fadeOut(120);
        }

        function generatePassword() {
            clearMessage();
            const $genBtn = $('#dms-pwd-btn-generate');
            $genBtn.prop('disabled', true).text('⏳...');

            $.ajax({
                url: ajaxurl,
                type: 'POST',
                cache: false,
                data: {
                    action: 'dms_admin_generate_password',
                    nonce: dmsPwdState.nonce,
                    length: 16
                },
                success: function(resp) {
                    $genBtn.prop('disabled', false).text('⚡ توليد عشوائي');
                    if (resp && resp.success && resp.data && resp.data.password) {
                        $('#dms-pwd-input').val(resp.data.password).attr('type', 'text');
                        $('#dms-pwd-toggle-vis').text('🙈');
                    } else {
                        showMessage('تعذر توليد كلمة المرور من الخادم.', true);
                    }
                },
                error: function(xhr, status, error) {
                    $genBtn.prop('disabled', false).text('⚡ توليد عشوائي');
                    showMessage('فشل الاتصال بالخادم أثناء توليد كلمة المرور.', true);
                }
            });
        }

        function toggleVisibility() {
            const $input = $('#dms-pwd-input');
            const $btn = $('#dms-pwd-toggle-vis');
            if ($input.attr('type') === 'password') {
                $input.attr('type', 'text');
                $btn.text('🙈');
            } else {
                $input.attr('type', 'password');
                $btn.text('👁️');
            }
        }

        function copySinglePassword() {
            const pwd = $('#dms-pwd-input').val();
            if (!pwd) {
                showMessage('لا توجد كلمة مرور لنسخها.', true);
                return;
            }
            copyToClipboard(pwd, function(success) {
                if (success) {
                    showMessage('تم نسخ كلمة المرور إلى الحافظة! ✓');
                    setTimeout(clearMessage, 2500);
                } else {
                    showMessage('تعذر النسخ تلقائياً. يمكنك نسخها يدوياً.', true);
                }
            });
        }

        function savePassword() {
            if (dmsPwdState.isSaving) {
                return;
            }

            const newPwd = $('#dms-pwd-input').val().trim();
            if (!newPwd) {
                showMessage('الرجاء إدخال أو توليد كلمة مرور أولاً.', true);
                return;
            }

            if (newPwd.length < 6) {
                showMessage('كلمة المرور يجب أن تتكون من 6 أحرف على الأقل.', true);
                return;
            }

            dmsPwdState.isSaving = true;
            clearMessage();
            $('#dms-pwd-btn-save').prop('disabled', true).text('جاري الحفظ...');
            $('#dms-pwd-btn-cancel').prop('disabled', true);
            $('#dms-pwd-btn-generate').prop('disabled', true);
            $('#dms-pwd-spinner').addClass('is-active');

            $.ajax({
                url: ajaxurl,
                type: 'POST',
                cache: false,
                data: {
                    action: 'dms_admin_set_customer_password',
                    nonce: dmsPwdState.nonce,
                    user_id: dmsPwdState.userId,
                    password: newPwd
                },
                success: function(resp) {
                    dmsPwdState.isSaving = false;
                    $('#dms-pwd-spinner').removeClass('is-active');
                    $('#dms-pwd-btn-cancel').prop('disabled', false);
                    $('#dms-pwd-btn-generate').prop('disabled', false);

                    if (resp && resp.success) {
                        dmsPwdState.savedPassword = newPwd;
                        $('#dms-pwd-btn-save').text('✓ تم الحفظ').prop('disabled', true);
                        showMessage(resp.data.message || 'تم تعيين كلمة المرور بنجاح!', false);
                        $('#dms-pwd-success-section').slideDown(150);
                    } else {
                        $('#dms-pwd-btn-save').prop('disabled', false).text('💾 حفظ وتعيين كلمة المرور');
                        const errorMsg = (resp && resp.data && resp.data.message) ? resp.data.message : 'حدث خطأ أثناء حفظ كلمة المرور.';
                        showMessage(errorMsg, true);
                    }
                },
                error: function(xhr, status, error) {
                    dmsPwdState.isSaving = false;
                    $('#dms-pwd-spinner').removeClass('is-active');
                    $('#dms-pwd-btn-save').prop('disabled', false).text('💾 حفظ وتعيين كلمة المرور');
                    $('#dms-pwd-btn-cancel').prop('disabled', false);
                    $('#dms-pwd-btn-generate').prop('disabled', false);
                    showMessage('فشل الاتصال بالخادم. يرجى المحاولة مرة أخرى.', true);
                }
            });
        }

        function copyFullCredentials() {
            const username = dmsPwdState.username || '';
            const password = dmsPwdState.savedPassword || $('#dms-pwd-input').val().trim();

            const template = 
`مرحباً بكم في تطبيق LPCO.

تم تعيين كلمة مرور جديدة لحسابكم.

اسم المستخدم: ${username}

كلمة المرور المؤقتة: ${password}

يرجى تغيير كلمة المرور بعد تسجيل الدخول حفاظاً على أمان حسابكم.

مع تحيات شركة LPCO.`;

            copyToClipboard(template, function(success) {
                const $fb = $('#dms-pwd-copy-feedback');
                if (success) {
                    $fb.text('✓ تم نسخ نص الرسالة وبيانات الدخول إلى الحافظة بنجاح! جاهز للإرسال للزبون.').show();
                } else {
                    $fb.text('تعذر النسخ التلقائي. يرجى نسخ النص يدوياً.').show();
                }
                setTimeout(() => $fb.fadeOut(), 4000);
            });
        }

        function copyToClipboard(text, callback) {
            if (navigator.clipboard && window.isSecureContext) {
                navigator.clipboard.writeText(text).then(function() {
                    callback(true);
                }).catch(function() {
                    fallbackCopy(text, callback);
                });
            } else {
                fallbackCopy(text, callback);
            }
        }

        function fallbackCopy(text, callback) {
            try {
                const textArea = document.createElement("textarea");
                textArea.value = text;
                textArea.style.position = "fixed";
                textArea.style.left = "-999999px";
                textArea.style.top = "-999999px";
                document.body.appendChild(textArea);
                textArea.focus();
                textArea.select();
                const successful = document.execCommand('copy');
                document.body.removeChild(textArea);
                callback(successful);
            } catch (err) {
                callback(false);
            }
        }

        // إتاحة إعادة ربط الأزرار عند تحميل عناصر جديدة عبر AJAX
        window.rebindDmsPasswordButtons = function() {
            $('.dms-open-pwd-modal-btn').off('click.dmsPwd').on('click.dmsPwd', function(e) {
                e.preventDefault();
                const data = $(this).data();
                openModal(data);
            });
        };

        $(document).ready(function() {
            window.rebindDmsPasswordButtons();

            $('#dms-pwd-close-x, #dms-pwd-btn-cancel, #dms-pwd-modal-backdrop').on('click', function(e) {
                e.preventDefault();
                closeModal();
            });

            // إغلاق عبر زر Escape
            $(document).on('keyup', function(e) {
                if (e.key === 'Escape' && $('#dms-pwd-modal').is(':visible')) {
                    closeModal();
                }
            });

            $('#dms-pwd-btn-generate').on('click', function(e) {
                e.preventDefault();
                generatePassword();
            });

            $('#dms-pwd-toggle-vis').on('click', function(e) {
                e.preventDefault();
                toggleVisibility();
            });

            $('#dms-pwd-copy-pwd').on('click', function(e) {
                e.preventDefault();
                copySinglePassword();
            });

            $('#dms-pwd-btn-save').on('click', function(e) {
                e.preventDefault();
                savePassword();
            });

            $('#dms-pwd-btn-copy-all').on('click', function(e) {
                e.preventDefault();
                copyFullCredentials();
            });
        });
    })(jQuery);
    </script>
    <?php
}
