<?php
/**
 * Remote-driven home layout builder
 * Admin UI stores layout JSON; REST endpoint serves structured layout to the app.
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!defined('DMS_APP_HOME_LAYOUT_OPTION')) {
    define('DMS_APP_HOME_LAYOUT_OPTION', 'dms_app_home_layout_json');
}
if (!defined('DMS_APP_HOME_LAYOUT_VERSION_OPTION')) {
    define('DMS_APP_HOME_LAYOUT_VERSION_OPTION', 'dms_app_home_layout_version');
}
if (!defined('DMS_APP_HOME_LAYOUT_TTL_OPTION')) {
    define('DMS_APP_HOME_LAYOUT_TTL_OPTION', 'dms_app_home_layout_ttl');
}
if (!defined('DMS_APP_THEME_OPTION')) {
    define('DMS_APP_THEME_OPTION', 'dms_app_theme_settings');
}

if (function_exists('add_action')) {
    add_action('admin_menu', function () {
        if (function_exists('add_submenu_page')) {
            add_submenu_page(
                'dms-app-main',
                'تخطيط الصفحة الرئيسية',
                'تخطيط الصفحة الرئيسية',
                'manage_woocommerce',
                'dms-app-home-layout',
                'dms_app_home_layout_render_admin'
            );
        }
    });
}

if (!function_exists('dms_app_home_layout_section_labels')) {
    function dms_app_home_layout_section_labels() {
        return array(
            'banner' => 'بانر',
            'categories' => 'التصنيفات',
            'brands' => 'العلامات التجارية',
            'products' => 'منتجات',
            'latest_products' => 'أحدث المنتجات',
            'featured_products' => 'منتجات مميزة',
            'home_by_category' => 'منتجات حسب التصنيف',
            'spacer' => 'مسافة'
        );
    }
}

if (!function_exists('dms_app_home_layout_default_sections')) {
    function dms_app_home_layout_default_sections() {
        return array(
            array('type' => 'banner', 'title' => 'ترحيب', 'image' => '', 'link' => '/'),
            array('type' => 'categories', 'title' => 'التصنيفات', 'limit' => 8),
            array('type' => 'brands', 'title' => 'العلامات التجارية', 'limit' => 10),
            array('type' => 'featured_products', 'title' => 'منتجات مميزة', 'limit' => 8),
            array('type' => 'latest_products', 'title' => 'أحدث المنتجات', 'limit' => 8),
            array('type' => 'home_by_category', 'title' => 'الأقسام', 'per_category' => 6)
        );
    }
}

if (!function_exists('dms_app_home_layout_sanitize_sections')) {
    function dms_app_home_layout_sanitize_sections($raw_sections) {
        if (!function_exists('dms_app_home_layout_section_labels')) return array();
        $allowed = array_keys(dms_app_home_layout_section_labels());
        $sections = array();
        if (!is_array($raw_sections)) {
            return $sections;
        }

        foreach ($raw_sections as $section) {
            if (!is_array($section)) {
                continue;
            }
            $type = function_exists('sanitize_key') ? sanitize_key($section['type'] ?? '') : ($section['type'] ?? '');
            if (!in_array($type, $allowed, true)) {
                continue;
            }
            $order = isset($section['order']) ? intval($section['order']) : 0;
            $title = function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($section['title'] ?? '') : ($section['title'] ?? '')) : ($section['title'] ?? '');

            $payload = array('type' => $type);
            if ($title !== '') {
                $payload['title'] = $title;
            }

            switch ($type) {
                case 'banner':
                    $image = function_exists('esc_url_raw') ? esc_url_raw(function_exists('wp_unslash') ? wp_unslash($section['image'] ?? '') : ($section['image'] ?? '')) : ($section['image'] ?? '');
                    $link = function_exists('esc_url_raw') ? esc_url_raw(function_exists('wp_unslash') ? wp_unslash($section['link'] ?? '') : ($section['link'] ?? '')) : ($section['link'] ?? '');
                    if ($image) {
                        $payload['image'] = $image;
                    }
                    if ($link) {
                        $payload['link'] = $link;
                    }
                    break;
                case 'categories':
                case 'brands':
                case 'products':
                case 'latest_products':
                case 'featured_products':
                    $limit = function_exists('absint') ? absint($section['limit'] ?? 0) : intval($section['limit'] ?? 0);
                    if ($limit > 0) {
                        $payload['limit'] = $limit;
                    }
                    break;
                case 'home_by_category':
                    $per_category = function_exists('absint') ? absint($section['per_category'] ?? 0) : intval($section['per_category'] ?? 0);
                    if ($per_category > 0) {
                        $payload['per_category'] = $per_category;
                    }
                    break;
                case 'spacer':
                    $height = function_exists('absint') ? absint($section['height'] ?? 16) : intval($section['height'] ?? 16);
                    $payload['height'] = $height > 0 ? $height : 16;
                    break;
            }

            $sections[] = array(
                'order' => $order,
                'data' => $payload
            );
        }

        if (empty($sections)) {
            return array();
        }

        usort($sections, function ($a, $b) {
            return ($a['order'] ?? 0) <=> ($b['order'] ?? 0);
        });

        $final = array();
        foreach ($sections as $row) {
            $final[] = $row['data'];
        }
        return $final;
    }
}

if (!function_exists('dms_app_theme_defaults')) {
    function dms_app_theme_defaults() {
        return array(
            'enabled' => 1,
            'primary' => '#D32F2F',
            'primary_dark' => '#B71C1C',
            'primary_light' => '#EF5350',
            'text_primary' => '#1A1A1A',
            'text_secondary' => '#666666',
            'text_tertiary' => '#999999',
            'bg_white' => '#FFFFFF',
            'bg_light' => '#F5F5F5',
            'border' => '#E0E0E0',
            'success' => '#4CAF50',
            'warning' => '#FF9800',
            'error' => '#F44336',
            'info' => '#2196F3',
            'updated_at' => ''
        );
    }
}

if (!function_exists('dms_app_theme_get')) {
    function dms_app_theme_get() {
        $stored = function_exists('get_option') ? get_option(DMS_APP_THEME_OPTION, array()) : array();
        if (!is_array($stored)) {
            $stored = array();
        }
        return function_exists('wp_parse_args') ? wp_parse_args($stored, dms_app_theme_defaults()) : array_merge(dms_app_theme_defaults(), $stored);
    }
}

if (!function_exists('dms_app_theme_sanitize_color')) {
    function dms_app_theme_sanitize_color($value, $fallback) {
        if ($value === null) return $fallback;
        $value = strtoupper(trim((string) $value));
        if ($value === '') {
            return $fallback;
        }
        if (preg_match('/^#([0-9A-F]{3}|[0-9A-F]{6})$/', $value)) {
            return $value;
        }
        return $fallback;
    }
}

if (!function_exists('dms_app_theme_sanitize')) {
    function dms_app_theme_sanitize($input) {
        $defaults = dms_app_theme_defaults();
        if (!is_array($input)) {
            return $defaults;
        }
        $clean = $defaults;
        $clean['enabled'] = !empty($input['enabled']) ? 1 : 0;
        foreach ($defaults as $key => $value) {
            if ($key === 'enabled') {
                continue;
            }
            if ($key === 'updated_at') {
                continue;
            }
            $clean[$key] = dms_app_theme_sanitize_color($input[$key] ?? '', $value);
        }
        $clean['updated_at'] = function_exists('current_time') ? current_time('c') : date('c');
        return $clean;
    }
}

if (!function_exists('dms_app_theme_save')) {
    function dms_app_theme_save($input) {
        $clean = dms_app_theme_sanitize($input);
        if (function_exists('update_option')) {
            update_option(DMS_APP_THEME_OPTION, $clean, false);
        }
        return dms_app_theme_get();
    }
}

if (!function_exists('dms_app_home_layout_enqueue_admin_assets')) {
    function dms_app_home_layout_enqueue_admin_assets($hook) {
        $page = isset($_GET['page']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($_GET['page']) : $_GET['page']) : $_GET['page']) : '';
        if ($page !== 'dms-app-home-layout') {
            return;
        }

        if (function_exists('wp_enqueue_script')) {
            wp_enqueue_script('jquery');
            wp_enqueue_script('jquery-ui-sortable');
        }
        if (function_exists('wp_enqueue_style')) {
            wp_enqueue_style('wp-color-picker');
            wp_enqueue_style('wp-admin');
        }
        if (function_exists('wp_enqueue_script')) {
            wp_enqueue_script('wp-color-picker');
        }
        if (function_exists('wp_enqueue_media')) wp_enqueue_media();

        $labels_json = function_exists('wp_json_encode') ? wp_json_encode(dms_app_home_layout_section_labels(), JSON_UNESCAPED_UNICODE) : json_encode(dms_app_home_layout_section_labels());
        $script = <<<JS
jQuery(function($) {
    var sectionLabels = {$labels_json};
    var mediaFrame = null;

    function updateOrder() {
        $('#dms-home-sections .dms-home-section').each(function(index) {
            $(this).find('.dms-section-order').val(index + 1);
        });
    }

    function updateSectionUI(section) {
        var type = section.find('.dms-section-type').val();
        var label = sectionLabels[type] || type || 'قسم';
        section.find('.dms-section-type-label').text(label);
        section.find('[data-show]').each(function() {
            var show = $(this).data('show');
            var list = (show || '').toString().split(',');
            $(this).toggle(list.indexOf(type) !== -1);
        });
    }

    function initSection(section) {
        updateSectionUI(section);
    }

    $('#dms-home-sections').sortable({
        handle: '.dms-home-section-handle',
        update: function() {
            updateOrder();
        }
    });

    updateOrder();
    $('#dms-home-sections .dms-home-section').each(function() {
        initSection($(this));
    });

    $(document).on('change', '.dms-section-type', function() {
        var section = $(this).closest('.dms-home-section');
        updateSectionUI(section);
    });

    $(document).on('click', '.dms-remove-section', function() {
        $(this).closest('.dms-home-section').remove();
        updateOrder();
    });

    $('#dms-add-section').on('click', function() {
        var key = 'section_' + Date.now();
        var template = $('#dms-section-template').html() || '';
        var html = template.replace(/\\{\\{key\\}\\}/g, key).replace(/\\{\\{order\\}\\}/g, $('#dms-home-sections .dms-home-section').length + 1);
        var newSection = $(html);
        $('#dms-home-sections').append(newSection);
        initSection(newSection);
        updateOrder();
    });

    $(document).on('click', '.dms-banner-select', function(e) {
        e.preventDefault();
        var wrapper = $(this).closest('.dms-banner-picker');
        var input = wrapper.find('.dms-banner-image');
        var preview = wrapper.find('.dms-banner-preview');
        if (!mediaFrame) {
            mediaFrame = wp.media({
                title: 'اختيار صورة',
                button: { text: 'استخدام الصورة' },
                multiple: false
            });
        }
        mediaFrame.off('select').on('select', function() {
            var attachment = mediaFrame.state().get('selection').first().toJSON();
            input.val(attachment.url);
            preview.attr('src', attachment.url).show();
            wrapper.find('.dms-banner-remove').show();
        });
        mediaFrame.open();
    });

    $(document).on('click', '.dms-banner-remove', function(e) {
        e.preventDefault();
        var wrapper = $(this).closest('.dms-banner-picker');
        wrapper.find('.dms-banner-image').val('');
        wrapper.find('.dms-banner-preview').attr('src', '').hide();
        $(this).hide();
    });

    if ($.fn.wpColorPicker) {
        $('.dms-color-field').wpColorPicker();
    }
});
JS;

        if (function_exists('wp_add_inline_script')) {
            wp_add_inline_script('jquery-ui-sortable', $script);
        }

        if (function_exists('wp_add_inline_style')) {
            wp_add_inline_style('wp-admin', "
                .dms-home-layout-wrap {direction: rtl;text-align: right;}
                .dms-section-note {color:#666;font-size:13px;margin:6px 0 0;}
                .dms-home-sections {list-style:none;margin:0;padding:0;}
                .dms-home-section {background:#fff;border:1px solid #ccd0d4;border-radius:8px;margin-bottom:12px;padding:12px;}
                .dms-home-section-head {display:flex;align-items:center;gap:10px;margin-bottom:10px;}
                .dms-home-section-handle {cursor:move;color:#666;}
                .dms-home-section-body {display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px;}
                .dms-home-section-body label {display:flex;flex-direction:column;gap:4px;font-size:13px;}
                .dms-home-section .button-link-delete {margin-right:auto;}
                .dms-banner-picker {display:flex;flex-direction:column;gap:6px;}
                .dms-banner-actions {display:flex;gap:6px;flex-wrap:wrap;}
                .dms-banner-preview {max-width:240px;border-radius:8px;border:1px solid #ccd0d4;}
                .dms-theme-grid {display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;}
                .dms-theme-grid label {display:flex;flex-direction:column;gap:6px;font-size:13px;}
            ");
        }
    }
}
if (function_exists('add_action')) {
    add_action('admin_enqueue_scripts', 'dms_app_home_layout_enqueue_admin_assets');
}

if (!function_exists('dms_app_home_layout_render_admin')) {
    function dms_app_home_layout_render_admin() {
        if (function_exists('current_user_can') && !current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            if (function_exists('wp_die')) {
                wp_die(__('ليس لديك صلاحية للوصول إلى هذه الصفحة', 'dms'));
            }
        }

        $saved = false;
        $error = '';
        if (isset($_POST['dms_home_layout_nonce']) && function_exists('wp_verify_nonce') && wp_verify_nonce($_POST['dms_home_layout_nonce'], 'dms_home_layout_save')) {
            $version = function_exists('sanitize_text_field') ? sanitize_text_field($_POST['dms_home_layout_version'] ?? '1.0.0') : ($_POST['dms_home_layout_version'] ?? '1.0.0');
            $cache_ttl = max(60, intval($_POST['dms_home_layout_ttl'] ?? 3600));
            $sections = dms_app_home_layout_sanitize_sections($_POST['dms_home_sections'] ?? array());

            if (empty($sections)) {
                $sections = dms_app_home_layout_default_sections();
            }

            if (function_exists('update_option') && function_exists('wp_json_encode')) {
                update_option(DMS_APP_HOME_LAYOUT_OPTION, wp_json_encode(array(
                    'sections' => $sections,
                    'updated_at' => function_exists('current_time') ? current_time('c') : date('c')
                ), JSON_UNESCAPED_UNICODE), false);
                update_option(DMS_APP_HOME_LAYOUT_VERSION_OPTION, $version, false);
                update_option(DMS_APP_HOME_LAYOUT_TTL_OPTION, $cache_ttl, false);

                $theme_input = $_POST['dms_app_theme'] ?? array();
                update_option(DMS_APP_THEME_OPTION, dms_app_theme_sanitize($theme_input), false);
            }

            $saved = true;
        }

        $current_layout = dms_app_home_layout_get();
        $sections = $current_layout['sections'] ?? dms_app_home_layout_default_sections();
        $version = function_exists('get_option') ? get_option(DMS_APP_HOME_LAYOUT_VERSION_OPTION, '1.0.0') : '1.0.0';
        $ttl = function_exists('get_option') ? intval(get_option(DMS_APP_HOME_LAYOUT_TTL_OPTION, 3600)) : 3600;
        $labels = dms_app_home_layout_section_labels();
        $theme = dms_app_theme_get();
        ?>
        <div class="wrap dms-home-layout-wrap">
            <h1>تصميم الواجهة الرئيسية</h1>
            <?php if ($saved): ?>
                <div class="notice notice-success"><p>تم الحفظ بنجاح.</p></div>
            <?php endif; ?>
            <?php if (!empty($error)): ?>
                <div class="notice notice-error"><p><?php echo function_exists('esc_html') ? esc_html($error) : $error; ?></p></div>
            <?php endif; ?>

            <form method="post">
                <?php if (function_exists('wp_nonce_field')) wp_nonce_field('dms_home_layout_save', 'dms_home_layout_nonce'); ?>
                <table class="form-table">
                    <tr>
                        <th scope="row">الإصدار</th>
                        <td><input type="text" name="dms_home_layout_version" value="<?php echo function_exists('esc_attr') ? esc_attr($version) : $version; ?>" class="regular-text"></td>
                    </tr>
                    <tr>
                        <th scope="row">Cache TTL (ثواني)</th>
                        <td><input type="number" min="60" name="dms_home_layout_ttl" value="<?php echo function_exists('esc_attr') ? esc_attr($ttl) : $ttl; ?>" class="regular-text"></td>
                    </tr>
                </table>

                <h2>أقسام الصفحة الرئيسية</h2>
                <p class="description">اسحب وأفلت لترتيب الأقسام، ثم عدّل العنوان والمحتوى لكل قسم.</p>
                <ul id="dms-home-sections" class="dms-home-sections">
                    <?php foreach ($sections as $index => $section): ?>
                        <?php
                        $key = 'section_' . $index;
                        $type = function_exists('sanitize_key') ? sanitize_key($section['type'] ?? 'products') : ($section['type'] ?? 'products');
                        $title = $section['title'] ?? '';
                        $limit = intval($section['limit'] ?? 0);
                        $image = $section['image'] ?? '';
                        $link = $section['link'] ?? '';
                        $height = intval($section['height'] ?? 16);
                        $per_category = intval($section['per_category'] ?? 6);
                        $esc_key = function_exists('esc_attr') ? esc_attr($key) : $key;
                        $esc_type_label = function_exists('esc_html') ? esc_html($labels[$type] ?? $type) : ($labels[$type] ?? $type);
                        $esc_title = function_exists('esc_attr') ? esc_attr($title) : $title;
                        $esc_limit = function_exists('esc_attr') ? esc_attr($limit ?: '') : ($limit ?: '');
                        $esc_image = function_exists('esc_attr') ? esc_attr($image) : $image;
                        $esc_link = function_exists('esc_attr') ? esc_attr($link) : $link;
                        $esc_pc = function_exists('esc_attr') ? esc_attr($per_category ?: '') : ($per_category ?: '');
                        $esc_height = function_exists('esc_attr') ? esc_attr($height ?: 16) : ($height ?: 16);
                        $esc_url_image = function_exists('esc_url') ? esc_url($image) : $image;
                        ?>
                        <li class="dms-home-section" data-key="<?php echo $esc_key; ?>">
                            <div class="dms-home-section-head">
                                <span class="dashicons dashicons-move dms-home-section-handle"></span>
                                <strong class="dms-section-type-label"><?php echo $esc_type_label; ?></strong>
                                <button type="button" class="button-link-delete dms-remove-section">إزالة</button>
                            </div>
                            <div class="dms-home-section-body">
                                <label>
                                    نوع القسم
                                    <select name="dms_home_sections[<?php echo $esc_key; ?>][type]" class="dms-section-type">
                                        <?php foreach ($labels as $value => $label): ?>
                                            <option value="<?php echo function_exists('esc_attr') ? esc_attr($value) : $value; ?>" <?php if (function_exists('selected')) selected($type, $value); ?>>
                                                <?php echo function_exists('esc_html') ? esc_html($label) : $label; ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                </label>
                                <label>
                                    العنوان
                                    <input type="text" name="dms_home_sections[<?php echo $esc_key; ?>][title]" value="<?php echo $esc_title; ?>" class="regular-text">
                                </label>
                                <label data-show="categories,brands,products,latest_products,featured_products">
                                    الحد الأقصى
                                    <input type="number" min="1" name="dms_home_sections[<?php echo $esc_key; ?>][limit]" value="<?php echo $esc_limit; ?>" class="small-text">
                                </label>
                                <div data-show="banner" class="dms-banner-picker">
                                    <label>صورة البانر</label>
                                    <input type="text" name="dms_home_sections[<?php echo $esc_key; ?>][image]" value="<?php echo $esc_image; ?>" class="regular-text dms-banner-image" placeholder="https://">
                                    <div class="dms-banner-actions">
                                        <button type="button" class="button dms-banner-select">اختيار صورة</button>
                                        <button type="button" class="button dms-banner-remove" <?php echo $image ? '' : 'style="display:none;"'; ?>>إزالة</button>
                                    </div>
                                    <img class="dms-banner-preview" src="<?php echo $esc_url_image; ?>" alt="" <?php echo $image ? '' : 'style="display:none;"'; ?>>
                                </div>
                                <label data-show="banner">
                                    رابط البانر
                                    <input type="text" name="dms_home_sections[<?php echo $esc_key; ?>][link]" value="<?php echo $esc_link; ?>" class="regular-text" placeholder="https://">
                                </label>
                                <label data-show="home_by_category">
                                    عدد المنتجات لكل تصنيف
                                    <input type="number" min="1" name="dms_home_sections[<?php echo $esc_key; ?>][per_category]" value="<?php echo $esc_pc; ?>" class="small-text">
                                </label>
                                <label data-show="spacer">
                                    ارتفاع المسافة (px)
                                    <input type="number" min="4" name="dms_home_sections[<?php echo $esc_key; ?>][height]" value="<?php echo $esc_height; ?>" class="small-text">
                                </label>
                                <p data-show="featured_products" class="dms-section-note">
                                    ترتيب المنتجات المميزة يتم من صفحة "ترتيب واجهة التطبيق".
                                </p>
                            </div>
                            <input type="hidden" name="dms_home_sections[<?php echo $esc_key; ?>][order]" class="dms-section-order" value="<?php echo function_exists('esc_attr') ? esc_attr($index + 1) : ($index + 1); ?>">
                        </li>
                    <?php endforeach; ?>
                </ul>
                <p>
                    <button type="button" class="button" id="dms-add-section">إضافة قسم</button>
                </p>

                <h2>ألوان التطبيق</h2>
                <p class="description">يمكن تعديل الألوان الرئيسية للتطبيق من هنا بدون تعديل أي كود.</p>
                <div class="dms-theme-grid">
                    <?php
                    $theme_fields = array(
                        'primary' => 'اللون الرئيسي',
                        'primary_dark' => 'لون داكن',
                        'primary_light' => 'لون فاتح',
                        'text_primary' => 'نص أساسي',
                        'text_secondary' => 'نص ثانوي',
                        'text_tertiary' => 'نص خافت',
                        'bg_white' => 'خلفية بيضاء',
                        'bg_light' => 'خلفية رمادية',
                        'border' => 'لون الحدود',
                        'success' => 'نجاح',
                        'warning' => 'تحذير',
                        'error' => 'خطأ',
                        'info' => 'معلومات'
                    );
                    foreach ($theme_fields as $f_key => $f_label):
                        $f_val = function_exists('esc_attr') ? esc_attr($theme[$f_key] ?? '') : ($theme[$f_key] ?? '');
                    ?>
                    <label>
                        <?php echo $f_label; ?>
                        <input type="text" name="dms_app_theme[<?php echo $f_key; ?>]" value="<?php echo $f_val; ?>" class="dms-color-field">
                    </label>
                    <?php endforeach; ?>
                    <label>
                        تفعيل الألوان الديناميكية
                        <input type="checkbox" name="dms_app_theme[enabled]" value="1" <?php if (function_exists('checked')) checked(!empty($theme['enabled'])); ?>>
                    </label>
                </div>

                <?php if (function_exists('submit_button')) submit_button('حفظ الإعدادات'); ?>
            </form>
        </div>

        <script type="text/html" id="dms-section-template">
            <li class="dms-home-section" data-key="{{key}}">
                <div class="dms-home-section-head">
                    <span class="dashicons dashicons-move dms-home-section-handle"></span>
                    <strong class="dms-section-type-label">قسم</strong>
                    <button type="button" class="button-link-delete dms-remove-section">إزالة</button>
                </div>
                <div class="dms-home-section-body">
                    <label>
                        نوع القسم
                        <select name="dms_home_sections[{{key}}][type]" class="dms-section-type">
                            <?php foreach ($labels as $value => $label): ?>
                                <option value="<?php echo function_exists('esc_attr') ? esc_attr($value) : $value; ?>"><?php echo function_exists('esc_html') ? esc_html($label) : $label; ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label>
                        العنوان
                        <input type="text" name="dms_home_sections[{{key}}][title]" value="" class="regular-text">
                    </label>
                    <label data-show="categories,brands,products,latest_products,featured_products">
                        الحد الأقصى
                        <input type="number" min="1" name="dms_home_sections[{{key}}][limit]" value="" class="small-text">
                    </label>
                    <div data-show="banner" class="dms-banner-picker">
                        <label>صورة البانر</label>
                        <input type="text" name="dms_home_sections[{{key}}][image]" value="" class="regular-text dms-banner-image" placeholder="https://">
                        <div class="dms-banner-actions">
                            <button type="button" class="button dms-banner-select">اختيار صورة</button>
                            <button type="button" class="button dms-banner-remove" style="display:none;">إزالة</button>
                        </div>
                        <img class="dms-banner-preview" src="" alt="" style="display:none;">
                    </div>
                    <label data-show="banner">
                        رابط البانر
                        <input type="text" name="dms_home_sections[{{key}}][link]" value="" class="regular-text" placeholder="https://">
                    </label>
                    <label data-show="home_by_category">
                        عدد المنتجات لكل تصنيف
                        <input type="number" min="1" name="dms_home_sections[{{key}}][per_category]" value="6" class="small-text">
                    </label>
                    <label data-show="spacer">
                        ارتفاع المسافة (px)
                        <input type="number" min="4" name="dms_home_sections[{{key}}][height]" value="16" class="small-text">
                    </label>
                    <p data-show="featured_products" class="dms-section-note">
                        ترتيب المنتجات المميزة يتم من صفحة "ترتيب واجهة التطبيق".
                    </p>
                </div>
                <input type="hidden" name="dms_home_sections[{{key}}][order]" class="dms-section-order" value="{{order}}">
            </li>
        </script>
        <?php
    }
}

if (!function_exists('dms_app_home_layout_get')) {
    function dms_app_home_layout_get() {
        $raw = function_exists('get_option') ? get_option(DMS_APP_HOME_LAYOUT_OPTION, '') : '';
        $version = function_exists('get_option') ? get_option(DMS_APP_HOME_LAYOUT_VERSION_OPTION, '1.0.0') : '1.0.0';
        $ttl = function_exists('get_option') ? intval(get_option(DMS_APP_HOME_LAYOUT_TTL_OPTION, 3600)) : 3600;
        $decoded = json_decode($raw, true);
        if (!is_array($decoded) || empty($decoded['sections']) || !is_array($decoded['sections'])) {
            return array(
                'version' => $version,
                'cache_ttl' => $ttl ?: 3600,
                'sections' => function_exists('dms_app_home_layout_default_sections') ? dms_app_home_layout_default_sections() : array(),
                'raw' => function_exists('dms_app_home_layout_default_json') ? dms_app_home_layout_default_json() : '',
                'updated_at' => ''
            );
        }
        return array(
            'version' => $version,
            'cache_ttl' => $ttl ?: 3600,
            'sections' => $decoded['sections'],
            'raw' => $raw,
            'updated_at' => isset($decoded['updated_at']) ? (function_exists('sanitize_text_field') ? sanitize_text_field($decoded['updated_at']) : $decoded['updated_at']) : ''
        );
    }
}

if (!function_exists('dms_app_home_layout_save')) {
    function dms_app_home_layout_save($input) {
        $sections = dms_app_home_layout_sanitize_sections($input['sections'] ?? array());
        if (empty($sections)) {
            $sections = dms_app_home_layout_default_sections();
        }

        $version = isset($input['version'])
            ? sanitize_text_field((string) $input['version'])
            : ((function_exists('get_option') ? get_option(DMS_APP_HOME_LAYOUT_VERSION_OPTION, '1.0.0') : '1.0.0'));
        if ($version === '') {
            $version = '1.0.0';
        }

        $cache_ttl = isset($input['cache_ttl']) ? intval($input['cache_ttl']) : 3600;
        if ($cache_ttl <= 0) {
            $cache_ttl = 3600;
        }

        $payload = array(
            'sections' => $sections,
            'updated_at' => function_exists('current_time') ? current_time('c') : date('c'),
        );

        if (function_exists('update_option')) {
            if (function_exists('wp_json_encode')) {
                update_option(DMS_APP_HOME_LAYOUT_OPTION, wp_json_encode($payload, JSON_UNESCAPED_UNICODE), false);
            } else {
                update_option(DMS_APP_HOME_LAYOUT_OPTION, json_encode($payload), false);
            }
            update_option(DMS_APP_HOME_LAYOUT_VERSION_OPTION, $version, false);
            update_option(DMS_APP_HOME_LAYOUT_TTL_OPTION, $cache_ttl, false);
        }

        return dms_app_home_layout_get();
    }
}

if (!function_exists('dms_app_home_layout_default_json')) {
    function dms_app_home_layout_default_json() {
        return function_exists('wp_json_encode') ? wp_json_encode(
            array('sections' => dms_app_home_layout_default_sections()),
            JSON_UNESCAPED_UNICODE
        ) : json_encode(array('sections' => dms_app_home_layout_default_sections()));
    }
}

if (function_exists('add_action')) {
    add_action('rest_api_init', function () {
        if (function_exists('register_rest_route')) {
            register_rest_route('dms/v1', '/app/home-layout', array(
                'methods' => 'GET',
                'callback' => function () {
                    $layout = dms_app_home_layout_get();
                    $layout_config = function_exists('lpco_app_layout_config_get')
                        ? lpco_app_layout_config_get()
                        : array(
                            'categories' => array(),
                            'brands' => array(),
                            'featured_products' => array(),
                            'updated_at' => ''
                        );
                    $payload = array(
                        'version' => $layout['version'],
                        'cache_ttl' => $layout['cache_ttl'],
                        'sections' => $layout['sections'],
                        'layout_config' => $layout_config,
                        'updated_at' => $layout['updated_at']
                    );
                    if (function_exists('dms_send_cache_headers') && function_exists('wp_json_encode')) {
                        dms_send_cache_headers('home_layout_' . md5(wp_json_encode($payload)));
                    }
                    return $payload;
                },
                'permission_callback' => '__return_true'
            ));

            register_rest_route('dms/v1', '/app/theme', array(
                'methods' => 'GET',
                'callback' => function () {
                    $theme = dms_app_theme_get();
                    if (empty($theme['enabled'])) {
                        return array('enabled' => false);
                    }
                    $colors = $theme;
                    unset($colors['enabled']);
                    $updated_at = isset($colors['updated_at']) ? $colors['updated_at'] : '';
                    unset($colors['updated_at']);
                    return array(
                        'enabled' => true,
                        'colors' => $colors,
                        'updated_at' => $updated_at
                    );
                },
                'permission_callback' => '__return_true'
            ));
        }
    });
}
