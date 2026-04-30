<?php
/**
 * دالة لتنسيق الأسعار برقم عشري مع نقطة (لضمان توافق النظام وتطبيق الموبايل)
 * 
 * @param float $price السعر المراد تنسيقه
 * @param string $currency نوع العملة (syp, usd)
 * @return string السعر المنسق
 */
function dms_format_price($price, $currency = 'syp') {
    if (!is_numeric($price)) {
        return $price;
    }
    
    $formatted = number_format((float)$price, 2, '.', ''); // استخدام النقطة كفاصل عشري
    
    if (strtolower($currency) === 'usd') {
        return '$' . $formatted;
    } elseif (strtolower($currency) === 'syp') {
        return $formatted . ' ل.س';
    }
    
    return $formatted;
}

/**
 * Function to get user-specific price for a product.
 * Accepts product_id directly instead of relying on global $product.
 *
 * @param int $product_id The ID of the product.
 * @param int $qty The quantity of the product.
 * @return float|false The calculated price, or false if not found.
 */
function dms_get_user_price($product_id, $qty = 1) {
    // التحقق من صلاحية معرف المنتج
    if (!$product_id) {
        return false;
    }

    $user_id = get_current_user_id();

    // التحقق من حالة الحساب: إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، لا تعرض الأسعار.
    // يتم السماح للمسؤولين دائماً برؤية الأسعار.
    if (current_user_can('manage_options') || (is_admin() && !defined('DOING_AJAX'))) {
        return false; // لا نطبق الأسعار المخصصة في لوحة التحكم بشكل افتراضي هنا، أو يمكن تركها للمسؤولين
    }

    if (!is_user_logged_in()) {
        return false;
    }

    $account_status = get_user_meta($user_id, 'dms_account_status', true);
    if ($account_status !== 'مؤكد') {
        return false; // المستخدم غير مؤكد، لذا لا يجب عرض الأسعار
    }

    $group = get_user_meta($user_id, 'dms_user_group', true);
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
    $prices = get_post_meta($product_id, '_dms_prices', true);
    $prices = is_array($prices) ? $prices : [];

    // الأولوية للسعر المحدد بالعملة للمجموعة (إذا كان موجوداً، ربما لسعر العلبة/الطرد إذا تم حفظه كذلك)
    if (isset($prices[$group])) {
        if (!empty($prices[$group][$currency])) {
            return floatval($prices[$group][$currency]) * $qty;
        }
        // إذا لم يكن هناك سعر محدد بالعملة للمجموعة، حاول الحصول على سعر القطعة
        if ($currency === 'syp' && !empty($prices[$group]['syp_piece'])) {
            return floatval($prices[$group]['syp_piece']) * $qty;
        }
        if ($currency === 'usd' && !empty($prices[$group]['usd_piece'])) {
            return floatval($prices[$group]['usd_piece']) * $qty;
        }
    }
    return false; // لا يوجد سعر مخصص
}

/**
 * Filter to modify the main displayed price HTML for a product.
 * This handles both simple and variable products on shop/archive/single product pages.
 *
 * @param string $price_html The original price HTML.
 * @param WC_Product $product The product object.
 * @return string The modified price HTML.
 */
add_filter('woocommerce_get_price_html', 'dms_custom_price_html', 99, 2);
add_filter('woocommerce_variation_price_html', 'dms_custom_price_html', 99, 2);

function dms_custom_price_html($price_html, $product) {
    $user_id = get_current_user_id();

    // إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، اعرض رسالة بدلاً من السعر.
    // يتم استثناء المسؤولين لضمان قدرتهم على إدارة الطلبات والمنتجات.
    if (!current_user_can('manage_options')) {
        if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
            return '<p class="dms-no-price-message" style="color: #FF0000; font-weight: bold;">الأسعار غير متاحة. يرجى تسجيل الدخول أو انتظار تأكيد حسابك.</p>';
        }
    }

    // الحصول على معرف المنتج الرئيسي للمتغيرات أيضاً
    $_product_id_for_meta = $product->is_type('variation') ? $product->get_parent_id() : $product->get_id();

    $group = get_user_meta($user_id, 'dms_user_group', true);
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
    
    // استرداد الأسعار من بيانات المنتج (أو المنتج الأب للمتغيرات)
    $prices = get_post_meta($_product_id_for_meta, '_dms_prices', true);
    $prices = is_array($prices) ? $prices : [];

    $amount = false;

    // محاولة الحصول على السعر بناءً على الوحدة المحددة أو سعر القطعة
    if (isset($prices[$group])) {
        if (!empty($prices[$group][$currency])) {
            $amount = (float) $prices[$group][$currency];
        } elseif ($currency === 'syp' && !empty($prices[$group]['syp_piece'])) {
            $amount = (float) $prices[$group]['syp_piece'];
        } elseif ($currency === 'usd' && !empty($prices[$group]['usd_piece'])) {
            $amount = (float) $prices[$group]['usd_piece'];
        }
    }

    if ($amount !== false) {
        // إذا كانت العملة دولار أمريكي، تأكد من تنسيق القيمة برقم عشري مع فاصلة
        if (strtolower($currency) === 'usd') {
            return '$' . number_format($amount, 2, '.', ''); // استخدام النقطة كفاصل عشري
        }
        // استخدام dms_format_price() لتنسيق الأسعار برقم عشري مع فاصلة
        return dms_format_price($amount, $currency);
    }

    return $price_html; // العودة للسعر الأصلي إذا لم يتم العثور على سعر مخصص
}

/**
 * Filters to set the actual price for WooCommerce products (simple and variations).
 * These hooks are crucial for making WooCommerce recognize the custom prices internally.
 */
add_filter('woocommerce_product_get_price', 'dms_set_product_price', 99, 2);
add_filter('woocommerce_product_get_regular_price', 'dms_set_product_price', 99, 2);
add_filter('woocommerce_product_get_sale_price', 'dms_set_product_price', 99, 2);

add_filter('woocommerce_product_variation_get_price', 'dms_set_variation_price', 99, 2);
add_filter('woocommerce_product_variation_get_regular_price', 'dms_set_variation_price', 99, 2);
add_filter('woocommerce_product_variation_get_sale_price', 'dms_set_variation_price', 99, 2);

function dms_set_product_price($price, $product) {
    $user_id = get_current_user_id();

    if (is_admin() && !defined('DOING_AJAX')) {
        return $price;
    }

    // إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، أرجع false لإخفاء السعر.
    // يتم استثناء المسؤولين.
    if (!current_user_can('manage_options')) {
        if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
            return ''; // إرجاع سلسلة فارغة لجعل WooCommerce يعتبر المنتج بدون سعر
        }
    }

    $custom_price = dms_get_user_price($product->get_id(), 1);
    if ($custom_price !== false) {
        return $custom_price;
    }
    return $price; // العودة للسعر الأصلي إذا لم يتم العثور على سعر مخصص
}

function dms_set_variation_price($price, $variation) {
    $user_id = get_current_user_id();

    if (is_admin() && !defined('DOING_AJAX')) {
        return $price;
    }

    // إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، أرجع false لإخفاء السعر.
    // يتم استثناء المسؤولين.
    if (!current_user_can('manage_options')) {
        if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
            return ''; // إرجاع سلسلة فارغة لجعل WooCommerce يعتبر المنتج بدون سعر
        }
    }

    // بالنسبة للمتغيرات، فإن دالة dms_get_user_price مصممة لجلب السعر من بيانات المنتج الأب.
    $custom_price = dms_get_user_price($variation->get_parent_id(), 1);
    if ($custom_price !== false) {
        return $custom_price;
    }
    return $price; // العودة للسعر الأصلي إذا لم يتم العثور على سعر مخصص
}


/**
 * Filter to modify the displayed price of a cart item.
 *
 * @param string $price The original price HTML.
 * @param array $item The cart item array.
 * @return string The modified price HTML.
 */
add_filter('woocommerce_cart_item_price', function($price, $item) {
    $user_id = get_current_user_id();

    // إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، لا تعرض الأسعار.
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return ''; // أو رسالة مثل 'الأسعار غير متاحة'
    }

    // التحقق مما إذا كان سعر الوحدة المحسوب مخصصاً موجوداً في بيانات عنصر سلة التسوق
    if (isset($item['dms_calculated_unit_price']) && is_numeric($item['dms_calculated_unit_price'])) {
        $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
        $amount = (float) $item['dms_calculated_unit_price'];

        // إذا كانت العملة دولار أمريكي، تأكد من تنسيق القيمة برقم عشري مع فاصلة
        if (strtolower($currency) === 'usd') {
            return '$' . number_format($amount, 2, '.', '');
        }
        return dms_format_price($amount, $currency);
    }

    // العودة إلى دالة dms_get_user_price الأصلية إذا لم يتم تعيين dms_calculated_unit_price أو كان غير صالحاً
    $custom = dms_get_user_price($item['product_id'], 1);
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';

    if ($custom !== false) {
        // إذا كانت العملة دولار أمريكي، تأكد من تنسيق القيمة برقم عشري مع فاصلة
        if (strtolower($currency) === 'usd') {
            return '$' . number_format($custom, 2, ',', '');
        }
        return dms_format_price($custom, $currency);
    }
    return $price;
}, 20, 2);

/**
 * Filter to modify the subtotal of a cart item.
 *
 * @param string $subtotal The original subtotal HTML.
 * @param array $item The cart item array.
 * @param string $cart_item_key The cart item key.
 * @return string The modified subtotal HTML.
 */
add_filter('woocommerce_cart_item_subtotal', function($subtotal, $item, $cart_item_key) {
    $user_id = get_current_user_id();

    // إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، لا تعرض المجاميع الفرعية.
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return ''; // أو رسالة مثل 'الأسعار غير متاحة'
    }

    // التحقق مما إذا كان سعر الوحدة المحسوب مخصصاً موجوداً في بيانات عنصر سلة التسوق
    if (isset($item['dms_calculated_unit_price']) && is_numeric($item['dms_calculated_unit_price'])) {
        $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
        $amount = (float) $item['dms_calculated_unit_price'] * $item['quantity'];

        // إذا كانت العملة دولار أمريكي، تأكد من تنسيق القيمة برقم عشري مع فاصلة
        if (strtolower($currency) === 'usd') {
            return '$' . number_format($amount, 2, '.', '');
        }
        return dms_format_price($amount, $currency);
    }

    $custom = dms_get_user_price($item['product_id'], 1); // الحصول على سعر الوحدة
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';

    if ($custom !== false) {
        $calculated_subtotal = $custom * $item['quantity'];
        // إذا كانت العملة دولار أمريكي، تأكد من تنسيق القيمة برقم عشري مع فاصلة
        if (strtolower($currency) === 'usd') {
            return '$' . number_format($calculated_subtotal, 2, ',', '');
        }
        return dms_format_price($calculated_subtotal, $currency);
    }
    return $subtotal;
}, 20, 3);


/**
 * Filter to change the currency symbol based on the current user's selected currency.
 *
 * @param string $currency_symbol The original currency symbol.
 * @param string $currency The current currency code.
 * @return string The modified currency symbol.
 */
add_filter('woocommerce_currency_symbol', 'dms_custom_currency_symbol', 20, 2);
function dms_custom_currency_symbol($currency_symbol, $currency) {
    $user_id = get_current_user_id();

    // إذا لم يكن المستخدم مسجلاً الدخول أو حالته ليست "مؤكد"، استخدم رمز عملة WooCommerce الافتراضي
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return $currency_symbol;
    }

    $user_currency = get_user_meta($user_id, 'dms_user_currency', true);

    if (empty($user_currency)) {
        return $currency_symbol; // إذا لم يتم تعيين عملة مخصصة، استخدم رمز عملة WooCommerce الافتراضي
    }

    switch (strtolower($user_currency)) {
        case 'syp':
            return 'ل.س';
        case 'usd':
            return '$';
        // أضف المزيد من الحالات للعملات الأخرى إذا لزم الأمر
        default:
            return $currency_symbol;
    }
}

/**
 * Filter to force 2 decimal places for USD currency in WooCommerce prices.
 */
add_filter('woocommerce_currency_args', 'dms_force_usd_decimals', 10, 1);
function dms_force_usd_decimals($args) {
    // هذا الفلتر يؤثر على wc_price() بشكل عام، ولكن قد لا يؤثر على العرض المباشر لبعض القوالب
    if (isset($args['currency']) && strtolower($args['currency']) === 'usd') {
        $args['decimals'] = 2; // فرض منزلتين عشريتين لعملة الدولار الأمريكي
    }
    return $args;
}
