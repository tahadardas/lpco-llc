<?php
/**
 * LPCO App Layout Control Panel
 * Manage ordering for categories, brands, and featured products.
 */

if (!defined('ABSPATH')) {
    exit;
}

define('LPCO_APP_LAYOUT_CONFIG_OPTION', 'lpco_app_layout_config');

if (!function_exists('lpco_app_layout_config_defaults')) {
/**
 * Default layout config.
 */
function lpco_app_layout_config_defaults() {
    return array(
        'categories' => array(),
        'brands' => array(),
        'hidden_categories' => array(),
        'hidden_brands' => array(),
        'featured_products' => array(),
        'updated_at' => ''
    );
}
}

if (!function_exists('lpco_app_layout_normalize_ids')) {
/**
 * Normalize array of ids.
 */
function lpco_app_layout_normalize_ids($ids) {
    if (!is_array($ids)) {
        $ids = array();
    }
    $ids = function_exists('absint') ? array_map('absint', $ids) : array_map('intval', $ids);
    $ids = array_filter($ids);
    $ids = array_values(array_unique($ids));
    return $ids;
}
}

if (!function_exists('lpco_app_layout_config_get')) {
/**
 * Get layout config from options.
 */
function lpco_app_layout_config_get() {
    $stored = function_exists('get_option') ? get_option(LPCO_APP_LAYOUT_CONFIG_OPTION, array()) : array();
    if (!is_array($stored)) {
        $stored = array();
    }
    $config = function_exists('wp_parse_args') ? wp_parse_args($stored, lpco_app_layout_config_defaults()) : array_merge(lpco_app_layout_config_defaults(), $stored);
    $config['categories'] = lpco_app_layout_normalize_ids($config['categories']);
    $config['brands'] = lpco_app_layout_normalize_ids($config['brands']);
    $config['hidden_categories'] = lpco_app_layout_normalize_ids($config['hidden_categories']);
    $config['hidden_brands'] = lpco_app_layout_normalize_ids($config['hidden_brands']);
    $config['featured_products'] = lpco_app_layout_normalize_ids($config['featured_products']);
    $config['updated_at'] = isset($config['updated_at']) ? (function_exists('sanitize_text_field') ? sanitize_text_field($config['updated_at']) : $config['updated_at']) : '';
    return $config;
}
}

if (!function_exists('lpco_app_layout_config_save')) {
/**
 * Save layout config.
 */
function lpco_app_layout_config_save($input) {
    $config = lpco_app_layout_config_defaults();
    $existing = lpco_app_layout_config_get();
    $config['categories'] = array_key_exists('categories', $input)
        ? lpco_app_layout_normalize_ids($input['categories'])
        : lpco_app_layout_normalize_ids($existing['categories'] ?? array());
    $config['brands'] = array_key_exists('brands', $input)
        ? lpco_app_layout_normalize_ids($input['brands'])
        : lpco_app_layout_normalize_ids($existing['brands'] ?? array());
    $config['hidden_categories'] = array_key_exists('hidden_categories', $input)
        ? lpco_app_layout_normalize_ids($input['hidden_categories'])
        : lpco_app_layout_normalize_ids($existing['hidden_categories'] ?? array());
    $config['hidden_brands'] = array_key_exists('hidden_brands', $input)
        ? lpco_app_layout_normalize_ids($input['hidden_brands'])
        : lpco_app_layout_normalize_ids($existing['hidden_brands'] ?? array());
    $config['featured_products'] = array_key_exists('featured_products', $input)
        ? lpco_app_layout_normalize_ids($input['featured_products'])
        : lpco_app_layout_normalize_ids($existing['featured_products'] ?? array());
    $config['updated_at'] = function_exists('current_time') ? current_time('c') : date('c');
    if (function_exists('update_option')) {
        update_option(LPCO_APP_LAYOUT_CONFIG_OPTION, $config, false);
    }
    return $config;
}
}

if (!function_exists('lpco_app_layout_hidden_key_for_taxonomy')) {
/**
 * Resolve config key for app-hidden terms by taxonomy.
 */
function lpco_app_layout_hidden_key_for_taxonomy($taxonomy) {
    $taxonomy = is_string($taxonomy) ? trim($taxonomy) : '';
    if ($taxonomy === 'product_cat') {
        return 'hidden_categories';
    }
    if ($taxonomy === 'product_brand' || $taxonomy === 'product_tag') {
        return 'hidden_brands';
    }
    return '';
}
}

if (!function_exists('lpco_app_layout_is_term_hidden')) {
/**
 * Check whether a term is hidden in app layout config.
 */
function lpco_app_layout_is_term_hidden($term_id, $taxonomy = 'product_cat') {
    $term_id = function_exists('absint') ? absint($term_id) : intval($term_id);
    if ($term_id <= 0) {
        return false;
    }

    $config_key = lpco_app_layout_hidden_key_for_taxonomy($taxonomy);
    if ($config_key === '') {
        return false;
    }

    $config = lpco_app_layout_config_get();
    return in_array($term_id, lpco_app_layout_normalize_ids($config[$config_key] ?? array()), true);
}
}

if (!function_exists('lpco_app_layout_apply_order')) {
/**
 * Apply ordering to an array of items by id key.
 */
function lpco_app_layout_apply_order($items, $ordered_ids, $id_key = 'id') {
    $ordered_ids = lpco_app_layout_normalize_ids($ordered_ids);
    if (empty($ordered_ids) || !is_array($items)) {
        return $items;
    }

    $order_map = array_flip($ordered_ids);
    $index = 0;
    $with_index = array();
    foreach ($items as $item) {
        $with_index[] = array(
            'item' => $item,
            'index' => $index++
        );
    }

    usort($with_index, function ($a, $b) use ($order_map, $id_key) {
        $a_item = $a['item'];
        $b_item = $b['item'];
        $a_id = is_array($a_item) ? intval($a_item[$id_key] ?? 0) : (is_object($a_item) ? intval($a_item->$id_key ?? 0) : 0);
        $b_id = is_array($b_item) ? intval($b_item[$id_key] ?? 0) : (is_object($b_item) ? intval($b_item->$id_key ?? 0) : 0);
        $a_in = array_key_exists($a_id, $order_map);
        $b_in = array_key_exists($b_id, $order_map);

        if ($a_in && $b_in) {
            return $order_map[$a_id] <=> $order_map[$b_id];
        }
        if ($a_in) {
            return -1;
        }
        if ($b_in) {
            return 1;
        }
        return $a['index'] <=> $b['index'];
    });

    $sorted = array();
    foreach ($with_index as $row) {
        $sorted[] = $row['item'];
    }
    return $sorted;
}
}

if (!function_exists('lpco_app_layout_parent_exists')) {
/**
 * Register admin submenu for layout control.
 */
function lpco_app_layout_parent_exists($slug) {
    global $menu;
    if (empty($menu) || !is_array($menu)) {
        return false;
    }
    foreach ($menu as $item) {
        if (isset($item[2]) && $item[2] === $slug) {
            return true;
        }
    }
    return false;
}
}

if (!function_exists('lpco_app_layout_register_menu')) {
function lpco_app_layout_register_menu() {
    $parent_slug = 'dms-app-main';
    $capability = 'manage_options';

    if (function_exists('current_user_can') && (!current_user_can('manage_options') || !lpco_app_layout_parent_exists($parent_slug))) {
        if (lpco_app_layout_parent_exists('dms-ecom')) {
            $parent_slug = 'dms-app-main';
            $capability = 'manage_woocommerce';
        } else {
            $parent_slug = 'options-general.php';
            $capability = 'manage_options';
        }
    }

    if (function_exists('add_submenu_page')) {
        add_submenu_page(
            $parent_slug,
            'لوحة ترتيب واجهة التطبيق',
            'ترتيب واجهة التطبيق',
            $capability,
            'lpco-app-layout',
            'lpco_app_layout_render_admin'
        );
    }
}
}

if (function_exists('add_action')) {
    add_action('admin_menu', 'lpco_app_layout_register_menu', 20);
}

if (!function_exists('lpco_app_layout_enqueue_admin_assets')) {
/**
 * Enqueue admin assets for layout control.
 */
function lpco_app_layout_enqueue_admin_assets($hook) {
    $page = isset($_GET['page']) ? (function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($_GET['page']) : $_GET['page']) : $_GET['page']) : '';
    if ($page !== 'lpco-app-layout') {
        return;
    }

    if (function_exists('wp_enqueue_script')) {
        wp_enqueue_script('jquery-ui-sortable');
    }
    if (function_exists('wp_add_inline_script')) {
        wp_add_inline_script('jquery-ui-sortable', "
            jQuery(function($) {
                function syncList(\$list) {
                    var ids = \$list.children('li').map(function() {
                        return \$(this).data('id');
                    }).get().filter(Boolean);
                    var input = \$list.data('input');
                    if (input) {
                        \$(input).val(ids.join(','));
                    }
                }

                function activateTab(hash) {
                    var target = hash || $('.lpco-tab-link').first().attr('href');
                    $('.lpco-tab-link').removeClass('nav-tab-active');
                    $('.lpco-tab-panel').removeClass('is-active');
                    var \$link = $('.lpco-tab-link[href=\"' + target + '\"]');
                    if (!\$link.length) {
                        \$link = $('.lpco-tab-link').first();
                        target = \$link.attr('href');
                    }
                    \$link.addClass('nav-tab-active');
                    $(target).addClass('is-active');
                }

                $('.lpco-tab-link').on('click', function(e) {
                    e.preventDefault();
                    var hash = $(this).attr('href');
                    activateTab(hash);
                });

                activateTab(window.location.hash);

                $('.lpco-sortable').each(function() {
                    syncList($(this));
                });

                $('.lpco-sortable').sortable({
                    handle: '.lpco-handle',
                    update: function() {
                        syncList($(this));
                    }
                }).on('click', '.lpco-item', function(e) {
                    // Prevent sortable from blocking clicks on buttons inside items
                    if ($(e.target).is('button, a, .dashicons-move')) return;
                });

                $(document).on('click', '.lpco-add-item', function() {
                    var \$item = $(this).closest('li');
                    var id = \$item.data('id');
                    var title = \$item.find('.lpco-item-title').text();
                    if (!id) return;

                    var \$newItem = $('<li class=\"lpco-item\" data-id=\"' + id + '\">' +
                        '<span class=\"lpco-handle dashicons dashicons-move\"></span>' +
                        '<span class=\"lpco-item-title\"></span>' +
                        '<button type=\"button\" class=\"button-link-delete lpco-remove-item\">إزالة</button>' +
                    '</li>');
                    \$newItem.find('.lpco-item-title').text(title);
                    $('#lpco-featured-list .lpco-item-placeholder').remove();
                    $('#lpco-featured-list').append(\$newItem);
                    \$item.remove();
                    syncList($('#lpco-featured-list'));
                });

                $(document).on('click', '.lpco-remove-item', function() {
                    var \$item = $(this).closest('li');
                    var id = \$item.data('id');
                    var title = \$item.find('.lpco-item-title').text();
                    if (!id) return;

                    var \$newItem = $('<li class=\"lpco-item\" data-id=\"' + id + '\">' +
                        '<span class=\"lpco-item-title\"></span>' +
                        '<button type=\"button\" class=\"button lpco-add-item\">إضافة</button>' +
                    '</li>');
                    \$newItem.find('.lpco-item-title').text(title);
                    $('#lpco-featured-available').append(\$newItem);
                    \$item.remove();
                    if (!$('#lpco-featured-list li[data-id]').length) {
                        $('#lpco-featured-list').append('<li class=\"lpco-item lpco-item-placeholder\">لم يتم اختيار منتجات بعد</li>');
                    }
                    syncList($('#lpco-featured-list'));
                });

                $('#lpco-featured-search').on('input', function() {
                    var term = $(this).val().toLowerCase();
                    $('#lpco-featured-available li').each(function() {
                        var text = $(this).text().toLowerCase();
                        $(this).toggle(text.indexOf(term) !== -1);
                    });
                });
            });
        ");
    }

    if (function_exists('wp_add_inline_style')) {
        wp_add_inline_style('wp-admin', "
            .lpco-layout-wrap {direction: rtl;text-align: right;}
            .lpco-tab-panel {display: none;margin-top: 16px;}
            .lpco-tab-panel.is-active {display: block;}
            .lpco-columns {display: grid;grid-template-columns: repeat(auto-fit,minmax(280px,1fr));gap: 16px;}
            .lpco-card {background: #fff;border: 1px solid #ccd0d4;border-radius: 6px;padding: 12px;}
            .lpco-card h3 {margin-top: 0;}
            .lpco-sortable, .lpco-available-list {list-style: none;margin: 0;padding: 0;}
            .lpco-item {display: flex;align-items: center;gap: 10px;padding: 10px 12px;border: 1px solid #e1e1e1;border-radius: 6px;background: #fafafa;margin-bottom: 8px;}
            .lpco-item:last-child {margin-bottom: 0;}
            .lpco-item-title {flex: 1;}
            .lpco-handle {cursor: move;color: #666;}
            .lpco-available-list .lpco-item {background: #fff;}
            .lpco-search {width: 100%;max-width: 360px;padding: 6px 10px;margin-bottom: 10px;}
            .lpco-note {color: #666;font-size: 13px;margin-top: 6px;}
        ");
    }
}
}

if (function_exists('add_action')) {
    add_action('admin_enqueue_scripts', 'lpco_app_layout_enqueue_admin_assets');
}

if (!function_exists('lpco_app_layout_render_admin')) {
/**
 * Render admin page.
 */
function lpco_app_layout_render_admin() {
    if (function_exists('current_user_can') && !current_user_can('manage_options') && !current_user_can('manage_woocommerce')) {
        if (function_exists('wp_die')) {
            wp_die(__('ليس لديك صلاحية للوصول إلى هذه الصفحة', 'dms-ecom'), 403);
        }
    }

    $saved = false;
    if (isset($_POST['lpco_app_layout_nonce']) && function_exists('wp_verify_nonce') && wp_verify_nonce($_POST['lpco_app_layout_nonce'], 'lpco_app_layout_save')) {
        $categories_raw = function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($_POST['lpco_layout_categories'] ?? '') : ($_POST['lpco_layout_categories'] ?? '')) : ($_POST['lpco_layout_categories'] ?? '');
        $brands_raw = function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($_POST['lpco_layout_brands'] ?? '') : ($_POST['lpco_layout_brands'] ?? '')) : ($_POST['lpco_layout_brands'] ?? '');
        $featured_raw = function_exists('sanitize_text_field') ? sanitize_text_field(function_exists('wp_unslash') ? wp_unslash($_POST['lpco_layout_featured'] ?? '') : ($_POST['lpco_layout_featured'] ?? '')) : ($_POST['lpco_layout_featured'] ?? '');

        $parse_list = function ($raw) {
            $parts = array_filter(array_map('trim', explode(',', $raw)));
            return array_values(array_filter(array_map(function_exists('absint') ? 'absint' : 'intval', $parts)));
        };

        lpco_app_layout_config_save(array(
            'categories' => $parse_list($categories_raw),
            'brands' => $parse_list($brands_raw),
            'featured_products' => $parse_list($featured_raw)
        ));
        $saved = true;
    }

    $config = lpco_app_layout_config_get();
    $taxonomy = (function_exists('taxonomy_exists') && taxonomy_exists('product_brand')) ? 'product_brand' : 'product_tag';

    $categories_terms = function_exists('get_terms') ? get_terms(array(
        'taxonomy' => 'product_cat',
        'hide_empty' => false,
        'orderby' => 'menu_order',
        'order' => 'ASC'
    )) : array();
    if (function_exists('is_wp_error') && !is_wp_error($categories_terms)) {
        $categories_terms = lpco_app_layout_apply_order($categories_terms, $config['categories'], 'term_id');
    }

    $brand_terms = function_exists('get_terms') ? get_terms(array(
        'taxonomy' => $taxonomy,
        'hide_empty' => false,
        'orderby' => 'name',
        'order' => 'ASC'
    )) : array();
    if (function_exists('is_wp_error') && !is_wp_error($brand_terms)) {
        $brand_terms = lpco_app_layout_apply_order($brand_terms, $config['brands'], 'term_id');
    }

    $featured_ids = $config['featured_products'];
    $featured_posts = array();
    if (!empty($featured_ids) && function_exists('get_posts')) {
        $featured_posts = get_posts(array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'post__in' => $featured_ids,
            'orderby' => 'post__in',
            'posts_per_page' => count($featured_ids)
        ));
    }

    $available_products = function_exists('get_posts') && function_exists('dms_build_ordered_product_query_args') ? get_posts(dms_build_ordered_product_query_args(array(
        'posts_per_page' => 500,
        'post__not_in' => $featured_ids
    ))) : array();
    ?>
    <div class="wrap lpco-layout-wrap">
        <h1>لوحة ترتيب واجهة التطبيق</h1>
        <?php if ($saved): ?>
            <div class="notice notice-success"><p>تم حفظ الترتيب بنجاح.</p></div>
        <?php endif; ?>

        <nav class="nav-tab-wrapper">
            <a href="#lpco-tab-categories" class="nav-tab lpco-tab-link">ترتيب التصنيفات</a>
            <a href="#lpco-tab-brands" class="nav-tab lpco-tab-link">ترتيب العلامات التجارية</a>
            <a href="#lpco-tab-featured" class="nav-tab lpco-tab-link">المنتجات المميزة</a>
        </nav>

        <form method="post">
            <?php if (function_exists('wp_nonce_field')) wp_nonce_field('lpco_app_layout_save', 'lpco_app_layout_nonce'); ?>

            <div id="lpco-tab-categories" class="lpco-tab-panel">
                <div class="lpco-card">
                    <h3>اسحب وأفلت لإعادة ترتيب التصنيفات</h3>
                    <ul class="lpco-sortable" data-input="#lpco-layout-categories">
                        <?php if (function_exists('is_wp_error') && !is_wp_error($categories_terms) && !empty($categories_terms)): ?>
                            <?php foreach ($categories_terms as $term): ?>
                                <li class="lpco-item" data-id="<?php echo function_exists('esc_attr') ? esc_attr($term->term_id) : $term->term_id; ?>">
                                    <span class="lpco-handle dashicons dashicons-move"></span>
                                    <span class="lpco-item-title"><?php echo function_exists('esc_html') ? esc_html($term->name) : $term->name; ?></span>
                                    <span><?php echo function_exists('esc_html') ? esc_html($term->count) : $term->count; ?></span>
                                </li>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <li class="lpco-item">لا توجد تصنيفات</li>
                        <?php endif; ?>
                    </ul>
                    <p class="lpco-note">يظهر هذا الترتيب أولاً في التطبيق.</p>
                </div>
            </div>

            <div id="lpco-tab-brands" class="lpco-tab-panel">
                <div class="lpco-card">
                    <h3>اسحب وأفلت لإعادة ترتيب العلامات التجارية</h3>
                    <ul class="lpco-sortable" data-input="#lpco-layout-brands">
                        <?php if (function_exists('is_wp_error') && !is_wp_error($brand_terms) && !empty($brand_terms)): ?>
                            <?php foreach ($brand_terms as $term): ?>
                                <li class="lpco-item" data-id="<?php echo function_exists('esc_attr') ? esc_attr($term->term_id) : $term->term_id; ?>">
                                    <span class="lpco-handle dashicons dashicons-move"></span>
                                    <span class="lpco-item-title"><?php echo function_exists('esc_html') ? esc_html($term->name) : $term->name; ?></span>
                                    <span><?php echo function_exists('esc_html') ? esc_html($term->count) : $term->count; ?></span>
                                </li>
                            <?php endforeach; ?>
                        <?php else: ?>
                            <li class="lpco-item">لا توجد علامات تجارية</li>
                        <?php endif; ?>
                    </ul>
                    <p class="lpco-note">يظهر هذا الترتيب أولاً في التطبيق.</p>
                </div>
            </div>

            <div id="lpco-tab-featured" class="lpco-tab-panel">
                <div class="lpco-columns">
                    <div class="lpco-card">
                        <h3>المنتجات المختارة</h3>
                        <ul id="lpco-featured-list" class="lpco-sortable" data-input="#lpco-layout-featured">
                            <?php if (!empty($featured_posts)): ?>
                                <?php foreach ($featured_posts as $post): ?>
                                    <li class="lpco-item" data-id="<?php echo function_exists('esc_attr') ? esc_attr($post->ID) : $post->ID; ?>">
                                        <span class="lpco-handle dashicons dashicons-move"></span>
                                        <span class="lpco-item-title"><?php echo function_exists('esc_html') ? esc_html($post->post_title) : $post->post_title; ?></span>
                                        <button type="button" class="button-link-delete lpco-remove-item">إزالة</button>
                                    </li>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <li class="lpco-item lpco-item-placeholder">لم يتم اختيار منتجات بعد</li>
                            <?php endif; ?>
                        </ul>
                        <p class="lpco-note">اسحب العناصر لتغيير الترتيب.</p>
                    </div>

                    <div class="lpco-card">
                        <h3>أضف منتجات</h3>
                        <input type="text" id="lpco-featured-search" class="lpco-search" placeholder="ابحث عن منتج...">
                        <ul id="lpco-featured-available" class="lpco-available-list">
                            <?php if (!empty($available_products)): ?>
                                <?php foreach ($available_products as $post): ?>
                                    <li class="lpco-item" data-id="<?php echo function_exists('esc_attr') ? esc_attr($post->ID) : $post->ID; ?>">
                                        <span class="lpco-item-title"><?php echo function_exists('esc_html') ? esc_html($post->post_title) : $post->post_title; ?></span>
                                        <button type="button" class="button lpco-add-item">إضافة</button>
                                    </li>
                                <?php endforeach; ?>
                            <?php else: ?>
                                <li class="lpco-item">لا توجد منتجات إضافية</li>
                            <?php endif; ?>
                        </ul>
                        <p class="lpco-note">القائمة تعرض أحدث 500 منتج منشور.</p>
                    </div>
                </div>
            </div>

            <input type="hidden" id="lpco-layout-categories" name="lpco_layout_categories" value="">
            <input type="hidden" id="lpco-layout-brands" name="lpco_layout_brands" value="">
            <input type="hidden" id="lpco-layout-featured" name="lpco_layout_featured" value="">

            <?php if (function_exists('submit_button')) submit_button('حفظ الترتيب'); ?>
        </form>
    </div>
    <?php
}
}
