<?php
/**
 * هذا الكود يضيف نظام إدارة أسعار مخصص للوحدات (علبة/طرد) في ووكومرس،
 * ويعدل طريقة عرض الأسعار في صفحة المنتج وسلة التسوق، مع الأخذ في الاعتبار
 * حالة المستخدم (مسجل/مؤكد) والمجموعة التي ينتمي إليها.
 *
 * الإصدار المحدث:
 * - تم تحسين آلية حساب الأسعار وتطبيقها في السلة.
 * - تمت إضافة نظام تسجيل الأخطاء (Debug Logging) للمساعدة في تتبع المشاكل.
 * - تم التأكد من أن سعر الطرد يتم حسابه بشكل صحيح.
 * - زيادة أولوية الفلاتر لضمان التغلب على أي إضافات أخرى.
 */

// =================================================================
// Debugging Configuration
// =================================================================

// uncomment the line below to enable debugging
// define('DMS_DEBUG', true);

// =================================================================
// Core Functions
// =================================================================

/**
 * دالة مساعدة لتسجيل الرسائل في ملف سجل الأخطاء.
 */
function dms_log($message) {
    if (defined('DMS_DEBUG') && DMS_DEBUG === true) {
        if (is_array($message) || is_object($message)) {
            $message = print_r($message, true);
        }
        $upload_dir = wp_upload_dir();
        $log_file = $upload_dir['basedir'] . '/dms-debug.log';
        file_put_contents($log_file, date('Y-m-d H:i:s') . ' - ' . $message . PHP_EOL, FILE_APPEND);
    }
}

if (!function_exists('dms_get_unit_label_display')) {
    function dms_get_unit_label_display($product_id, $unit_type, $context = 'api', $unit_name = '', $pieces_count = null, $group_override = '') {
        $unit_type = is_string($unit_type) ? strtolower($unit_type) : '';
        $unit_name = is_string($unit_name) ? $unit_name : '';
        $pieces_count = is_null($pieces_count) ? null : absint($pieces_count);
        $group_override = is_string($group_override) ? $group_override : '';

        $prices_meta = is_numeric($product_id) ? get_post_meta($product_id, '_dms_prices', true) : array();
        $prices_meta = is_array($prices_meta) ? $prices_meta : array();

        $group = $group_override;
        if ($group === '') {
            $current_user_id = get_current_user_id();
            $group = $current_user_id ? get_user_meta($current_user_id, 'dms_user_group', true) : '';
        }

        $default_prices = $prices_meta['default'] ?? reset($prices_meta);
        $active_prices = ($group !== '') ? ($prices_meta[$group] ?? null) : null;
        $default_prices = is_array($default_prices) ? $default_prices : array();
        $active_prices = is_array($active_prices) ? $active_prices : array();

        // Keep labels stable between guest/auth flows; pricing can still vary by group.
        $piece_name = sanitize_text_field($default_prices['box_unit_name'] ?? '');
        if ($piece_name === '') {
            $piece_name = sanitize_text_field($active_prices['box_unit_name'] ?? '');
        }

        $package_name = sanitize_text_field($default_prices['package_unit_name'] ?? '');
        if ($package_name === '') {
            $package_name = sanitize_text_field($active_prices['package_unit_name'] ?? '');
        }

        $piece_count = absint($default_prices['box_pieces_count'] ?? 0);
        if ($piece_count <= 0) {
            $piece_count = absint($active_prices['box_pieces_count'] ?? 0);
        }

        $package_count = absint($default_prices['package_pieces_count'] ?? 0);
        if ($package_count <= 0) {
            $package_count = absint($active_prices['package_pieces_count'] ?? 0);
        }

        if ($unit_name === '' || $pieces_count === null) {
            if ($unit_type === 'package') {
                if ($unit_name === '') {
                    $unit_name = $package_name;
                }
                if ($pieces_count === null) {
                    $pieces_count = $package_count;
                }
            } else {
                if ($unit_name === '') {
                    $unit_name = $piece_name;
                }
                if ($pieces_count === null) {
                    $pieces_count = $piece_count;
                }
            }
        }

        if ($unit_name === '') {
            if ($unit_type === 'package') {
                $unit_name = 'طرد';
            } elseif ($unit_type === 'box' || $unit_type === 'piece') {
                $unit_name = 'علبة';
            } else {
                $unit_name = 'قطعة';
            }
        }

        $count_unit_label = $piece_name !== '' ? $piece_name : $unit_name;

        if (!is_null($pieces_count) && $pieces_count <= 1) {
            $unit_name = preg_replace('/\s*\(\s*[١1]\s+قطعة\s*\)\s*$/u', '', $unit_name);
        }

        $label_ar = $unit_name;
        if (!is_null($pieces_count) && $pieces_count > 1) {
            $label_ar .= ' (' . $pieces_count . ' ' . $count_unit_label . ')';
        }

        return array(
            'ar' => $label_ar,
            'en' => ''
        );
    }
}

/**
 * إضافة حقول الأسعار المخصصة للمنتجات في لوحة الإدارة (WordPress Admin).
 */
add_action('woocommerce_product_options_general_tab', 'dms_add_custom_product_price_fields');
function dms_add_custom_product_price_fields() {
    global $woocommerce, $post;
    dms_log('Action: woocommerce_product_options_general_tab triggered.');

    echo '<div class="options_group dms_prices_group">';
    echo '<h4>أسعار الوحدات المخصصة</h4>';

    $user_groups = get_option('dms_user_groups', []);
    if (empty($user_groups)) {
        echo '<p>الرجاء إضافة مجموعات المستخدمين أولاً في صفحة إعدادات DMS.</p>';
        echo '</div>';
        return;
    }

    $product_prices = get_post_meta($post->ID, '_dms_prices', true);
    $product_prices = is_array($product_prices) ? $product_prices : [];

    foreach ($user_groups as $group_id => $group_name) {
        echo '<div class="dms-group-prices" style="border: 1px solid #eee; padding: 10px; margin-bottom: 15px;">';
        echo '<h5>أسعار المجموعة: ' . esc_html($group_name) . ' (' . esc_html($group_id) . ')</h5>';

        woocommerce_wp_text_input(
            array(
                'id'            => '_dms_prices[' . esc_attr($group_id) . '][syp_piece]',
                'label'         => __('سعر القطعة (ل.س)', 'textdomain'),
                'placeholder'   => 'مثال: 145200',
                'description'   => __('سعر الوحدة الأساسية (قطعة/علبة) بالليرة السورية.', 'textdomain'),
                'value'         => wc_clean($product_prices[$group_id]['syp_piece'] ?? ''),
                'data_type'     => 'price',
                'wrapper_class' => 'form-field',
            )
        );

        woocommerce_wp_text_input(
            array(
                'id'            => '_dms_prices[' . esc_attr($group_id) . '][usd_piece]',
                'label'         => __('سعر القطعة (دولار أمريكي)', 'textdomain'),
                'placeholder'   => 'مثال: 13.2',
                'description'   => __('سعر الوحدة الأساسية (قطعة/علبة) بالدولار الأمريكي.', 'textdomain'),
                'value'         => wc_clean($product_prices[$group_id]['usd_piece'] ?? ''),
                'data_type'     => 'price',
                'wrapper_class' => 'form-field',
            )
        );
        
        woocommerce_wp_text_input(
            array(
                'id'            => '_dms_prices[' . esc_attr($group_id) . '][box_unit_name]',
                'label'         => __('اسم وحدة العلبة', 'textdomain'),
                'placeholder'   => 'علبة',
                'description'   => __('مثال: علبة 24 كرت.', 'textdomain'),
                'value'         => wc_clean($product_prices[$group_id]['box_unit_name'] ?? ''),
                'wrapper_class' => 'form-field',
            )
        );
        
        woocommerce_wp_text_input(
            array(
                'id'            => '_dms_prices[' . esc_attr($group_id) . '][box_pieces_count]',
                'label'         => __('عدد القطع في العلبة', 'textdomain'),
                'placeholder'   => '1',
                'description'   => __('عدد القطع الموجودة في وحدة العلبة. (مثال: 1 إذا كانت العلبة تعتبر "قطعة" واحدة).', 'textdomain'),
                'value'         => wc_clean($product_prices[$group_id]['box_pieces_count'] ?? ''),
                'data_type'     => 'number',
                'wrapper_class' => 'form-field',
            )
        );
        
        woocommerce_wp_text_input(
            array(
                'id'            => '_dms_prices[' . esc_attr($group_id) . '][package_unit_name]',
                'label'         => __('اسم وحدة الطرد', 'textdomain'),
                'placeholder'   => 'طرد',
                'description'   => __('مثال: طرد 12 علبة.', 'textdomain'),
                'value'         => wc_clean($product_prices[$group_id]['package_unit_name'] ?? ''),
                'wrapper_class' => 'form-field',
            )
        );
        
        woocommerce_wp_text_input(
            array(
                'id'            => '_dms_prices[' . esc_attr($group_id) . '][package_pieces_count]',
                'label'         => __('عدد القطع في الطرد', 'textdomain'),
                'placeholder'   => '12',
                'description'   => __('عدد القطع الموجودة في وحدة الطرد. (مثال: 12 إذا كان الطرد 12 علبة وكل علبة تعتبر قطعة).', 'textdomain'),
                'value'         => wc_clean($product_prices[$group_id]['package_pieces_count'] ?? ''),
                'data_type'     => 'number',
                'wrapper_class' => 'form-field',
            )
        );

        echo '</div>';
    }

    echo '</div>';
}

/**
 * حفظ حقول الأسعار المخصصة للمنتجات في قاعدة البيانات.
 */
add_action('woocommerce_process_product_meta', 'dms_save_custom_product_price_fields');
function dms_save_custom_product_price_fields($post_id) {
    dms_log('Action: woocommerce_process_product_meta triggered for Post ID: ' . $post_id);
    if (isset($_POST['_dms_prices']) && is_array($_POST['_dms_prices'])) {
        $dms_prices = $_POST['_dms_prices'];
        $sanitized_prices = [];
        $has_valid_data = false;

        foreach ($dms_prices as $group_id => $group_data) {
            if (
                !empty($group_data['syp_piece']) || !empty($group_data['usd_piece']) ||
                !empty($group_data['box_unit_name']) || !empty($group_data['box_pieces_count']) ||
                !empty($group_data['package_unit_name']) || !empty($group_data['package_pieces_count'])
            ) {
                $sanitized_prices[$group_id] = [
                    'syp_piece'          => wc_clean($group_data['syp_piece'] ?? ''),
                    'usd_piece'          => wc_clean($group_data['usd_piece'] ?? ''),
                    'box_unit_name'      => sanitize_text_field($group_data['box_unit_name'] ?? ''),
                    'box_pieces_count'   => absint($group_data['box_pieces_count'] ?? 0),
                    'package_unit_name'  => sanitize_text_field($group_data['package_unit_name'] ?? ''),
                    'package_pieces_count' => absint($group_data['package_pieces_count'] ?? 0),
                ];
                $has_valid_data = true;
            }
        }

        if ($has_valid_data) {
            update_post_meta($post_id, '_dms_prices', $sanitized_prices);
            dms_log('Custom prices saved for post ID ' . $post_id . ': ' . print_r($sanitized_prices, true));
        } else {
            delete_post_meta($post_id, '_dms_prices');
            dms_log('Custom prices deleted for post ID ' . $post_id . ' (no valid data)');
        }
    }
}

/**
 * إضافة خيار اختيار الوحدة (علبة/طرد) في صفحة المنتج الفردي.
 */
add_action('woocommerce_before_add_to_cart_button', 'dms_add_unit_selection_to_product_page');
function dms_add_unit_selection_to_product_page() {
    global $product;
    if (!$product) return;

    $user_id = get_current_user_id();

    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        echo '<p class="dms-no-price-message" style="color: #FF0000; font-weight: bold; margin-bottom: 15px;">الأسعار غير متاحة للمستخدمين غير المسجلين أو غير المؤكدين.</p>';
        return;
    }

    $group = get_user_meta($user_id, 'dms_user_group', true);
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
    $prices_meta = get_post_meta($product->get_id(), '_dms_prices', true);
    $prices_meta = is_array($prices_meta) ? $prices_meta : [];

    dms_log('Displaying unit selection for product ID ' . $product->get_id() . '. User group: ' . $group . ', Currency: ' . $currency);

    if (isset($prices_meta[$group])) {
        $group_prices = $prices_meta[$group];
        $syp_piece_base_price = (float) ($group_prices['syp_piece'] ?? 0);
        $usd_piece_base_price = (float) ($group_prices['usd_piece'] ?? 0);
        $box_pieces_count = absint($group_prices['box_pieces_count'] ?? 0);
        $package_pieces_count = absint($group_prices['package_pieces_count'] ?? 0);
        $box_unit_name = sanitize_text_field($group_prices['box_unit_name'] ?? 'علبة');
        $package_unit_name = sanitize_text_field($group_prices['package_unit_name'] ?? 'طرد');
        $has_box = ($box_pieces_count > 0 && ($syp_piece_base_price > 0 || $usd_piece_base_price > 0));
        $has_package = ($package_pieces_count > 0 && ($syp_piece_base_price > 0 || $usd_piece_base_price > 0));

        if ($has_box || $has_package) {
            ?>
            <div class="dms-main-product-price" style="font-weight: bold; font-size: 1.5em; margin-bottom: 15px;">
                </div>
            <div class="dms-unit-selection" style="margin-bottom: 15px;">
                <label for="dms_unit_type">اختر الوحدة:</label>
                <select name="dms_unit_type" id="dms_unit_type" style="width: auto; display: inline-block; margin-left: 10px;">
                    <?php if ($has_box) : ?>
                        <option value="box"
                                data-syp-price-per-unit="<?php echo esc_attr($syp_piece_base_price); ?>"
                                data-usd-price-per-unit="<?php echo esc_attr($usd_piece_base_price); ?>"
                                data-pieces-in-unit="<?php echo esc_attr($box_pieces_count); ?>"
                                data-unit-name="<?php echo esc_attr($box_unit_name); ?>"><?php echo esc_html($box_unit_name); ?></option>
                    <?php endif; ?>
                    <?php if ($has_package) : ?>
                        <option value="package"
                                data-syp-price-per-unit="<?php echo esc_attr($syp_piece_base_price * $package_pieces_count); ?>"
                                data-usd-price-per-unit="<?php echo esc_attr($usd_piece_base_price * $package_pieces_count); ?>"
                                data-pieces-in-unit="<?php echo esc_attr($package_pieces_count); ?>"
                                data-unit-name="<?php echo esc_attr($package_unit_name); ?>"><?php echo esc_html($package_unit_name); ?></option>
                    <?php endif; ?>
                </select>
                <p class="dms-current-price-display" style="font-weight: bold; margin-top: 10px;"></p>
            </div>
            <script type="text/javascript">
                jQuery(document).ready(function($) {
                    var $unitSelect = $('#dms_unit_type');
                    var $qtyInput = $('input.qty');
                    var $priceDisplay = $('.dms-current-price-display');
                    var $mainProductPrice = $('.dms-main-product-price');
                    var currentCurrency = '<?php echo esc_js($currency); ?>';
                    var initialBoxPriceSYP = parseFloat('<?php echo esc_js($syp_piece_base_price); ?>');
                    var initialBoxPriceUSD = parseFloat('<?php echo esc_js($usd_piece_base_price); ?>');
                    var initialBoxUnitName = '<?php echo esc_js($box_unit_name); ?>';

                    function formatPrice(price, currency) {
                        if (isNaN(price)) return 'N/A';
                        if (currency === 'syp') {
                            // عرض السعر برقم عشري مع نقطة
                            var parts = price.toFixed(2).toString().split('.');
                            var formatted = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',') + '.' + parts[1];
                            return formatted + ' ل.س';
                        } else if (currency === 'usd') {
                            // عرض الدولار برقم عشري مع نقطة
                            var parts = price.toFixed(2).toString().split('.');
                            var formatted = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',') + '.' + parts[1];
                            return '$' + formatted;
                        } else {
                            // للعملات الأخرى أيضاً استخدم النقطة
                            var parts = price.toFixed(2).toString().split('.');
                            var formatted = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',') + '.' + parts[1];
                            return formatted + ' ' + currency.toUpperCase();
                        }
                    }

                    function hideOriginalWooPrice() {
                        var $originalPrice = $('.summary .price, .product-info .price, .woocommerce-Price-amount, .price_slider_amount .price');
                        if ($originalPrice.length) {
                             $originalPrice.each(function() {
                                var $this = $(this);
                                if (!$this.closest('.dms-main-product-price').length && !$this.closest('.dms-current-price-display').length) {
                                    $this.hide();
                                }
                            });
                        }
                    }

                    function updateDisplayedPrice() {
                        var selectedOption = $unitSelect.find('option:selected');
                        if (selectedOption.length === 0) {
                            $priceDisplay.html('');
                            $mainProductPrice.html('');
                            return;
                        }

                        var pricePerSelectedUnit = parseFloat(selectedOption.data(currentCurrency + '-price-per-unit'));
                        var piecesInSelectedUnit = parseInt(selectedOption.data('pieces-in-unit'));
                        var unitName = selectedOption.data('unit-name');
                        var quantity = parseInt($qtyInput.val());

                        if (isNaN(pricePerSelectedUnit) || isNaN(quantity) || pricePerSelectedUnit <= 0 || quantity <= 0) {
                            $priceDisplay.html('السعر غير متوفر أو غير صالح');
                            return;
                        }

                        var totalCalculatedPrice = pricePerSelectedUnit * quantity;
                        $priceDisplay.html('السعر الإجمالي: ' + formatPrice(totalCalculatedPrice, currentCurrency) + ' <small>(لكل ' + quantity + ' ' + unitName + (piecesInSelectedUnit > 0 ? ' (' + piecesInSelectedUnit + ' قطعة)' : '') + ')</small>');
                        var initialDisplayPrice = (currentCurrency === 'syp' ? initialBoxPriceSYP : initialBoxPriceUSD);
                        if (isNaN(initialDisplayPrice) || initialDisplayPrice <= 0) {
                            $mainProductPrice.html('السعر غير متوفر');
                        } else {
                            $mainProductPrice.html(formatPrice(initialDisplayPrice, currentCurrency) + ' / ' + initialBoxUnitName);
                        }
                    }

                    hideOriginalWooPrice();
                    updateDisplayedPrice();

                    $unitSelect.on('change', updateDisplayedPrice);
                    $qtyInput.on('change keyup', updateDisplayedPrice);

                    $(document.body).on('wc_variation_form.woocommerce', function(){
                        hideOriginalWooPrice();
                        updateDisplayedPrice();
                    });
                    $(document.body).on('updated_wc_div', function() {
                        hideOriginalWooPrice();
                        updateDisplayedPrice();
                    });

                    setTimeout(hideOriginalWooPrice, 500);
                });
            </script>
            <style type="text/css">
                .woocommerce-product-gallery + .summary .price,
                .product .summary .price,
                .product-type-simple .price,
                .single-product-summary .price,
                .price_slider_amount .price,
                .price ins,
                .price del
                {
                    display: none !important;
                }
                .dms-main-product-price,
                .dms-current-price-display {
                    display: block !important;
                }
                .archive .product .price,
                .tax-product_cat .product .price,
                .post-type-archive-product .price
                {
                    display: none !important;
                }
                .dms-archive-price {
                    display: block !important;
                }
            </style>
            <?php
        }
    }
}

/**
 * Replace default WooCommerce product price display with the price of the first available unit for confirmed users
 * in archive/shop pages.
 */
add_filter('woocommerce_get_price_html', 'dms_display_initial_custom_price_html_archive', 999, 2);
function dms_display_initial_custom_price_html_archive($price_html, $product) {
    if (is_product() || is_cart() || is_checkout() || (defined('DOING_AJAX') && DOING_AJAX)) {
        return $price_html;
    }

    $user_id = get_current_user_id();
    $is_user_confirmed = is_user_logged_in() && (get_user_meta($user_id, 'dms_account_status', true) === 'مؤكد');

    if (!$is_user_confirmed) {
        return $price_html;
    }

    $group = get_user_user_group($user_id);
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
    $prices_meta = get_post_meta($product->get_id(), '_dms_prices', true);
    $prices_meta = is_array($prices_meta) ? $prices_meta : [];

    dms_log('Filtering archive price for product ID ' . $product->get_id() . '. User group: ' . $group);

    if (isset($prices_meta[$group])) {
        $group_prices = $prices_meta[$group];
        $piece_price_key = $currency . '_piece';
        $base_piece_price = floatval($group_prices[$piece_price_key] ?? 0);
        $box_pieces_count = absint($group_prices['box_pieces_count'] ?? 0);
        $package_pieces_count = absint($group_prices['package_pieces_count'] ?? 0);

        $initial_display_price = 0;
        $unit_name_for_display = '';

        if ($box_pieces_count > 0 && $base_piece_price > 0) {
            $initial_display_price = $base_piece_price;
            $unit_name_for_display = sanitize_text_field($group_prices['box_unit_name'] ?? 'علبة');
            dms_log('Archive price: Using box unit price ' . $initial_display_price . ' for product ID ' . $product->get_id());
        } elseif ($package_pieces_count > 0 && $base_piece_price > 0) {
            $initial_display_price = $base_piece_price * $package_pieces_count;
            $unit_name_for_display = sanitize_text_field($group_prices['package_unit_name'] ?? 'طرد');
            dms_log('Archive price: Using package unit price ' . $initial_display_price . ' for product ID ' . $product->get_id());
        } else {
            return $price_html;
        }

        if ($initial_display_price > 0) {
            $formatted_price = wc_price($initial_display_price, ['currency' => $currency]);
            return '<span class="price dms-archive-price">' . $formatted_price . ( !empty($unit_name_for_display) ? ' / ' . esc_html($unit_name_for_display) : '' ) . '</span>';
        }
    }

    return $price_html;
}

/**
 * Save unit type and calculated unit price in cart item data.
 */
add_filter('woocommerce_add_cart_item_data', 'dms_add_unit_type_to_cart_item_data', 10, 2);
function dms_add_unit_type_to_cart_item_data($cart_item_data, $product_id) {
    $user_id = get_current_user_id();

    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return $cart_item_data;
    }
    
    $selected_unit_type = isset($_POST['dms_unit_type']) ? sanitize_text_field($_POST['dms_unit_type']) : null;
    dms_log('Hook: woocommerce_add_cart_item_data. Product ID: ' . $product_id . ', Selected Unit Type: ' . ($selected_unit_type ?? 'N/A'));

    if (!$selected_unit_type) {
        return $cart_item_data;
    }

    $cart_item_data['dms_unit_type'] = $selected_unit_type;

    $group = get_user_user_group($user_id);
    $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
    $prices_meta = get_post_meta($product_id, '_dms_prices', true);
    $prices_meta = is_array($prices_meta) ? $prices_meta : [];

    if (isset($prices_meta[$group])) {
        $group_prices = $prices_meta[$group];
        $piece_price_key = $currency . '_piece';
        $base_piece_price = floatval($group_prices[$piece_price_key] ?? 0);

        $unit_price = 0;
        $unit_name = '';
        $pieces_in_unit = 0;

        if ($selected_unit_type === 'box') {
            $unit_price = $base_piece_price;
            $unit_name_key = 'box_unit_name';
            $pieces_count_key = 'box_pieces_count';
            $default_unit_name = 'علبة';
            dms_log('Calculated price for box unit: ' . $unit_price);
        } elseif ($selected_unit_type === 'package') {
            $package_pieces_count = absint($group_prices['package_pieces_count'] ?? 0);
            $unit_price = $base_piece_price * $package_pieces_count;
            $unit_name_key = 'package_unit_name';
            $pieces_count_key = 'package_pieces_count';
            $default_unit_name = 'طرد';
            dms_log('Calculated price for package unit: ' . $unit_price . ' (base piece price: ' . $base_piece_price . ', pieces: ' . $package_pieces_count . ')');
        }

        $unit_name = sanitize_text_field($group_prices[$unit_name_key] ?? $default_unit_name);
        $pieces_in_unit = absint($group_prices[$pieces_count_key] ?? 0);
        
        $cart_item_data['dms_calculated_unit_price'] = $unit_price;
        $cart_item_data['dms_unit_name'] = $unit_name;
        $cart_item_data['dms_piece_price_base'] = $base_piece_price;
        $cart_item_data['dms_unit_pieces_count'] = $pieces_in_unit;

    } else {
        dms_log('No DMS price found for user group: ' . $group);
        $cart_item_data['dms_calculated_unit_price'] = 0;
        $cart_item_data['dms_piece_price_base'] = 0;
        $cart_item_data['dms_unit_pieces_count'] = 0;
        $cart_item_data['dms_unit_name'] = ($selected_unit_type === 'box') ? 'علبة' : 'طرد';
    }
    return $cart_item_data;
}

/**
 * استعادة بيانات الوحدة من الجلسة عند تحميل السلة.
 */
add_filter('woocommerce_get_cart_item_from_session', 'dms_get_unit_type_from_cart_session', 10, 3);
function dms_get_unit_type_from_cart_session($cart_item, $values, $key) {
    if (isset($values['dms_unit_type'])) {
        $cart_item['dms_unit_type'] = $values['dms_unit_type'];
    }
    if (isset($values['dms_piece_price_base'])) {
        $cart_item['dms_piece_price_base'] = $values['dms_piece_price_base'];
    }
    if (isset($values['dms_unit_pieces_count'])) {
        $cart_item['dms_unit_pieces_count'] = $values['dms_unit_pieces_count'];
    }
    if (isset($values['dms_unit_name'])) {
        $cart_item['dms_unit_name'] = $values['dms_unit_name'];
    }
    if (isset($values['dms_calculated_unit_price'])) {
        $cart_item['dms_calculated_unit_price'] = $values['dms_calculated_unit_price'];
    }
    return $cart_item;
}

/**
 * ضبط السعر المخصص لعنصر السلة باستخدام الخطاف `woocommerce_before_calculate_totals`.
 */
add_action('woocommerce_before_calculate_totals', 'dms_set_custom_cart_item_price_on_totals', 999, 1);
function dms_set_custom_cart_item_price_on_totals($cart) {
    if (is_admin() && !defined('DOING_AJAX')) {
        return;
    }
    
    if (is_null($cart) || !method_exists($cart, 'get_cart')) {
        return;
    }
    
    dms_log('Hook: woocommerce_before_calculate_totals triggered. Current cart contents: ' . count($cart->get_cart()) . ' items.');

    foreach ($cart->get_cart() as $cart_item_key => &$cart_item) {
        $product_id = $cart_item['product_id'];
        $unit_price = isset($cart_item['dms_calculated_unit_price']) ? floatval($cart_item['dms_calculated_unit_price']) : 0;
        
        dms_log('Processing cart item key: ' . $cart_item_key . ' for product ID: ' . $product_id);
        dms_log('DMS Calculated Unit Price: ' . $unit_price);
        dms_log('Quantity: ' . $cart_item['quantity']);

        if ($unit_price > 0 && isset($cart_item['data']) && is_a($cart_item['data'], 'WC_Product')) {
            $cart_item['data']->set_price($unit_price);
            $cart_item['data']->set_regular_price($unit_price);
            dms_log('Price successfully set for item ' . $cart_item_key . ' to ' . $unit_price);
        } else {
            dms_log('Price NOT set for item ' . $cart_item_key . '. Reason: unit price is 0 or product data is invalid.');
        }
    }
}

/**
 * NEW: Last resort hook to ensure the final cart total is correct.
 */
add_filter('woocommerce_calculated_total', 'dms_force_cart_total_recalculation', 9999, 2);
function dms_force_cart_total_recalculation($total, $cart) {
    if (is_admin() && !defined('DOING_AJAX')) {
        return $total;
    }
    
    dms_log('Hook: woocommerce_calculated_total triggered. Original total: ' . $total);

    $custom_total = 0;
    foreach ($cart->get_cart() as $cart_item) {
        $quantity = $cart_item['quantity'];
        if (isset($cart_item['dms_calculated_unit_price'])) {
            $unit_price = floatval($cart_item['dms_calculated_unit_price']);
            $custom_total += ($unit_price * $quantity);
            dms_log('Item: ' . $cart_item['product_id'] . ', Unit Price: ' . $unit_price . ', Quantity: ' . $quantity . ', Subtotal: ' . ($unit_price * $quantity));
        } else {
            $custom_total += ($cart_item['data']->get_price() * $quantity);
            dms_log('Item: ' . $cart_item['product_id'] . ', Using default price. Price: ' . $cart_item['data']->get_price() . ', Quantity: ' . $quantity . ', Subtotal: ' . ($cart_item['data']->get_price() * $quantity));
        }
    }

    dms_log('Forced total calculation result: ' . $custom_total);
    return $custom_total;
}

/**
 * إضافة صفحة إعدادات لـ DMS في لوحة التحكم (لإدارة مجموعات المستخدمين).
 */
add_action('admin_menu', 'dms_add_admin_menu');
function dms_add_admin_menu() {
    add_menu_page(
        'إعدادات DMS',
        'DMS',
        'manage_options',
        'dms-settings',
        'dms_settings_page_content',
        'dashicons-cart',
        30
    );
}

function dms_settings_page_content() {
    if (isset($_POST['dms_settings_nonce']) && wp_verify_nonce($_POST['dms_settings_nonce'], 'dms_save_settings')) {
        if (isset($_POST['dms_user_groups'])) {
            $new_groups = array_map('sanitize_text_field', $_POST['dms_user_groups']);
            $new_groups = array_filter($new_groups);
            $final_groups = [];
            foreach ($new_groups as $group) {
                $final_groups[str_replace(' ', '_', strtoupper($group))] = $group;
            }
            update_option('dms_user_groups', $final_groups);
            echo '<div class="notice notice-success is-dismissible"><p>تم حفظ مجموعات المستخدمين بنجاح.</p></div>';
        } else {
            delete_option('dms_user_groups');
        }
    }

    $user_groups = get_option('dms_user_groups', []);
    ?>
    <div class="wrap">
        <h1>إعدادات DMS</h1>

        <form method="post" action="">
            <?php wp_nonce_field('dms_save_settings', 'dms_settings_nonce'); ?>

            <h2>مجموعات المستخدمين</h2>
            <p>أدخل أسماء مجموعات المستخدمين (مثل: A, B, C, العملاء المميزين). ستستخدم هذه المجموعات لتحديد الأسعار المخصصة.</p>
            <div id="dms-user-groups-container">
                <?php if (!empty($user_groups)) : ?>
                    <?php foreach ($user_groups as $group_id => $group_name) : ?>
                        <p>
                            <input type="text" name="dms_user_groups[]" value="<?php echo esc_attr($group_name); ?>" placeholder="اسم المجموعة" style="width: 300px;" />
                            <input type="button" class="button remove-dms-group" value="إزالة" />
                        </p>
                    <?php endforeach; ?>
                <?php else : ?>
                    <p>
                        <input type="text" name="dms_user_groups[]" placeholder="اسم المجموعة" style="width: 300px;" />
                        <input type="button" class="button remove-dms-group" value="إزالة" />
                    </p>
                <?php endif; ?>
            </div>
            <p><input type="button" class="button add-dms-group" value="إضافة مجموعة جديدة" /></p>

            <?php submit_button('حفظ التغييرات'); ?>
        </form>
    </div>

    <script type="text/javascript">
        jQuery(document).ready(function($){
            $('.add-dms-group').on('click', function(){
                $('#dms-user-groups-container').append(
                    '<p><input type="text" name="dms_user_groups[]" placeholder="اسم المجموعة" style="width: 300px;" /><input type="button" class="button remove-dms-group" value="إزالة" /></p>'
                );
            });

            $('#dms-user-groups-container').on('click', '.remove-dms-group', function(){
                $(this).closest('p').remove();
                if ($('#dms-user-groups-container p').length === 0) {
                    $('#dms-user-groups-container').append(
                        '<p><input type="text" name="dms_user_groups[]" placeholder="اسم المجموعة" style="width: 300px;" /><input type="button" class="button remove-dms-group" value="إزالة" /></p>'
                    );
                }
            });
        });
    </script>
    <?php
}

add_action('show_user_profile', 'dms_add_custom_user_profile_fields');
add_action('edit_user_profile', 'dms_add_custom_user_profile_fields');
function dms_add_custom_user_profile_fields($user) {
    $user_groups = get_option('dms_user_groups', []);
    $current_group = get_user_meta($user->ID, 'dms_user_group', true);
    $current_status = get_user_meta($user->ID, 'dms_account_status', true);
    $current_currency = get_user_meta($user->ID, 'dms_user_currency', true);
    ?>
    <h3>إعدادات DMS</h3>
    <table class="form-table">
        <tr>
            <th><label for="dms_user_group">مجموعة المستخدم</label></th>
            <td>
                <select name="dms_user_group" id="dms_user_group">
                    <option value="">-- اختر مجموعة --</option>
                    <?php foreach ($user_groups as $group_id => $group_name) : ?>
                        <option value="<?php echo esc_attr($group_id); ?>" <?php selected($current_group, $group_id); ?>>
                            <?php echo esc_html($group_name); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <p class="description">المجموعة التي ينتمي إليها المستخدم لتحديد الأسعار المخصصة.</p>
            </td>
        </tr>
        <tr>
            <th><label for="dms_account_status">حالة الحساب</label></th>
            <td>
                <select name="dms_account_status" id="dms_account_status">
                    <option value="قيد المراجعة" <?php selected($current_status, 'قيد المراجعة'); ?>>قيد المراجعة</option>
                    <option value="مؤكد" <?php selected($current_status, 'مؤكد'); ?>>مؤكد</option>
                    <option value="مرفوض" <?php selected($current_status, 'مرفوض'); ?>>مرفوض</option>
                </select>
                <p class="description">حالة حساب المستخدم لتحديد ما إذا كان يمكنه رؤية الأسعار.</p>
            </td>
        </tr>
        <tr>
            <th><label for="dms_user_currency">العملة المفضلة</label></th>
            <td>
                <select name="dms_user_currency" id="dms_user_currency">
                    <option value="syp" <?php selected($current_currency, 'syp'); ?>>ليرة سورية (SYP)</option>
                    <option value="usd" <?php selected($current_currency, 'usd'); ?>>دولار أمريكي (USD)</option>
                </select>
                <p class="description">العملة التي سيتم عرض الأسعار بها لهذا المستخدم.</p>
            </td>
        </tr>
    </table>
    <?php
}

add_action('personal_options_update', 'dms_save_custom_user_profile_fields');
add_action('edit_user_profile_update', 'dms_save_custom_user_profile_fields');
function dms_save_custom_user_profile_fields($user_id) {
    if (!current_user_can('edit_user', $user_id)) {
        return false;
    }
    if (isset($_POST['dms_user_group'])) {
        update_user_meta($user_id, 'dms_user_group', sanitize_text_field($_POST['dms_user_group']));
    }
    if (isset($_POST['dms_account_status'])) {
        update_user_meta($user_id, 'dms_account_status', sanitize_text_field($_POST['dms_account_status']));
    }
    if (isset($_POST['dms_user_currency'])) {
        update_user_meta($user_id, 'dms_user_currency', sanitize_text_field($_POST['dms_user_currency']));
    }
}

add_action('user_register', 'dms_set_default_account_status_on_register', 10, 1);
function dms_set_default_account_status_on_register($user_id) {
    if (function_exists('dms_sync_member_record')) {
        dms_sync_member_record($user_id);
        return;
    }
    add_user_meta($user_id, 'dms_account_status', 'قيد المراجعة', true);
}

add_action('pre_get_posts', 'dms_hide_products_from_unconfirmed_users_archive');
function dms_hide_products_from_unconfirmed_users_archive($query) {
    if (!is_admin() && $query->is_main_query() && (is_shop() || is_product_category() || is_product_tag())) {
        $user_id = get_current_user_id();
        if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
            $query->set('post__in', array(0));
        }
    }
}

add_filter('woocommerce_is_purchasable', 'dms_hide_add_to_cart_for_unconfirmed', 10, 2);
function dms_hide_add_to_cart_for_unconfirmed($purchasable, $product) {
    if (!is_admin()) {
        $user_id = get_current_user_id();
        if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
            return false;
        }
    }
    return $purchasable;
}

add_filter('woocommerce_product_single_add_to_cart_text', 'dms_custom_add_to_cart_text');
add_filter('woocommerce_product_add_to_cart_text', 'dms_custom_add_to_cart_text');
function dms_custom_add_to_cart_text($text) {
    if (!is_admin()) {
        $user_id = get_current_user_id();
        if (!is_user_logged_in()) {
            return __('سجل للدخول لعرض الأسعار', 'textdomain');
        } elseif (get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
            return __('حسابك قيد المراجعة', 'textdomain');
        }
    }
    return $text;
}

add_filter('woocommerce_cart_item_name', 'dms_display_unit_type_in_cart', 10, 3);
function dms_display_unit_type_in_cart($product_name, $cart_item, $cart_item_key) {
    $user_id = get_current_user_id();
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return $product_name;
    }

    if (isset($cart_item['dms_unit_type'])) {
        $unit_type = $cart_item['dms_unit_type'];
        $unit_label = $cart_item['dms_unit_name'] ?? (($unit_type === 'box') ? 'علبة' : 'طرد');
        $pieces_in_unit = $cart_item['dms_unit_pieces_count'] ?? 0;
        $display = dms_get_unit_label_display($cart_item['product_id'], $unit_type, 'cart', $unit_label, $pieces_in_unit);
        $product_name .= '<br><small>الوحدة: ' . esc_html($display['ar']) . '</small>';
    }
    return $product_name;
}

add_filter('woocommerce_order_item_name', 'dms_display_unit_type_in_order', 10, 2);
function dms_display_unit_type_in_order($item_name, $item) {
    $unit_type = wc_get_order_item_meta($item->get_id(), 'unit_type', true);
    $unit_name = wc_get_order_item_meta($item->get_id(), 'unit_name', true);
    $pieces_in_unit = wc_get_order_item_meta($item->get_id(), 'unit_pieces', true);
    
    // Legacy meta keys fallback
    if (empty($unit_type)) {
        $unit_type = wc_get_order_item_meta($item->get_id(), 'dms_unit_type', true);
    }
    if (empty($unit_name)) {
        $unit_name = wc_get_order_item_meta($item->get_id(), 'dms_unit_name', true);
    }
    if (empty($pieces_in_unit)) {
        $pieces_in_unit = wc_get_order_item_meta($item->get_id(), 'dms_unit_pieces_count', true);
    }
    
    $default_label = ($unit_type === 'package') ? 'طرد' : (($unit_type === 'box') ? 'علبة' : 'قطعة');
    $unit_label = $unit_name ?: $default_label;
    $display = dms_get_unit_label_display($item->get_product_id(), $unit_type, 'order', $unit_label, $pieces_in_unit);
    $item_name .= '<br><small>الوحدة: ' . esc_html($display['ar']) . '</small>';
    return $item_name;
}

add_action('woocommerce_checkout_create_order_line_item', 'dms_save_unit_type_as_order_line_item_meta', 10, 3);
function dms_save_unit_type_as_order_line_item_meta($item, $cart_item_key, $values) {
    $user_id = get_current_user_id();
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return;
    }

    if (isset($values['dms_unit_type'])) {
        $item->add_meta_data('unit_type', $values['dms_unit_type']);
        $item->add_meta_data('unit_name', $values['dms_unit_name']);
        $item->add_meta_data('unit_price', $values['dms_calculated_unit_price']);
        $item->add_meta_data('unit_pieces', $values['dms_unit_pieces_count']);
        $item->add_meta_data('dms_unit_type', $values['dms_unit_type']);
        $item->add_meta_data('dms_unit_name', $values['dms_unit_name']);
        $item->add_meta_data('dms_calculated_unit_price', $values['dms_calculated_unit_price']);
        $item->add_meta_data('dms_piece_price_base', $values['dms_piece_price_base']);
        $item->add_meta_data('dms_unit_pieces_count', $values['dms_unit_pieces_count']);
    }
}

if (!function_exists('get_user_user_group')) {
    function get_user_user_group($user_id) {
        return get_user_meta($user_id, 'dms_user_group', true);
    }
}

add_filter('woocommerce_cart_item_price', 'dms_hide_cart_item_price_for_unconfirmed', 10, 3);
function dms_hide_cart_item_price_for_unconfirmed($price, $cart_item, $cart_item_key) {
    $user_id = get_current_user_id();
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return '';
    }
    
    if (isset($cart_item['dms_unit_type'])) {
        return '';
    }
    
    return $price;
}

add_filter('woocommerce_cart_subtotal', 'dms_hide_cart_subtotal_for_unconfirmed', 10, 3);
add_filter('woocommerce_cart_total', 'dms_hide_cart_total_for_unconfirmed', 10, 1);
add_filter('woocommerce_cart_tax_total', 'dms_hide_cart_tax_total_for_unconfirmed', 10, 1);
add_filter('woocommerce_cart_shipping_method_full_label', 'dms_hide_cart_shipping_for_unconfirmed', 10, 2);
add_filter('woocommerce_cart_totals_order_total_html', 'dms_hide_cart_order_total_for_unconfirmed', 10, 1);
add_filter('woocommerce_get_formatted_order_total', 'dms_hide_order_total_for_unconfirmed', 10, 2);

function dms_hide_cart_prices_if_unconfirmed($value) {
    $user_id = get_current_user_id();
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return '';
    }
    return $value;
}
function dms_hide_cart_subtotal_for_unconfirmed($subtotal, $compound, $cart) {
    return dms_hide_cart_prices_if_unconfirmed($subtotal);
}
function dms_hide_cart_total_for_unconfirmed($total) {
    return dms_hide_cart_prices_if_unconfirmed($total);
}
function dms_hide_cart_tax_total_for_unconfirmed($tax_total) {
    return dms_hide_cart_prices_if_unconfirmed($tax_total);
}
function dms_hide_cart_shipping_for_unconfirmed($label, $method) {
    $user_id = get_current_user_id();
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return '';
    }
    return $label;
}
function dms_hide_cart_order_total_for_unconfirmed($total_html) {
    return dms_hide_cart_prices_if_unconfirmed($total_html);
}
function dms_hide_order_total_for_unconfirmed($formatted_total, $order) {
    $user_id = $order->get_customer_id();
    // Allow admins to see totals always
    if (current_user_can('manage_options')) {
        return $formatted_total;
    }
    if (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return '';
    }
    return $formatted_total;
}

add_filter('woocommerce_cart_item_price', 'dms_display_custom_price_in_cart', 10, 3);
function dms_display_custom_price_in_cart($price_html, $cart_item, $cart_item_key) {
    $user_id = get_current_user_id();
    // Allow admins to see prices always
    if (current_user_can('manage_options')) {
        // Continue to show custom price if available
    } elseif (!is_user_logged_in() || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return $price_html;
    }

    if (isset($cart_item['dms_calculated_unit_price'])) {
        $currency = get_user_meta($user_id, 'dms_user_currency', true) ?: 'syp';
        $unit_price = floatval($cart_item['dms_calculated_unit_price']);

        if ($unit_price > 0) {
            $formatted_price = wc_price($unit_price, ['currency' => $currency]);
            $unit_info = '';
            if (isset($cart_item['dms_unit_name'])) {
                $unit_info = ' / ' . esc_html($cart_item['dms_unit_name']);
            }
            return '<span class="dms-custom-cart-price">' . $formatted_price . $unit_info . '</span>';
        }
    }

    return $price_html;
}

add_filter('woocommerce_order_item_get_formatted_price', 'dms_display_custom_price_in_order', 10, 2);
function dms_display_custom_price_in_order($formatted_price, $item) {
    $order = $item->get_order();
    $user_id = ($order) ? $order->get_customer_id() : get_current_user_id();

    // Allow admins to see prices always
    if (current_user_can('manage_options')) {
        // Continue to show custom price if available
    } elseif (!$user_id || get_user_meta($user_id, 'dms_account_status', true) !== 'مؤكد') {
        return $formatted_price;
    }

    $unit_price = wc_get_order_item_meta($item->get_id(), 'dms_calculated_unit_price', true);
    if ($unit_price) {
        $currency = $item->get_order()->get_currency();
        return wc_price($unit_price, ['currency' => $currency]);
    }

    return $formatted_price;
}

add_filter('woocommerce_product_get_price', 'dms_get_custom_product_price_filter', 999, 2);
add_filter('woocommerce_product_get_regular_price', 'dms_get_custom_product_price_filter', 999, 2);
add_filter('woocommerce_product_get_sale_price', 'dms_get_custom_product_price_filter', 999, 2);
function dms_get_custom_product_price_filter($price, $product) {
    if (is_admin() && !defined('DOING_AJAX')) {
        return $price;
    }

    if (WC()->cart && !WC()->cart->is_empty()) {
        foreach (WC()->cart->get_cart() as $cart_item) {
            if ($cart_item['product_id'] == $product->get_id() && isset($cart_item['dms_calculated_unit_price'])) {
                $new_price = floatval($cart_item['dms_calculated_unit_price']);
                if ($new_price > 0) {
                    return $new_price;
                }
            }
        }
    }

    return $price;
}

add_filter('woocommerce_product_get_price_including_tax', 'dms_recalculate_price_on_the_fly', 999, 3);
add_filter('woocommerce_product_get_price_excluding_tax', 'dms_recalculate_price_on_the_fly', 999, 3);
function dms_recalculate_price_on_the_fly($price, $qty, $product) {
    if (is_admin() && !defined('DOING_AJAX')) {
        return $price;
    }

    if (WC()->cart && !WC()->cart->is_empty()) {
        foreach (WC()->cart->get_cart() as $cart_item) {
            if ($cart_item['product_id'] === $product->get_id() && isset($cart_item['dms_calculated_unit_price'])) {
                $custom_price = floatval($cart_item['dms_calculated_unit_price']);
                return $custom_price;
            }
        }
    }

    return $price;
}
