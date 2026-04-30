<?php
/**
 * CSV ordering management for app product lists.
 */

if (!defined('ABSPATH')) {
    exit;
}

if (!function_exists('dms_app_order_meta_key')) {
    function dms_app_order_meta_key($brand_term_id = 0) {
        $brand_term_id = absint($brand_term_id);
        if ($brand_term_id > 0) {
            return '_dms_app_order_brand_' . $brand_term_id;
        }
        return '_dms_app_order_home';
    }
}

if (!function_exists('dms_app_order_enabled_key')) {
    function dms_app_order_enabled_key($brand_term_id = 0) {
        $brand_term_id = absint($brand_term_id);
        if ($brand_term_id > 0) {
            return 'dms_app_order_brand_enabled_' . $brand_term_id;
        }
        return 'dms_app_order_home_enabled';
    }
}

if (!function_exists('dms_app_order_render_page')) {
    function dms_app_order_render_page() {
        if (!current_user_can('manage_woocommerce')) {
            wp_die(__('ليس لديك صلاحية للوصول إلى هذه الصفحة', 'dms-ecom'), 403);
        }

        $notice = '';
        if (!empty($_GET['dms_app_order_updated'])) {
            $notice = '<div class="notice notice-success"><p>' . esc_html__('تم حفظ ترتيب المنتجات.', 'dms-ecom') . '</p></div>';
        } elseif (!empty($_GET['dms_app_order_error'])) {
            $notice = '<div class="notice notice-error"><p>' . esc_html__('تعذر قراءة ملف CSV. تأكد من التنسيق.', 'dms-ecom') . '</p></div>';
        }

        $taxonomy = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
        $brand_terms = get_terms(array(
            'taxonomy' => $taxonomy,
            'hide_empty' => false
        ));
        ?>
        <div class="wrap">
            <h1><?php esc_html_e('ترتيب المنتجات (CSV)', 'dms-ecom'); ?></h1>
            <?php echo $notice; ?>

            <h2><?php esc_html_e('ترتيب الواجهة الرئيسية', 'dms-ecom'); ?></h2>
            <p><?php esc_html_e('ارفع ملف CSV يحتوي على الأعمدة: product_id, product_name. سيتم اعتماد الترتيب كما هو.', 'dms-ecom'); ?></p>
            <p>
                <a class="button" href="<?php echo esc_url(admin_url('admin-post.php?action=dms_app_order_download_template&scope=home')); ?>">
                    <?php esc_html_e('تحميل قالب CSV', 'dms-ecom'); ?>
                </a>
            </p>
            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" enctype="multipart/form-data">
                <?php wp_nonce_field('dms_app_order_upload_home', 'dms_app_order_nonce'); ?>
                <input type="hidden" name="action" value="dms_app_order_upload_home">
                <table class="form-table">
                    <tr>
                        <th scope="row"><?php esc_html_e('ملف CSV', 'dms-ecom'); ?></th>
                        <td><input type="file" name="dms_app_order_csv" accept=".csv" required></td>
                    </tr>
                    <tr>
                        <th scope="row"><?php esc_html_e('تطبيق على غير المدرج', 'dms-ecom'); ?></th>
                        <td>
                            <label>
                                <input type="checkbox" name="dms_app_order_reset_missing" value="1" checked>
                                <?php esc_html_e('ضع المنتجات غير الموجودة في CSV في آخر القائمة', 'dms-ecom'); ?>
                            </label>
                        </td>
                    </tr>
                </table>
                <?php submit_button(__('حفظ الترتيب', 'dms-ecom')); ?>
            </form>

            <hr>

            <h2><?php esc_html_e('ترتيب حسب العلامة التجارية', 'dms-ecom'); ?></h2>
            <p><?php esc_html_e('اختر العلامة ثم ارفع ملف CSV بنفس التنسيق.', 'dms-ecom'); ?></p>
            <p>
                <a class="button" href="<?php echo esc_url(admin_url('admin-post.php?action=dms_app_order_download_template&scope=brand')); ?>">
                    <?php esc_html_e('تحميل قالب CSV', 'dms-ecom'); ?>
                </a>
            </p>
            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" enctype="multipart/form-data">
                <?php wp_nonce_field('dms_app_order_upload_brand', 'dms_app_order_nonce'); ?>
                <input type="hidden" name="action" value="dms_app_order_upload_brand">
                <table class="form-table">
                    <tr>
                        <th scope="row"><?php esc_html_e('العلامة التجارية', 'dms-ecom'); ?></th>
                        <td>
                            <select name="dms_app_order_brand" required>
                                <option value=""><?php esc_html_e('-- اختر العلامة --', 'dms-ecom'); ?></option>
                                <?php
                                if (!is_wp_error($brand_terms) && !empty($brand_terms)) {
                                    foreach ($brand_terms as $term) {
                                        printf(
                                            '<option value="%s">%s</option>',
                                            esc_attr($term->slug),
                                            esc_html($term->name)
                                        );
                                    }
                                }
                                ?>
                            </select>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row"><?php esc_html_e('ملف CSV', 'dms-ecom'); ?></th>
                        <td><input type="file" name="dms_app_order_csv" accept=".csv" required></td>
                    </tr>
                    <tr>
                        <th scope="row"><?php esc_html_e('تطبيق على غير المدرج', 'dms-ecom'); ?></th>
                        <td>
                            <label>
                                <input type="checkbox" name="dms_app_order_reset_missing" value="1" checked>
                                <?php esc_html_e('ضع منتجات العلامة غير الموجودة في CSV في آخر القائمة', 'dms-ecom'); ?>
                            </label>
                        </td>
                    </tr>
                </table>
                <?php submit_button(__('حفظ ترتيب العلامة', 'dms-ecom')); ?>
            </form>
        </div>
        <?php
    }
}

add_action('admin_menu', function () {
    add_submenu_page(
        'dms-store-main',
        __('ترتيب المنتجات (CSV)', 'dms-ecom'),
        __('ترتيب المنتجات', 'dms-ecom'),
        'manage_woocommerce',
        'dms-app-product-order',
        'dms_app_order_render_page'
    );
});

function dms_app_order_parse_csv($file_path) {
    $rows = array();
    if (!file_exists($file_path)) {
        return $rows;
    }
    $handle = fopen($file_path, 'r');
    if (!$handle) {
        return $rows;
    }
    $index = 0;
    $header_map = array(
        'product_id' => 0,
        'sku' => 1,
        'product_name' => 2,
        'order' => 3,
        'latest_order' => 4,
    );
    while (($data = fgetcsv($handle)) !== false) {
        $index++;
        if ($index === 1) {
            $normalized = array_map(function ($col) {
                return strtolower(trim((string) $col));
            }, $data);
            $map = array();
            foreach ($normalized as $i => $key) {
                if (isset($header_map[$key])) {
                    $map[$key] = $i;
                }
            }
            $header_map = $map + $header_map;
            continue;
        }
        $product_id_idx = $header_map['product_id'] ?? 0;
        $product_id = isset($data[$product_id_idx]) ? absint($data[$product_id_idx]) : 0;
        if ($product_id <= 0) {
            continue;
        }
        $sku_idx = $header_map['sku'] ?? 1;
        $name_idx = $header_map['product_name'] ?? 2;
        $order_idx = $header_map['order'] ?? 3;
        $latest_idx = $header_map['latest_order'] ?? 4;
        $rows[] = array(
            'product_id'   => $product_id,
            'sku'          => isset($data[$sku_idx]) ? sanitize_text_field($data[$sku_idx]) : '',
            'product_name' => isset($data[$name_idx]) ? sanitize_text_field($data[$name_idx]) : '',
            'order'        => isset($data[$order_idx]) && $data[$order_idx] !== '' ? intval($data[$order_idx]) : null,
            'latest_order' => isset($data[$latest_idx]) && $data[$latest_idx] !== '' ? intval($data[$latest_idx]) : null,
        );
    }
    fclose($handle);
    return $rows;
}

function dms_app_order_update_products($rows, $meta_key, $reset_missing = false, $brand_term_id = 0) {
    $meta_key = sanitize_key($meta_key);
    $brand_term_id = absint($brand_term_id);
    $position = 1;
    $ordered_ids = array();
    $latest_ids = array();
    $latest_meta_key = '_dms_app_latest_order';

    foreach ($rows as $row) {
        $product_id = absint($row['product_id']);
        if ($product_id <= 0) {
            continue;
        }
        $order_value = isset($row['order']) && $row['order'] !== null ? intval($row['order']) : $position;
        update_post_meta($product_id, $meta_key, $order_value);
        $ordered_ids[] = $product_id;
        $position++;

        if (isset($row['latest_order']) && $row['latest_order'] !== null) {
            $latest_value = intval($row['latest_order']);
            update_post_meta($product_id, $latest_meta_key, $latest_value);
            $latest_ids[] = $product_id;
        }
    }

    if ($reset_missing) {
        $args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'fields' => 'ids',
            'posts_per_page' => -1,
            'no_found_rows' => true,
        );
        if ($brand_term_id > 0) {
            $taxonomy = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
            $args['tax_query'] = array(
                array(
                    'taxonomy' => $taxonomy,
                    'field' => 'term_id',
                    'terms' => $brand_term_id
                )
            );
        }
        $query = new WP_Query($args);
        if (!empty($query->posts)) {
            foreach ($query->posts as $product_id) {
                if (!in_array($product_id, $ordered_ids, true)) {
                    update_post_meta($product_id, $meta_key, DMS_ECOM_CUSTOM_PRODUCT_ORDER_DEFAULT);
                }
                if (!in_array($product_id, $latest_ids, true)) {
                    delete_post_meta($product_id, $latest_meta_key);
                }
            }
        }
        wp_reset_postdata();
    }

    update_option('dms_app_latest_manual_enabled', count($latest_ids) > 0 ? 1 : 0);

    return count($ordered_ids);
}

function dms_app_order_handle_upload($scope = 'home') {
    if (!current_user_can('manage_woocommerce')) {
        wp_die(__('ليس لديك صلاحية للوصول إلى هذه الصفحة', 'dms-ecom'), 403);
    }
    $nonce_action = $scope === 'brand' ? 'dms_app_order_upload_brand' : 'dms_app_order_upload_home';
    if (empty($_POST['dms_app_order_nonce']) || !wp_verify_nonce($_POST['dms_app_order_nonce'], $nonce_action)) {
        wp_die(__('فشل التحقق الأمني.', 'dms-ecom'), 403);
    }
    if (empty($_FILES['dms_app_order_csv']['tmp_name'])) {
        wp_safe_redirect(add_query_arg('dms_app_order_error', 1, wp_get_referer()));
        exit;
    }
    $file_path = $_FILES['dms_app_order_csv']['tmp_name'];
    $rows = dms_app_order_parse_csv($file_path);
    if (empty($rows)) {
        wp_safe_redirect(add_query_arg('dms_app_order_error', 1, wp_get_referer()));
        exit;
    }

    $reset_missing = !empty($_POST['dms_app_order_reset_missing']);
    $brand_term_id = 0;
    if ($scope === 'brand') {
        $brand_slug = isset($_POST['dms_app_order_brand']) ? sanitize_text_field($_POST['dms_app_order_brand']) : '';
        if ($brand_slug !== '') {
            $taxonomy = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
            $term = get_term_by('slug', $brand_slug, $taxonomy);
            if ($term && !is_wp_error($term)) {
                $brand_term_id = (int) $term->term_id;
            }
        }
        if ($brand_term_id <= 0) {
            wp_safe_redirect(add_query_arg('dms_app_order_error', 1, wp_get_referer()));
            exit;
        }
    }

    $meta_key = dms_app_order_meta_key($brand_term_id);
    dms_app_order_update_products($rows, $meta_key, $reset_missing, $brand_term_id);
    update_option(dms_app_order_enabled_key($brand_term_id), 1);

    wp_safe_redirect(add_query_arg('dms_app_order_updated', 1, wp_get_referer()));
    exit;
}

add_action('admin_post_dms_app_order_upload_home', function () {
    dms_app_order_handle_upload('home');
});

add_action('admin_post_dms_app_order_upload_brand', function () {
    dms_app_order_handle_upload('brand');
});

add_action('admin_post_dms_app_order_download_template', function () {
    if (!current_user_can('manage_woocommerce')) {
        wp_die(__('??? ???? ?????? ?????? ??? ??? ??????', 'dms-ecom'), 403);
    }
    $scope = isset($_GET['scope']) ? sanitize_text_field($_GET['scope']) : 'home';
    $brand_slug = isset($_GET['brand']) ? sanitize_text_field($_GET['brand']) : '';
    $args = array(
        'post_type' => 'product',
        'post_status' => 'publish',
        'posts_per_page' => -1,
        'no_found_rows' => true,
        'fields' => 'ids',
        'orderby' => 'ID',
        'order' => 'ASC',
    );
    if ($scope === 'brand' && $brand_slug !== '') {
        $taxonomy = taxonomy_exists('product_brand') ? 'product_brand' : 'product_tag';
        $args['tax_query'] = array(
            array(
                'taxonomy' => $taxonomy,
                'field' => 'slug',
                'terms' => $brand_slug,
            )
        );
    }
    $query = new WP_Query($args);
    $products = !empty($query->posts) ? $query->posts : array();
    $latest_meta_key = '_dms_app_latest_order';
    $filename = 'dms-products-template.csv';
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=' . $filename);
    $output = fopen('php://output', 'w');
    fputcsv($output, array('product_id', 'sku', 'product_name', 'order', 'latest_order'));
    foreach ($products as $product_id) {
        $product = wc_get_product($product_id);
        if (!$product) {
            continue;
        }
        $sku = $product->get_sku();
        $latest_value = get_post_meta($product_id, $latest_meta_key, true);
        fputcsv($output, array(
            $product_id,
            $sku,
            $product->get_name(),
            '',
            is_numeric($latest_value) ? $latest_value : ''
        ));
    }
    fclose($output);
    exit;
});

