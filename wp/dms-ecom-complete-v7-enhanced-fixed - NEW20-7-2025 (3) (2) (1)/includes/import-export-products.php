<?php
// صفحة استيراد / تصدير المنتجات
add_action('admin_menu', function() {
    add_submenu_page(
        'dms-store-main',
        'استيراد / تصدير المنتجات',
        'استيراد / تصدير المنتجات',
        'manage_woocommerce',
        'dms-import-export-products',
        'dms_render_import_export_products_page'
    );
});

function dms_render_import_export_products_page() {
    // -------------------------------------------------------------
    // هذا هو الجزء المسؤول عن عرض رسالة التأكيد.
    // -------------------------------------------------------------
    if (isset($_GET['import'])) {
        $message = '';
        $type = 'success';
        switch ($_GET['import']) {
            case 'prices_success':
                $message = 'تم استيراد الأسعار بنجاح!';
                break;
            case 'stock_success':
                $message = 'تم استيراد المخزون بنجاح!';
                break;
            case 'ordering_success':
                $message = 'تم استيراد ترتيب المنتجات بنجاح!';
                break;
            case 'error':
                $message = 'حدث خطأ أثناء عملية الاستيراد.';
                $type = 'error';
                break;
        }

        if ($message) {
            echo '<div class="notice notice-' . $type . ' is-dismissible">';
            echo '<p>' . esc_html($message) . '</p>';
            echo '</div>';
        }
    }
    
    // قسم التشخيص - عرض عينة من البيانات المحفوظة
    if (isset($_GET['debug']) && $_GET['debug'] === 'prices') {
        echo '<div style="background-color: #fff3cd; padding: 15px; margin: 15px 0; border: 1px solid #ffc107; border-radius: 4px;">';
        echo '<h3>🔍 تشخيص بيانات الأسعار</h3>';
        $products = wc_get_products(['limit' => 5]);
        foreach ($products as $product) {
            $meta = get_post_meta($product->get_id(), '_dms_prices', true);
            echo '<div style="margin: 10px 0; padding: 10px; background: white; border-radius: 3px; border-left: 4px solid #0073aa;">';
            echo '<strong>المنتج:</strong> ' . esc_html($product->get_name()) . '<br>';
            echo '<strong>SKU:</strong> ' . esc_html($product->get_sku()) . '<br>';
            
            if (is_array($meta) && !empty($meta)) {
                foreach ($meta as $cat => $values) {
                    echo '<div style="margin: 5px 0; padding: 5px; background: #f5f5f5;">';
                    echo '<strong>التصنيف:</strong> ' . esc_html($cat) . '<br>';
                    echo 'box_pieces_count: ' . (isset($values['box_pieces_count']) ? esc_html($values['box_pieces_count']) : '<span style="color:red;">فارغ</span>') . '<br>';
                    echo 'box_unit_name: ' . (isset($values['box_unit_name']) && !empty($values['box_unit_name']) ? esc_html($values['box_unit_name']) : '<span style="color:red;">فارغ</span>') . '<br>';
                    echo 'package_pieces_count: ' . (isset($values['package_pieces_count']) ? esc_html($values['package_pieces_count']) : '<span style="color:red;">فارغ</span>') . '<br>';
                    echo 'package_unit_name: ' . (isset($values['package_unit_name']) && !empty($values['package_unit_name']) ? esc_html($values['package_unit_name']) : '<span style="color:red;">فارغ</span>') . '<br>';
                    echo '</div>';
                }
            } else {
                echo '<span style="color:red;">لا توجد بيانات محفوظة</span>';
            }
            echo '</div>';
        }
        echo '</div>';
    }
    
    // عرض سجل الاستيراد
    if (isset($_GET['debug']) && $_GET['debug'] === 'log') {
        $log_file = WP_CONTENT_DIR . '/dms-import.log';
        echo '<div style="background-color: #e7f3ff; padding: 15px; margin: 15px 0; border: 1px solid #0073aa; border-radius: 4px;">';
        echo '<h3>📋 سجل الاستيراد</h3>';
        
        if (file_exists($log_file)) {
            $log_content = file_get_contents($log_file);
            $log_lines = array_reverse(explode("\n", $log_content));
            echo '<pre style="background: white; padding: 10px; border-radius: 3px; max-height: 400px; overflow-y: auto;">';
            echo esc_html(implode("\n", array_slice($log_lines, 0, 100)));
            echo '</pre>';
            
            echo '<p style="margin-top: 10px;">';
            echo '<a href="' . wp_nonce_url(admin_url('admin.php?page=dms-import-export-products&clear_log=1'), 'clear_dms_log') . '" class="button button-secondary" onclick="return confirm(\'هل تريد حذف السجل?\')">🗑️ حذف السجل</a>';
            echo '</p>';
        } else {
            echo '<p>لا يوجد سجل حتى الآن</p>';
        }
        echo '</div>';
    }
    
    // حذف السجل
    if (isset($_GET['clear_log']) && wp_verify_nonce($_GET['_wpnonce'], 'clear_dms_log')) {
        $log_file = WP_CONTENT_DIR . '/dms-import.log';
        if (file_exists($log_file)) {
            unlink($log_file);
            echo '<div class="notice notice-success is-dismissible"><p>تم حذف السجل بنجاح</p></div>';
        }
    }
    
    ?>
    <div class="wrap">
    <div class="wrap">
        <h1>استيراد / تصدير المنتجات</h1>
        <p>يمكنك هنا تصدير أو استيراد أسعار المنتجات والمخزون وترتيبها عبر ملفات CSV منفصلة.</p>
        
        <p style="text-align: right;">
            <a href="<?php echo admin_url('admin.php?page=dms-import-export-products&debug=prices'); ?>" class="button button-secondary">
                🔍 تشخيص بيانات الأسعار
            </a>
            <a href="<?php echo admin_url('admin.php?page=dms-import-export-products&debug=log'); ?>" class="button button-secondary">
                📋 عرض سجل الاستيراد
            </a>
        </p>

        <!-- قسم الأسعار -->
        <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; margin-bottom: 30px;">
            <h2>📈 الأسعار</h2>
            <p>تصدير واستيراد أسعار المنتجات لكل تصنيف.</p>

            <h3>📤 تصدير الأسعار إلى CSV</h3>
            <form method="post">
                <input type="hidden" name="dms_export_prices" value="1">
                <input type="submit" class="button button-primary" value="تصدير الأسعار">
            </form>

            <hr>

            <h3>📥 استيراد الأسعار من CSV</h3>
            <form method="post" enctype="multipart/form-data">
                <input type="file" name="import_prices_file" accept=".csv" required>
                <input type="hidden" name="dms_import_prices" value="1">
                <input type="submit" class="button button-primary" value="استيراد الأسعار">
            </form>
        </div>

        <!-- قسم المخزون -->
        <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd; margin-bottom: 30px;">
            <h2>📦 المخزون</h2>
            <p>تصدير واستيراد كميات المخزون، وحالة تفعيل تتبعه، وحد المخزون المتبقي بناءً على رمز SKU.</p>

            <h3>📤 تصدير المخزون إلى CSV</h3>
            <form method="post">
                <input type="hidden" name="dms_export_stock" value="1">
                <input type="submit" class="button button-primary" value="تصدير المخزون">
            </form>

            <hr>

            <h3>📥 استيراد المخزون من CSV</h3>
            <form method="post" enctype="multipart/form-data">
                <input type="file" name="import_stock_file" accept=".csv" required>
                <input type="hidden" name="dms_import_stock" value="1">
                <input type="submit" class="button button-primary" value="استيراد المخزون">
            </form>
        </div>

        <!-- قسم جديد لترتيب المنتجات -->
        <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
            <h2>📊 ترتيب المنتجات</h2>
            <p>تصدير واستيراد ترتيب المنتجات (الأولوية واتجاه العرض) بناءً على رمز SKU.</p>

            <h3>📤 تصدير الترتيب إلى CSV</h3>
            <form method="post">
                <input type="hidden" name="dms_export_ordering" value="1">
                <input type="submit" class="button button-primary" value="تصدير الترتيب">
            </form>

            <hr>

            <h3>📥 استيراد الترتيب من CSV</h3>
            <form method="post" enctype="multipart/form-data">
                <input type="file" name="import_ordering_file" accept=".csv" required>
                <input type="hidden" name="dms_import_ordering" value="1">
                <input type="submit" class="button button-primary" value="استيراد الترتيب">
            </form>
        </div>
    </div>
    <?php
}

// ------------------------------
// وظائف التصدير
// ------------------------------

// تصدير الأسعار
add_action('admin_init', function() {
    if (isset($_POST['dms_export_prices'])) {
        $cats = get_option('dms_price_categories', []);
        if (empty($cats)) {
            wp_die('لا توجد تصنيفات محفوظة للتصدير');
        }
        
        $products = wc_get_products([
            'limit' => -1,
            'status' => 'publish'
        ]);
        
        $rows = [[
            "اسم المنتج",
            "SKU",
            "التصنيف",
            "سعر القطعة ل.س",
            "سعر القطعة $",
            "عدد القطع في العلبة",
            "اسم وحدة العلبة",
            "عدد القطع في الطرد",
            "اسم وحدة الطرد"
        ]];

        foreach ($products as $product) {
            $meta = get_post_meta($product->get_id(), '_dms_prices', true);
            if (!is_array($meta)) {
                continue;
            }
            
            foreach ($cats as $cat) {
                $cat_data = $meta[$cat] ?? [];
                
                $syp_piece = $cat_data['syp_piece'] ?? '';
                $usd_piece = $cat_data['usd_piece'] ?? '';
                $box_pieces_count = $cat_data['box_pieces_count'] ?? 1;
                $box_unit_name = $cat_data['box_unit_name'] ?? 'علبة';
                $package_pieces_count = $cat_data['package_pieces_count'] ?? 1;
                $package_unit_name = $cat_data['package_unit_name'] ?? 'طرد';

                $rows[] = [
                    $product->get_name(),
                    $product->get_sku(),
                    $cat,
                    $syp_piece,
                    $usd_piece,
                    $box_pieces_count,
                    $box_unit_name,
                    $package_pieces_count,
                    $package_unit_name
                ];
            }
        }
        
        if (count($rows) > 1) {
            dms_export_csv($rows, 'products-prices-export-' . date('Y-m-d-His') . '.csv');
        } else {
            wp_die('لا توجد بيانات للتصدير');
        }
    }
});

// تصدير المخزون
add_action('admin_init', function() {
    if (isset($_POST['dms_export_stock'])) {
        $products = wc_get_products([
            'limit' => -1,
            'status' => 'publish'
        ]);
        
        $rows = [[
            "SKU",
            "اسم المنتج",
            "المخزون",
            "إدارة المخزون",
            "حد المخزون المتبقي" 
        ]];
        
        foreach ($products as $product) {
            $manage_stock_status = $product->get_manage_stock() ? 'نعم' : 'لا';
            $low_stock_amount = $product->get_low_stock_amount() ?: '';
            
            $rows[] = [
                $product->get_sku() ?: '',
                $product->get_name(),
                $product->get_stock_quantity() ?: 0,
                $manage_stock_status,
                $low_stock_amount
            ];
        }
        
        if (count($rows) > 1) {
            dms_export_csv($rows, 'products-stock-export-' . date('Y-m-d-His') . '.csv');
        } else {
            wp_die('لا توجد بيانات للتصدير');
        }
    }
});

// تصدير ترتيب المنتجات
add_action('admin_init', function() {
    if (isset($_POST['dms_export_ordering'])) {
        $products = wc_get_products([
            'limit' => -1,
            'status' => 'publish'
        ]);
        
        $rows = [[
            "SKU",
            "اسم المنتج",
            "الأولوية",
            "اتجاه العرض"
        ]];
        
        foreach ($products as $product) {
            $priority = get_post_meta($product->get_id(), '_custom_product_priority', true) ?: '';
            $direction = get_post_meta($product->get_id(), '_custom_product_direction', true) ?: '';
            
            $rows[] = [
                $product->get_sku() ?: '',
                $product->get_name(),
                $priority,
                $direction
            ];
        }
        
        if (count($rows) > 1) {
            dms_export_csv($rows, 'products-ordering-export-' . date('Y-m-d-His') . '.csv');
        } else {
            wp_die('لا توجد بيانات للتصدير');
        }
    }
});

// وظيفة مساعدة للتصدير
function dms_export_csv($rows, $filename) {
    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');
    
    $output = fopen('php://output', 'w');
    
    // كتابة BOM لـ UTF-8 لضمان الترميز الصحيح في Excel
    fprintf($output, chr(0xEF) . chr(0xBB) . chr(0xBF));
    
    // كتابة الصفوف
    foreach ($rows as $row) {
        fputcsv($output, $row);
    }
    fclose($output);
    exit;
}

// ------------------------------
// وظائف الاستيراد
// ------------------------------

// دالة تسجيل الاستيراد
if (!function_exists('dms_log_import')) {
    function dms_log_import($message) {
        $log_file = WP_CONTENT_DIR . '/dms-import.log';
        $timestamp = date('Y-m-d H:i:s');
        file_put_contents($log_file, "[$timestamp] $message\n", FILE_APPEND);
    }
}

// دالة البحث عن المنتج بأساليب متعددة
function dms_find_product_by_sku($sku) {
    if (empty($sku)) {
        return null;
    }
    
    // الطريقة 1: البحث المباشر عن SKU
    $product_id = wc_get_product_id_by_sku($sku);
    if ($product_id) {
        return $product_id;
    }
    
    // الطريقة 2: البحث عبر meta_query مع الضبط الدقيق
    $args = [
        'post_type' => 'product',
        'posts_per_page' => 1,
        'meta_query' => [
            [
                'key' => '_sku',
                'value' => $sku,
                'compare' => '='
            ]
        ]
    ];
    $products_found = get_posts($args);
    
    if (!empty($products_found)) {
        return $products_found[0]->ID;
    }
    
    // الطريقة 3: البحث عبر post_name (slug) كآخر محاولة
    $post = get_page_by_path($sku, OBJECT, 'product');
    if ($post) {
        return $post->ID;
    }
    
    return null;
}

// استيراد الأسعار
add_action('admin_init', function() {
    if (isset($_POST['dms_import_prices']) && isset($_FILES['import_prices_file'])) {
        $file = $_FILES['import_prices_file']['tmp_name'];
        
        dms_log_import("=== بدء الاستيراد ===");
        dms_log_import("اسم الملف: " . sanitize_text_field($_FILES['import_prices_file']['name']));
        dms_log_import("حجم الملف: " . filesize($file) . " بايت");
        dms_log_import("الوقت: " . current_time('mysql'));
        
        // زيادة حد الوقت والذاكرة
        set_time_limit(600); // 10 دقائق بدلاً من 5
        wp_raise_memory_limit('admin');
        ignore_user_abort(true); // السماح للعملية بالاستمرار حتى لو قطع المستخدم الاتصال
        
        if (($handle = fopen($file, 'r')) !== false) {
            // قراءة رأس الملف وتنظيفه
            $header = fgetcsv($handle, 1000, ',');
            if ($header) {
                $header = array_map(function($h) { 
                    $h = str_replace("\xEF\xBB\xBF", '', $h); // إزالة BOM
                    return trim($h); 
                }, $header);
            }
            
            dms_log_import("عدد الأعمدة المتوقعة: 9");
            dms_log_import("عدد الأعمدة المقروءة: " . count($header ?? []));
            
            // التأكد من وجود الأعمدة الصحيحة
            if (!$header || count($header) < 9) {
                dms_log_import("❌ خطأ حرج: عدد الأعمدة غير كافي");
                dms_log_import("الأعمدة المستقبلة: " . (is_array($header) ? implode(", ", $header) : "فارغ"));
                fclose($handle);
                wp_safe_redirect(admin_url('admin.php?page=dms-import-export-products&import=error'));
                exit;
            }
            
            $row_count = 0;
            $import_count = 0;
            $skip_count = 0;
            $update_count = 0;
            $skip_reasons = [
                'empty_sku' => 0,
                'empty_category' => 0,
                'product_not_found' => 0,
                'invalid_data' => 0,
                'update_failure' => 0
            ];
            
            dms_log_import("--- بدء معالجة الصفوف ---");
            
            while (($data = fgetcsv($handle, 1000, ',')) !== false) {
                $row_count++;
                
                // تنظيف البيانات بشكل صحيح
                $data = array_map(function($value) {
                    $value = str_replace("\xEF\xBB\xBF", '', $value); // إزالة BOM من كل حقل
                    return trim($value);
                }, $data);
                
                // تعيين الحقول مع قيم افتراضية
                if (count($data) < 9) {
                    $data = array_pad($data, 9, '');
                }
                
                $name = sanitize_text_field($data[0] ?? '');
                $sku = sanitize_text_field($data[1] ?? '');
                $cat = sanitize_text_field($data[2] ?? '');
                $syp_piece = floatval($data[3] ?? 0);
                $usd_piece = floatval($data[4] ?? 0);
                $box_pieces_count = absint($data[5] ?? 0);
                $box_unit_name = sanitize_text_field($data[6] ?? '');
                $package_pieces_count = absint($data[7] ?? 0);
                $package_unit_name = sanitize_text_field($data[8] ?? '');
                
                // تسجيل التقدم كل 500 صف
                if ($row_count % 500 === 0) {
                    dms_log_import("📊 معالجة الصف $row_count... (مستورد: $import_count، محدث: $update_count، متخطى: $skip_count)");
                }
                
                // ✓ التحقق من SKU
                if (empty($sku)) {
                    $skip_count++;
                    $skip_reasons['empty_sku']++;
                    continue;
                }
                
                // ✓ التحقق من التصنيف
                if (empty($cat)) {
                    $skip_count++;
                    $skip_reasons['empty_category']++;
                    continue;
                }
                
                // ✓ البحث عن المنتج بأساليب متعددة
                $product_id = dms_find_product_by_sku($sku);
                
                if (!$product_id) {
                    $skip_count++;
                    $skip_reasons['product_not_found']++;
                    continue;
                }
                
                // ✓ الحصول على البيانات المحفوظة الحالية
                $meta = get_post_meta($product_id, '_dms_prices', true);
                if (!is_array($meta)) {
                    $meta = [];
                }
                
                // ✓ تهيئة بيانات التصنيف إذا لم تكن موجودة
                if (!isset($meta[$cat])) {
                    $meta[$cat] = [];
                }
                
                // ✓ حفظ جميع البيانات مع القيم الافتراضية
                $meta[$cat]['syp_piece'] = $syp_piece;
                $meta[$cat]['usd_piece'] = $usd_piece;
                
                // الحفاظ على العلامات الموجودة أو تعيين قيم افتراضية
                $meta[$cat]['show_syp_piece'] = isset($meta[$cat]['show_syp_piece']) ? $meta[$cat]['show_syp_piece'] : false;
                $meta[$cat]['show_usd_piece'] = isset($meta[$cat]['show_usd_piece']) ? $meta[$cat]['show_usd_piece'] : false;
                $meta[$cat]['show_syp_package'] = isset($meta[$cat]['show_syp_package']) ? $meta[$cat]['show_syp_package'] : false;
                $meta[$cat]['show_usd_package'] = isset($meta[$cat]['show_usd_package']) ? $meta[$cat]['show_usd_package'] : false;
                
                // ✓ حفظ معلومات الصناديق والرزم مع القيم الافتراضية
                $meta[$cat]['box_pieces_count'] = ($box_pieces_count > 0) ? $box_pieces_count : 1;
                $meta[$cat]['box_unit_name'] = !empty($box_unit_name) ? $box_unit_name : 'علبة';
                $meta[$cat]['package_pieces_count'] = ($package_pieces_count > 0) ? $package_pieces_count : 1;
                $meta[$cat]['package_unit_name'] = !empty($package_unit_name) ? $package_unit_name : 'طرد';
                
                // ✓ حفظ في قاعدة البيانات باستخدام نمط الحذف والإضافة للإجبار على الحفظ
                delete_post_meta($product_id, '_dms_prices');
                $result = add_post_meta($product_id, '_dms_prices', $meta);
                
                if ($result) {
                    $import_count++;
                } else {
                    // قد يكون السبب وجود البيانات بالفعل، حاول بـ update_post_meta
                    $update_result = update_post_meta($product_id, '_dms_prices', $meta);
                    if ($update_result !== false) {
                        $update_count++;
                    } else {
                        $skip_reasons['update_failure']++;
                    }
                }
            }
            fclose($handle);
            
            dms_log_import("--- انتهت معالجة الصفوف ---");
            dms_log_import("=== ملخص الاستيراد الشامل ===");
            dms_log_import("إجمالي الصفوف المقروءة: $row_count");
            dms_log_import("✅ الصفوف المستوردة (جديدة): $import_count");
            dms_log_import("🔄 الصفوف المحدثة (موجودة): $update_count");
            dms_log_import("⏭️  الصفوف المتخطاة: $skip_count");
            dms_log_import("--- تفاصيل الأسباب ---");
            dms_log_import("- SKU فارغ: " . $skip_reasons['empty_sku']);
            dms_log_import("- التصنيف فارغ: " . $skip_reasons['empty_category']);
            dms_log_import("- المنتج غير موجود: " . $skip_reasons['product_not_found']);
            dms_log_import("- فشل التحديث: " . $skip_reasons['update_failure']);
            dms_log_import("=== انتهى الاستيراد بنجاح ===");
        } else {
            dms_log_import("❌ خطأ حرج: لا يمكن فتح الملف");
            wp_safe_redirect(admin_url('admin.php?page=dms-import-export-products&import=error'));
            exit;
        }
        
        wp_safe_redirect(admin_url('admin.php?page=dms-import-export-products&import=prices_success'));
        exit;
    }
});

// استيراد المخزون
add_action('admin_init', function() {
    if (isset($_POST['dms_import_stock']) && isset($_FILES['import_stock_file'])) {
        $file = $_FILES['import_stock_file']['tmp_name'];
        
        dms_log_import("=== بدء استيراد المخزون ===");
        dms_log_import("اسم الملف: " . sanitize_text_field($_FILES['import_stock_file']['name']));
        
        set_time_limit(600);
        wp_raise_memory_limit('admin');
        
        $row_count = 0;
        $update_count = 0;
        $skip_count = 0;
        $skip_reasons = ['product_not_found' => 0, 'invalid_data' => 0];
        
        if (($handle = fopen($file, 'r')) !== false) {
            // تخطي رأس الملف
            fgetcsv($handle, 1000, ',');
            
            while (($data = fgetcsv($handle, 1000, ',')) !== false) {
                $row_count++;
                
                if ($row_count % 500 === 0) {
                    dms_log_import("معالجة الصف $row_count من المخزون... (محدث: $update_count)");
                }
                
                // تنظيف البيانات
                $data = array_map(function($value) {
                    $value = str_replace("\xEF\xBB\xBF", '', $value);
                    return trim($value);
                }, $data);
                
                list($sku, $product_name, $stock_quantity, $manage_stock_status, $low_stock_amount) = array_pad($data, 5, '');
                
                if (empty($sku)) {
                    $skip_count++;
                    $skip_reasons['invalid_data']++;
                    continue;
                }
                
                // البحث عن المنتج بأساليب متعددة
                $product_id = dms_find_product_by_sku($sku);
                
                if (!$product_id) {
                    $skip_count++;
                    $skip_reasons['product_not_found']++;
                    continue;
                }
                
                $product = wc_get_product($product_id);
                if ($product) {
                    $product->set_stock_quantity(absint($stock_quantity));
                    
                    $manage_stock_bool = ($manage_stock_status === 'نعم');
                    $product->set_manage_stock($manage_stock_bool);
                    
                    if (!empty($low_stock_amount)) {
                        $product->set_low_stock_amount(absint($low_stock_amount));
                    }
                    
                    $product->save();
                    $update_count++;
                }
            }
            fclose($handle);
            
            dms_log_import("=== ملخص استيراد المخزون ===");
            dms_log_import("إجمالي الصفوف: $row_count");
            dms_log_import("✅ محدث: $update_count");
            dms_log_import("⏭️  متخطى: $skip_count");
            dms_log_import("- المنتج غير موجود: " . $skip_reasons['product_not_found']);
            dms_log_import("- بيانات غير صحيحة: " . $skip_reasons['invalid_data']);
            dms_log_import("=== انتهى استيراد المخزون ===");
        }
        
        wp_safe_redirect(admin_url('admin.php?page=dms-import-export-products&import=stock_success'));
        exit;
    }
});

// استيراد ترتيب المنتجات
add_action('admin_init', function() {
    if (isset($_POST['dms_import_ordering']) && isset($_FILES['import_ordering_file'])) {
        $file = $_FILES['import_ordering_file']['tmp_name'];
        
        dms_log_import("=== بدء استيراد الترتيب ===");
        dms_log_import("اسم الملف: " . sanitize_text_field($_FILES['import_ordering_file']['name']));
        
        set_time_limit(600);
        wp_raise_memory_limit('admin');
        
        $row_count = 0;
        $update_count = 0;
        $skip_count = 0;
        $skip_reasons = ['product_not_found' => 0];
        
        if (($handle = fopen($file, 'r')) !== false) {
            // تخطي رأس الملف
            fgetcsv($handle, 1000, ',');
            
            while (($data = fgetcsv($handle, 1000, ',')) !== false) {
                $row_count++;
                
                if ($row_count % 500 === 0) {
                    dms_log_import("معالجة الصف $row_count من الترتيب... (محدث: $update_count)");
                }
                
                // تنظيف البيانات
                $data = array_map(function($value) {
                    $value = str_replace("\xEF\xBB\xBF", '', $value);
                    return trim($value);
                }, $data);
                
                list($sku, $product_name, $priority, $direction) = array_pad($data, 4, '');
                
                if (empty($sku)) {
                    $skip_count++;
                    continue;
                }
                
                // البحث عن المنتج بأساليب متعددة
                $product_id = dms_find_product_by_sku($sku);
                
                if (!$product_id) {
                    $skip_count++;
                    $skip_reasons['product_not_found']++;
                    continue;
                }
                
                // تحديث الحقول المخصصة
                update_post_meta($product_id, '_custom_product_priority', sanitize_text_field($priority));
                update_post_meta($product_id, '_custom_product_direction', sanitize_text_field($direction));
                $update_count++;
            }
            fclose($handle);
            
            dms_log_import("=== ملخص استيراد الترتيب ===");
            dms_log_import("إجمالي الصفوف: $row_count");
            dms_log_import("✅ محدث: $update_count");
            dms_log_import("⏭️  متخطى: $skip_count");
            dms_log_import("- المنتج غير موجود: " . $skip_reasons['product_not_found']);
            dms_log_import("=== انتهى استيراد الترتيب ===");
        }
        
        wp_safe_redirect(admin_url('admin.php?page=dms-import-export-products&import=ordering_success'));
        exit;
    }
});