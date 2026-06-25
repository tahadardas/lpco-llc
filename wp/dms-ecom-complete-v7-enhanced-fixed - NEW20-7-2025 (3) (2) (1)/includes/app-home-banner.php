<?php
/**
 * App home banner settings + API.
 */

if (!defined('ABSPATH')) {
    exit;
}

define('DMS_APP_HOME_BANNER_OPTION', 'dms_app_home_banner');
define('DMS_APP_HOME_BANNERS_OPTION', 'dms_app_home_banners');

if (!function_exists('dms_app_home_banner_defaults')) {
function dms_app_home_banner_defaults() {
    return array(
        'enabled' => 0,
        'image_id' => 0,
        'image_url' => '',
        'title' => '',
        'subtitle' => '',
        'button_label' => '',
        'button_link' => '',
        'action_type' => 'none',
        'action_value' => '',
        'product_ids' => '',
        'show_title' => 1,
        'show_subtitle' => 1,
        'show_button' => 1,
        'content_alignment' => 'start',
        'content_vertical_alignment' => 'center',
        'image_fit' => 'cover',
        'overlay_opacity' => 60,
        'title_color' => '#FFFFFF',
        'subtitle_color' => '#FFFFFF',
        'button_background_color' => '#D31225',
        'button_text_color' => '#FFFFFF'
    );
}
}

if (!function_exists('dms_app_home_banner_get')) {
function dms_app_home_banner_get() {
    $stored = function_exists('get_option') ? get_option(DMS_APP_HOME_BANNER_OPTION, array()) : array();
    if (!is_array($stored)) {
        $stored = array();
    }
    $banner = function_exists('wp_parse_args') ? wp_parse_args($stored, dms_app_home_banner_defaults()) : array_merge(dms_app_home_banner_defaults(), $stored);
    $banner['enabled'] = !empty($banner['enabled']);
    $banner['image_id'] = function_exists('absint') ? absint($banner['image_id']) : $banner['image_id'];
    $banner['image_url'] = is_string($banner['image_url']) ? $banner['image_url'] : '';
    $banner['title'] = is_string($banner['title']) ? $banner['title'] : '';
    $banner['subtitle'] = is_string($banner['subtitle']) ? $banner['subtitle'] : '';
    $banner['button_label'] = is_string($banner['button_label']) ? $banner['button_label'] : '';
    $banner['button_link'] = is_string($banner['button_link']) ? $banner['button_link'] : '';
    $banner['action_type'] = is_string($banner['action_type']) ? $banner['action_type'] : 'none';
    $banner['action_value'] = is_string($banner['action_value']) ? $banner['action_value'] : '';
    $banner['product_ids'] = is_string($banner['product_ids']) ? $banner['product_ids'] : '';
    return $banner;
}
}

if (!function_exists('dms_app_home_banner_sanitize')) {
function dms_app_home_banner_sanitize($input) {
    $clean = dms_app_home_banner_defaults();
    if (!is_array($input)) {
        return $clean;
    }
    $clean['enabled'] = !empty($input['enabled']) ? 1 : 0;
    $clean['image_id'] = isset($input['image_id']) ? (function_exists('absint') ? absint($input['image_id']) : $input['image_id']) : 0;
    $clean['image_url'] = isset($input['image_url']) ? (function_exists('esc_url_raw') ? esc_url_raw(function_exists('wp_unslash') ? wp_unslash($input['image_url']) : $input['image_url']) : $input['image_url']) : '';
    $clean['title'] = isset($input['title']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($input['title']) : $input['title']) : $input['title']) : '';
    $clean['subtitle'] = isset($input['subtitle']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($input['subtitle']) : $input['subtitle']) : $input['subtitle']) : '';
    $clean['button_label'] = isset($input['button_label']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($input['button_label']) : $input['button_label']) : $input['button_label']) : '';
    $clean['button_link'] = isset($input['button_link']) ? (function_exists('esc_url_raw') ? esc_url_raw(function_exists('wp_unslash') ? wp_unslash($input['button_link']) : $input['button_link']) : $input['button_link']) : '';
    $allowed_actions = array('none', 'category', 'brand', 'product', 'search', 'internalRoute', 'externalUrl');
    $action_type = isset($input['action_type']) ? (string) $input['action_type'] : 'none';
    $clean['action_type'] = in_array($action_type, $allowed_actions, true) ? $action_type : 'none';
    $action_value = isset($input['action_value']) ? (string) $input['action_value'] : '';
    $clean['action_value'] = $clean['action_type'] === 'externalUrl'
        ? esc_url_raw($action_value)
        : sanitize_text_field($action_value);
    $clean['product_ids'] = isset($input['product_ids']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($input['product_ids']) : $input['product_ids']) : $input['product_ids']) : '';
    $clean['show_title'] = array_key_exists('show_title', $input) ? (!empty($input['show_title']) ? 1 : 0) : 1;
    $clean['show_subtitle'] = array_key_exists('show_subtitle', $input) ? (!empty($input['show_subtitle']) ? 1 : 0) : 1;
    $clean['show_button'] = array_key_exists('show_button', $input) ? (!empty($input['show_button']) ? 1 : 0) : 1;
    $allowed_alignments = array('start', 'center', 'end');
    $content_alignment = sanitize_key((string) ($input['content_alignment'] ?? 'start'));
    $clean['content_alignment'] = in_array($content_alignment, $allowed_alignments, true) ? $content_alignment : 'start';
    $allowed_vertical_alignments = array('top', 'center', 'bottom');
    $vertical_alignment = sanitize_key((string) ($input['content_vertical_alignment'] ?? 'center'));
    $clean['content_vertical_alignment'] = in_array($vertical_alignment, $allowed_vertical_alignments, true) ? $vertical_alignment : 'center';
    $image_fit = sanitize_key((string) ($input['image_fit'] ?? 'cover'));
    $clean['image_fit'] = in_array($image_fit, array('cover', 'contain'), true) ? $image_fit : 'cover';
    $clean['overlay_opacity'] = max(0, min(100, intval($input['overlay_opacity'] ?? 60)));
    foreach (array('title_color', 'subtitle_color', 'button_background_color', 'button_text_color') as $color_key) {
        $fallback = $color_key === 'button_background_color' ? '#D31225' : '#FFFFFF';
        $color = sanitize_hex_color((string) ($input[$color_key] ?? $fallback));
        $clean[$color_key] = $color ?: $fallback;
    }
    return $clean;
}
}

if (!function_exists('dms_app_home_banner_save')) {
function dms_app_home_banner_save($input) {
    $clean = dms_app_home_banner_sanitize($input);
    if (function_exists('update_option')) {
        update_option(DMS_APP_HOME_BANNER_OPTION, $clean, false);
    }
    return dms_app_home_banner_get();
}
}

if (!function_exists('dms_app_home_banner_admin_payload')) {
function dms_app_home_banner_admin_payload() {
    $banner = dms_app_home_banner_get();
    $image_url = '';
    if (!empty($banner['image_id']) && function_exists('wp_get_attachment_image_url')) {
        $image_url = (string) wp_get_attachment_image_url($banner['image_id'], 'full');
    }
    if ($image_url === '') {
        $image_url = (string) ($banner['image_url'] ?? '');
    }

    return array(
        'enabled' => !empty($banner['enabled']),
        'image_id' => intval($banner['image_id'] ?? 0),
        'image_url' => $image_url,
        'title' => (string) ($banner['title'] ?? ''),
        'subtitle' => (string) ($banner['subtitle'] ?? ''),
        'button_label' => (string) ($banner['button_label'] ?? ''),
        'button_link' => (string) ($banner['button_link'] ?? ''),
        'action_type' => (string) ($banner['action_type'] ?? 'none'),
        'action_value' => (string) ($banner['action_value'] ?? ''),
        'product_ids' => array_map('intval', array_filter(array_map('trim', explode(',', (string) ($banner['product_ids'] ?? ''))))),
    );
}
}

if (!function_exists('dms_app_home_banner_register_settings')) {
function dms_app_home_banner_register_settings() {
    if (function_exists('register_setting')) {
        register_setting('dms_app_home_banner', DMS_APP_HOME_BANNER_OPTION, 'dms_app_home_banner_sanitize');
    }

    if (function_exists('add_settings_section')) {
        add_settings_section(
            'dms_app_home_banner_section',
            'إدارة الإعلانات والبانر الرئيسي',
            'dms_app_home_banner_section_cb',
            'dms-app-home-banner'
        );
    }

    if (function_exists('add_settings_field')) {
        add_settings_field(
            'dms_app_home_banner_enabled',
            'تفعيل البانر في التطبيق',
            'dms_app_home_banner_field_enabled',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );

        add_settings_field(
            'dms_app_home_banner_image',
            'صورة البانر',
            'dms_app_home_banner_field_image',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );

        add_settings_field(
            'dms_app_home_banner_title',
            'العنوان',
            'dms_app_home_banner_field_title',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );

        add_settings_field(
            'dms_app_home_banner_subtitle',
            'الوصف المختصر',
            'dms_app_home_banner_field_subtitle',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );

        add_settings_field(
            'dms_app_home_banner_button_label',
            'نص الزر',
            'dms_app_home_banner_field_button_label',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );

        add_settings_field(
            'dms_app_home_banner_button_link',
            'رابط الزر',
            'dms_app_home_banner_field_button_link',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );

        add_settings_field(
            'dms_app_home_banner_product_ids',
            'أرقام المنتجات (IDs)',
            'dms_app_home_banner_field_product_ids',
            'dms-app-home-banner',
            'dms_app_home_banner_section'
        );
    }
}
}
add_action('admin_init', 'dms_app_home_banner_register_settings');

if (!function_exists('dms_app_home_banner_section_cb')) {
function dms_app_home_banner_section_cb() {
    echo '<p>يمكن تعديل بيانات البانر وسيتم تحديثها في التطبيق مباشرة.</p>';
}
}

if (!function_exists('dms_app_home_banner_field_enabled')) {
function dms_app_home_banner_field_enabled() {
    $banner = dms_app_home_banner_get();
    if (function_exists('printf') && function_exists('esc_attr') && function_exists('checked')) {
        printf(
            '<label><input type="checkbox" name="%s[enabled]" value="1" %s> %s</label>',
            esc_attr(DMS_APP_HOME_BANNER_OPTION),
            checked($banner['enabled'], true, false),
            'تفعيل البانر في التطبيق'
        );
    }
}
}

if (!function_exists('dms_app_home_banner_field_image')) {
function dms_app_home_banner_field_image() {
    $banner = dms_app_home_banner_get();
    $image_id = function_exists('absint') ? absint($banner['image_id']) : $banner['image_id'];
    $image_url = ($image_id && function_exists('wp_get_attachment_image_url')) ? wp_get_attachment_image_url($image_id, 'medium') : '';
    $preview_style = $image_url ? '' : 'style="display:none;"';
    $remove_style = $image_url ? '' : 'style="display:none;"';
    $esc_option = function_exists('esc_attr') ? esc_attr(DMS_APP_HOME_BANNER_OPTION) : DMS_APP_HOME_BANNER_OPTION;
    $esc_id = function_exists('esc_attr') ? esc_attr($image_id) : $image_id;
    $esc_url = function_exists('esc_url') ? esc_url($image_url) : $image_url;
    ?>
    <input type="hidden" id="dms_home_banner_image_id" name="<?php echo $esc_option; ?>[image_id]" value="<?php echo $esc_id; ?>">
    <div style="margin-bottom:8px;">
        <img id="dms_home_banner_preview" src="<?php echo $esc_url; ?>" alt="" style="max-width: 320px; height: auto; border: 1px solid #ccd0d4; border-radius: 6px;" <?php echo $preview_style; ?>>
    </div>
    <button type="button" class="button" id="dms-home-banner-upload">اختيار صورة</button>
    <button type="button" class="button" id="dms-home-banner-remove" <?php echo $remove_style; ?>>إزالة</button>
    <p class="description">اختر صورة مناسبة للبانر الرئيسي في صفحة التطبيق الرئيسية.</p>
    <?php
}
}

if (!function_exists('dms_app_home_banner_field_title')) {
function dms_app_home_banner_field_title() {
    $banner = dms_app_home_banner_get();
    if (function_exists('printf') && function_exists('esc_attr')) {
        printf(
            '<input type="text" class="regular-text" name="%s[title]" value="%s" />',
            esc_attr(DMS_APP_HOME_BANNER_OPTION),
            esc_attr($banner['title'])
        );
    }
}
}

if (!function_exists('dms_app_home_banner_field_subtitle')) {
function dms_app_home_banner_field_subtitle() {
    $banner = dms_app_home_banner_get();
    if (function_exists('printf') && function_exists('esc_attr') && function_exists('esc_textarea')) {
        printf(
            '<textarea class="large-text" rows="2" name="%s[subtitle]">%s</textarea>',
            esc_attr(DMS_APP_HOME_BANNER_OPTION),
            esc_textarea($banner['subtitle'])
        );
    }
}
}

if (!function_exists('dms_app_home_banner_field_button_label')) {
function dms_app_home_banner_field_button_label() {
    $banner = dms_app_home_banner_get();
    if (function_exists('printf') && function_exists('esc_attr')) {
        printf(
            '<input type="text" class="regular-text" name="%s[button_label]" value="%s" />',
            esc_attr(DMS_APP_HOME_BANNER_OPTION),
            esc_attr($banner['button_label'])
        );
    }
}
}

if (!function_exists('dms_app_home_banner_field_button_link')) {
function dms_app_home_banner_field_button_link() {
    $banner = dms_app_home_banner_get();
    if (function_exists('printf') && function_exists('esc_attr')) {
        printf(
            '<input type="url" class="regular-text ltr" name="%s[button_link]" value="%s" placeholder="https://..." />',
            esc_attr(DMS_APP_HOME_BANNER_OPTION),
            esc_attr($banner['button_link'])
        );
    }
}
}

if (!function_exists('dms_app_home_banner_field_product_ids')) {
function dms_app_home_banner_field_product_ids() {
    $banner = dms_app_home_banner_get();
    if (function_exists('printf') && function_exists('esc_attr')) {
        printf(
            '<input type="text" class="regular-text" name="%s[product_ids]" value="%s" placeholder="مثال: 101, 102, 103" />',
            esc_attr(DMS_APP_HOME_BANNER_OPTION),
            esc_attr($banner['product_ids'])
        );
        echo '<p class="description">أدخل أرقام المنتجات (IDs) مفصولة بفاصلة لعرضها في البانر.</p>';
    }
}
}

if (!function_exists('dms_app_home_banner_register_menu')) {
function dms_app_home_banner_register_menu() {
    if (function_exists('add_submenu_page')) {
        add_submenu_page(
            'dms-app-main',
            'إدارة إعلانات التطبيق',
            'إدارة إعلانات التطبيق',
            'manage_woocommerce',
            'dms-app-settings',
            'dms_app_home_banner_render_page'
        );
    }
}
}
// The legacy WordPress banner screen is intentionally not registered.
// Flutter Admin is the production UI for the canonical home-banners contract.

if (!function_exists('dms_app_home_banner_render_page')) {
function dms_app_home_banner_render_page() {
    if (function_exists('current_user_can') && !current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
        if (function_exists('wp_die')) {
            wp_die(__('ليس لديك صلاحية للوصول إلى هذه الصفحة', 'dms-ecom'), 403);
        }
    }
    ?>
    <div class="wrap">
        <h1>إدارة إعلانات التطبيق</h1>
        <form method="post" action="options.php">
            <?php
            if (function_exists('settings_fields')) settings_fields('dms_app_home_banner');
            if (function_exists('do_settings_sections')) do_settings_sections('dms-app-home-banner');
            if (function_exists('submit_button')) submit_button('حفظ البانر');
            ?>
        </form>
    </div>
    <?php
}
}

if (!function_exists('dms_app_home_banner_admin_assets')) {
function dms_app_home_banner_admin_assets($hook) {
    $page = isset($_GET['page']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($_GET['page']) : $_GET['page']) : $_GET['page']) : '';
    if ($page !== 'dms-app-settings') {
        return;
    }
    if (function_exists('wp_enqueue_script')) wp_enqueue_script('jquery');
    if (function_exists('wp_enqueue_media')) wp_enqueue_media();
    if (function_exists('wp_add_inline_script')) {
        wp_add_inline_script('jquery', "
            jQuery(function($) {
                var frame;
                $('#dms-home-banner-upload').on('click', function(e) {
                    e.preventDefault();
                    if (frame) {
                        frame.open();
                        return;
                    }
                    frame = wp.media({
                        title: 'اختيار صورة البانر',
                        button: { text: 'استخدام الصورة' },
                        multiple: false
                    });
                    frame.on('select', function() {
                        var attachment = frame.state().get('selection').first().toJSON();
                        $('#dms_home_banner_image_id').val(attachment.id);
                        $('#dms_home_banner_preview').attr('src', attachment.url).show();
                        $('#dms-home-banner-remove').show();
                    });
                    frame.open();
                });
                $('#dms-home-banner-remove').on('click', function(e) {
                    e.preventDefault();
                    $('#dms_home_banner_image_id').val('');
                    $('#dms_home_banner_preview').attr('src', '').hide();
                    $(this).hide();
                });
            });
        ");
    }
}
}
add_action('admin_enqueue_scripts', 'dms_app_home_banner_admin_assets');

if (!function_exists('dms_app_home_banner_rest_response')) {
function dms_app_home_banner_rest_response() {
    $canonical = function_exists('dms_app_home_banners_get') ? dms_app_home_banners_get() : array('items' => array());
    $banner = !empty($canonical['items'][0]) && is_array($canonical['items'][0])
        ? $canonical['items'][0]
        : array('enabled' => false);
    if (empty($banner['enabled'])) {
        return array('enabled' => false);
    }

    $image_url = '';
    if (!empty($banner['image_id']) && function_exists('wp_get_attachment_image_url')) {
        $image_url = (string) wp_get_attachment_image_url($banner['image_id'], 'full');
    }
    if ($image_url === '') {
        $image_url = (string) ($banner['image_url'] ?? '');
    }
    if (!$image_url) {
        return array('enabled' => false);
    }

    return array(
        'enabled' => true,
        'image_url' => $image_url,
        'title' => $banner['title'],
        'subtitle' => $banner['subtitle'],
        'button_label' => $banner['button_label'],
        'button_link' => $banner['button_link'],
        'action_type' => (string) ($banner['action_type'] ?? 'none'),
        'action_value' => (string) ($banner['action_value'] ?? ''),
        'product_ids' => is_array($banner['product_ids'] ?? null)
            ? array_values(array_map('intval', $banner['product_ids']))
            : array_map('intval', array_filter(explode(',', (string) ($banner['product_ids'] ?? ''))))
    );
}
}

if (function_exists('add_action')) {
    add_action('rest_api_init', function () {
        if (function_exists('register_rest_route')) {
            register_rest_route('dms/v1', '/home-banner', array(
                'methods' => 'GET',
                'callback' => 'dms_app_home_banner_rest_response',
                'permission_callback' => '__return_true'
            ));
            register_rest_route('dms/v1', '/home-banners', array(
                'methods' => 'GET',
                'callback' => 'dms_app_home_banners_rest_response',
                'permission_callback' => '__return_true'
            ));
        }
    });
}

if (!function_exists('dms_app_home_banner_item_sanitize')) {
function dms_app_home_banner_item_sanitize($item, $index = 0) {
    $item = is_array($item) ? $item : array();
    $legacy = dms_app_home_banner_sanitize($item);
    $product_ids = isset($item['product_ids']) && is_array($item['product_ids'])
        ? array_values(array_filter(array_map('absint', $item['product_ids'])))
        : array_values(array_filter(array_map('absint', explode(',', (string) ($legacy['product_ids'] ?? '')))));
    return array_merge($legacy, array(
        'id' => sanitize_text_field((string) ($item['id'] ?? ('banner-' . ($index + 1)))),
        'sort_order' => isset($item['sort_order']) ? intval($item['sort_order']) : $index,
        'starts_at' => sanitize_text_field((string) ($item['starts_at'] ?? '')),
        'ends_at' => sanitize_text_field((string) ($item['ends_at'] ?? '')),
        'product_ids' => $product_ids,
        'updated_at' => current_time('c'),
    ));
}
}

if (!function_exists('dms_app_home_banners_get')) {
function dms_app_home_banners_get() {
    $stored = get_option(DMS_APP_HOME_BANNERS_OPTION, null);
    $items = is_array($stored) && isset($stored['items']) && is_array($stored['items']) ? $stored['items'] : array();
    if (!is_array($stored)) {
        $legacy = dms_app_home_banner_admin_payload();
        $legacy['id'] = 'legacy-home-banner';
        $legacy['sort_order'] = 0;
        $items = array($legacy);
    }
    usort($items, function($a, $b) { return intval($a['sort_order'] ?? 0) <=> intval($b['sort_order'] ?? 0); });
    return array(
        'items' => array_values($items),
        'updated_at' => (string) ($stored['updated_at'] ?? ''),
        'revision' => (string) ($stored['revision'] ?? ''),
    );
}
}

if (!function_exists('dms_app_home_banners_save')) {
function dms_app_home_banners_save($input) {
    $raw_items = is_array($input) && isset($input['items']) && is_array($input['items']) ? $input['items'] : array();
    $items = array();
    foreach (array_slice($raw_items, 0, 30) as $index => $item) {
        $items[] = dms_app_home_banner_item_sanitize($item, $index);
    }
    $revision = wp_generate_uuid4();
    foreach ($items as &$item) {
        $item['revision'] = $revision;
    }
    unset($item);
    $saved = array(
        'items' => $items,
        'updated_at' => current_time('c'),
        'revision' => $revision,
    );
    update_option(DMS_APP_HOME_BANNERS_OPTION, $saved, false);
    if (!empty($items)) {
        $legacy = $items[0];
        if (is_array($legacy['product_ids'])) $legacy['product_ids'] = implode(',', $legacy['product_ids']);
        dms_app_home_banner_save($legacy);
    }
    if (function_exists('lpco_dms_clear_catalog_cache')) {
        lpco_dms_clear_catalog_cache('home_banners_updated', 0);
    }
    return $saved;
}
}

if (!function_exists('dms_app_home_banners_rest_response')) {
function dms_app_home_banners_rest_response() {
    $data = dms_app_home_banners_get();
    $now = current_time('timestamp');
    $data['items'] = array_values(array_filter($data['items'], function($item) use ($now) {
        if (empty($item['enabled'])) return false;
        $starts = !empty($item['starts_at']) ? strtotime($item['starts_at']) : 0;
        $ends = !empty($item['ends_at']) ? strtotime($item['ends_at']) : 0;
        return (!$starts || $starts <= $now) && (!$ends || $ends >= $now);
    }));
    return $data;
}
}
