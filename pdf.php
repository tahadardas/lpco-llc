/**
 * نظام فواتير HTML متقدم لووكومرس
 * يدعم فواتير متعددة حسب العلامات التجارية
 * مع صفحة تحرير للإدارة قبل التحميل
 */

// دالة جديدة للحصول على رابط صورة المنتج
function get_product_image_url($product_id, $size = 'thumbnail') {
    $product = wc_get_product($product_id);
    if (!$product) {
        return '';
    }
    
    // الحصول على معرف الصورة المصغرة
    $image_id = $product->get_image_id();
    
    if ($image_id) {
        $image_url = wp_get_attachment_image_url($image_id, $size);
        if ($image_url) {
            return $image_url;
        }
    }
    
    // إذا لم توجد صورة، نستخدم صورة افتراضية
    return wc_placeholder_img_src($size);
}

// دالة مساعدة لعرض صورة المنتج في جدول المنتجات
function render_product_image_column($product_id, $size = 'thumbnail') {
    $image_url = get_product_image_url($product_id, $size);
    if ($image_url) {
        return '<img src="' . esc_url($image_url) . '" alt="صورة المنتج" style="width: 60px; height: 60px; object-fit: cover; border-radius: 8px; border: 1px solid #e0e0e0; padding: 3px; background: white;">';
    }
    return '<div style="width: 60px; height: 60px; background: #f5f5f5; border-radius: 8px; display: flex; align-items: center; justify-content: center; border: 1px solid #e0e0e0;"><span style="color: #999; font-size: 12px;">لا توجد</span></div>';
}

// إنشاء فواتير HTML منفصلة لكل علامة تجارية (للإدارة فقط)
function generate_order_html($order_id) {
    if (!$order_id) {
        wp_die('رقم الطلب غير موجود');
    }
    
    $order = wc_get_order($order_id);
    if (!$order) {
        wp_die('الطلب غير موجود');
    }
    
    // الحصول على تصنيف العملة للطلب من بيانات العميل
    $order_currency = get_order_currency_type($order);
    
    // إنشاء فواتير HTML قابلة للتحميل منفصلة لكل مجموعة علامات تجارية (للإدارة فقط)
    generate_separated_brand_invoices($order_id, $order, $order_currency);
    exit;
}

// الحصول على تصنيف العملة للطلب من بيانات العميل
function get_order_currency_type($order) {
    // أولاً: جلب تصنيف العميل من بيانات الفاتورة
    $customer_id = $order->get_customer_id();
    
    if ($customer_id) {
        // البحث في حقول العميل عن تصنيف العملة
        $customer_currency = get_customer_currency_type($customer_id);
        if ($customer_currency) {
            return $customer_currency;
        }
    }
    
    // ثانياً: إذا لم يكن هناك تصنيف، ننظر في بيانات الفاتورة
    $billing_country = $order->get_billing_country();
    $billing_city = $order->get_billing_city();
    
    // إذا كان العنوان في سوريا أو المدن السورية، نعتبره ليرة سورية
    if ($billing_country === 'SY' || 
        stripos($billing_city, 'دمشق') !== false ||
        stripos($billing_city, 'حلب') !== false ||
        stripos($billing_city, 'حمص') !== false ||
        stripos($billing_city, 'اللاذقية') !== false ||
        stripos($billing_city, 'سوريا') !== false) {
        return 'syp';
    }
    
    return 'usd'; // افتراضي دولار
}

// الحصول على تصنيف العملة للزبون من الإدارة
function get_customer_currency_type($customer_id) {
    if (!$customer_id) {
        return false;
    }
    
    // البحث في جميع الحقول الممكنة في إدارة ووكومرس
    $possible_fields = [
        'billing_currency',
        'customer_currency_type', 
        'currency_type',
        'preferred_currency',
        'customer_currency',
        '_billing_currency',
        'account_currency',
        'user_currency',
        'payment_currency'
    ];
    
    foreach ($possible_fields as $field) {
        $currency = get_user_meta($customer_id, $field, true);
        if ($currency) {
            $currency_lower = strtolower($currency);
            
            // البحث عن أي إشارة لليرة السورية
            if (in_array($currency_lower, ['syp', 'lbp', 'ليرة', 'ليرة سورية', 'ل.س', 'ليره', 'ليره سوريه', 'syrian', 'syria', 'سوري', 'سورية'])) {
                return 'syp';
            }
            
            // البحث عن أي إشارة للدولار
            if (in_array($currency_lower, ['usd', 'dollar', 'دولار', '$', 'دولار امريكي', 'american', 'us'])) {
                return 'usd';
            }
        }
    }
    
    return false;
}

// الحصول على التصنيف الائتماني للعميل
function get_customer_credit_class($customer_id) {
    if (!$customer_id) {
        return 'غير محدد';
    }
    
    // جلب التصنيف الائتماني من ميتا بيانات المستخدم
    $credit_class = get_user_meta($customer_id, 'credit_class', true);
    
    // إذا لم يكن موجوداً، جربه من حقل آخر
    if (!$credit_class) {
        $credit_class = get_user_meta($customer_id, 'credit_rating', true);
    }
    
    // التحقق من القيم المحتملة
    $credit_class = strtolower(trim($credit_class));
    
    if (in_array($credit_class, ['عالي', 'high', 'a', 'excellent'])) {
        return 'عالي';
    } elseif (in_array($credit_class, ['متوسط', 'medium', 'b', 'good', 'متوسط'])) {
        return 'متوسط';
    } elseif (in_array($credit_class, ['ضعيف', 'low', 'c', 'poor', 'منخفض'])) {
        return 'ضعيف';
    }
    
    return 'غير محدد';
}

// الحصول على اسم العميل من الإدارة (حساب المستخدم)
function get_customer_name_from_admin($customer_id, $order) {
    if (!$customer_id) {
        // إذا لم يكن هناك حساب مستخدم، نستخدم بيانات الفاتورة
        return $order->get_billing_first_name() . ' ' . $order->get_billing_last_name();
    }
    
    // البحث عن اسم المستخدم من الإدارة (حساب المستخدم)
    $user = get_user_by('id', $customer_id);
    if ($user) {
        // أولاً: جلب الاسم من الحقول المخصصة للإدارة
        $possible_name_fields = [
            'billing_first_name',
            'first_name',
            'display_name',
            'nickname',
            'user_login',
            'customer_name',
            'account_name'
        ];
        
        $first_name = '';
        $last_name = '';
        
        // البحث عن الاسم الأول
        foreach ($possible_name_fields as $field) {
            $name = get_user_meta($customer_id, $field, true);
            if (!empty($name)) {
                $first_name = $name;
                break;
            }
        }
        
        // البحث عن الاسم الأخير
        $last_name_fields = ['billing_last_name', 'last_name'];
        foreach ($last_name_fields as $field) {
            $name = get_user_meta($customer_id, $field, true);
            if (!empty($name)) {
                $last_name = $name;
                break;
            }
        }
        
        // إذا وجدنا اسم أول أو أخير
        if (!empty($first_name) || !empty($last_name)) {
            return trim($first_name . ' ' . $last_name);
        }
        
        // استخدام الاسم المعروض
        if (!empty($user->display_name)) {
            return $user->display_name;
        }
        
        // استخدام اسم المستخدم كملجأ أخير
        return $user->user_login;
    }
    
    // إذا فشل كل شيء، نستخدم بيانات الفاتورة
    return $order->get_billing_first_name() . ' ' . $order->get_billing_last_name();
}

// تحديد العلامة التجارية للمنتج
function get_product_brand($product_id) {
    // العلامات التجارية المعرفة
    $brand_mappings = [
        'لَيْكْسِي' => 'lexi',
        'لَيْكْسِي دَاكْسْ' => 'lexi',
        'لكسي' => 'lexi',
        'لكسي داكس' => 'lexi',
        'ليكسي' => 'lexi',
        'ليكسي داكس' => 'lexi',
        'زدني' => 'lexi',
        'زيرو' => 'lexi',
        'قرطاسية' => 'lexi',
        'قرطاسيه' => 'lexi',
        'ديلي' => 'deli',
        'ديلاي' => 'deli',
        'دلي' => 'deli',
        'سونمي' => 'deli',
        'صونمي' => 'deli',
        'مور' => 'moor',
        'يومور' => 'moor',
        'يو مور' => 'moor'
    ];
    
    // 1. التحقق من العلامة التجارية من التصنيفات
    $terms = wp_get_post_terms($product_id, 'product_cat');
    foreach ($terms as $term) {
        $term_name = strtolower(trim($term->name));
        foreach ($brand_mappings as $brand_name => $brand_key) {
            $search_name = strtolower($brand_name);
            if (strpos($term_name, $search_name) !== false || strpos($search_name, $term_name) !== false) {
                return $brand_key;
            }
        }
    }
    
    // 2. التحقق من العلامة التجارية من الوسوم
    $tags = wp_get_post_terms($product_id, 'product_tag');
    foreach ($tags as $tag) {
        $tag_name = strtolower(trim($tag->name));
        foreach ($brand_mappings as $brand_name => $brand_key) {
            $search_name = strtolower($brand_name);
            if (strpos($tag_name, $search_name) !== false || strpos($search_name, $tag_name) !== false) {
                return $brand_key;
            }
        }
    }
    
    // 3. التحقق من العلامة التجارية من اسم المنتج
    $product = wc_get_product($product_id);
    if ($product) {
        $product_name = strtolower($product->get_name());
        foreach ($brand_mappings as $brand_name => $brand_key) {
            $search_name = strtolower($brand_name);
            if (strpos($product_name, $search_name) !== false) {
                return $brand_key;
            }
        }
    }
    
    // 4. التحقق من العلامة التجارية من الحقول المخصصة
    $custom_brand = get_post_meta($product_id, '_brand', true);
    if ($custom_brand) {
        $custom_brand_lower = strtolower($custom_brand);
        foreach ($brand_mappings as $brand_name => $brand_key) {
            $search_name = strtolower($brand_name);
            if (strpos($custom_brand_lower, $search_name) !== false) {
                return $brand_key;
            }
        }
    }
    
    return 'unknown'; // علامة تجارية غير معروفة
}

// الحصول على وحدة القياس للمنتج من بيانات الطلب (ميتا بيانات العنصر)
function get_product_unit($order_item) {
    // أولاً: محاولة الحصول من ميتا بيانات العنصر في الطلب
    $item_meta_data = $order_item->get_meta_data();
    
    // الحقول المحتملة للوحدة في ميتا بيانات العنصر
    $possible_unit_meta_keys = [
        'unit_name',
        'dms_unit_name',
        'unit_type',
        'dms_unit_type',
        '_unit', 
        '_product_unit',
        'unit',
        'product_unit'
    ];
    
    foreach ($possible_unit_meta_keys as $meta_key) {
        $unit = $order_item->get_meta($meta_key);
        if (!empty($unit) && $unit !== '') {
            return $unit;
        }
    }
    
    // ثانياً: إذا لم نجد في ميتا البيانات، نبحث في المنتج نفسه
    $product_id = $order_item->get_product_id();
    $variation_id = $order_item->get_variation_id();
    $actual_product_id = $variation_id ?: $product_id;
    
    $product = wc_get_product($actual_product_id);
    if (!$product) {
        return 'قطعة'; // قيمة افتراضية
    }
    
    // الحقول المحتملة لوحدة القياس في المنتج
    $possible_unit_fields = [
        '_unit', '_product_unit', 'unit', 'product_unit',
        '_measurement_unit', 'measurement_unit', '_unit_of_measure',
        '_uom', 'uom', '_quantity_unit', 'quantity_unit'
    ];
    
    foreach ($possible_unit_fields as $field) {
        $unit = get_post_meta($actual_product_id, $field, true);
        if (!empty($unit) && $unit !== '') {
            return $unit;
        }
    }
    
    // إذا لم نجد حقل وحدة، نستخدم القيمة الافتراضية
    return 'قطعة';
}

// دالة جديدة لجلب الوحدة بالعربية من ميتا البيانات
function get_product_unit_arabic($order_item) {
    // الحصول على الوحدة بالعربية من ميتا البيانات
    $arabic_unit = $order_item->get_meta('unit_name');
    if (!empty($arabic_unit)) {
        return $arabic_unit;
    }
    
    // محاولة الحصول من حقل آخر
    $arabic_unit = $order_item->get_meta('dms_unit_name');
    if (!empty($arabic_unit)) {
        return $arabic_unit;
    }
    
    // استخدام الدالة الأصلية كبديل
    return get_product_unit($order_item);
}

// تجميع المنتجات حسب العلامات التجارية (للإدارة فقط)
function group_products_by_brand($order_items) {
    $grouped_items = [
        'lexi' => [],    // ليكسي وقرطاسية
        'deli' => [],    // ديلي وسونمي
        'moor' => []     // يومور
    ];
    
    foreach ($order_items as $item_id => $item) {
        $product_id = $item->get_product_id();
        $variation_id = $item->get_variation_id();
        
        // استخدام معرف المنتج أو المتغير
        $actual_product_id = $variation_id ?: $product_id;
        
        $brand = get_product_brand($actual_product_id);
        $unit = get_product_unit_arabic($item); // استخدام الدالة الجديدة
        $image_url = get_product_image_url($actual_product_id, 'thumbnail'); // إضافة صورة المنتج
        
        // إذا كانت العلامة التجارية غير معروفة، نضعها في المجموعة الافتراضية (ليكسي)
        if ($brand === 'unknown') {
            $brand = 'lexi';
        }
        
        // تجميع ديلي وسونمي معاً
        if ($brand === 'sonmi') {
            $brand = 'deli';
        }
        
        if (isset($grouped_items[$brand])) {
            $grouped_items[$brand][] = [
                'item' => $item,
                'item_id' => $item_id,
                'product_id' => $actual_product_id,
                'name' => $item->get_name(),
                'quantity' => $item->get_quantity(),
                'unit' => $unit,
                'total' => $item->get_total(),
                'image_url' => $image_url // إضافة رابط الصورة
            ];
        }
    }
    
    // إزالة المجموعات الفارغة
    foreach ($grouped_items as $brand_key => $items) {
        if (empty($items)) {
            unset($grouped_items[$brand_key]);
        }
    }
    
    return $grouped_items;
}

// الحصول على اسم المجموعة بالعربية (تم التعديل هنا)
function get_brand_group_name($brand_key) {
    $brand_names = [
        'lexi' => '', // تم حذف النص هنا
        'deli' => 'ديلي / سونمي',
        'moor' => 'يومور'
    ];
    
    return isset($brand_names[$brand_key]) ? $brand_names[$brand_key] : $brand_key;
}

// صفحة تحرير الفاتورة قبل التحميل (للإدارة فقط) - معدلة لإضافة صورة المنتج
function generate_invoice_edit_page($order_id, $order, $order_currency, $brand_key, $items) {
    $is_syp_order = ($order_currency === 'syp');
    
    // حساب المجموع لهذه العلامة التجارية
    $brand_total = 0;
    foreach ($items as $item_data) {
        $brand_total += $item_data['total'];
    }
    
    // الحصول على رابط اللوغو
    $logo_url = get_theme_logo_url();
    
    // الحصول على اسم العميل من الإدارة
    $customer_id = $order->get_customer_id();
    $customer_name = get_customer_name_from_admin($customer_id, $order);
    
    // الحصول على التصنيف الائتماني للعميل
    $credit_class = get_customer_credit_class($customer_id);
    
    ?>
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>تعديل مسودة الطلب #<?php echo $order_id; ?> - <?php echo get_brand_group_name($brand_key); ?></title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: #000;
                background: #f5f5f5;
                min-height: 100vh;
                padding: 20px;
                direction: rtl;
            }
            .edit-container {
                max-width: 1300px;
                margin: 0 auto;
                background: white;
                border: 2px solid #c00;
                border-radius: 10px;
                overflow: hidden;
                box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            }
            .edit-header {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 30px 40px;
                text-align: center;
                position: relative;
                border-bottom: 3px solid #fff;
            }
            .store-logo {
                max-width: 180px;
                max-height: 70px;
                margin-bottom: 15px;
                background: white;
                padding: 10px;
                border-radius: 8px;
            }
            .edit-header h1 {
                font-size: 2em;
                margin-bottom: 10px;
                color: white;
                border-bottom: 2px solid rgba(255,255,255,0.3);
                padding-bottom: 10px;
            }
            .brand-title {
                font-size: 1.6em;
                color: white;
                margin: 10px 0;
                background: rgba(255,255,255,0.2);
                padding: 10px 20px;
                border-radius: 5px;
                display: inline-block;
                backdrop-filter: blur(10px);
            }
            .edit-content {
                padding: 30px;
            }
            .alert {
                background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
                border: 2px solid #c00;
                border-radius: 8px;
                padding: 20px;
                margin-bottom: 25px;
                text-align: center;
            }
            .alert h4 {
                color: #c00;
                margin-bottom: 10px;
                font-size: 1.2em;
            }
            .card {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-bottom: 25px;
                transition: all 0.3s ease;
            }
            .card:hover {
                border-color: #c00;
                box-shadow: 0 5px 15px rgba(192,0,0,0.1);
            }
            .card h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .card h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 15px;
            }
            .form-group {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }
            .form-group label {
                font-weight: bold;
                color: #333;
                font-size: 0.9em;
                display: flex;
                align-items: center;
                gap: 5px;
            }
            .form-group label:after {
                content: ":";
            }
            .form-input, .form-textarea {
                width: 100%;
                padding: 12px 15px;
                border: 2px solid #e0e0e0;
                border-radius: 6px;
                font-size: 1em;
                text-align: right;
                direction: rtl;
                transition: all 0.3s ease;
                background: #f9f9f9;
            }
            .form-input:focus, .form-textarea:focus {
                border-color: #c00;
                outline: none;
                background: white;
                box-shadow: 0 0 0 3px rgba(192,0,0,0.1);
            }
            .form-textarea {
                min-height: 100px;
                resize: vertical;
                font-family: inherit;
                line-height: 1.5;
            }
            .products-table {
                width: 100%;
                border-collapse: collapse;
                background: white;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                overflow: hidden;
            }
            .products-table th {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 15px;
                text-align: right;
                font-weight: 600;
                border: none;
            }
            .products-table td {
                padding: 15px;
                border: 1px solid #e0e0e0;
                text-align: right;
                color: #333;
                vertical-align: middle;
            }
            .products-table tr:nth-child(even) {
                background: #f9f9f9;
            }
            .products-table tr:hover {
                background: #f0f0f0;
            }
            .product-image {
                width: 70px;
                height: 70px;
                object-fit: cover;
                border-radius: 8px;
                border: 2px solid #e0e0e0;
                padding: 3px;
                background: white;
            }
            .unit-column {
                text-align: center;
                font-size: 0.9em;
                color: #666;
                width: 120px;
            }
            .action-buttons {
                display: flex;
                justify-content: center;
                gap: 20px;
                margin-top: 40px;
                padding-top: 30px;
                border-top: 2px solid #e0e0e0;
                flex-wrap: wrap;
            }
            .btn {
                padding: 14px 35px;
                font-size: 1em;
                border-radius: 6px;
                cursor: pointer;
                transition: all 0.3s ease;
                display: inline-flex;
                align-items: center;
                gap: 10px;
                text-decoration: none;
                min-width: 200px;
                justify-content: center;
                font-weight: 600;
                border: 2px solid transparent;
            }
            .btn-primary {
                background: linear-gradient(135deg, #28a745 0%, #218838 100%);
                color: white;
            }
            .btn-primary:hover {
                background: linear-gradient(135deg, #218838 0%, #1e7e34 100%);
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(40,167,69,0.3);
            }
            .btn-secondary {
                background: white;
                color: #666;
                border-color: #e0e0e0;
            }
            .btn-secondary:hover {
                background: #f5f5f5;
                border-color: #c00;
                color: #c00;
                transform: translateY(-2px);
            }
            .btn-print {
                background: linear-gradient(135deg, #007bff 0%, #0056b3 100%);
                color: white;
            }
            .btn-print:hover {
                background: linear-gradient(135deg, #0056b3 0%, #004085 100%);
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(0,123,255,0.3);
            }
            .edit-footer {
                background: #f8f9fa;
                padding: 25px;
                text-align: center;
                color: #666;
                border-top: 2px solid #e0e0e0;
                font-size: 0.9em;
            }
            .remove-checkbox {
                transform: scale(1.3);
                cursor: pointer;
            }
            .remove-label {
                display: flex;
                align-items: center;
                gap: 5px;
                color: #dc3545;
                font-weight: bold;
                cursor: pointer;
            }
            .total-display {
                font-size: 1.8em;
                font-weight: bold;
                color: #c00;
                text-align: center;
                margin: 20px 0;
                padding: 15px;
                border: 2px dashed #c00;
                border-radius: 8px;
                background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
            }
            
            /* تنسيقات إضافية للتصنيف الائتماني */
            .credit-info {
                background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%);
                border: 2px solid #2196f3;
                border-radius: 8px;
                padding: 15px;
                margin-bottom: 20px;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            
            .credit-class-badge {
                display: inline-block;
                padding: 8px 16px;
                border-radius: 20px;
                font-weight: bold;
                font-size: 1em;
                color: white;
                text-align: center;
                min-width: 100px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            
            .credit-high {
                background: linear-gradient(135deg, #4caf50, #2e7d32);
            }
            
            .credit-medium {
                background: linear-gradient(135deg, #ff9800, #f57c00);
            }
            
            .credit-low {
                background: linear-gradient(135deg, #f44336, #c62828);
            }
            
            .credit-undefined {
                background: linear-gradient(135deg, #9e9e9e, #616161);
            }
            
            @media print {
                body {
                    background: white !important;
                    padding: 0 !important;
                }
                .edit-container {
                    box-shadow: none !important;
                    border-radius: 0 !important;
                    border: 2px solid #000 !important;
                }
                .action-buttons {
                    display: none !important;
                }
            }
            @media (max-width: 768px) {
                .edit-content {
                    padding: 15px;
                }
                .card {
                    padding: 15px;
                }
                .products-table {
                    font-size: 0.9em;
                }
                .products-table th, 
                .products-table td {
                    padding: 10px;
                }
                .btn {
                    min-width: 100%;
                    margin-bottom: 10px;
                }
                .action-buttons {
                    flex-direction: column;
                }
                .credit-info {
                    flex-direction: column;
                    gap: 10px;
                    text-align: center;
                }
                .product-image {
                    width: 50px;
                    height: 50px;
                }
            }
        </style>
    </head>
    <body>
        <form id="invoiceEditForm" method="post" action="<?php echo esc_url(add_query_arg([
            'download_invoice' => 'final',
            'order_id' => $order_id,
            'brand' => $brand_key,
            '_wpnonce' => wp_create_nonce('download_final_invoice_' . $order_id . '_' . $brand_key)
        ], home_url('/'))); ?>">
            
            <div class="edit-container">
                <!-- رأس صفحة التحرير -->
                <div class="edit-header">
                    <?php if ($logo_url): ?>
                    <img src="<?php echo $logo_url; ?>" alt="<?php echo get_bloginfo('name'); ?>" class="store-logo">
                    <?php endif; ?>
                    <h1>✏️ تعديل مسودة الطلب #<?php echo $order_id; ?></h1>
                    <?php if (!empty(get_brand_group_name($brand_key))): ?>
                    <div class="brand-title">📋 <?php echo get_brand_group_name($brand_key); ?></div>
                    <?php endif; ?>
                </div>
                
                <!-- محتوى صفحة التحرير -->
                <div class="edit-content">
                    <!-- تنبيه للإدارة -->
                    <div class="alert">
                        <h4>🛠️ صفحة التحرير للإدارة فقط</h4>
                        <p>يمكنك تعديل أي بيانات قبل تحميل الفاتورة النهائية. التعديلات ستظهر فقط في الفاتورة التي ستقوم بتحميلها.</p>
                    </div>
                    
                    <!-- التصنيف الائتماني -->
                    <div class="credit-info">
                        <div>
                            <strong>📊 التصنيف الائتماني للعميل:</strong>
                            <p style="margin: 5px 0 0 0; color: #555;">
                                <?php 
                                switch($credit_class) {
                                    case 'عالي':
                                        echo '<span style="color: #4caf50;">✓ موافق - ممتاز</span>';
                                        break;
                                    case 'متوسط':
                                        echo '<span style="color: #ff9800;">✓ موافق - جيد</span>';
                                        break;
                                    case 'ضعيف':
                                        echo '<span style="color: #f44336;">✗ غير موافق - يحتاج مراجعة</span>';
                                        break;
                                    default:
                                        echo '<span style="color: #9e9e9e;">غير محدد</span>';
                                }
                                ?>
                            </p>
                        </div>
                        <div>
                            <span class="credit-class-badge credit-<?php 
                                switch($credit_class) {
                                    case 'عالي': echo 'high'; break;
                                    case 'متوسط': echo 'medium'; break;
                                    case 'ضعيف': echo 'low'; break;
                                    default: echo 'undefined';
                                }
                            ?>">
                                <?php echo $credit_class; ?>
                            </span>
                        </div>
                    </div>
                    
                    <!-- المجموع الحالي -->
                    <div class="total-display">
                        المجموع الحالي: 
                        <?php if ($is_syp_order): ?>
                        <?php echo number_format($brand_total, 0); ?> ليرة سورية
                        <?php else: ?>
                        $ <?php echo number_format($brand_total, 2); ?>
                        <?php endif; ?>
                    </div>
                    
                    <!-- معلومات العميل -->
                    <div class="card">
                        <h3>👤 معلومات العميل</h3>
                        <div class="grid">
                            <div class="form-group">
                                <label>الاسم الكامل</label>
                                <input type="text" name="customer_name" value="<?php echo esc_attr($customer_name); ?>" class="form-input" required>
                            </div>
                            <div class="form-group">
                                <label>البريد الإلكتروني</label>
                                <input type="email" name="customer_email" value="<?php echo esc_attr($order->get_billing_email()); ?>" class="form-input" required>
                            </div>
                            <div class="form-group">
                                <label>رقم الهاتف</label>
                                <input type="text" name="customer_phone" value="<?php echo esc_attr($order->get_billing_phone()); ?>" class="form-input" required>
                            </div>
                            <div class="form-group">
                                <label>العنوان</label>
                                <textarea name="customer_address" class="form-textarea" required><?php echo esc_textarea($order->get_billing_address_1() . ', ' . $order->get_billing_city()); ?></textarea>
                            </div>
                        </div>
                    </div>
                    
                    <!-- المنتجات -->
                    <div class="card">
                        <h3>🛍️ المنتجات المطلوبة</h3>
                        <table class="products-table">
                            <thead>
                                <tr>
                                    <th width="12%">الصورة</th>
                                    <th width="28%">المنتج</th>
                                    <th width="12%">الكمية</th>
                                    <th width="12%">الوحدة</th>
                                    <th width="18%">المجموع</th>
                                    <th width="18%">الإجراء</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($items as $index => $item_data): ?>
                                <tr>
                                    <td style="text-align: center;">
                                        <?php echo render_product_image_column($item_data['product_id'], 'thumbnail'); ?>
                                        <input type="hidden" 
                                               name="products[<?php echo $index; ?>][image_url]" 
                                               value="<?php echo esc_attr($item_data['image_url']); ?>">
                                    </td>
                                    <td>
                                        <input type="text" 
                                               name="products[<?php echo $index; ?>][name]" 
                                               value="<?php echo esc_attr($item_data['name']); ?>" 
                                               class="form-input"
                                               required>
                                        <input type="hidden" 
                                               name="products[<?php echo $index; ?>][item_id]" 
                                               value="<?php echo $item_data['item_id']; ?>">
                                        <input type="hidden" 
                                               name="products[<?php echo $index; ?>][product_id]" 
                                               value="<?php echo $item_data['product_id']; ?>">
                                    </td>
                                    <td>
                                        <input type="number" 
                                               name="products[<?php echo $index; ?>][quantity]" 
                                               value="<?php echo esc_attr($item_data['quantity']); ?>" 
                                               class="form-input"
                                               min="1" 
                                               step="1"
                                               style="text-align: center;"
                                               required
                                               onchange="calculateTotal(this, <?php echo $index; ?>)">
                                    </td>
                                    <td>
                                        <input type="text" 
                                               name="products[<?php echo $index; ?>][unit]" 
                                               value="<?php echo esc_attr($item_data['unit']); ?>" 
                                               class="form-input"
                                               style="text-align: center;"
                                               required>
                                    </td>
                                    <td>
                                        <div style="display: flex; align-items: center; gap: 5px;">
                                            <input type="number" 
                                                   name="products[<?php echo $index; ?>][total]" 
                                                   value="<?php echo esc_attr($item_data['total']); ?>" 
                                                   class="form-input"
                                                   min="0"
                                                   step="0.01"
                                                   style="text-align: center; font-weight: bold;"
                                                   required
                                                   onchange="updateGrandTotal()">
                                            <span style="font-weight: bold; color: #c00;">
                                                <?php echo $is_syp_order ? 'ل.س' : '$'; ?>
                                            </span>
                                        </div>
                                    </td>
                                    <td style="text-align: center;">
                                        <label class="remove-label">
                                            <input type="checkbox" 
                                                   name="products[<?php echo $index; ?>][remove]" 
                                                   value="1" 
                                                   class="remove-checkbox"
                                                   onchange="updateGrandTotal()">
                                            🗑️ حذف
                                        </label>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                        <div style="margin-top: 15px; text-align: center;">
                            <small style="color: #666;">💡 ملاحظة: يمكنك تعديل الكمية أو السعر أو حذف المنتجات غير المطلوبة</small>
                        </div>
                    </div>
                    
                    <!-- ملاحظات إضافية -->
                    <div class="card">
                        <h3>📝 ملاحظات إضافية</h3>
                        <div class="grid">
                            <div class="form-group">
                                <label>ملاحظات تظهر في الفاتورة</label>
                                <textarea name="invoice_notes" class="form-textarea" placeholder="اكتب أي ملاحظات إضافية تريد إضافتها للفاتورة..."></textarea>
                            </div>
                            <div class="form-group">
                                <label>ملاحظات داخلية (للإدارة فقط)</label>
                                <textarea name="internal_notes" class="form-textarea" placeholder="ملاحظات داخلية للإدارة فقط..."></textarea>
                            </div>
                        </div>
                    </div>
                    
                    <!-- معلومات الدفع والحالة -->
                    <div class="card">
                        <h3>💳 معلومات الدفع والحالة</h3>
                        <div class="grid">
                            <div class="form-group">
                                <label>طريقة الدفع</label>
                                <input type="text" 
                                       name="payment_method" 
                                       value="<?php echo esc_attr($order->get_payment_method_title() ?: 'غير محدد'); ?>" 
                                       class="form-input">
                            </div>
                            <div class="form-group">
                                <label>حالة الطلب</label>
                                <select name="order_status" class="form-input">
                                    <option value="قيد الانتظار" <?php echo $order->get_status() == 'pending' ? 'selected' : ''; ?>>قيد الانتظار</option>
                                    <option value="قيد المعالجة" <?php echo $order->get_status() == 'processing' ? 'selected' : ''; ?>>قيد المعالجة</option>
                                    <option value="مكتمل" <?php echo $order->get_status() == 'completed' ? 'selected' : ''; ?>>مكتمل</option>
                                    <option value="معلق" <?php echo $order->get_status() == 'on-hold' ? 'selected' : ''; ?>>معلق</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label>تاريخ التعديل</label>
                                <input type="datetime-local" 
                                       name="modified_date" 
                                       value="<?php echo date('Y-m-d\TH:i'); ?>" 
                                       class="form-input">
                            </div>
                        </div>
                    </div>
                    
                    <!-- أزرار الإجراءات -->
                    <div class="action-buttons">
                        <button type="submit" class="btn btn-primary">
                            💾 حفظ وتحميل الفاتورة النهائية
                        </button>
                        <button type="button" class="btn btn-print" onclick="window.print()">
                            🖨️ معاينة قبل التحميل
                        </button>
                        <a href="<?php echo esc_url(add_query_arg([
                            'download_invoice' => 'links',
                            'order_id' => $order_id,
                            '_wpnonce' => wp_create_nonce('download_links_' . $order_id)
                        ], home_url('/'))); ?>" class="btn btn-secondary">
                            ↩️ العودة للقائمة
                        </a>
                    </div>
                </div>
                
                <!-- تذييل صفحة التحرير -->
                <div class="edit-footer">
                    <p><strong>📄 صفحة التحرير للإدارة فقط</strong></p>
                    <p>جميع التعديلات ستظهر في الفاتورة النهائية فقط</p>
                    <p>تاريخ الإنشاء: <?php echo date('Y-m-d H:i'); ?></p>
                    <?php if (!empty(get_brand_group_name($brand_key))): ?>
                    <p style="margin-top: 10px;">
                        فاتورة: <?php echo get_brand_group_name($brand_key); ?>
                    </p>
                    <?php endif; ?>
                    <p style="margin-top: 10px; font-weight: bold; color: #2196f3;">
                        التصنيف الائتماني للعميل: <?php echo $credit_class; ?>
                    </p>
                </div>
            </div>
            
            <!-- حقول مخفية -->
            <input type="hidden" name="order_id" value="<?php echo $order_id; ?>">
            <input type="hidden" name="brand_key" value="<?php echo $brand_key; ?>">
            <input type="hidden" name="currency" value="<?php echo $order_currency; ?>">
            <input type="hidden" name="original_total" value="<?php echo $brand_total; ?>">
            <input type="hidden" name="credit_class" value="<?php echo $credit_class; ?>">
            
        </form>
        
        <script>
        // حساب المجموع الكلي
        function updateGrandTotal() {
            let grandTotal = 0;
            const rows = document.querySelectorAll('tbody tr');
            
            rows.forEach((row, index) => {
                const removeCheckbox = row.querySelector('.remove-checkbox');
                const totalInput = row.querySelector('input[name*="[total]"]');
                
                // إذا لم يكن المنتج محذوفاً
                if (!removeCheckbox.checked && totalInput) {
                    const total = parseFloat(totalInput.value) || 0;
                    grandTotal += total;
                }
            });
            
            // تحديث عرض المجموع
            const totalDisplay = document.querySelector('.total-display');
            const currency = '<?php echo $is_syp_order ? "ليرة سورية" : "$"; ?>';
            
            if (totalDisplay) {
                if ('<?php echo $is_syp_order; ?>' === '1') {
                    totalDisplay.innerHTML = `المجموع الحالي: <strong>${grandTotal.toLocaleString('ar-EG')} ${currency}</strong>`;
                } else {
                    totalDisplay.innerHTML = `المجموع الحالي: <strong>${currency} ${grandTotal.toFixed(2)}</strong>`;
                }
            }
            
            return grandTotal;
        }
        
        // حساب المجموع بناءً على الكمية
        function calculateTotal(input, index) {
            const quantity = parseFloat(input.value) || 0;
            // يمكنك إضافة منطق لحساب السعر إذا كان لديك سعر الوحدة
            // حالياً نترك السعر كما هو أو يمكن تعديله يدوياً
        }
        
        // تحديث المجموع عند تحميل الصفحة
        document.addEventListener('DOMContentLoaded', function() {
            updateGrandTotal();
            
            // إضافة مستمعات للأحداث
            document.querySelectorAll('input[name*="[total]"], .remove-checkbox').forEach(input => {
                input.addEventListener('change', updateGrandTotal);
            });
        });
        
        // منع الإرسال المزدوج للاستمارة
        document.getElementById('invoiceEditForm').addEventListener('submit', function(e) {
            const submitBtn = this.querySelector('button[type="submit"]');
            const grandTotal = updateGrandTotal();
            
            // تأكيد قبل الإرسال
            if (!confirm(`هل تريد حفظ التعديلات وتحميل الفاتورة؟\nالمجموع النهائي: ${grandTotal.toLocaleString('ar-EG')} <?php echo $is_syp_order ? "ليرة سورية" : "$"; ?>`)) {
                e.preventDefault();
                return;
            }
            
            submitBtn.disabled = true;
            submitBtn.innerHTML = '⏳ جاري التحميل...';
        });
        
        // معاينة قبل الطباعة
        function printPreview() {
            window.print();
        }
        </script>
    </body>
    </html>
    <?php
    exit;
}

// إنشاء فاتورة فردية لعلامة تجارية محددة بعد التحرير - مع إضافة صورة المنتج
function generate_final_invoice_html($order_id, $order, $order_currency, $brand_key, $items, $form_data = []) {
    $is_syp_order = ($order_currency === 'syp');
    
    // استخدام البيانات من النموذج إذا كانت موجودة
    $customer_name = isset($form_data['customer_name']) ? $form_data['customer_name'] : get_customer_name_from_admin($order->get_customer_id(), $order);
    $customer_email = isset($form_data['customer_email']) ? $form_data['customer_email'] : $order->get_billing_email();
    $customer_phone = isset($form_data['customer_phone']) ? $form_data['customer_phone'] : $order->get_billing_phone();
    $customer_address = isset($form_data['customer_address']) ? $form_data['customer_address'] : $order->get_billing_address_1() . ', ' . $order->get_billing_city();
    $payment_method = isset($form_data['payment_method']) ? $form_data['payment_method'] : ($order->get_payment_method_title() ?: 'غير محدد');
    $invoice_notes = isset($form_data['invoice_notes']) ? $form_data['invoice_notes'] : '';
    $order_status = isset($form_data['order_status']) ? $form_data['order_status'] : $order->get_status();
    $modified_date = isset($form_data['modified_date']) ? $form_data['modified_date'] : date('Y-m-d H:i');
    
    // الحصول على التصنيف الائتماني
    $customer_id = $order->get_customer_id();
    $credit_class = isset($form_data['credit_class']) ? $form_data['credit_class'] : get_customer_credit_class($customer_id);
    
    // حساب المجموع بعد التعديلات
    $brand_total = 0;
    $filtered_items = [];
    
    foreach ($items as $index => $item_data) {
        // التحقق إذا كان المنتج محذوف
        $remove_item = isset($form_data['products'][$index]['remove']) && $form_data['products'][$index]['remove'] == '1';
        
        if (!$remove_item) {
            // استخدام البيانات المعدلة إذا كانت موجودة
            $item_name = isset($form_data['products'][$index]['name']) ? $form_data['products'][$index]['name'] : $item_data['name'];
            $quantity = isset($form_data['products'][$index]['quantity']) ? floatval($form_data['products'][$index]['quantity']) : $item_data['quantity'];
            $unit = isset($form_data['products'][$index]['unit']) ? $form_data['products'][$index]['unit'] : $item_data['unit'];
            $total = isset($form_data['products'][$index]['total']) ? floatval($form_data['products'][$index]['total']) : $item_data['total'];
            $image_url = isset($form_data['products'][$index]['image_url']) ? $form_data['products'][$index]['image_url'] : $item_data['image_url'];
            
            $filtered_items[] = [
                'name' => $item_name,
                'quantity' => $quantity,
                'unit' => $unit,
                'total' => $total,
                'image_url' => $image_url,
                'product_id' => $item_data['product_id']
            ];
            
            $brand_total += $total;
        }
    }
    
    // الحصول على رابط اللوغو
    $logo_url = get_theme_logo_url();
    
    // إعداد الهيدر للتحميل
    header('Content-Type: text/html; charset=utf-8');
    header('Content-Disposition: attachment; filename="مسودة_الطلب_' . $order_id . '_' . $brand_key . '_نهائية.html"');
    header('Pragma: no-cache');
    header('Expires: 0');
    
    ?>
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>مسودة الطلب #<?php echo $order_id; ?> - <?php echo get_bloginfo('name'); ?></title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: #000;
                background: #fff;
                min-height: 100vh;
                padding: 20px;
                direction: rtl;
            }
            .invoice-container {
                max-width: 1100px;
                margin: 0 auto;
                background: white;
                border: 2px solid #c00;
                border-radius: 10px;
                overflow: hidden;
            }
            .invoice-header {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 30px 40px;
                text-align: center;
                position: relative;
                border-bottom: 3px solid white;
            }
            .store-logo {
                max-width: 200px;
                max-height: 80px;
                margin-bottom: 15px;
                background: white;
                padding: 10px;
                border-radius: 8px;
            }
            .invoice-header h1 {
                font-size: 2.2em;
                margin-bottom: 10px;
                color: white;
                border-bottom: 2px solid rgba(255,255,255,0.3);
                padding-bottom: 10px;
            }
            .brand-title {
                font-size: 1.6em;
                color: white;
                margin: 10px 0;
                background: rgba(255,255,255,0.2);
                padding: 10px 20px;
                border-radius: 5px;
                display: inline-block;
            }
            .credit-badge-header {
                display: inline-block;
                margin-top: 10px;
                padding: 6px 15px;
                border-radius: 15px;
                font-weight: bold;
                color: white;
                font-size: 0.9em;
            }
            .credit-high {
                background: linear-gradient(135deg, #4caf50, #2e7d32);
            }
            .credit-medium {
                background: linear-gradient(135deg, #ff9800, #f57c00);
            }
            .credit-low {
                background: linear-gradient(135deg, #f44336, #c62828);
            }
            .credit-undefined {
                background: linear-gradient(135deg, #9e9e9e, #616161);
            }
            .modified-badge {
                background: #28a745;
                color: white;
                padding: 8px 20px;
                border-radius: 20px;
                font-size: 0.9em;
                margin-top: 10px;
                display: inline-block;
                font-weight: bold;
            }
            .invoice-content {
                padding: 30px;
            }
            .customer-card {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-bottom: 25px;
            }
            .customer-card h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .customer-card h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .customer-info-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 15px;
            }
            .info-item {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }
            .info-label {
                font-weight: bold;
                color: #333;
                font-size: 0.9em;
            }
            .info-value {
                color: #000;
                font-size: 1.1em;
                padding: 10px;
                background: #f9f9f9;
                border-radius: 5px;
                border-right: 3px solid #c00;
            }
            .products-section {
                margin: 30px 0;
            }
            .products-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .products-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .products-table {
                width: 100%;
                border-collapse: collapse;
                background: white;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                overflow: hidden;
            }
            .products-table th {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 15px;
                text-align: right;
                font-weight: 600;
                border: none;
            }
            .products-table td {
                padding: 15px;
                border: 1px solid #e0e0e0;
                text-align: right;
                color: #333;
                vertical-align: middle;
            }
            .products-table tr:nth-child(even) {
                background: #f9f9f9;
            }
            .product-image {
                width: 60px;
                height: 60px;
                object-fit: cover;
                border-radius: 8px;
                border: 2px solid #e0e0e0;
                padding: 3px;
                background: white;
            }
            .unit-column {
                text-align: center;
                font-size: 0.9em;
                color: #666;
                width: 100px;
            }
            .notes-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
                display: <?php echo !empty($invoice_notes) ? 'block' : 'none'; ?>;
            }
            .notes-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .notes-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .notes-content {
                color: #000;
                font-size: 1em;
                line-height: 1.8;
                padding: 15px;
                background: #f9f9f9;
                border-radius: 5px;
                border-right: 3px solid #c00;
                white-space: pre-line;
            }
            .total-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
            }
            .total-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .total-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .total-amount {
                font-size: 2em;
                font-weight: bold;
                color: #c00;
                text-align: center;
                margin: 20px 0;
                padding: 20px;
                border: 2px dashed #c00;
                border-radius: 8px;
                background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
            }
            .payment-info {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 15px;
                margin-top: 20px;
            }
            
            /* قسم التصنيف الائتماني */
            .credit-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
            }
            .credit-section h3 {
                color: #2196f3;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .credit-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #2196f3;
                border-radius: 2px;
            }
            .credit-display {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                border: 1px solid #dee2e6;
            }
            .credit-class-display {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            .credit-class-label {
                font-weight: bold;
                color: #333;
            }
            .credit-class-value {
                padding: 10px 20px;
                border-radius: 20px;
                color: white;
                font-weight: bold;
                min-width: 100px;
                text-align: center;
            }
            .credit-status {
                text-align: center;
                padding: 10px;
                border-radius: 8px;
                font-weight: bold;
                margin-top: 10px;
            }
            .approved {
                background: #e8f5e9;
                color: #2e7d32;
                border: 2px solid #4caf50;
            }
            .not-approved {
                background: #ffebee;
                color: #c62828;
                border: 2px solid #f44336;
            }
            
            .print-section {
                text-align: center;
                margin-top: 40px;
                padding-top: 30px;
                border-top: 2px solid #e0e0e0;
            }
            .print-btn {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                border: none;
                padding: 15px 40px;
                font-size: 1.1em;
                border-radius: 6px;
                cursor: pointer;
                transition: all 0.3s ease;
                display: inline-flex;
                align-items: center;
                gap: 10px;
                font-weight: bold;
            }
            .print-btn:hover {
                background: linear-gradient(135deg, #a00 0%, #800 100%);
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(192,0,0,0.3);
            }
            .invoice-footer {
                background: #f8f9fa;
                padding: 25px;
                text-align: center;
                color: #666;
                border-top: 2px solid #e0e0e0;
                margin-top: 30px;
            }
            @media print {
                body {
                    background: white !important;
                    padding: 0 !important;
                }
                .invoice-container {
                    box-shadow: none !important;
                    border-radius: 0 !important;
                    border: 2px solid #000 !important;
                }
                .print-section {
                    display: none !important;
                }
                .product-image {
                    width: 50px;
                    height: 50px;
                }
            }
            @media (max-width: 768px) {
                .products-table th, 
                .products-table td {
                    padding: 10px;
                }
                .product-image {
                    width: 40px;
                    height: 40px;
                }
            }
        </style>
    </head>
    <body>
        <div class="invoice-container">
            <!-- رأس الفاتورة -->
            <div class="invoice-header">
                <?php if ($logo_url): ?>
                <img src="<?php echo $logo_url; ?>" alt="<?php echo get_bloginfo('name'); ?>" class="store-logo">
                <?php endif; ?>
                <h1>📄 مسودة الطلب #<?php echo $order_id; ?></h1>
                <?php if (!empty(get_brand_group_name($brand_key))): ?>
                <div class="brand-title"><?php echo get_brand_group_name($brand_key); ?></div>
                <?php endif; ?>
                <div class="credit-badge-header credit-<?php 
                    switch($credit_class) {
                        case 'عالي': echo 'high'; break;
                        case 'متوسط': echo 'medium'; break;
                        case 'ضعيف': echo 'low'; break;
                        default: echo 'undefined';
                    }
                ?>">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                </div>
                <div class="modified-badge">📝 معدلة بتاريخ: <?php echo $modified_date; ?></div>
            </div>
            
            <!-- محتوى الفاتورة -->
            <div class="invoice-content">
                <!-- معلومات العميل -->
                <div class="customer-card">
                    <h3>👤 معلومات العميل</h3>
                    <div class="customer-info-grid">
                        <div class="info-item">
                            <span class="info-label">الاسم الكامل</span>
                            <span class="info-value"><?php echo esc_html($customer_name); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">البريد الإلكتروني</span>
                            <span class="info-value"><?php echo esc_html($customer_email); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">رقم الهاتف</span>
                            <span class="info-value"><?php echo esc_html($customer_phone); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">العنوان</span>
                            <span class="info-value"><?php echo esc_html($customer_address); ?></span>
                        </div>
                    </div>
                </div>
                
                <!-- قسم التصنيف الائتماني -->
                <div class="credit-section">
                    <h3>📊 التصنيف الائتماني</h3>
                    <div class="credit-display">
                        <div class="credit-class-display">
                            <span class="credit-class-label">تصنيف العميل:</span>
                            <span class="credit-class-value credit-<?php 
                                switch($credit_class) {
                                    case 'عالي': echo 'high'; break;
                                    case 'متوسط': echo 'medium'; break;
                                    case 'ضعيف': echo 'low'; break;
                                    default: echo 'undefined';
                                }
                            ?>">
                                <?php echo $credit_class; ?>
                            </span>
                        </div>
                        <div class="credit-status <?php 
                            echo ($credit_class == 'عالي' || $credit_class == 'متوسط') ? 'approved' : 'not-approved';
                        ?>">
                            <?php 
                            if ($credit_class == 'عالي') {
                                echo '✓ موافق - ممتاز (جميع الطلبات مقبولة)';
                            } elseif ($credit_class == 'متوسط') {
                                echo '✓ موافق - جيد (الطلبات مقبولة)';
                            } elseif ($credit_class == 'ضعيف') {
                                echo '✗ غير موافق - يحتاج مراجعة';
                            } else {
                                echo 'غير محدد';
                            }
                            ?>
                        </div>
                    </div>
                </div>
                
                <!-- المنتجات -->
                <div class="products-section">
                    <h3>🛍️ المنتجات المطلوبة</h3>
                    <table class="products-table">
                        <thead>
                            <tr>
                                <th width="15%">الصورة</th>
                                <th width="45%">المنتج</th>
                                <th width="10%">الكمية</th>
                                <th width="10%" class="unit-column">الوحدة</th>
                                <th width="20%">المجموع</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($filtered_items as $item): ?>
                            <tr>
                                <td style="text-align: center;">
                                    <?php 
                                    if (!empty($item['image_url'])) {
                                        echo '<img src="' . esc_url($item['image_url']) . '" alt="' . esc_attr($item['name']) . '" class="product-image">';
                                    } else {
                                        echo render_product_image_column($item['product_id'], 'thumbnail');
                                    }
                                    ?>
                                </td>
                                <td><?php echo esc_html($item['name']); ?></td>
                                <td style="text-align: center;"><?php echo $item['quantity']; ?></td>
                                <td class="unit-column"><?php echo esc_html($item['unit']); ?></td>
                                <td style="font-weight: bold; color: #c00;">
                                    <?php if ($is_syp_order): ?>
                                    <?php echo number_format($item['total'], 0); ?> ل.س
                                    <?php else: ?>
                                    $ <?php echo number_format($item['total'], 2); ?>
                                    <?php endif; ?>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
                
                <!-- ملاحظات -->
                <?php if (!empty($invoice_notes)): ?>
                <div class="notes-section">
                    <h3>📝 ملاحظات إضافية</h3>
                    <div class="notes-content">
                        <?php echo nl2br(esc_html($invoice_notes)); ?>
                    </div>
                </div>
                <?php endif; ?>
                
                <!-- المجموع النهائي -->
                <div class="total-section">
                    <h3>💰 الحساب النهائي</h3>
                    <div class="total-amount">
                        <?php if ($is_syp_order): ?>
                        <?php echo number_format($brand_total, 0); ?> ليرة سورية
                        <?php else: ?>
                        $ <?php echo number_format($brand_total, 2); ?>
                        <?php endif; ?>
                    </div>
                    <div class="payment-info">
                        <div class="info-item">
                            <span class="info-label">💳 طريقة الدفع</span>
                            <span class="info-value"><?php echo esc_html($payment_method); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">📊 حالة الطلب</span>
                            <span class="info-value"><?php echo esc_html($order_status); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">📅 تاريخ الطلب</span>
                            <span class="info-value"><?php echo $order->get_date_created()->format('Y-m-d H:i'); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">✏️ آخر تعديل</span>
                            <span class="info-value"><?php echo $modified_date; ?></span>
                        </div>
                    </div>
                </div>
                
                <!-- زر الطباعة -->
                <div class="print-section">
                    <button class="print-btn" onclick="window.print()">
                        🖨️ طباعة المسودة النهائية
                    </button>
                </div>
            </div>
            
            <!-- تذييل الفاتورة -->
            <div class="invoice-footer">
                <p><strong>شكراً لكم على ثقتكم بنا 🤝</strong></p>
                <p>📞 لمتابعة الطلب يمكنكم الاتصال بنا على الرقم</p>
                <p style="font-weight: bold; font-size: 1.2em; margin: 10px 0; color: #c00;">0965433110</p>
                <p>📅 تاريخ الإنشاء: <?php echo date('Y-m-d H:i'); ?></p>
                <p>✏️ آخر تعديل: <?php echo $modified_date; ?></p>
                <?php if (!empty(get_brand_group_name($brand_key))): ?>
                <p style="margin-top: 10px; font-size: 0.9em; color: #666;">
                    📋 فاتورة <?php echo get_brand_group_name($brand_key); ?>
                </p>
                <?php endif; ?>
                <p style="margin-top: 10px; font-weight: bold; color: #2196f3;">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                    <?php 
                    if ($credit_class == 'عالي' || $credit_class == 'متوسط') {
                        echo ' - ✓ موافق';
                    } elseif ($credit_class == 'ضعيف') {
                        echo ' - ✗ غير موافق';
                    }
                    ?>
                </p>
            </div>
        </div>
    </body>
    </html>
    <?php
}

// إنشاء فاتورة كاملة واحدة للزبائن (تم التعديل هنا) - مع إضافة صورة المنتج
function generate_complete_invoice_for_customer($order_id, $order, $order_currency) {
    $is_syp_order = ($order_currency === 'syp');
    $order_total = $order->get_total();
    
    // الحصول على رابط اللوغو
    $logo_url = get_theme_logo_url();
    
    // الحصول على اسم العميل من الإدارة
    $customer_id = $order->get_customer_id();
    $customer_name = get_customer_name_from_admin($customer_id, $order);
    
    // الحصول على التصنيف الائتماني للعميل
    $credit_class = get_customer_credit_class($customer_id);
    
    // إعداد الهيدر للتحميل
    header('Content-Type: text/html; charset=utf-8');
    header('Content-Disposition: attachment; filename="مسودة_الطلب_' . $order_id . '.html"');
    header('Pragma: no-cache');
    header('Expires: 0');
    
    // الحصول على جميع منتجات الطلب
    $order_items = $order->get_items();
    
    ?>
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>مسودة الطلب #<?php echo $order_id; ?> - <?php echo get_bloginfo('name'); ?></title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: #000;
                background: #fff;
                min-height: 100vh;
                padding: 20px;
                direction: rtl;
            }
            .invoice-container {
                max-width: 1100px;
                margin: 0 auto;
                background: white;
                border: 2px solid #c00;
                border-radius: 10px;
                overflow: hidden;
            }
            .invoice-header {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 30px 40px;
                text-align: center;
                position: relative;
                border-bottom: 3px solid white;
            }
            .store-logo {
                max-width: 200px;
                max-height: 80px;
                margin-bottom: 15px;
                background: white;
                padding: 10px;
                border-radius: 8px;
            }
            .invoice-header h1 {
                font-size: 2.2em;
                margin-bottom: 10px;
                color: white;
                border-bottom: 2px solid rgba(255,255,255,0.3);
                padding-bottom: 10px;
            }
            .invoice-header .store-info {
                font-size: 1.1em;
                color: white;
                margin-top: 10px;
                opacity: 0.9;
            }
            
            /* تنسيق التصنيف الائتماني في الهيدر */
            .credit-badge-header {
                display: inline-block;
                margin-top: 10px;
                padding: 6px 15px;
                border-radius: 15px;
                font-weight: bold;
                color: white;
                font-size: 0.9em;
            }
            .credit-high {
                background: linear-gradient(135deg, #4caf50, #2e7d32);
            }
            .credit-medium {
                background: linear-gradient(135deg, #ff9800, #f57c00);
            }
            .credit-low {
                background: linear-gradient(135deg, #f44336, #c62828);
            }
            .credit-undefined {
                background: linear-gradient(135deg, #9e9e9e, #616161);
            }
            
            .invoice-content {
                padding: 30px;
            }
            .customer-card {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-bottom: 25px;
            }
            .customer-card h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .customer-card h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .customer-info-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 15px;
            }
            .info-item {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }
            .info-label {
                font-weight: bold;
                color: #333;
                font-size: 0.9em;
            }
            .info-value {
                color: #000;
                font-size: 1.1em;
                padding: 10px;
                background: #f9f9f9;
                border-radius: 5px;
                border-right: 3px solid #c00;
            }
            .products-section {
                margin: 30px 0;
            }
            .products-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .products-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .products-table {
                width: 100%;
                border-collapse: collapse;
                background: white;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                overflow: hidden;
            }
            .products-table th {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 15px;
                text-align: right;
                font-weight: 600;
                border: none;
            }
            .products-table td {
                padding: 15px;
                border: 1px solid #e0e0e0;
                text-align: right;
                color: #333;
                vertical-align: middle;
            }
            .products-table tr:nth-child(even) {
                background: #f9f9f9;
            }
            .product-image {
                width: 60px;
                height: 60px;
                object-fit: cover;
                border-radius: 8px;
                border: 2px solid #e0e0e0;
                padding: 3px;
                background: white;
            }
            .unit-column {
                text-align: center;
                font-size: 0.9em;
                color: #666;
                width: 100px;
            }
            .total-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
            }
            .total-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .total-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .total-amount {
                font-size: 2em;
                font-weight: bold;
                color: #c00;
                text-align: center;
                margin: 20px 0;
                padding: 20px;
                border: 2px dashed #c00;
                border-radius: 8px;
                background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
            }
            .payment-info {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 15px;
                margin-top: 20px;
            }
            
            /* قسم التصنيف الائتماني */
            .credit-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
            }
            .credit-section h3 {
                color: #2196f3;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .credit-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #2196f3;
                border-radius: 2px;
            }
            .credit-display {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                border: 1px solid #dee2e6;
            }
            .credit-class-display {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            .credit-class-label {
                font-weight: bold;
                color: #333;
            }
            .credit-class-value {
                padding: 10px 20px;
                border-radius: 20px;
                color: white;
                font-weight: bold;
                min-width: 100px;
                text-align: center;
            }
            .credit-status {
                text-align: center;
                padding: 10px;
                border-radius: 8px;
                font-weight: bold;
                margin-top: 10px;
            }
            .approved {
                background: #e8f5e9;
                color: #2e7d32;
                border: 2px solid #4caf50;
            }
            .not-approved {
                background: #ffebee;
                color: #c62828;
                border: 2px solid #f44336;
            }
            
            .print-section {
                text-align: center;
                margin-top: 40px;
                padding-top: 30px;
                border-top: 2px solid #e0e0e0;
            }
            .print-btn {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                border: none;
                padding: 15px 40px;
                font-size: 1.1em;
                border-radius: 6px;
                cursor: pointer;
                transition: all 0.3s ease;
                display: inline-flex;
                align-items: center;
                gap: 10px;
                font-weight: bold;
            }
            .print-btn:hover {
                background: linear-gradient(135deg, #a00 0%, #800 100%);
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(192,0,0,0.3);
            }
            .invoice-footer {
                background: #f8f9fa;
                padding: 25px;
                text-align: center;
                color: #666;
                border-top: 2px solid #e0e0e0;
                margin-top: 30px;
            }
            @media print {
                body {
                    background: white !important;
                    padding: 0 !important;
                }
                .invoice-container {
                    box-shadow: none !important;
                    border-radius: 0 !important;
                    border: 2px solid #000 !important;
                }
                .print-section {
                    display: none !important;
                }
                .product-image {
                    width: 50px;
                    height: 50px;
                }
            }
            @media (max-width: 768px) {
                .products-table th, 
                .products-table td {
                    padding: 10px;
                }
                .product-image {
                    width: 40px;
                    height: 40px;
                }
            }
        </style>
    </head>
    <body>
        <div class="invoice-container">
            <!-- رأس الفاتورة -->
            <div class="invoice-header">
                <?php if ($logo_url): ?>
                <img src="<?php echo $logo_url; ?>" alt="<?php echo get_bloginfo('name'); ?>" class="store-logo">
                <?php endif; ?>
                <h1>📄 فاتورة مبدأئية #<?php echo $order_id; ?></h1>
                <div class="credit-badge-header credit-<?php 
                    switch($credit_class) {
                        case 'عالي': echo 'high'; break;
                        case 'متوسط': echo 'medium'; break;
                        case 'ضعيف': echo 'low'; break;
                        default: echo 'undefined';
                    }
                ?>">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                </div>
                <div class="store-info">
                    <strong><?php echo get_bloginfo('name'); ?></strong>
                </div>
            </div>
            
            <!-- محتوى الفاتورة -->
            <div class="invoice-content">
                <!-- معلومات العميل -->
                <div class="customer-card">
                    <h3>👤 معلومات العميل</h3>
                    <div class="customer-info-grid">
                        <div class="info-item">
                            <span class="info-label">الاسم الكامل</span>
                            <span class="info-value"><?php echo esc_html($customer_name); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">البريد الإلكتروني</span>
                            <span class="info-value"><?php echo $order->get_billing_email(); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">رقم الهاتف</span>
                            <span class="info-value"><?php echo $order->get_billing_phone(); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">العنوان</span>
                            <span class="info-value"><?php echo $order->get_billing_address_1() . ', ' . $order->get_billing_city(); ?></span>
                        </div>
                    </div>
                </div>
                
                <!-- قسم التصنيف الائتماني -->
                <div class="credit-section">
                    <h3>📊 التصنيف الائتماني</h3>
                    <div class="credit-display">
                        <div class="credit-class-display">
                            <span class="credit-class-label">تصنيف العميل:</span>
                            <span class="credit-class-value credit-<?php 
                                switch($credit_class) {
                                    case 'عالي': echo 'high'; break;
                                    case 'متوسط': echo 'medium'; break;
                                    case 'ضعيف': echo 'low'; break;
                                    default: echo 'undefined';
                                }
                            ?>">
                                <?php echo $credit_class; ?>
                            </span>
                        </div>
                        <div class="credit-status <?php 
                            echo ($credit_class == 'عالي' || $credit_class == 'متوسط') ? 'approved' : 'not-approved';
                        ?>">
                            <?php 
                            if ($credit_class == 'عالي') {
                                echo '✓ موافق - ممتاز (جميع الطلبات مقبولة)';
                            } elseif ($credit_class == 'متوسط') {
                                echo '✓ موافق - جيد (الطلبات مقبولة)';
                            } elseif ($credit_class == 'ضعيف') {
                                echo '✗ غير موافق - يحتاج مراجعة';
                            } else {
                                echo 'غير محدد';
                            }
                            ?>
                        </div>
                    </div>
                </div>
                
                <!-- المنتجات -->
                <div class="products-section">
                    <h3>🛍️ المنتجات المطلوبة</h3>
                    <table class="products-table">
                        <thead>
                            <tr>
                                <th width="15%">الصورة</th>
                                <th width="45%">المنتج</th>
                                <th width="10%">الكمية</th>
                                <th width="10%" class="unit-column">الوحدة</th>
                                <th width="20%">المجموع</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php 
                            foreach ($order_items as $item_id => $item): 
                                $product_id = $item->get_product_id();
                                $variation_id = $item->get_variation_id();
                                $actual_product_id = $variation_id ?: $product_id;
                                $unit = get_product_unit_arabic($item);
                                $image_url = get_product_image_url($actual_product_id, 'thumbnail');
                            ?>
                            <tr>
                                <td style="text-align: center;">
                                    <?php 
                                    if ($image_url) {
                                        echo '<img src="' . esc_url($image_url) . '" alt="' . esc_attr($item->get_name()) . '" class="product-image">';
                                    } else {
                                        echo render_product_image_column($actual_product_id, 'thumbnail');
                                    }
                                    ?>
                                </td>
                                <td><?php echo $item->get_name(); ?></td>
                                <td style="text-align: center;"><?php echo $item->get_quantity(); ?></td>
                                <td class="unit-column"><?php echo $unit; ?></td>
                                <td style="font-weight: bold; color: #c00;">
                                    <?php if ($is_syp_order): ?>
                                    <?php echo number_format($item->get_total(), 0); ?> ل.س
                                    <?php else: ?>
                                    $ <?php echo number_format($item->get_total(), 2); ?>
                                    <?php endif; ?>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
                
                <!-- المجموع النهائي -->
                <div class="total-section">
                    <h3>💰 الحساب النهائي</h3>
                    <div class="total-amount">
                        <?php if ($is_syp_order): ?>
                        <?php echo number_format($order_total, 0); ?> ليرة سورية
                        <?php else: ?>
                        $ <?php echo number_format($order_total, 2); ?>
                        <?php endif; ?>
                    </div>
                    <div class="payment-info">
                        <div class="info-item">
                            <span class="info-label">💳 طريقة الدفع</span>
                            <span class="info-value"><?php echo $order->get_payment_method_title() ?: 'غير محدد'; ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">📊 حالة الطلب</span>
                            <span class="info-value">
                                <?php 
                                $status = $order->get_status();
                                $status_labels = [
                                    'pending' => 'قيد الانتظار',
                                    'processing' => 'قيد المعالجة', 
                                    'completed' => 'مكتمل',
                                    'on-hold' => 'معلق',
                                    'cancelled' => 'ملغى',
                                    'refunded' => 'تم الاسترجاع'
                                ];
                                echo $status_labels[$status] ?? $status;
                                ?>
                            </span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">📅 تاريخ الطلب</span>
                            <span class="info-value"><?php echo $order->get_date_created()->format('Y-m-d H:i'); ?></span>
                        </div>
                    </div>
                </div>
                
                <!-- زر الطباعة -->
                <div class="print-section">
                    <button class="print-btn" onclick="window.print()">
                        🖨️ طباعة الفاتورة المبدئية
                    </button>
                </div>
            </div>
            
            <!-- تذييل الفاتورة -->
            <div class="invoice-footer">
                <p><strong>شكراً لاستخدامكم تطبيق الأمير الصغير 🤝</strong></p>
                <p>📞 لمتابعة الطلب يمكنكم الاتصال بنا على الرقم</p>
                <p style="font-weight: bold; font-size: 1.2em; margin: 10px 0; color: #c00;">0965433110</p>
                <p>📅 تاريخ الإنشاء: <?php echo date('Y-m-d H:i'); ?></p>
                <p style="margin-top: 10px; font-weight: bold; color: #2196f3;">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                    <?php 
                    if ($credit_class == 'عالي' || $credit_class == 'متوسط') {
                        echo ' - ✓ موافق';
                    } elseif ($credit_class == 'ضعيف') {
                        echo ' - ✗ غير موافق';
                    }
                    ?>
                </p>
            </div>
        </div>
    </body>
    </html>
    <?php
}

// إنشاء فاتورة منفصلة لكل مجموعة علامات تجارية (للإدارة فقط) - مع إضافة صورة المنتج
function generate_separated_brand_invoices($order_id, $order, $order_currency) {
    // التحقق إذا كان الطلب من الإدارة أو من الزبون
    $is_admin_request = (is_admin() || current_user_can('edit_shop_orders'));
    
    // إذا كان طلب من الزبون، عرض فاتورة كاملة واحدة
    if (!$is_admin_request) {
        generate_complete_invoice_for_customer($order_id, $order, $order_currency);
        exit;
    }
    
    // تجميع المنتجات حسب العلامات التجارية
    $order_items = $order->get_items();
    $grouped_products = group_products_by_brand($order_items);
    
    // التحقق من نوع الطلب
    if (!isset($_GET['brand'])) {
        generate_invoice_download_links_page($order_id, $order, $order_currency, $grouped_products);
        exit;
    }
    
    $requested_brand = sanitize_text_field($_GET['brand']);
    
    // التحقق من أن العلامة التجارية المطلوبة موجودة
    if (!isset($grouped_products[$requested_brand])) {
        wp_die('الفاتورة المطلوبة غير موجودة');
    }
    
    // التحقق إذا كان طلب تحرير
    if (isset($_GET['edit']) && $_GET['edit'] == 'true') {
        // عرض صفحة التحرير
        generate_invoice_edit_page($order_id, $order, $order_currency, $requested_brand, $grouped_products[$requested_brand]);
        exit;
    }
    
    // إنشاء الفاتورة العادية بدون تحرير
    $is_syp_order = ($order_currency === 'syp');
    $brand_total = 0;
    foreach ($grouped_products[$requested_brand] as $item_data) {
        $brand_total += $item_data['total'];
    }
    
    // الحصول على رابط اللوغو
    $logo_url = get_theme_logo_url();
    
    // الحصول على اسم العميل من الإدارة
    $customer_id = $order->get_customer_id();
    $customer_name = get_customer_name_from_admin($customer_id, $order);
    
    // الحصول على التصنيف الائتماني للعميل
    $credit_class = get_customer_credit_class($customer_id);
    
    // إعداد الهيدر للتحميل
    header('Content-Type: text/html; charset=utf-8');
    header('Content-Disposition: attachment; filename="مسودة_الطلب_' . $order_id . '_' . $requested_brand . '.html"');
    header('Pragma: no-cache');
    header('Expires: 0');
    
    ?>
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>مسودة الطلب #<?php echo $order_id; ?> - <?php echo get_bloginfo('name'); ?></title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: #000;
                background: #fff;
                min-height: 100vh;
                padding: 20px;
                direction: rtl;
            }
            .invoice-container {
                max-width: 1100px;
                margin: 0 auto;
                background: white;
                border: 2px solid #c00;
                border-radius: 10px;
                overflow: hidden;
            }
            .invoice-header {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 30px 40px;
                text-align: center;
                position: relative;
                border-bottom: 3px solid white;
            }
            .store-logo {
                max-width: 200px;
                max-height: 80px;
                margin-bottom: 15px;
                background: white;
                padding: 10px;
                border-radius: 8px;
            }
            .invoice-header h1 {
                font-size: 2.2em;
                margin-bottom: 10px;
                color: white;
                border-bottom: 2px solid rgba(255,255,255,0.3);
                padding-bottom: 10px;
            }
            .brand-title {
                font-size: 1.6em;
                color: white;
                margin: 10px 0;
                background: rgba(255,255,255,0.2);
                padding: 10px 20px;
                border-radius: 5px;
                display: inline-block;
            }
            
            /* تنسيق التصنيف الائتماني في الهيدر */
            .credit-badge-header {
                display: inline-block;
                margin-top: 10px;
                padding: 6px 15px;
                border-radius: 15px;
                font-weight: bold;
                color: white;
                font-size: 0.9em;
            }
            .credit-high {
                background: linear-gradient(135deg, #4caf50, #2e7d32);
            }
            .credit-medium {
                background: linear-gradient(135deg, #ff9800, #f57c00);
            }
            .credit-low {
                background: linear-gradient(135deg, #f44336, #c62828);
            }
            .credit-undefined {
                background: linear-gradient(135deg, #9e9e9e, #616161);
            }
            
            .invoice-header .store-info {
                font-size: 1.1em;
                color: white;
                margin-top: 10px;
                opacity: 0.9;
            }
            .invoice-content {
                padding: 30px;
            }
            .customer-card {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-bottom: 25px;
            }
            .customer-card h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .customer-card h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .customer-info-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 15px;
            }
            .info-item {
                display: flex;
                flex-direction: column;
                gap: 8px;
            }
            .info-label {
                font-weight: bold;
                color: #333;
                font-size: 0.9em;
            }
            .info-value {
                color: #000;
                font-size: 1.1em;
                padding: 10px;
                background: #f9f9f9;
                border-radius: 5px;
                border-right: 3px solid #c00;
            }
            .products-section {
                margin: 30px 0;
            }
            .products-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .products-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .products-table {
                width: 100%;
                border-collapse: collapse;
                background: white;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                overflow: hidden;
            }
            .products-table th {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 15px;
                text-align: right;
                font-weight: 600;
                border: none;
            }
            .products-table td {
                padding: 15px;
                border: 1px solid #e0e0e0;
                text-align: right;
                color: #333;
                vertical-align: middle;
            }
            .products-table tr:nth-child(even) {
                background: #f9f9f9;
            }
            .product-image {
                width: 60px;
                height: 60px;
                object-fit: cover;
                border-radius: 8px;
                border: 2px solid #e0e0e0;
                padding: 3px;
                background: white;
            }
            .unit-column {
                text-align: center;
                font-size: 0.9em;
                color: #666;
                width: 100px;
            }
            .total-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
            }
            .total-section h3 {
                color: #c00;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .total-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #c00;
                border-radius: 2px;
            }
            .total-amount {
                font-size: 2em;
                font-weight: bold;
                color: #c00;
                text-align: center;
                margin: 20px 0;
                padding: 20px;
                border: 2px dashed #c00;
                border-radius: 8px;
                background: linear-gradient(135deg, #ffebee 0%, #ffcdd2 100%);
            }
            .payment-info {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 15px;
                margin-top: 20px;
            }
            
            /* قسم التصنيف الائتماني */
            .credit-section {
                background: white;
                padding: 25px;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                margin-top: 30px;
            }
            .credit-section h3 {
                color: #2196f3;
                margin-bottom: 20px;
                font-size: 1.3em;
                border-bottom: 2px solid #f0f0f0;
                padding-bottom: 10px;
                display: flex;
                align-items: center;
                gap: 10px;
            }
            .credit-section h3:before {
                content: "";
                display: inline-block;
                width: 5px;
                height: 20px;
                background: #2196f3;
                border-radius: 2px;
            }
            .credit-display {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                border: 1px solid #dee2e6;
            }
            .credit-class-display {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-bottom: 15px;
            }
            .credit-class-label {
                font-weight: bold;
                color: #333;
            }
            .credit-class-value {
                padding: 10px 20px;
                border-radius: 20px;
                color: white;
                font-weight: bold;
                min-width: 100px;
                text-align: center;
            }
            .credit-status {
                text-align: center;
                padding: 10px;
                border-radius: 8px;
                font-weight: bold;
                margin-top: 10px;
            }
            .approved {
                background: #e8f5e9;
                color: #2e7d32;
                border: 2px solid #4caf50;
            }
            .not-approved {
                background: #ffebee;
                color: #c62828;
                border: 2px solid #f44336;
            }
            
            .print-section {
                text-align: center;
                margin-top: 40px;
                padding-top: 30px;
                border-top: 2px solid #e0e0e0;
            }
            .print-btn {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                border: none;
                padding: 15px 40px;
                font-size: 1.1em;
                border-radius: 6px;
                cursor: pointer;
                transition: all 0.3s ease;
                display: inline-flex;
                align-items: center;
                gap: 10px;
                font-weight: bold;
            }
            .print-btn:hover {
                background: linear-gradient(135deg, #a00 0%, #800 100%);
                transform: translateY(-2px);
                box-shadow: 0 8px 20px rgba(192,0,0,0.3);
            }
            .invoice-footer {
                background: #f8f9fa;
                padding: 25px;
                text-align: center;
                color: #666;
                border-top: 2px solid #e0e0e0;
                margin-top: 30px;
            }
            @media print {
                body {
                    background: white !important;
                    padding: 0 !important;
                }
                .invoice-container {
                    box-shadow: none !important;
                    border-radius: 0 !important;
                    border: 2px solid #000 !important;
                }
                .print-section {
                    display: none !important;
                }
                .product-image {
                    width: 50px;
                    height: 50px;
                }
            }
            @media (max-width: 768px) {
                .products-table th, 
                .products-table td {
                    padding: 10px;
                }
                .product-image {
                    width: 40px;
                    height: 40px;
                }
            }
        </style>
    </head>
    <body>
        <div class="invoice-container">
            <!-- رأس الفاتورة -->
            <div class="invoice-header">
                <?php if ($logo_url): ?>
                <img src="<?php echo $logo_url; ?>" alt="<?php echo get_bloginfo('name'); ?>" class="store-logo">
                <?php endif; ?>
                <h1>📄 مسودة الطلب #<?php echo $order_id; ?></h1>
                <?php if (!empty(get_brand_group_name($requested_brand))): ?>
                <div class="brand-title"><?php echo get_brand_group_name($requested_brand); ?></div>
                <?php endif; ?>
                <div class="credit-badge-header credit-<?php 
                    switch($credit_class) {
                        case 'عالي': echo 'high'; break;
                        case 'متوسط': echo 'medium'; break;
                        case 'ضعيف': echo 'low'; break;
                        default: echo 'undefined';
                    }
                ?>">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                </div>
                <div class="store-info">
                    <strong><?php echo get_bloginfo('name'); ?></strong>
                </div>
            </div>
            
            <!-- محتوى الفاتورة -->
            <div class="invoice-content">
                <!-- معلومات العميل -->
                <div class="customer-card">
                    <h3>👤 معلومات العميل</h3>
                    <div class="customer-info-grid">
                        <div class="info-item">
                            <span class="info-label">الاسم الكامل</span>
                            <span class="info-value"><?php echo esc_html($customer_name); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">البريد الإلكتروني</span>
                            <span class="info-value"><?php echo $order->get_billing_email(); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">رقم الهاتف</span>
                            <span class="info-value"><?php echo $order->get_billing_phone(); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">العنوان</span>
                            <span class="info-value"><?php echo $order->get_billing_address_1() . ', ' . $order->get_billing_city(); ?></span>
                        </div>
                    </div>
                </div>
                
                <!-- قسم التصنيف الائتماني -->
                <div class="credit-section">
                    <h3>📊 التصنيف الائتماني</h3>
                    <div class="credit-display">
                        <div class="credit-class-display">
                            <span class="credit-class-label">تصنيف العميل:</span>
                            <span class="credit-class-value credit-<?php 
                                switch($credit_class) {
                                    case 'عالي': echo 'high'; break;
                                    case 'متوسط': echo 'medium'; break;
                                    case 'ضعيف': echo 'low'; break;
                                    default: echo 'undefined';
                                }
                            ?>">
                                <?php echo $credit_class; ?>
                            </span>
                        </div>
                        <div class="credit-status <?php 
                            echo ($credit_class == 'عالي' || $credit_class == 'متوسط') ? 'approved' : 'not-approved';
                        ?>">
                            <?php 
                            if ($credit_class == 'عالي') {
                                echo '✓ موافق - ممتاز (جميع الطلبات مقبولة)';
                            } elseif ($credit_class == 'متوسط') {
                                echo '✓ موافق - جيد (الطلبات مقبولة)';
                            } elseif ($credit_class == 'ضعيف') {
                                echo '✗ غير موافق - يحتاج مراجعة';
                            } else {
                                echo 'غير محدد';
                            }
                            ?>
                        </div>
                    </div>
                </div>
                
                <!-- المنتجات -->
                <div class="products-section">
                    <h3>🛍️ المنتجات المطلوبة</h3>
                    <table class="products-table">
                        <thead>
                            <tr>
                                <th width="15%">الصورة</th>
                                <th width="45%">المنتج</th>
                                <th width="10%">الكمية</th>
                                <th width="10%" class="unit-column">الوحدة</th>
                                <th width="20%">المجموع</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($grouped_products[$requested_brand] as $item_data): ?>
                            <tr>
                                <td style="text-align: center;">
                                    <?php 
                                    if (!empty($item_data['image_url'])) {
                                        echo '<img src="' . esc_url($item_data['image_url']) . '" alt="' . esc_attr($item_data['name']) . '" class="product-image">';
                                    } else {
                                        echo render_product_image_column($item_data['product_id'], 'thumbnail');
                                    }
                                    ?>
                                </td>
                                <td><?php echo $item_data['name']; ?></td>
                                <td style="text-align: center;"><?php echo $item_data['quantity']; ?></td>
                                <td class="unit-column"><?php echo $item_data['unit']; ?></td>
                                <td style="font-weight: bold; color: #c00;">
                                    <?php if ($is_syp_order): ?>
                                    <?php echo number_format($item_data['total'], 0); ?> ل.س
                                    <?php else: ?>
                                    $ <?php echo number_format($item_data['total'], 2); ?>
                                    <?php endif; ?>
                                </td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
                
                <!-- المجموع النهائي -->
                <div class="total-section">
                    <h3>💰 الحساب النهائي<?php echo !empty(get_brand_group_name($requested_brand)) ? ' - ' . get_brand_group_name($requested_brand) : ''; ?></h3>
                    <div class="total-amount">
                        <?php if ($is_syp_order): ?>
                        <?php echo number_format($brand_total, 0); ?> ليرة سورية
                        <?php else: ?>
                        $ <?php echo number_format($brand_total, 2); ?>
                        <?php endif; ?>
                    </div>
                    <div class="payment-info">
                        <div class="info-item">
                            <span class="info-label">💳 طريقة الدفع</span>
                            <span class="info-value"><?php echo $order->get_payment_method_title() ?: 'غير محدد'; ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">📊 حالة الطلب</span>
                            <span class="info-value">
                                <?php 
                                $status = $order->get_status();
                                $status_labels = [
                                    'pending' => 'قيد الانتظار',
                                    'processing' => 'قيد المعالجة', 
                                    'completed' => 'مكتمل',
                                    'on-hold' => 'معلق',
                                    'cancelled' => 'ملغى',
                                    'refunded' => 'تم الاسترجاع'
                                ];
                                echo $status_labels[$status] ?? $status;
                                ?>
                            </span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">📅 تاريخ الطلب</span>
                            <span class="info-value"><?php echo $order->get_date_created()->format('Y-m-d H:i'); ?></span>
                        </div>
                    </div>
                </div>
                
                <!-- زر الطباعة -->
                <div class="print-section">
                    <button class="print-btn" onclick="window.print()">
                        🖨️ طباعة المسودة
                    </button>
                </div>
            </div>
            
            <!-- تذييل الفاتورة -->
            <div class="invoice-footer">
                <p><strong>شكراً لكم على ثقتكم بنا 🤝</strong></p>
                <p>📞 لمتابعة الطلب يمكنكم الاتصال بنا على الرقم</p>
                <p style="font-weight: bold; font-size: 1.2em; margin: 10px 0; color: #c00;">0965433110</p>
                <p>📅 تاريخ الإنشاء: <?php echo date('Y-m-d H:i'); ?></p>
                <?php if (!empty(get_brand_group_name($requested_brand))): ?>
                <p style="margin-top: 10px; font-size: 0.9em; color: #666;">
                    📋 فاتورة <?php echo get_brand_group_name($requested_brand); ?>
                </p>
                <?php endif; ?>
                <p style="margin-top: 10px; font-weight: bold; color: #2196f3;">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                    <?php 
                    if ($credit_class == 'عالي' || $credit_class == 'متوسط') {
                        echo ' - ✓ موافق';
                    } elseif ($credit_class == 'ضعيف') {
                        echo ' - ✗ غير موافق';
                    }
                    ?>
                </p>
            </div>
        </div>
    </body>
    </html>
    <?php
}

// صفحة رئيسية لعرض روابط تحميل الفواتير المنفصلة (للإدارة فقط)
function generate_invoice_download_links_page($order_id, $order, $order_currency, $grouped_products) {
    $customer_id = $order->get_customer_id();
    $customer_name = get_customer_name_from_admin($customer_id, $order);
    
    // الحصول على التصنيف الائتماني للعميل
    $credit_class = get_customer_credit_class($customer_id);
    
    ?>
    <!DOCTYPE html>
    <html dir="rtl" lang="ar">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>تحميل فواتير الطلب #<?php echo $order_id; ?> (الإدارة)</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                line-height: 1.6;
                color: #333;
                background: #f5f5f5;
                min-height: 100vh;
                padding: 20px;
                direction: rtl;
            }
            .container {
                max-width: 1000px;
                margin: 50px auto;
                background: white;
                border-radius: 10px;
                box-shadow: 0 5px 15px rgba(0,0,0,0.1);
                overflow: hidden;
            }
            .header {
                background: linear-gradient(135deg, #c00 0%, #a00 100%);
                color: white;
                padding: 40px 30px;
                text-align: center;
            }
            .header h1 {
                font-size: 2.2em;
                margin-bottom: 10px;
            }
            .header p {
                font-size: 1.1em;
                opacity: 0.9;
            }
            
            /* تنسيق التصنيف الائتماني في الهيدر */
            .credit-header-badge {
                display: inline-block;
                margin-top: 10px;
                padding: 8px 20px;
                border-radius: 20px;
                font-weight: bold;
                color: white;
                font-size: 1em;
            }
            .credit-high {
                background: linear-gradient(135deg, #4caf50, #2e7d32);
            }
            .credit-medium {
                background: linear-gradient(135deg, #ff9800, #f57c00);
            }
            .credit-low {
                background: linear-gradient(135deg, #f44336, #c62828);
            }
            .credit-undefined {
                background: linear-gradient(135deg, #9e9e9e, #616161);
            }
            
            .content {
                padding: 40px;
            }
            .order-info {
                background: #f9f9f9;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 30px;
                border-right: 4px solid #c00;
            }
            .order-info h3 {
                color: #c00;
                margin-bottom: 15px;
                font-size: 1.3em;
            }
            .info-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                gap: 15px;
            }
            .info-item {
                display: flex;
                flex-direction: column;
            }
            .info-label {
                font-weight: bold;
                color: #666;
                font-size: 0.9em;
                margin-bottom: 5px;
            }
            .info-value {
                color: #333;
                font-size: 1em;
            }
            .invoices-list {
                margin: 30px 0;
            }
            .invoice-card {
                background: white;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                padding: 25px;
                margin-bottom: 20px;
                transition: all 0.3s ease;
                position: relative;
            }
            .invoice-card:hover {
                border-color: #c00;
                transform: translateY(-2px);
                box-shadow: 0 5px 15px rgba(192,0,0,0.1);
            }
            .invoice-card h3 {
                color: #c00;
                margin-bottom: 10px;
                font-size: 1.4em;
            }
            .invoice-details {
                display: flex;
                justify-content: space-between;
                align-items: center;
                margin-top: 15px;
                flex-wrap: wrap;
                gap: 15px;
            }
            .invoice-stats {
                display: flex;
                gap: 20px;
            }
            .stat {
                display: flex;
                flex-direction: column;
                align-items: center;
                padding: 8px 15px;
                background: #f0f0f0;
                border-radius: 5px;
                min-width: 100px;
            }
            .stat-label {
                font-size: 0.8em;
                color: #666;
                margin-bottom: 3px;
            }
            .stat-value {
                font-size: 1.1em;
                font-weight: bold;
                color: #333;
            }
            .action-buttons {
                display: flex;
                gap: 10px;
            }
            .action-btn {
                background: #c00;
                color: white;
                border: none;
                padding: 10px 20px;
                font-size: 0.9em;
                border-radius: 5px;
                cursor: pointer;
                transition: all 0.3s ease;
                text-decoration: none;
                display: inline-flex;
                align-items: center;
                gap: 5px;
            }
            .action-btn:hover {
                background: #a00;
                transform: translateY(-2px);
                box-shadow: 0 4px 8px rgba(192,0,0,0.2);
            }
            .action-btn.edit {
                background: #28a745;
            }
            .action-btn.edit:hover {
                background: #218838;
            }
            .action-btn.download {
                background: #007bff;
            }
            .action-btn.download:hover {
                background: #0069d9;
            }
            .footer {
                text-align: center;
                padding: 20px;
                background: #f5f5f5;
                border-top: 1px solid #e0e0e0;
                color: #666;
                font-size: 0.9em;
            }
            .brand-badge {
                display: inline-block;
                background: #c00;
                color: white;
                padding: 5px 15px;
                border-radius: 20px;
                font-size: 0.9em;
                margin-right: 10px;
                margin-bottom: 10px;
            }
            .admin-note {
                background: #ffebee;
                border: 2px solid #c00;
                border-radius: 8px;
                padding: 20px;
                margin-bottom: 30px;
                text-align: center;
            }
            .admin-note h4 {
                color: #c00;
                margin-bottom: 10px;
            }
            .full-invoice {
                background: #e8f4fd;
                border: 2px solid #007bff;
                border-radius: 8px;
                padding: 25px;
                margin-top: 30px;
            }
            .full-invoice h3 {
                color: #007bff;
                margin-bottom: 15px;
            }
            
            /* قسم التصنيف الائتماني */
            .credit-summary {
                background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%);
                border: 2px solid #2196f3;
                border-radius: 8px;
                padding: 20px;
                margin-bottom: 20px;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            .credit-info {
                display: flex;
                flex-direction: column;
                gap: 5px;
            }
            .credit-label {
                font-weight: bold;
                color: #1565c0;
                font-size: 1.1em;
            }
            .credit-value {
                display: inline-flex;
                align-items: center;
                gap: 10px;
                color: #333;
            }
            .credit-class-badge {
                padding: 8px 20px;
                border-radius: 20px;
                color: white;
                font-weight: bold;
                min-width: 100px;
                text-align: center;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            .credit-status {
                padding: 8px 15px;
                border-radius: 8px;
                font-weight: bold;
                font-size: 0.9em;
            }
            .status-approved {
                background: #e8f5e9;
                color: #2e7d32;
                border: 2px solid #4caf50;
            }
            .status-not-approved {
                background: #ffebee;
                color: #c62828;
                border: 2px solid #f44336;
            }
            .status-undefined {
                background: #f5f5f5;
                color: #616161;
                border: 2px solid #9e9e9e;
            }
            
            @media (max-width: 768px) {
                .container {
                    margin: 20px auto;
                }
                .header {
                    padding: 30px 20px;
                }
                .content {
                    padding: 20px;
                }
                .invoice-details {
                    flex-direction: column;
                    align-items: stretch;
                }
                .invoice-stats {
                    justify-content: space-around;
                }
                .action-buttons {
                    width: 100%;
                    justify-content: center;
                }
                .credit-summary {
                    flex-direction: column;
                    gap: 15px;
                    text-align: center;
                }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>📄 فواتير الطلب #<?php echo $order_id; ?></h1>
                <p>الإدارة - الفواتير المنفصلة حسب العلامات التجارية</p>
                <div class="credit-header-badge credit-<?php 
                    switch($credit_class) {
                        case 'عالي': echo 'high'; break;
                        case 'متوسط': echo 'medium'; break;
                        case 'ضعيف': echo 'low'; break;
                        default: echo 'undefined';
                    }
                ?>">
                    📊 التصنيف الائتماني: <?php echo $credit_class; ?>
                </div>
            </div>
            
            <div class="content">
                <div class="admin-note">
                    <h4>💼 صفحة الإدارة</h4>
                    <p>يمكنك تحميل الفاتورة مباشرة أو تعديلها قبل التحميل</p>
                </div>
                
                <!-- قسم التصنيف الائتماني -->
                <div class="credit-summary">
                    <div class="credit-info">
                        <div class="credit-label">التصنيف الائتماني للعميل:</div>
                        <div class="credit-value">
                            <span class="credit-class-badge" style="background: <?php 
                                switch($credit_class) {
                                    case 'عالي': echo '#4caf50'; break;
                                    case 'متوسط': echo '#ff9800'; break;
                                    case 'ضعيف': echo '#f44336'; break;
                                    default: echo '#9e9e9e';
                                }
                            ?>">
                                <?php echo $credit_class; ?>
                            </span>
                            <span class="credit-status <?php 
                                if ($credit_class == 'عالي' || $credit_class == 'متوسط') {
                                    echo 'status-approved';
                                } elseif ($credit_class == 'ضعيف') {
                                    echo 'status-not-approved';
                                } else {
                                    echo 'status-undefined';
                                }
                            ?>">
                                <?php 
                                if ($credit_class == 'عالي') {
                                    echo '✓ موافق - ممتاز';
                                } elseif ($credit_class == 'متوسط') {
                                    echo '✓ موافق - جيد';
                                } elseif ($credit_class == 'ضعيف') {
                                    echo '✗ غير موافق - يحتاج مراجعة';
                                } else {
                                    echo 'غير محدد';
                                }
                                ?>
                            </span>
                        </div>
                    </div>
                    <div>
                        <small style="color: #666; font-style: italic;">
                            هذا التصنيف سيظهر في جميع الفواتير التي يتم تحميلها
                        </small>
                    </div>
                </div>
                
                <div class="order-info">
                    <h3>معلومات الطلب</h3>
                    <div class="info-grid">
                        <div class="info-item">
                            <span class="info-label">العميل</span>
                            <span class="info-value"><?php echo esc_html($customer_name); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">عدد الفواتير</span>
                            <span class="info-value"><?php echo count($grouped_products); ?> فاتورة</span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">التاريخ</span>
                            <span class="info-value"><?php echo $order->get_date_created()->format('Y-m-d H:i'); ?></span>
                        </div>
                        <div class="info-item">
                            <span class="info-label">حالة الطلب</span>
                            <span class="info-value">
                                <?php 
                                $status = $order->get_status();
                                $status_labels = [
                                    'pending' => 'قيد الانتظار',
                                    'processing' => 'قيد المعالجة', 
                                    'completed' => 'مكتمل',
                                    'on-hold' => 'معلق',
                                    'cancelled' => 'ملغى',
                                    'refunded' => 'تم الاسترجاع'
                                ];
                                echo $status_labels[$status] ?? $status;
                                ?>
                            </span>
                        </div>
                    </div>
                </div>
                
                <div class="invoices-list">
                    <h2 style="color: #333; margin-bottom: 20px; text-align: center;">الفواتير المتاحة</h2>
                    
                    <?php 
                    $brand_count = 0;
                    foreach ($grouped_products as $brand_key => $items): 
                        $brand_count++;
                        $brand_total = 0;
                        $total_items = 0;
                        foreach ($items as $item_data) {
                            $brand_total += $item_data['total'];
                            $total_items += $item_data['quantity'];
                        }
                    ?>
                    
                    <div class="invoice-card">
                        <span class="brand-badge">فاتورة <?php echo $brand_count; ?></span>
                        <h3><?php echo !empty(get_brand_group_name($brand_key)) ? get_brand_group_name($brand_key) : 'فاتورة عامة'; ?></h3>
                        
                        <div class="invoice-details">
                            <div class="invoice-stats">
                                <div class="stat">
                                    <span class="stat-label">عدد المنتجات</span>
                                    <span class="stat-value"><?php echo count($items); ?></span>
                                </div>
                                <div class="stat">
                                    <span class="stat-label">الكمية الكلية</span>
                                    <span class="stat-value"><?php echo $total_items; ?></span>
                                </div>
                                <div class="stat">
                                    <span class="stat-label">المجموع</span>
                                    <span class="stat-value" style="color: #c00;">
                                        <?php if ($order_currency === 'syp'): ?>
                                        <?php echo number_format($brand_total, 0); ?> ل.س
                                        <?php else: ?>
                                        $<?php echo number_format($brand_total, 2); ?>
                                        <?php endif; ?>
                                    </span>
                                </div>
                            </div>
                            
                            <div class="action-buttons">
                                <a href="<?php echo esc_url(add_query_arg([
                                    'download_invoice' => 'single',
                                    'order_id' => $order_id,
                                    'brand' => $brand_key,
                                    'edit' => 'true',
                                    '_wpnonce' => wp_create_nonce('edit_invoice_' . $order_id . '_' . $brand_key)
                                ], home_url('/'))); ?>" 
                                   class="action-btn edit">
                                   ✏️ تعديل قبل التحميل
                                </a>
                                
                                <a href="<?php echo esc_url(add_query_arg([
                                    'download_invoice' => 'single',
                                    'order_id' => $order_id,
                                    'brand' => $brand_key,
                                    '_wpnonce' => wp_create_nonce('download_single_invoice_' . $order_id . '_' . $brand_key)
                                ], home_url('/'))); ?>" 
                                   class="action-btn download">
                                   ⬇️ تحميل مباشر
                                </a>
                            </div>
                        </div>
                    </div>
                    
                    <?php endforeach; ?>
                </div>
                
                <!-- فاتورة كاملة للزبون -->
                <div class="full-invoice">
                    <h3>📦 فاتورة كاملة للزبون</h3>
                    <p>تحميل فاتورة كاملة واحدة (جميع المنتجات معاً) كما يراها الزبون</p>
                    <div style="text-align: center; margin-top: 20px;">
                        <a href="<?php echo esc_url(add_query_arg([
                            'download_invoice' => 'customer',
                            'order_id' => $order_id,
                            '_wpnonce' => wp_create_nonce('download_customer_invoice_' . $order_id)
                        ], home_url('/'))); ?>" 
                           class="action-btn download" style="padding: 12px 30px; font-size: 1em;">
                           👤 تحميل فاتورة الزبون الكاملة
                        </a>
                    </div>
                </div>
            </div>
            
            <div class="footer">
                <p>© <?php echo date('Y'); ?> <?php echo get_bloginfo('name'); ?> - جميع الحقوق محفوظة</p>
                <p style="margin-top: 10px; font-size: 0.8em;">
                    <a href="<?php echo esc_url(admin_url('edit.php?post_type=shop_order')); ?>" style="color: #c00; text-decoration: none;">
                        ← العودة إلى إدارة الطلبات
                    </a>
                </p>
            </div>
        </div>
    </body>
    </html>
    <?php
}

// دالة للحصول على رابط لوغو الموقع
function get_theme_logo_url() {
    // محاولة الحصول على اللوغو من الإعدادات المخصصة
    $logo_url = '';
    
    // الطريقة الأولى: من خلال ووكومرس
    if (function_exists('get_option')) {
        $site_logo = get_option('site_logo');
        if ($site_logo) {
            $logo_url = wp_get_attachment_url($site_logo);
        }
    }
    
    // الطريقة الثانية: من خلال الإعدادات العامة
    if (empty($logo_url)) {
        $custom_logo_id = get_theme_mod('custom_logo');
        if ($custom_logo_id) {
            $logo_url = wp_get_attachment_url($custom_logo_id);
        }
    }
    
    // الطريقة الثالثة: من خلال خيارات المظهر
    if (empty($logo_url)) {
        $logo_url = get_theme_mod('logo');
    }
    
    return $logo_url;
}

// معالجة طلبات تحميل الفواتير
add_action('init', 'handle_invoice_download_requests');
function handle_invoice_download_requests() {
    if (!isset($_GET['download_invoice']) || !isset($_GET['order_id'])) {
        return;
    }
    
    $order_id = intval($_GET['order_id']);
    $order = wc_get_order($order_id);
    
    if (!$order) {
        wp_die('الطلب غير موجود');
    }
    
    $download_type = sanitize_text_field($_GET['download_invoice']);
    
    switch ($download_type) {
        case 'customer':
            // تحميل فاتورة كاملة للزبون
            if (!isset($_GET['_wpnonce']) || !wp_verify_nonce($_GET['_wpnonce'], 'download_customer_invoice_' . $order_id)) {
                wp_die('طلب غير مصرح');
            }
            
            $order_currency = get_order_currency_type($order);
            generate_complete_invoice_for_customer($order_id, $order, $order_currency);
            exit;
            
        case 'single':
            // تحميل فاتورة فردية (للإدارة فقط)
            if (!isset($_GET['brand'])) {
                wp_die('العلامة التجارية غير محددة');
            }
            
            $brand_key = sanitize_text_field($_GET['brand']);
            
            // التحقق من nonce
            if (isset($_GET['edit']) && $_GET['edit'] == 'true') {
                // تحرير الفاتورة
                if (!isset($_GET['_wpnonce']) || !wp_verify_nonce($_GET['_wpnonce'], 'edit_invoice_' . $order_id . '_' . $brand_key)) {
                    wp_die('طلب غير مصرح');
                }
                
                $order_currency = get_order_currency_type($order);
                $order_items = $order->get_items();
                $grouped_products = group_products_by_brand($order_items);
                
                if (!isset($grouped_products[$brand_key])) {
                    wp_die('الفاتورة المطلوبة غير موجودة');
                }
                
                generate_invoice_edit_page($order_id, $order, $order_currency, $brand_key, $grouped_products[$brand_key]);
                exit;
            } else {
                // تحميل مباشر
                if (!isset($_GET['_wpnonce']) || !wp_verify_nonce($_GET['_wpnonce'], 'download_single_invoice_' . $order_id . '_' . $brand_key)) {
                    wp_die('طلب غير مصرح');
                }
                
                $order_currency = get_order_currency_type($order);
                generate_separated_brand_invoices($order_id, $order, $order_currency);
                exit;
            }
            
        case 'final':
            // تحميل فاتورة نهائية بعد التحرير
            if (!isset($_GET['brand'])) {
                wp_die('العلامة التجارية غير محددة');
            }
            
            $brand_key = sanitize_text_field($_GET['brand']);
            
            // التحقق من nonce
            if (!isset($_GET['_wpnonce']) || !wp_verify_nonce($_GET['_wpnonce'], 'download_final_invoice_' . $order_id . '_' . $brand_key)) {
                wp_die('طلب غير مصرح');
            }
            
            $order_currency = get_order_currency_type($order);
            $order_items = $order->get_items();
            $grouped_products = group_products_by_brand($order_items);
            
            if (!isset($grouped_products[$brand_key])) {
                wp_die('الفاتورة المطلوبة غير موجودة');
            }
            
            // جمع بيانات النموذج
            $form_data = [
                'customer_name' => isset($_POST['customer_name']) ? sanitize_text_field($_POST['customer_name']) : '',
                'customer_email' => isset($_POST['customer_email']) ? sanitize_email($_POST['customer_email']) : '',
                'customer_phone' => isset($_POST['customer_phone']) ? sanitize_text_field($_POST['customer_phone']) : '',
                'customer_address' => isset($_POST['customer_address']) ? sanitize_textarea_field($_POST['customer_address']) : '',
                'payment_method' => isset($_POST['payment_method']) ? sanitize_text_field($_POST['payment_method']) : '',
                'invoice_notes' => isset($_POST['invoice_notes']) ? sanitize_textarea_field($_POST['invoice_notes']) : '',
                'order_status' => isset($_POST['order_status']) ? sanitize_text_field($_POST['order_status']) : '',
                'modified_date' => isset($_POST['modified_date']) ? sanitize_text_field($_POST['modified_date']) : '',
                'credit_class' => isset($_POST['credit_class']) ? sanitize_text_field($_POST['credit_class']) : get_customer_credit_class($order->get_customer_id()),
                'products' => isset($_POST['products']) ? array_map(function($product) {
                    return [
                        'name' => isset($product['name']) ? sanitize_text_field($product['name']) : '',
                        'quantity' => isset($product['quantity']) ? floatval($product['quantity']) : 0,
                        'unit' => isset($product['unit']) ? sanitize_text_field($product['unit']) : '',
                        'total' => isset($product['total']) ? floatval($product['total']) : 0,
                        'remove' => isset($product['remove']) ? intval($product['remove']) : 0,
                        'image_url' => isset($product['image_url']) ? esc_url_raw($product['image_url']) : ''
                    ];
                }, $_POST['products']) : []
            ];
            
            generate_final_invoice_html($order_id, $order, $order_currency, $brand_key, $grouped_products[$brand_key], $form_data);
            exit;
            
        case 'links':
            // عرض صفحة روابط التحميل (للإدارة فقط)
            $order_currency = get_order_currency_type($order);
            $order_items = $order->get_items();
            $grouped_products = group_products_by_brand($order_items);
            generate_invoice_download_links_page($order_id, $order, $order_currency, $grouped_products);
            exit;
    }
}

// الكود القديم لأزرار الإدارة (بدون تغييرات)
// 1️⃣ زر تحميل المسودة في قائمة الطلبات
add_filter('woocommerce_admin_order_actions', 'add_order_download_draft_action', 100, 2);
function add_order_download_draft_action($actions, $order) {
    $order_id = $order->get_id();
    
    $actions['download_draft'] = array(
        'url'    => wp_nonce_url(admin_url('admin-post.php?action=download_order_draft&order_id=' . $order_id), 'download_draft_' . $order_id),
        'name'   => __('📄 مسودة', 'woocommerce'),
        'action' => 'download-draft',
        'title'  => 'تحميل مسودة الطلب'
    );
    
    return $actions;
}

// 2️⃣ زر تحميل المسودة في صفحة تفاصيل الطلب
add_action('woocommerce_admin_order_totals_after_total', 'add_download_draft_button_order_page');
function add_download_draft_button_order_page($order_id) {
    $order = wc_get_order($order_id);
    if (!$order) return;
    
    $order_items = $order->get_items();
    $grouped_products = group_products_by_brand($order_items);
    $brand_count = count($grouped_products);
    
    // الحصول على التصنيف الائتماني
    $customer_id = $order->get_customer_id();
    $credit_class = get_customer_credit_class($customer_id);
    
    ?>
    <div style="margin: 20px 0; padding: 20px; background: #fff; border: 2px solid #c00; border-radius: 5px;">
        <h3 style="color: #c00; margin-bottom: 10px;">📄 مسودة الطلب</h3>
        <p style="margin-bottom: 15px; color: #666;">
            <?php if ($brand_count > 1): ?>
            سيتم إنشاء <?php echo $brand_count; ?> فواتير منفصلة حسب العلامات التجارية:
            <ul style="margin: 10px 0; padding-right: 20px;">
                <?php foreach ($grouped_products as $brand_key => $items): ?>
                <li><?php echo !empty(get_brand_group_name($brand_key)) ? get_brand_group_name($brand_key) : 'فاتورة عامة'; ?></li>
                <?php endforeach; ?>
            </ul>
            <?php else: ?>
            سيتم تحميل مسودة الطلب بنفس الصيغة والألوان
            <?php endif; ?>
        </p>
        
        <!-- عرض التصنيف الائتماني -->
        <div style="margin-bottom: 15px; padding: 10px; background: <?php 
            switch($credit_class) {
                case 'عالي': echo '#e8f5e9'; break;
                case 'متوسط': echo '#fff3e0'; break;
                case 'ضعيف': echo '#ffebee'; break;
                default: echo '#f5f5f5';
            }
        ?>; border: 1px solid <?php 
            switch($credit_class) {
                case 'عالي': echo '#4caf50'; break;
                case 'متوسط': echo '#ff9800'; break;
                case 'ضعيف': echo '#f44336'; break;
                default: echo '#9e9e9e';
            }
        ?>; border-radius: 5px;">
            <strong>📊 التصنيف الائتماني:</strong> 
            <span style="color: <?php 
                switch($credit_class) {
                    case 'عالي': echo '#2e7d32'; break;
                    case 'متوسط': echo '#f57c00'; break;
                    case 'ضعيف': echo '#c62828'; break;
                    default: echo '#616161';
                }
            ?>; font-weight: bold;">
                <?php echo $credit_class; ?>
                <?php 
                if ($credit_class == 'عالي' || $credit_class == 'متوسط') {
                    echo ' (✓ موافق)';
                } elseif ($credit_class == 'ضعيف') {
                    echo ' (✗ غير موافق)';
                }
                ?>
            </span>
        </div>
        
        <a href="<?php echo wp_nonce_url(admin_url('admin-post.php?action=download_order_draft&order_id=' . $order_id), 'download_draft_' . $order_id); ?>" 
           class="button button-primary" 
           style="background: #c00; color: white; border: none; padding: 12px 25px; font-size: 14px; text-decoration: none; display: inline-block; border-radius: 4px;">
           ⬇️ تحميل مسودة الطلب
        </a>
        <p style="margin-top: 10px; font-size: 12px; color: #888;">
            سيتم تحميل ملف HTML يحتوي على مسودة/مسودات الطلب بنفس التصميم والألوان
        </p>
    </div>
    <?php
}

// 3️⃣ إضافة زر في صندوق معلومات الطلب
add_action('woocommerce_admin_order_data_after_order_details', 'add_download_draft_to_order_meta_box');
function add_download_draft_to_order_meta_box($order) {
    $order_id = $order->get_id();
    
    $order_items = $order->get_items();
    $grouped_products = group_products_by_brand($order_items);
    $brand_count = count($grouped_products);
    
    // الحصول على التصنيف الائتماني
    $customer_id = $order->get_customer_id();
    $credit_class = get_customer_credit_class($customer_id);
    
    ?>
    <p class="form-field" style="padding: 10px; background: #ffebee; border: 1px solid #c00; border-radius: 4px;">
        <strong style="color: #c00;">📄 مسودة الطلب:</strong><br>
        <?php if ($brand_count > 1): ?>
        <small style="color: #666; display: block; margin: 5px 0;">
            <?php echo $brand_count; ?> فواتير منفصلة حسب العلامات التجارية
        </small>
        <?php endif; ?>
        
        <!-- عرض التصنيف الائتماني -->
        <small style="color: #666; display: block; margin: 5px 0; font-weight: bold; color: <?php 
            switch($credit_class) {
                case 'عالي': echo '#2e7d32'; break;
                case 'متوسط': echo '#f57c00'; break;
                case 'ضعيف': echo '#c62828'; break;
                default: echo '#616161';
            }
        ?>;">
            📊 التصنيف: <?php echo $credit_class; ?>
            <?php 
            if ($credit_class == 'عالي' || $credit_class == 'متوسط') {
                echo ' ✓';
            } elseif ($credit_class == 'ضعيف') {
                echo ' ✗';
            }
            ?>
        </small>
        
        <a href="<?php echo wp_nonce_url(admin_url('admin-post.php?action=download_order_draft&order_id=' . $order_id), 'download_draft_' . $order_id); ?>" 
           class="button" 
           style="background: #c00; color: white; border: none; padding: 8px 15px; font-size: 13px; margin-top: 5px;">
           ⬇️ تحميل المسودة/المسودات
        </a>
    </p>
    <?php
}

// 4️⃣ تنسيق CSS للزر في قائمة الطلبات
add_action('admin_head', 'custom_order_download_draft_css');
function custom_order_download_draft_css() {
    ?>
    <style>
        .wc-action-button-download-draft {
            background: #c00 !important;
            color: white !important;
            border-color: #c00 !important;
            margin-left: 4px !important;
            display: inline-flex !important;
            align-items: center !important;
        }
        .wc-action-button-download-draft::after {
            content: "📄" !important;
            margin-right: 4px !important;
        }
        .wc-action-button-download-draft:hover {
            background: #a00 !important;
            border-color: #a00 !important;
        }
        
        .button[style*="background: #c00"]:hover {
            background: #a00 !important;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(192, 0, 0, 0.3);
        }
    </style>
    <?php
}

// معالجة طلب تحميل المسودة من الإدارة
add_action('admin_post_download_order_draft', 'handle_admin_download_order_draft');
function handle_admin_download_order_draft() {
    if (!isset($_GET['_wpnonce']) || !wp_verify_nonce($_GET['_wpnonce'], 'download_draft_' . $_GET['order_id'])) {
        wp_die('طلب غير مصرح');
    }
    
    if (!current_user_can('edit_shop_orders')) {
        wp_die('غير مصرح لك بالوصول إلى هذه الصفحة');
    }
    
    $order_id = isset($_GET['order_id']) ? intval($_GET['order_id']) : 0;
    
    if (!$order_id) {
        wp_die('رقم الطلب غير موجود');
    }
    
    $order = wc_get_order($order_id);
    if (!$order) {
        wp_die('الطلب غير موجود');
    }
    
    $order_currency = get_order_currency_type($order);
    
    // إنشاء صفحة روابط التحميل بدلاً من تحميل مباشر
    $order_items = $order->get_items();
    $grouped_products = group_products_by_brand($order_items);
    generate_invoice_download_links_page($order_id, $order, $order_currency, $grouped_products);
    exit;
}

// تعديل عرض زر تحميل الفواتير في صفحة تأكيد الطلب للزبائن
add_action('woocommerce_thankyou', 'display_invoice_download_button', 20);
function display_invoice_download_button($order_id) {
    if (!$order_id) return;
    
    $order = wc_get_order($order_id);
    if (!$order) return;
    
    echo '<div style="text-align: center; margin: 30px 0; padding: 20px; border: 2px solid #c00; border-radius: 10px; background: #ffebee;">';
    echo '<h3 style="color: #c00;">📄 تحميل مسودة طلبك</h3>';
    echo '<p style="margin: 15px 0; color: #000;">لتحميل مسودة الطلب واضحة وجاهزة للطباعة اضغط هنا</p>';
    echo '<a href="' . esc_url(add_query_arg([
        'download_invoice' => 'customer',
        'order_id' => $order_id,
        '_wpnonce' => wp_create_nonce('download_customer_invoice_' . $order_id)
    ], home_url('/'))) . '" class="button" style="background: #c00; color: white; padding: 15px 30px; font-size: 16px; text-decoration: none; border-radius: 5px; display: inline-block;">⬇️ تحميل مسودة الطلب</a>';
    echo '</div>';
}