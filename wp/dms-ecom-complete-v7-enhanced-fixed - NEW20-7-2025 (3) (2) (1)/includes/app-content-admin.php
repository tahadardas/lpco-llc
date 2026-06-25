<?php
/**
 * Canonical WordPress editor for app banners and home product sections.
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!function_exists('lpco_app_content_admin_capability')) {
    function lpco_app_content_admin_capability() {
        return current_user_can('manage_woocommerce') ? 'manage_woocommerce' : 'manage_options';
    }
}

if (!function_exists('lpco_app_content_admin_register_menu')) {
    function lpco_app_content_admin_register_menu() {
        add_submenu_page(
            'dms-app-main',
            'محتوى الصفحة الرئيسية',
            'محتوى الصفحة الرئيسية',
            lpco_app_content_admin_capability(),
            'lpco-app-content',
            'lpco_app_content_admin_render'
        );
    }
}
add_action('admin_menu', 'lpco_app_content_admin_register_menu', 30);

if (!function_exists('lpco_app_content_admin_products')) {
    function lpco_app_content_admin_products() {
        if (!function_exists('wc_get_products')) {
            return array();
        }

        return wc_get_products(array(
            'limit' => -1,
            'status' => 'publish',
            'orderby' => 'title',
            'order' => 'ASC',
            'return' => 'objects',
        ));
    }
}

if (!function_exists('lpco_app_content_admin_parse_ids')) {
    function lpco_app_content_admin_parse_ids($value) {
        if (is_array($value)) {
            return lpco_app_layout_normalize_ids($value);
        }

        $value = sanitize_text_field(wp_unslash((string) $value));
        return lpco_app_layout_normalize_ids(array_filter(array_map('trim', explode(',', $value))));
    }
}

if (!function_exists('lpco_app_content_admin_save')) {
    function lpco_app_content_admin_save() {
        if (
            empty($_POST['lpco_app_content_nonce'])
            || !wp_verify_nonce(
                sanitize_text_field(wp_unslash($_POST['lpco_app_content_nonce'])),
                'lpco_app_content_save'
            )
        ) {
            return new WP_Error('invalid_nonce', 'تعذر التحقق من طلب الحفظ.');
        }

        $raw_banners = isset($_POST['banners']) && is_array($_POST['banners'])
            ? wp_unslash($_POST['banners'])
            : array();
        $banner_items = array();

        foreach (array_values($raw_banners) as $index => $raw_banner) {
            if (!is_array($raw_banner)) {
                continue;
            }

            $banner_items[] = array(
                'id' => sanitize_text_field((string) ($raw_banner['id'] ?? ('banner-' . ($index + 1)))),
                'enabled' => !empty($raw_banner['enabled']),
                'image_id' => absint($raw_banner['image_id'] ?? 0),
                'image_url' => esc_url_raw((string) ($raw_banner['image_url'] ?? '')),
                'title' => sanitize_text_field((string) ($raw_banner['title'] ?? '')),
                'subtitle' => sanitize_text_field((string) ($raw_banner['subtitle'] ?? '')),
                'button_label' => sanitize_text_field((string) ($raw_banner['button_label'] ?? '')),
                'button_link' => esc_url_raw((string) ($raw_banner['button_link'] ?? '')),
                'action_type' => sanitize_text_field((string) ($raw_banner['action_type'] ?? 'none')),
                'action_value' => sanitize_text_field((string) ($raw_banner['action_value'] ?? '')),
                'sort_order' => $index,
                'starts_at' => sanitize_text_field((string) ($raw_banner['starts_at'] ?? '')),
                'ends_at' => sanitize_text_field((string) ($raw_banner['ends_at'] ?? '')),
                'product_ids' => lpco_app_content_admin_parse_ids($raw_banner['product_ids'] ?? ''),
                'show_title' => !empty($raw_banner['show_title']),
                'show_subtitle' => !empty($raw_banner['show_subtitle']),
                'show_button' => !empty($raw_banner['show_button']),
                'content_alignment' => sanitize_key((string) ($raw_banner['content_alignment'] ?? 'start')),
                'content_vertical_alignment' => sanitize_key((string) ($raw_banner['content_vertical_alignment'] ?? 'center')),
                'image_fit' => sanitize_key((string) ($raw_banner['image_fit'] ?? 'cover')),
                'overlay_opacity' => intval($raw_banner['overlay_opacity'] ?? 60),
                'title_color' => sanitize_hex_color((string) ($raw_banner['title_color'] ?? '#FFFFFF')),
                'subtitle_color' => sanitize_hex_color((string) ($raw_banner['subtitle_color'] ?? '#FFFFFF')),
                'button_background_color' => sanitize_hex_color((string) ($raw_banner['button_background_color'] ?? '#D31225')),
                'button_text_color' => sanitize_hex_color((string) ($raw_banner['button_text_color'] ?? '#FFFFFF')),
            );
        }

        $saved_banners = dms_app_home_banners_save(array('items' => $banner_items));

        $layout = lpco_app_layout_config_get();
        $saved_layout = lpco_app_layout_config_save(array(
            'categories' => $layout['categories'],
            'brands' => $layout['brands'],
            'hidden_categories' => $layout['hidden_categories'],
            'hidden_brands' => $layout['hidden_brands'],
            'slider_products' => lpco_app_content_admin_parse_ids($_POST['slider_products'] ?? ''),
            'featured_products' => lpco_app_content_admin_parse_ids($_POST['featured_products'] ?? ''),
            'latest_products' => lpco_app_content_admin_parse_ids($_POST['latest_products'] ?? ''),
            'latest_mode' => isset($_POST['latest_mode']) && $_POST['latest_mode'] === 'manual'
                ? 'manual'
                : 'auto',
        ));

        $verified_banners = dms_app_home_banners_get();
        $verified_layout = lpco_app_layout_config_get();
        if (
            ($verified_banners['revision'] ?? '') !== ($saved_banners['revision'] ?? '')
            || ($verified_layout['revision'] ?? '') !== ($saved_layout['revision'] ?? '')
        ) {
            return new WP_Error('persistence_failed', 'تم إرسال الحفظ لكن تعذر التحقق من البيانات المخزنة.');
        }

        return array(
            'banners' => $verified_banners,
            'layout' => $verified_layout,
        );
    }
}

if (!function_exists('lpco_app_content_admin_render_product_picker')) {
    function lpco_app_content_admin_render_product_picker($key, $title, $selected_ids, $products) {
        $selected_ids = lpco_app_layout_normalize_ids($selected_ids);
        $products_by_id = array();
        foreach ($products as $product) {
            $products_by_id[$product->get_id()] = $product;
        }
        ?>
        <section class="lpco-content-card">
            <h2><?php echo esc_html($title); ?></h2>
            <input
                type="hidden"
                id="lpco-<?php echo esc_attr($key); ?>-input"
                name="<?php echo esc_attr($key); ?>"
                value="<?php echo esc_attr(implode(',', $selected_ids)); ?>"
            >
            <div class="lpco-product-picker" data-input="#lpco-<?php echo esc_attr($key); ?>-input">
                <div>
                    <h3>المختارة داخل التطبيق</h3>
                    <ul class="lpco-selected-products">
                        <?php foreach ($selected_ids as $product_id): ?>
                            <?php if (empty($products_by_id[$product_id])) continue; ?>
                            <li data-id="<?php echo esc_attr($product_id); ?>">
                                <span class="dashicons dashicons-move"></span>
                                <strong><?php echo esc_html($products_by_id[$product_id]->get_name()); ?></strong>
                                <small>#<?php echo esc_html($product_id); ?></small>
                                <button type="button" class="button-link-delete lpco-remove-product">إزالة</button>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                    <p class="lpco-empty-selected" <?php echo empty($selected_ids) ? '' : 'hidden'; ?>>
                        لا توجد منتجات مختارة.
                    </p>
                </div>
                <div>
                    <h3>إضافة منتج</h3>
                    <input type="search" class="regular-text lpco-product-search" placeholder="ابحث بالاسم أو ID">
                    <div class="lpco-product-results">
                        <?php foreach ($products as $product): ?>
                            <?php
                            $product_id = $product->get_id();
                            $selected = in_array($product_id, $selected_ids, true);
                            ?>
                            <button
                                type="button"
                                class="button lpco-add-product"
                                data-id="<?php echo esc_attr($product_id); ?>"
                                data-title="<?php echo esc_attr($product->get_name()); ?>"
                                <?php echo $selected ? 'hidden' : ''; ?>
                            >
                                إضافة <?php echo esc_html($product->get_name()); ?> (#<?php echo esc_html($product_id); ?>)
                            </button>
                        <?php endforeach; ?>
                    </div>
                </div>
            </div>
        </section>
        <?php
    }
}

if (!function_exists('lpco_app_content_admin_render_banner')) {
    function lpco_app_content_admin_render_banner($banner, $index) {
        $image_url = (string) ($banner['image_url'] ?? '');
        if (!empty($banner['image_id'])) {
            $media_url = wp_get_attachment_image_url(absint($banner['image_id']), 'medium');
            if ($media_url) {
                $image_url = $media_url;
            }
        }
        ?>
        <article class="lpco-banner-card">
            <div class="lpco-banner-head">
                <span class="dashicons dashicons-move lpco-banner-handle"></span>
                <strong>بانر <span class="lpco-banner-number"><?php echo esc_html($index + 1); ?></span></strong>
                <button type="button" class="button-link-delete lpco-remove-banner">حذف البانر</button>
            </div>
            <input type="hidden" data-name="id" value="<?php echo esc_attr($banner['id'] ?? ''); ?>">
            <input type="hidden" class="lpco-banner-image-id" data-name="image_id" value="<?php echo esc_attr($banner['image_id'] ?? 0); ?>">
            <input type="hidden" class="lpco-banner-image-url" data-name="image_url" value="<?php echo esc_attr($banner['image_url'] ?? ''); ?>">
            <div class="lpco-banner-grid">
                <label class="lpco-checkbox">
                    <input type="checkbox" data-name="enabled" value="1" <?php checked(!empty($banner['enabled'])); ?>>
                    مفعّل ويظهر للأعضاء
                </label>
                <label class="lpco-checkbox">
                    <input type="checkbox" data-name="show_title" value="1" <?php checked(!array_key_exists('show_title', $banner) || !empty($banner['show_title'])); ?>>
                    إظهار العنوان
                </label>
                <label class="lpco-checkbox">
                    <input type="checkbox" data-name="show_subtitle" value="1" <?php checked(!array_key_exists('show_subtitle', $banner) || !empty($banner['show_subtitle'])); ?>>
                    إظهار الوصف
                </label>
                <label class="lpco-checkbox">
                    <input type="checkbox" data-name="show_button" value="1" <?php checked(!array_key_exists('show_button', $banner) || !empty($banner['show_button'])); ?>>
                    إظهار زر الإجراء
                </label>
                <label>العنوان<input type="text" data-name="title" value="<?php echo esc_attr($banner['title'] ?? ''); ?>" placeholder="اتركه فارغًا لبانر صورة فقط"></label>
                <label>الوصف<input type="text" data-name="subtitle" value="<?php echo esc_attr($banner['subtitle'] ?? ''); ?>" placeholder="اختياري"></label>
                <label>نص الزر<input type="text" data-name="button_label" value="<?php echo esc_attr($banner['button_label'] ?? ''); ?>" placeholder="اختياري"></label>
                <label>
                    نوع الإجراء
                    <select data-name="action_type">
                        <?php
                        $actions = array(
                            'none' => 'بدون إجراء',
                            'category' => 'فتح تصنيف',
                            'brand' => 'فتح علامة تجارية',
                            'product' => 'فتح منتج',
                            'search' => 'بحث',
                            'internalRoute' => 'مسار داخل التطبيق',
                            'externalUrl' => 'رابط خارجي',
                        );
                        foreach ($actions as $value => $label):
                        ?>
                            <option value="<?php echo esc_attr($value); ?>" <?php selected($banner['action_type'] ?? 'none', $value); ?>>
                                <?php echo esc_html($label); ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label>قيمة الإجراء<input type="text" data-name="action_value" list="lpco-app-action-values" value="<?php echo esc_attr($banner['action_value'] ?? ''); ?>" placeholder="slug أو ID أو نص البحث"></label>
                <label>رابط احتياطي<input type="url" data-name="button_link" value="<?php echo esc_attr($banner['button_link'] ?? ''); ?>" placeholder="https://"></label>
                <label>منتجات البانر<input type="text" data-name="product_ids" value="<?php echo esc_attr(implode(',', (array) ($banner['product_ids'] ?? array()))); ?>" placeholder="101,102"></label>
                <label>يبدأ في<input type="datetime-local" data-name="starts_at" value="<?php echo esc_attr($banner['starts_at'] ?? ''); ?>"></label>
                <label>ينتهي في<input type="datetime-local" data-name="ends_at" value="<?php echo esc_attr($banner['ends_at'] ?? ''); ?>"></label>
                <label>
                    محاذاة المحتوى
                    <select data-name="content_alignment">
                        <option value="start" <?php selected($banner['content_alignment'] ?? 'start', 'start'); ?>>بداية السطر</option>
                        <option value="center" <?php selected($banner['content_alignment'] ?? 'start', 'center'); ?>>وسط</option>
                        <option value="end" <?php selected($banner['content_alignment'] ?? 'start', 'end'); ?>>نهاية السطر</option>
                    </select>
                </label>
                <label>
                    موضع المحتوى عموديًا
                    <select data-name="content_vertical_alignment">
                        <option value="top" <?php selected($banner['content_vertical_alignment'] ?? 'center', 'top'); ?>>أعلى</option>
                        <option value="center" <?php selected($banner['content_vertical_alignment'] ?? 'center', 'center'); ?>>وسط</option>
                        <option value="bottom" <?php selected($banner['content_vertical_alignment'] ?? 'center', 'bottom'); ?>>أسفل</option>
                    </select>
                </label>
                <label>
                    ملاءمة الصورة
                    <select data-name="image_fit">
                        <option value="cover" <?php selected($banner['image_fit'] ?? 'cover', 'cover'); ?>>ملء مساحة البانر</option>
                        <option value="contain" <?php selected($banner['image_fit'] ?? 'cover', 'contain'); ?>>إظهار الصورة كاملة</option>
                    </select>
                </label>
                <label>تعتيم الخلفية (0–100)<input type="number" min="0" max="100" data-name="overlay_opacity" value="<?php echo esc_attr($banner['overlay_opacity'] ?? 60); ?>"></label>
                <label>لون العنوان<input type="color" data-name="title_color" value="<?php echo esc_attr($banner['title_color'] ?? '#FFFFFF'); ?>"></label>
                <label>لون الوصف<input type="color" data-name="subtitle_color" value="<?php echo esc_attr($banner['subtitle_color'] ?? '#FFFFFF'); ?>"></label>
                <label>لون خلفية الزر<input type="color" data-name="button_background_color" value="<?php echo esc_attr($banner['button_background_color'] ?? '#D31225'); ?>"></label>
                <label>لون نص الزر<input type="color" data-name="button_text_color" value="<?php echo esc_attr($banner['button_text_color'] ?? '#FFFFFF'); ?>"></label>
            </div>
            <div class="lpco-banner-media">
                <img class="lpco-banner-preview" src="<?php echo esc_url($image_url); ?>" alt="" <?php echo $image_url ? '' : 'hidden'; ?>>
                <button type="button" class="button lpco-select-banner-image">اختيار صورة من مكتبة الوسائط</button>
                <button type="button" class="button lpco-clear-banner-image" <?php echo $image_url ? '' : 'hidden'; ?>>إزالة الصورة</button>
            </div>
        </article>
        <?php
    }
}

if (!function_exists('lpco_app_content_admin_render')) {
    function lpco_app_content_admin_render() {
        if (!current_user_can('manage_woocommerce') && !current_user_can('manage_options')) {
            wp_die('ليس لديك صلاحية للوصول إلى هذه الصفحة.', 403);
        }

        $notice = '';
        $error = '';
        if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['lpco_app_content_submit'])) {
            $result = lpco_app_content_admin_save();
            if (is_wp_error($result)) {
                $error = $result->get_error_message();
            } else {
                $notice = 'تم الحفظ والتحقق بنجاح. هذه البيانات أصبحت المصدر المركزي لكل أعضاء التطبيق.';
            }
        }

        $banners = dms_app_home_banners_get();
        $layout = lpco_app_layout_config_get();
        $products = lpco_app_content_admin_products();
        $categories = taxonomy_exists('product_cat')
            ? get_terms(array('taxonomy' => 'product_cat', 'hide_empty' => false))
            : array();
        $brand_taxonomy = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
        $brands = taxonomy_exists($brand_taxonomy)
            ? get_terms(array('taxonomy' => $brand_taxonomy, 'hide_empty' => false))
            : array();
        ?>
        <div class="wrap lpco-app-content-wrap" dir="rtl">
            <h1>محتوى الصفحة الرئيسية للتطبيق</h1>
            <p class="description">
                هذه الصفحة تحفظ مباشرة في WordPress. تطبيق Flutter يقرأ نفس البيانات عبر
                <code>/home-banners</code> و<code>/app/home-layout</code>، لذلك يشاهدها جميع الأعضاء.
            </p>
            <?php if ($notice): ?><div class="notice notice-success"><p><?php echo esc_html($notice); ?></p></div><?php endif; ?>
            <?php if ($error): ?><div class="notice notice-error"><p><?php echo esc_html($error); ?></p></div><?php endif; ?>

            <form method="post" id="lpco-app-content-form">
                <?php wp_nonce_field('lpco_app_content_save', 'lpco_app_content_nonce'); ?>

                <section class="lpco-content-card">
                    <div class="lpco-section-head">
                        <div>
                            <h2>البانرات</h2>
                            <p>أضف أو احذف أو رتّب البانرات. تعطيل الجميع يعيد قائمة فارغة للتطبيق.</p>
                        </div>
                        <button type="button" class="button button-primary" id="lpco-add-banner">إضافة بانر</button>
                    </div>
                    <div id="lpco-banner-list">
                        <?php foreach ((array) ($banners['items'] ?? array()) as $index => $banner): ?>
                            <?php lpco_app_content_admin_render_banner($banner, $index); ?>
                        <?php endforeach; ?>
                    </div>
                    <p id="lpco-no-banners" <?php echo empty($banners['items']) ? '' : 'hidden'; ?>>لا توجد بانرات حاليًا.</p>
                </section>

                <?php
                lpco_app_content_admin_render_product_picker(
                    'slider_products',
                    'منتجات السلايدر',
                    $layout['slider_products'],
                    $products
                );
                lpco_app_content_admin_render_product_picker(
                    'featured_products',
                    'المنتجات المميزة',
                    $layout['featured_products'],
                    $products
                );
                ?>

                <section class="lpco-content-card">
                    <h2>أحدث المنتجات</h2>
                    <label>
                        طريقة العرض
                        <select name="latest_mode" id="lpco-latest-mode">
                            <option value="auto" <?php selected($layout['latest_mode'], 'auto'); ?>>تلقائي حسب تاريخ الإضافة في WooCommerce</option>
                            <option value="manual" <?php selected($layout['latest_mode'], 'manual'); ?>>اختيار يدوي</option>
                        </select>
                    </label>
                </section>

                <div id="lpco-latest-manual">
                    <?php
                    lpco_app_content_admin_render_product_picker(
                        'latest_products',
                        'أحدث المنتجات المختارة يدويًا',
                        $layout['latest_products'],
                        $products
                    );
                    ?>
                </div>

                <p class="submit">
                    <button type="submit" name="lpco_app_content_submit" value="1" class="button button-primary button-hero">
                        حفظ ونشر لجميع الأعضاء
                    </button>
                </p>
            </form>
            <datalist id="lpco-app-action-values">
                <?php if (!is_wp_error($categories)): ?>
                    <?php foreach ($categories as $category): ?>
                        <option value="<?php echo esc_attr($category->slug); ?>">
                            تصنيف: <?php echo esc_html($category->name); ?>
                        </option>
                    <?php endforeach; ?>
                <?php endif; ?>
                <?php if (!is_wp_error($brands)): ?>
                    <?php foreach ($brands as $brand): ?>
                        <option value="<?php echo esc_attr($brand->slug); ?>">
                            علامة: <?php echo esc_html($brand->name); ?>
                        </option>
                    <?php endforeach; ?>
                <?php endif; ?>
                <?php foreach ($products as $product): ?>
                    <option value="<?php echo esc_attr($product->get_id()); ?>">
                        منتج: <?php echo esc_html($product->get_name()); ?>
                    </option>
                <?php endforeach; ?>
            </datalist>
        </div>

        <script type="text/html" id="lpco-banner-template">
            <?php
            lpco_app_content_admin_render_banner(array(
                'id' => '',
                'enabled' => true,
                'image_id' => 0,
                'image_url' => '',
                'title' => '',
                'subtitle' => '',
                'button_label' => 'تسوق الآن',
                'button_link' => '',
                'action_type' => 'none',
                'action_value' => '',
                'sort_order' => 0,
                'starts_at' => '',
                'ends_at' => '',
                'product_ids' => array(),
                'show_title' => true,
                'show_subtitle' => true,
                'show_button' => true,
                'content_alignment' => 'start',
                'content_vertical_alignment' => 'center',
                'image_fit' => 'cover',
                'overlay_opacity' => 60,
                'title_color' => '#FFFFFF',
                'subtitle_color' => '#FFFFFF',
                'button_background_color' => '#D31225',
                'button_text_color' => '#FFFFFF',
            ), 0);
            ?>
        </script>
        <?php
    }
}

if (!function_exists('lpco_app_content_admin_assets')) {
    function lpco_app_content_admin_assets() {
        $page = isset($_GET['page']) ? sanitize_key(wp_unslash($_GET['page'])) : '';
        if ($page !== 'lpco-app-content') {
            return;
        }

        wp_enqueue_media();
        wp_enqueue_script('jquery-ui-sortable');
        wp_add_inline_style('wp-admin', '
            .lpco-app-content-wrap{max-width:1280px;text-align:right}
            .lpco-content-card{background:#fff;border:1px solid #dcdcde;border-radius:10px;padding:18px;margin:18px 0}
            .lpco-content-card h2{margin-top:0}
            .lpco-section-head,.lpco-banner-head{display:flex;align-items:center;justify-content:space-between;gap:12px}
            .lpco-banner-card{border:1px solid #dcdcde;border-radius:8px;padding:14px;margin:12px 0;background:#fafafa}
            .lpco-banner-head{cursor:move;margin-bottom:14px}
            .lpco-banner-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px}
            .lpco-banner-grid label{display:flex;flex-direction:column;gap:5px;font-weight:600}
            .lpco-banner-grid input,.lpco-banner-grid select{width:100%}
            .lpco-banner-grid .lpco-checkbox{flex-direction:row;align-items:center}
            .lpco-banner-grid .lpco-checkbox input{width:auto}
            .lpco-banner-media{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:14px}
            .lpco-banner-preview{width:180px;max-height:100px;object-fit:cover;border-radius:6px;border:1px solid #dcdcde}
            .lpco-product-picker{display:grid;grid-template-columns:1fr 1fr;gap:18px}
            .lpco-selected-products{list-style:none;margin:0;padding:0;min-height:44px}
            .lpco-selected-products li{display:flex;align-items:center;gap:8px;padding:9px;border:1px solid #dcdcde;border-radius:6px;background:#fafafa;margin-bottom:7px;cursor:move}
            .lpco-selected-products strong{flex:1}
            .lpco-product-results{max-height:330px;overflow:auto;display:flex;flex-direction:column;gap:6px;margin-top:10px}
            .lpco-product-results .button{text-align:right;white-space:normal}
            @media(max-width:782px){.lpco-product-picker{grid-template-columns:1fr}}
        ');

        wp_add_inline_script('jquery-ui-sortable', "
            jQuery(function($) {
                function syncPicker(picker) {
                    var ids = picker.find('.lpco-selected-products li').map(function() {
                        return $(this).data('id');
                    }).get();
                    $(picker.data('input')).val(ids.join(','));
                    picker.find('.lpco-empty-selected').prop('hidden', ids.length > 0);
                }

                function syncBanners() {
                    $('#lpco-banner-list .lpco-banner-card').each(function(index) {
                        var card = $(this);
                        card.find('.lpco-banner-number').text(index + 1);
                        card.find('[data-name]').each(function() {
                            $(this).attr('name', 'banners[' + index + '][' + $(this).data('name') + ']');
                        });
                        var id = card.find('[data-name=\"id\"]');
                        if (!id.val()) id.val('banner-' + Date.now() + '-' + index);
                    });
                    $('#lpco-no-banners').prop('hidden', $('#lpco-banner-list .lpco-banner-card').length > 0);
                }

                $('.lpco-selected-products').sortable({
                    handle: '.dashicons-move',
                    update: function() { syncPicker($(this).closest('.lpco-product-picker')); }
                });
                $('#lpco-banner-list').sortable({handle: '.lpco-banner-head', update: syncBanners});

                $(document).on('click', '.lpco-add-product', function() {
                    var button = $(this);
                    var picker = button.closest('.lpco-product-picker');
                    var item = $('<li>').attr('data-id', button.data('id'))
                        .append('<span class=\"dashicons dashicons-move\"></span>')
                        .append($('<strong>').text(button.data('title')))
                        .append($('<small>').text('#' + button.data('id')))
                        .append('<button type=\"button\" class=\"button-link-delete lpco-remove-product\">إزالة</button>');
                    picker.find('.lpco-selected-products').append(item);
                    button.prop('hidden', true);
                    syncPicker(picker);
                });

                $(document).on('click', '.lpco-remove-product', function() {
                    var item = $(this).closest('li');
                    var picker = item.closest('.lpco-product-picker');
                    picker.find('.lpco-add-product[data-id=\"' + item.data('id') + '\"]').prop('hidden', false);
                    item.remove();
                    syncPicker(picker);
                });

                $('.lpco-product-search').on('input', function() {
                    var query = $(this).val().toLowerCase();
                    $(this).closest('.lpco-product-picker').find('.lpco-add-product').each(function() {
                        var button = $(this);
                        if (button.prop('hidden')) return;
                        button.toggle(button.text().toLowerCase().indexOf(query) !== -1);
                    });
                });

                $('#lpco-add-banner').on('click', function() {
                    $('#lpco-banner-list').append($('#lpco-banner-template').html());
                    syncBanners();
                });
                $(document).on('click', '.lpco-remove-banner', function() {
                    $(this).closest('.lpco-banner-card').remove();
                    syncBanners();
                });

                $(document).on('click', '.lpco-select-banner-image', function() {
                    var card = $(this).closest('.lpco-banner-card');
                    var frame = wp.media({title:'اختيار صورة البانر',button:{text:'استخدام الصورة'},multiple:false});
                    frame.on('select', function() {
                        var image = frame.state().get('selection').first().toJSON();
                        card.find('.lpco-banner-image-id').val(image.id);
                        card.find('.lpco-banner-image-url').val(image.url);
                        card.find('.lpco-banner-preview').attr('src', image.url).prop('hidden', false);
                        card.find('.lpco-clear-banner-image').prop('hidden', false);
                    });
                    frame.open();
                });
                $(document).on('click', '.lpco-clear-banner-image', function() {
                    var card = $(this).closest('.lpco-banner-card');
                    card.find('.lpco-banner-image-id,.lpco-banner-image-url').val('');
                    card.find('.lpco-banner-preview').attr('src', '').prop('hidden', true);
                    $(this).prop('hidden', true);
                });

                function toggleLatest() {
                    $('#lpco-latest-manual').toggle($('#lpco-latest-mode').val() === 'manual');
                }
                $('#lpco-latest-mode').on('change', toggleLatest);
                toggleLatest();
                syncBanners();
                $('.lpco-product-picker').each(function(){ syncPicker($(this)); });
            });
        ");
    }
}
add_action('admin_enqueue_scripts', 'lpco_app_content_admin_assets');
