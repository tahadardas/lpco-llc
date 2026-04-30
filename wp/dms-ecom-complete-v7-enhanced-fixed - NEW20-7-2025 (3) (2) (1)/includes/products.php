<?php
// حفظ الأسعار حسب التصنيف في شاشة المنتج
add_action('add_meta_boxes', function() {
    add_meta_box('dms_prices', 'أسعار حسب التصنيفات والوحدات', 'dms_prices_box', 'product', 'normal', 'default');
});

if (!function_exists('dms_prices_box')) {
function dms_prices_box($post) {
    $values = get_post_meta($post->ID, '_dms_prices', true);
    $values = is_array($values) ? $values : [];
    $cats = get_option('dms_price_categories', []);
    if (!is_array($cats) || empty($cats)) {
        echo '<p>لم يتم العثور على تصنيفات أسعار مخصصة. الرجاء إضافتها أولاً من لوحة التحكم.</p>';
        return;
    }
    foreach ($cats as $cat) {
        $syp_piece = $values[$cat]['syp_piece'] ?? '';
        $usd_piece = $values[$cat]['usd_piece'] ?? '';
        $box_pieces_count = $values[$cat]['box_pieces_count'] ?? '';
        $package_pieces_count = $values[$cat]['package_pieces_count'] ?? '';
        $box_unit_name = $values[$cat]['box_unit_name'] ?? 'علبة';
        $package_unit_name = $values[$cat]['package_unit_name'] ?? 'طرد';

        // Checkbox values to decide which price to display
        $show_syp_piece = isset($values[$cat]['show_syp_piece']) ? 'checked' : '';
        $show_usd_piece = isset($values[$cat]['show_usd_piece']) ? 'checked' : '';
        $show_syp_package = isset($values[$cat]['show_syp_package']) ? 'checked' : '';
        $show_usd_package = isset($values[$cat]['show_usd_package']) ? 'checked' : '';
        
        echo "<h3>التصنيف: " . esc_html($cat) . "</h3>";
        
        // SYP Price Fields
        echo "<p>
            <strong>سعر القطعة (SYP):</strong>
            <input type='text' name='dms_price[{$cat}][syp_piece]' value='{$syp_piece}' placeholder='سعر القطعة بالليرة السورية'>
            <label><input type='checkbox' class='dms-price-toggle' data-currency='syp' data-unit='piece' name='dms_price[{$cat}][show_syp_piece]' {$show_syp_piece}> عرض سعر القطعة</label>
        </p>";

        echo "<p>
            <strong>سعر الطرد (SYP):</strong>
            <span class='dms-calculated-price' id='syp_package_price_{$cat}'>" . ((float)$syp_piece * (int)($package_pieces_count ?: 0)) . "</span> ل.س
            <label><input type='checkbox' class='dms-price-toggle' data-currency='syp' data-unit='package' name='dms_price[{$cat}][show_syp_package]' {$show_syp_package}> عرض سعر الطرد</label>
        </p>";

        // USD Price Fields
        echo "<p>
            <strong>سعر القطعة (USD):</strong>
            <input type='text' name='dms_price[{$cat}][usd_piece]' value='{$usd_piece}' placeholder='سعر القطعة بالدولار الأمريكي'>
            <label><input type='checkbox' class='dms-price-toggle' data-currency='usd' data-unit='piece' name='dms_price[{$cat}][show_usd_piece]' {$show_usd_piece}> عرض سعر القطعة</label>
        </p>";
        
        echo "<p>
            <strong>سعر الطرد (USD):</strong>
            <span class='dms-calculated-price' id='usd_package_price_{$cat}'>" . ((float)$usd_piece * (int)($package_pieces_count ?: 0)) . "</span> $
            <label><input type='checkbox' class='dms-price-toggle' data-currency='usd' data-unit='package' name='dms_price[{$cat}][show_usd_package]' {$show_usd_package}> عرض سعر الطرد</label>
        </p>";

        // Unit Details
        echo "<p><strong>تفاصيل العلبة:</strong><br>
            <input type='number' name='dms_price[{$cat}][box_pieces_count]' value='{$box_pieces_count}' placeholder='عدد القطع في العلبة' min='1'>
            <input type='text' name='dms_price[{$cat}][box_unit_name]' value='{$box_unit_name}' placeholder='اسم وحدة العلبة (مثال: صندوق)'></p>";

        echo "<p><strong>تفاصيل الطرد:</strong><br>
            <input type='number' name='dms_price[{$cat}][package_pieces_count]' value='{$package_pieces_count}' placeholder='عدد القطع في الطرد' min='1'>
            <input type='text' name='dms_price[{$cat}][package_unit_name]' value='{$package_unit_name}' placeholder='اسم وحدة الطرد (مثال: حزمة)'></p><hr>";
    }
    
    ?>
    <script type="text/javascript">
        // jQuery is not needed for this simple task, and it was causing an error
        // Let's remove the old JavaScript and use a simpler one.
    </script>
    <?php
}
}

add_action('save_post_product', function($post_id) {
    if (isset($_POST['dms_price'])) {
        update_post_meta($post_id, '_dms_prices', array_map(function($row) {
            return [
                'syp_piece' => sanitize_text_field($row['syp_piece'] ?? ''),
                'usd_piece' => sanitize_text_field($row['usd_piece'] ?? ''),
                'show_syp_piece' => isset($row['show_syp_piece']) ? true : false,
                'show_usd_piece' => isset($row['show_usd_piece']) ? true : false,
                'show_syp_package' => isset($row['show_syp_package']) ? true : false,
                'show_usd_package' => isset($row['show_usd_package']) ? true : false,
                'box_pieces_count' => isset($row['box_pieces_count']) && $row['box_pieces_count'] !== '' ? absint($row['box_pieces_count']) : '',
                'box_unit_name' => sanitize_text_field($row['box_unit_name'] ?? ''),
                'package_pieces_count' => isset($row['package_pieces_count']) && $row['package_pieces_count'] !== '' ? absint($row['package_pieces_count']) : '',
                'package_unit_name' => sanitize_text_field($row['package_unit_name'] ?? '')
            ];
        }, $_POST['dms_price']));
    }
});

// هذا هو الجزء الذي يحل المشكلة في الواجهة الأمامية
if (!function_exists('dms_custom_frontend_price_display')) {
function dms_custom_frontend_price_display($price_html, $product) {
    if (!function_exists('wc_get_product')) {
        return $price_html;
    }
    $custom_prices = get_post_meta($product->get_id(), '_dms_prices', true);
    if (empty($custom_prices) || !is_array($custom_prices)) {
        return $price_html;
    }

    $currency_code = get_woocommerce_currency();

    $all_keys = array_keys($custom_prices);
    if (empty($all_keys)) {
        return $price_html;
    }
    $cat = $all_keys[0];
    $cat_prices = $custom_prices[$cat] ?? [];
    if (empty($cat_prices)) {
        return $price_html;
    }

    $syp_price = (float) ($cat_prices['syp_piece'] ?? 0);
    $usd_price = (float) ($cat_prices['usd_piece'] ?? 0);
    
    // استخدام null coalescing operator للتحقق من أن القيمة ليست فارغة قبل تحويلها
    $package_pieces_count = (int) ($cat_prices['package_pieces_count'] ?? 0);
    $package_unit_name = $cat_prices['package_unit_name'] ?? 'طرد';

    $syp_package_price = $syp_price * $package_pieces_count;
    $usd_package_price = $usd_price * $package_pieces_count;

    $price_to_display = [];

    if ($currency_code === 'SYP') {
        if (isset($cat_prices['show_syp_piece']) && $cat_prices['show_syp_piece']) {
            $price_to_display[] = wc_price($syp_price) . ' / قطعة';
        }
        if (isset($cat_prices['show_syp_package']) && $cat_prices['show_syp_package']) {
            $price_to_display[] = wc_price($syp_package_price) . ' / ' . esc_html($package_unit_name);
        }
    } elseif ($currency_code === 'USD') {
        if (isset($cat_prices['show_usd_piece']) && $cat_prices['show_usd_piece']) {
            $price_to_display[] = wc_price($usd_price) . ' / قطعة';
        }
        if (isset($cat_prices['show_usd_package']) && $cat_prices['show_usd_package']) {
            $price_to_display[] = wc_price($usd_package_price) . ' / ' . esc_html($package_unit_name);
        }
    }

    if (!empty($price_to_display)) {
        return implode(' | ', $price_to_display);
    }

    return $price_html;
}
}

// ✅ إخفاء حقول السعر الافتراضية لووكومرس في لوحة تحكم المنتج
if (!function_exists('dms_hide_woocommerce_default_price_fields')) {
function dms_hide_woocommerce_default_price_fields() {
    global $post;
    if ('product' !== get_post_type($post)) {
        return;
    }
    ?>
    <style type="text/css">
        /* إخفاء حقول السعر العادية في تبويب "عام" */
        .woocommerce_options_panel ._regular_price_field,
        .woocommerce_options_panel ._sale_price_field {
            display: none !important;
        }
        /* إخفاء حقول السعر داخل كل تباين للمنتجات المتغيرة */
        .woocommerce_variation_fields .form-row.form-row-first,
        .woocommerce_variation_fields .form-row.form-row-last {
            display: none !important;
        }
        /* إخفاء عمود السعر في جدول التباينات */
        .woocommerce_variations_tab .woocommerce_variable_attributes table.wp-list-table th.variation_price {
            display: none !important;
        }
        .woocommerce_variations_tab .woocommerce_variable_attributes table.wp-list-table td.variation_price {
            display: none !important;
        }
        /* إخفاء حقول السعر الافتراضية داخل لوحة معلومات كل تباين فردي */
        .woocommerce_variation_fields .variable_pricing input[name*="_regular_price"],
        .woocommerce_variation_fields .variable_pricing input[name*="_sale_price"],
        .woocommerce_variable_attributes .wc_input_price {
            display: none !important;
        }
    </style>
    <?php
}
}