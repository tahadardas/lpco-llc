<?php
/**
 * Popup Ad Management for Mobile App
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!function_exists('dms_get_app_popup_config')) {
function dms_get_app_popup_config() {
    return array(
        'enabled' => (bool) get_option('dms_app_popup_ad_enabled'),
        'image_url' => (string) get_option('dms_app_popup_ad_image_url'),
        'action_type' => (string) get_option('dms_app_popup_ad_action_type', 'none'),
        'action_value' => (string) get_option('dms_app_popup_ad_action_value'),
    );
}
}

if (!function_exists('dms_save_app_popup_config')) {
function dms_save_app_popup_config($input) {
    $enabled = !empty($input['enabled']) ? 1 : 0;
    $image_url = esc_url_raw((string) ($input['image_url'] ?? ''));
    $action_type = sanitize_key((string) ($input['action_type'] ?? 'none'));
    $allowed_actions = array('none', 'product', 'category', 'url');
    if (!in_array($action_type, $allowed_actions, true)) {
        $action_type = 'none';
    }

    $action_value = (string) ($input['action_value'] ?? '');
    if ($action_type === 'url') {
        $action_value = esc_url_raw($action_value);
    } else {
        $action_value = sanitize_text_field($action_value);
    }

    update_option('dms_app_popup_ad_enabled', $enabled, false);
    update_option('dms_app_popup_ad_image_url', $image_url, false);
    update_option('dms_app_popup_ad_action_type', $action_type, false);
    update_option('dms_app_popup_ad_action_value', $action_value, false);

    return dms_get_app_popup_config();
}
}

// 1. Register Settings
add_action('admin_init', 'dms_app_popup_ad_register_settings');
function dms_app_popup_ad_register_settings() {
    register_setting('dms_app_popup_ad_group', 'dms_app_popup_ad_enabled');
    register_setting('dms_app_popup_ad_group', 'dms_app_popup_ad_image_url');
    register_setting('dms_app_popup_ad_group', 'dms_app_popup_ad_action_type');
    register_setting('dms_app_popup_ad_group', 'dms_app_popup_ad_action_value');
}

// 2. Register Menu
add_action('admin_menu', 'dms_app_popup_ad_register_menu');
function dms_app_popup_ad_register_menu() {
    add_submenu_page(
        'dms-app-main',
        'الإعلان المنبثق (Popup)',
        'الإعلان المنبثق',
        'manage_woocommerce',
        'dms-app-popup-ad',
        'dms_app_popup_ad_render_page'
    );
}

// 3. Render Admin Page
function dms_app_popup_ad_render_page() {
    ?>
    <div class="wrap">
        <h1 style="background: #1f2937; color: white; padding: 20px; border-radius: 8px; margin: 0 0 30px 0; display: flex; align-items: center;">
            <span class="dashicons dashicons-megaphone" style="font-size: 30px; width: 30px; height: 30px; margin-left: 15px;"></span>
            إدارة الإعلان المنبثق في التطبيق (Popup Ad)
        </h1>

        <form method="post" action="options.php">
            <?php settings_fields('dms_app_popup_ad_group'); ?>
            <?php do_settings_sections('dms_app_popup_ad_group'); ?>

            <div style="background: white; padding: 25px; border-radius: 12px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); max-width: 800px;">
                
                <table class="form-table">
                    <tr>
                        <th scope="row">تفعيل الإعلان</th>
                        <td>
                            <label class="switch">
                                <input type="checkbox" name="dms_app_popup_ad_enabled" value="1" <?php checked(1, get_option('dms_app_popup_ad_enabled'), true); ?>>
                                <span class="slider round"></span>
                            </label>
                            <p class="description">عرض إعلان منبثق عند فتح التطبيق.</p>
                        </td>
                    </tr>

                    <tr>
                        <th scope="row">صورة الإعلان</th>
                        <td>
                            <div style="display: flex; flex-direction: column; gap: 10px;">
                                <input type="text" name="dms_app_popup_ad_image_url" id="popup_image_url" value="<?php echo esc_attr(get_option('dms_app_popup_ad_image_url')); ?>" class="regular-text">
                                <div>
                                    <button type="button" class="button" id="upload_popup_image_btn">اختيار من المكتبة</button>
                                </div>
                                <div id="popup_image_preview" style="margin-top: 10px;">
                                    <?php if ($url = get_option('dms_app_popup_ad_image_url')): ?>
                                        <img src="<?php echo esc_url($url); ?>" style="max-width: 300px; border-radius: 8px; border: 1px solid #ddd;">
                                    <?php endif; ?>
                                </div>
                            </div>
                        </td>
                    </tr>

                    <tr>
                        <th scope="row">نوع الإجراء (Click Action)</th>
                        <td>
                            <select name="dms_app_popup_ad_action_type" id="popup_action_type">
                                <option value="none" <?php selected('none', get_option('dms_app_popup_ad_action_type')); ?>>لا يوجد (صورة فقط)</option>
                                <option value="product" <?php selected('product', get_option('dms_app_popup_ad_action_type')); ?>>منتج معين</option>
                                <option value="category" <?php selected('category', get_option('dms_app_popup_ad_action_type')); ?>>قسم معين</option>
                                <option value="url" <?php selected('url', get_option('dms_app_popup_ad_action_type')); ?>>رابط خارجي</option>
                            </select>
                        </td>
                    </tr>

                    <tr>
                        <th scope="row">قيمة الإجراء</th>
                        <td>
                            <input type="text" name="dms_app_popup_ad_action_value" value="<?php echo esc_attr(get_option('dms_app_popup_ad_action_value')); ?>" class="regular-text" placeholder="ID المنتج أو القسم أو الرابط">
                            <p class="description">أدخل الرقم التعريفي (ID) للقسم أو المنتج، أو الرابط الكامل.</p>
                        </td>
                    </tr>
                </table>

                <?php submit_button('حفظ الإعدادات', 'primary', 'submit', true, array('style' => 'background: #dc2626; border: none; padding: 10px 30px; font-weight: bold;')); ?>
            </div>
        </form>
    </div>

    <style>
        .switch { position: relative; display: inline-block; width: 50px; height: 24px; }
        .switch input { opacity: 0; width: 0; height: 0; }
        .slider { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #ccc; transition: .4s; border-radius: 34px; }
        .slider:before { position: absolute; content: ""; height: 16px; width: 16px; left: 4px; bottom: 4px; background-color: white; transition: .4s; border-radius: 50%; }
        input:checked + .slider { background-color: #dc2626; }
        input:checked + .slider:before { transform: translateX(26px); }
    </style>

    <script>
        jQuery(document).ready(function($){
            $('#upload_popup_image_btn').click(function(e) {
                e.preventDefault();
                var image = wp.media({ 
                    title: 'اختيار صورة الإعلان',
                    multiple: false
                }).open()
                .on('select', function(e){
                    var uploaded_image = image.state().get('selection').first();
                    var image_url = uploaded_image.toJSON().url;
                    $('#popup_image_url').val(image_url);
                    $('#popup_image_preview').html('<img src="' + image_url + '" style="max-width: 300px; border-radius: 8px; border: 1px solid #ddd;">');
                });
            });
        });
    </script>
    <?php
}

// 4. REST API Endpoint
add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/config/popup', array(
        'methods' => 'GET',
        'callback' => 'dms_get_app_popup_config',
        'permission_callback' => '__return_true'
    ));
});
