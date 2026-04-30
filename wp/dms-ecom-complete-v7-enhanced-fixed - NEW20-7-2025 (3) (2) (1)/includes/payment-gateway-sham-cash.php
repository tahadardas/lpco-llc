<?php
/**
 * Plugin Name: WooCommerce الدفع الفوري - الباركود
 * Description: نظام الدفع عبر الباركود الفوري للتحويل المباشر
 * Version: 1.0
 */

if (!defined('ABSPATH')) exit;

if (!function_exists('dms_get_sham_cash_config')) {
    function dms_get_sham_cash_config() {
        $settings = get_option('woocommerce_instant_barcode_settings', array());
        $account_code = sanitize_text_field($settings['account_code'] ?? '');
        $company_name = sanitize_text_field($settings['company_name'] ?? '');
        $time_limit = intval($settings['time_limit'] ?? 15);

        if ($account_code === '') {
            $account_code = '2f3b91dd0befb9f619ef06697e7a1dc8';
        }
        if ($company_name === '') {
            $company_name = 'لبكو المحدودة المسؤولية';
        }
        if ($time_limit <= 0) {
            $time_limit = 15;
        }

        return array(
            'account_code' => $account_code,
            'company_name' => $company_name,
            'time_limit' => $time_limit,
        );
    }
}

// 1. إضافة بوابة الدفع عبر الباركود الفوري
add_action('plugins_loaded', 'init_instant_barcode_payment');
function init_instant_barcode_payment() {
    if (!class_exists('WC_Payment_Gateway')) return;
    
    class WC_Gateway_Instant_Barcode extends WC_Payment_Gateway {
        public $account_code;
        public $company_name;
        public $company_email;

        public function __construct() {
            $this->id                 = 'instant_barcode';
            $this->icon               = '';
            $this->has_fields         = true;
            $this->method_title       = 'شام كاش - الباركود الفوري';
            $this->method_description = 'تحويل فوري عبر شام كاش (تصوير الباركود)';
            $this->supports           = array('products');
            
            // تحميل الإعدادات
            $this->init_form_fields();
            $this->init_settings();
            
            // تعريف المتغيرات
            $this->title        = $this->get_option('title');
            $this->description  = $this->get_option('description');
            $default_config = dms_get_sham_cash_config();
            $this->account_code = sanitize_text_field($this->get_option('account_code', $default_config['account_code']));
            $this->company_name = sanitize_text_field($this->get_option('company_name', $default_config['company_name']));
            $this->company_email = get_option('admin_email'); // استخدام إيميل الموقع
            
            // حفظ الإعدادات
            add_action('woocommerce_update_options_payment_gateways_' . $this->id, array($this, 'process_admin_options'));
            
            // إضافة التعليمات إلى البريد الإلكتروني فقط
            add_action('woocommerce_email_before_order_table', array($this, 'email_instructions'), 10, 3);
        }
        
        public function init_form_fields() {
            $this->form_fields = array(
                'enabled' => array(
                    'title'   => 'تفعيل/تعطيل',
                    'type'    => 'checkbox',
                    'label'   => 'تفعيل الدفع عبر شام كاش',
                    'default' => 'yes'
                ),
                'title' => array(
                    'title'       => 'العنوان',
                    'type'        => 'text',
                    'default'     => 'شام كاش - الباركود الفوري',
                ),
                'description' => array(
                    'title'       => 'الوصف',
                    'type'        => 'textarea',
                    'default'     => 'تحويل فوري عبر تصوير باركود شام كاش. يرجى تصوير الباركود وتحويل المبلغ ثم إرفاق صورة إشعار التحويل.',
                ),
                'company_name' => array(
                    'title'       => 'اسم الشركة',
                    'type'        => 'text',
                    'default'     => 'لبكو المحدودة المسؤولية',
                ),
                'account_code' => array(
                    'title'       => 'رقم حساب شام كاش',
                    'type'        => 'text',
                    'default'     => '2f3b91dd0befb9f619ef06697e7a1dc8',
                ),
                'time_limit' => array(
                    'title'       => 'مهلة التحويل (دقائق)',
                    'type'        => 'number',
                    'default'     => '15',
                ),
            );
        }
        
        // عرض صفحة الدفع مع الباركود
        public function payment_fields() {
            $order_total = WC()->cart->total;
            
            echo '<div class="instant-payment-container" style="background: white; border: 2px solid #dc2626; border-radius: 10px; padding: 15px; margin-bottom: 20px; max-width: 100%; overflow: hidden;">';
            
            // مبلغ الدفع - تصميم متجاوب
            echo '<div style="background: #f9fafb; border: 1px solid #e5e7eb; padding: 12px; border-radius: 8px; margin-bottom: 15px; text-align: center;">';
            echo '<p style="margin: 0 0 8px 0; font-weight: 600; font-size: 14px;">💰 مبلغ الدفع:</p>';
            echo '<div style="font-size: 22px; font-weight: 700; color: #dc2626; word-break: break-word;">' . wc_price($order_total) . '</div>';
            echo '</div>';
            
            // باركود الدفع - تصميم متجاوب
            echo '<div style="background: white; padding: 15px; border-radius: 8px; margin-bottom: 15px; border: 1px solid #e5e7eb; text-align: center;">';
            echo '<p style="margin: 0 0 12px 0; font-weight: 700; font-size: 16px;">📷 باركود شام كاش</p>';
            
            // إنشاء باركود QR
            $qr_data = urlencode(json_encode(array(
                'company' => $this->company_name,
                'account' => $this->account_code,
                'amount' => $order_total,
                'timestamp' => time()
            )));
            
            // حجم متجاوب للباركود
            $barcode_size = wp_is_mobile() ? '180' : '200';
            $barcode_url = 'https://api.qrserver.com/v1/create-qr-code/?size='.$barcode_size.'x'.$barcode_size.'&data=' . $qr_data . '&color=dc2626&bgcolor=ffffff';
            
            echo '<img src="' . esc_url($barcode_url) . '" alt="باركود شام كاش" style="width: 100%; max-width: '.$barcode_size.'px; height: auto; border: 2px solid #dc2626; border-radius: 8px; margin: 0 auto; display: block;">';
            
            echo '<p style="color: #6b7280; margin: 12px 0 0 0; font-size: 13px; line-height: 1.4;">قم بتصوير الباركود باستخدام تطبيق شام كاش</p>';
            echo '</div>';
            
            // معلومات الحساب - تصميم متجاوب
            echo '<div style="background: #f9fafb; padding: 15px; border-radius: 8px; text-align: right; margin-bottom: 15px;">';
            echo '<h4 style="margin: 0 0 12px 0; color: #1f2937; font-size: 15px;">معلومات التحويل:</h4>';
            
            echo '<div style="margin-bottom: 12px; font-size: 14px;">';
            echo '<div style="margin-bottom: 8px; line-height: 1.5;"><strong>الشركة:</strong><br>' . esc_html($this->company_name) . '</div>';
            echo '<div style="margin-bottom: 8px; line-height: 1.5;"><strong>رقم الحساب:</strong><br>';
            echo '<div style="background: white; padding: 8px; border-radius: 6px; border: 1px solid #e5e7eb; font-family: monospace; color: #1f2937; font-size: 13px; word-break: break-all; margin-top: 4px;">' . esc_html($this->account_code) . '</div>';
            echo '</div>';
            echo '<div style="margin-bottom: 8px; line-height: 1.5;"><strong>المبلغ:</strong><br><span style="font-weight: 700; color: #dc2626; font-size: 16px;">' . wc_price($order_total) . '</span></div>';
            echo '<div style="line-height: 1.5;"><strong>المهلة:</strong><br>' . $this->get_option('time_limit') . ' دقيقة</div>';
            echo '</div>';
            echo '</div>';
            
            // نموذج إرفاق الإشعار - تصميم متجاوب
            echo '<div style="margin-top: 15px; background: #fef2f2; padding: 15px; border-radius: 8px; border-right: 4px solid #dc2626;">';
            echo '<h4 style="margin: 0 0 12px 0; color: #1f2937; font-size: 15px;">📤 إرفاق إشعار التحويل</h4>';
            echo '<p style="color: #6b7280; margin-bottom: 12px; font-size: 13px; line-height: 1.4;">بعد إتمام التحويل، يرجى إرفاق صورة إشعار التحويل</p>';
            
            echo '<div id="payment-proof-container" style="display: none; margin-bottom: 12px;">';
            echo '<input type="file" id="payment_proof" name="payment_proof" accept="image/*" style="width: 100%; padding: 10px; border: 1px dashed #d1d5db; border-radius: 6px; font-size: 14px; box-sizing: border-box;">';
            echo '<p style="color: #9ca3af; font-size: 12px; margin-top: 8px; line-height: 1.4;">يمكنك رفع الصورة لاحقاً من صفحة تأكيد الطلب</p>';
            echo '</div>';
            
            echo '<button type="button" id="show-upload-btn" style="background: #dc2626; color: white; border: none; padding: 12px; border-radius: 6px; font-size: 15px; font-weight: 600; cursor: pointer; width: 100%; box-sizing: border-box; transition: background-color 0.3s;" onmouseover="this.style.backgroundColor=\'#b91c1c\'" onmouseout="this.style.backgroundColor=\'#dc2626\'">إظهار حقل رفع الصورة</button>';
            echo '</div>';
            
            echo '</div>'; // نهاية الحاوية
            
            if ($this->description) {
                echo '<div style="margin-top: 15px; color: #6b7280; font-size: 13px; line-height: 1.5;">';
                echo wpautop(wp_kses_post($this->description));
                echo '</div>';
            }
            
            // JavaScript لإظهار/إخفاء حقل الرفع
            ?>
            <script>
            jQuery(document).ready(function($) {
                $('#show-upload-btn').click(function() {
                    $('#payment-proof-container').slideDown();
                    $(this).hide();
                });
                
                // تحسين تجربة الموبايل
                if ($(window).width() < 768) {
                    $('.instant-payment-container').css({
                        'padding': '12px',
                        'margin': '10px 0'
                    });
                    
                    // جعل الباركود قابل للضغط للتكبير على الموبايل
                    $('.instant-payment-container img').wrap('<a href="' + $('.instant-payment-container img').attr('src') + '" target="_blank" style="display: block; text-align: center;"></a>');
                    $('.instant-payment-container img').css('cursor', 'pointer');
                }
            });
            </script>
            <?php
        }
        
        public function process_payment($order_id) {
            $order = wc_get_order($order_id);
            $order_total = $order->get_total();
            $expiry_time = time() + ($this->get_option('time_limit') * 60);
            
            // حفظ معلومات الدفع
            $order->update_meta_data('_sham_cash_method', 'barcode_transfer');
            $order->update_meta_data('_sham_cash_company', $this->company_name);
            $order->update_meta_data('_sham_cash_account', $this->account_code);
            $order->update_meta_data('_sham_cash_amount', $order_total);
            $order->update_meta_data('_sham_cash_expiry', $expiry_time);
            $order->update_meta_data('_sham_cash_status', 'pending');
            
            // معالجة صورة الإشعار إذا تم رفعها
            if (!empty($_FILES['payment_proof']['name'])) {
                $this->handle_payment_proof_upload($order_id);
            }
            
            // تحديث حالة الطلب
            $order->update_status('pending', sprintf(
                'بانتظار التحويل عبر شام كاش<br>رقم الحساب: %s<br>المهلة: %s دقيقة',
                $this->account_code,
                $this->get_option('time_limit')
            ));
            
            // إضافة ملاحظة
            $order->add_order_note(sprintf(
                'تم اختيار الدفع عبر شام كاش - الباركود الفوري.<br>رقم الحساب: %s<br>المبلغ: %s',
                $this->account_code,
                wc_price($order_total)
            ));
            
            // إرسال إيميل للشركة
            $this->send_payment_email_to_company($order);
            
            // تقليل المخزون
            wc_reduce_stock_levels($order_id);
            
            // إفراغ عربة التسوق
            WC()->cart->empty_cart();
            
            // إعادة التوجيه إلى صفحة الشكر العادية
            return array(
                'result'   => 'success',
                'redirect' => $this->get_return_url($order)
            );
        }
        
        // معالجة رفع صورة الإشعار
        private function handle_payment_proof_upload($order_id) {
            require_once(ABSPATH . 'wp-admin/includes/file.php');
            require_once(ABSPATH . 'wp-admin/includes/media.php');
            require_once(ABSPATH . 'wp-admin/includes/image.php');
            
            $uploadedfile = $_FILES['payment_proof'];
            $upload_overrides = array('test_form' => false);
            
            $movefile = wp_handle_upload($uploadedfile, $upload_overrides);
            
            if ($movefile && !isset($movefile['error'])) {
                $order = wc_get_order($order_id);
                $order->update_meta_data('_payment_proof_url', $movefile['url']);
                $order->add_order_note('تم رفع صورة إشعار التحويل: ' . $movefile['url']);
                $order->save();
                
                return true;
            }
            
            return false;
        }
        
        // إرسال إيميل للشركة
        private function send_payment_email_to_company($order) {
            $to = $this->company_email;
            $subject = 'طلب جديد - شام كاش #' . $order->get_id();
            
            $message = '
            <!DOCTYPE html>
            <html dir="rtl">
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>طلب جديد - شام كاش</title>
                <style>
                    @media (max-width: 600px) {
                        .container {
                            padding: 10px !important;
                        }
                        .header h1 {
                            font-size: 20px !important;
                            padding: 15px !important;
                        }
                        .info-box {
                            padding: 12px !important;
                        }
                        .button {
                            padding: 10px 15px !important;
                            font-size: 14px !important;
                            display: block !important;
                            width: 100% !important;
                            margin: 5px 0 !important;
                        }
                    }
                </style>
            </head>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0;">
                <div class="container" style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <div class="header" style="background: #1f2937; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
                        <h1 style="margin: 0; font-size: 24px;">طلب جديد - شام كاش</h1>
                    </div>
                    
                    <div style="background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px;">
                        <div class="info-box" style="background: white; padding: 15px; border-radius: 6px; margin-bottom: 20px; border-right: 4px solid #dc2626;">
                            <h2 style="color: #1f2937; margin-top: 0; margin-bottom: 15px; font-size: 18px;">معلومات الطلب</h2>
                            <table style="width: 100%; border-collapse: collapse;">
                                <tr>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>رقم الطلب:</strong></td>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;">#' . $order->get_id() . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>العميل:</strong></td>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;">' . $order->get_billing_first_name() . ' ' . $order->get_billing_last_name() . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>رقم الحساب:</strong></td>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;"><code style="background: #f3f4f6; padding: 4px 8px; border-radius: 4px; font-size: 12px;">' . $this->account_code . '</code></td>
                                </tr>
                                <tr>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>المبلغ:</strong></td>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left; font-weight: bold; color: #dc2626; font-size: 16px;">' . wc_price($order->get_total()) . '</td>
                                </tr>
                                <tr>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>المهلة:</strong></td>
                                    <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;">' . $this->get_option('time_limit') . ' دقيقة</td>
                                </tr>
                                <tr>
                                    <td style="padding: 8px 0;"><strong>حالة الدفع:</strong></td>
                                    <td style="padding: 8px 0; text-align: left;"><span style="background: #f59e0b; color: white; padding: 4px 10px; border-radius: 12px; font-size: 12px;">في انتظار التحويل</span></td>
                                </tr>
                            </table>
                        </div>
                        
                        <div style="background: white; padding: 15px; border-radius: 6px; margin-bottom: 20px; text-align: center;">
                            <h3 style="color: #1f2937; margin-top: 0; margin-bottom: 15px; font-size: 16px;">باركود الطلب</h3>
                            <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=' . urlencode('ORDER-' . $order->get_id()) . '&color=dc2626&bgcolor=ffffff" alt="باركود الطلب" style="width: 150px; height: 150px; border: 2px solid #dc2626; border-radius: 6px; max-width: 100%; height: auto;">
                        </div>
                        
                        <div style="text-align: center; margin-top: 20px;">
                            <a href="' . admin_url('post.php?post=' . $order->get_id() . '&action=edit') . '" style="background: #dc2626; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block;">
                                عرض الطلب في لوحة التحكم
                            </a>
                        </div>
                    </div>
                    
                    <div style="text-align: center; margin-top: 20px; color: #9ca3af; font-size: 12px;">
                        <p>تم إرسال هذا الإيميل تلقائياً من نظام شام كاش</p>
                    </div>
                </div>
            </body>
            </html>
            ';
            
            $headers = array(
                'Content-Type: text/html; charset=UTF-8',
                'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>'
            );
            
            wp_mail($to, $subject, $message, $headers);
        }
        
        // إضافة التعليمات إلى البريد الإلكتروني
        public function email_instructions($order, $sent_to_admin, $plain_text = false) {
            if (!$sent_to_admin && $order->get_payment_method() === 'instant_barcode') {
                $account_code = $order->get_meta('_sham_cash_account');
                $amount = $order->get_meta('_sham_cash_amount');
                
                if ($account_code) {
                    if ($plain_text) {
                        echo "\n\n" . "تعليمات الدفع عبر شام كاش" . "\n";
                        echo "========================================" . "\n";
                        echo "رقم الحساب: " . $account_code . "\n";
                        echo "المبلغ: " . wc_price($amount) . "\n";
                        echo "المهلة: " . $this->get_option('time_limit') . " دقيقة\n";
                        echo "\n";
                    } else {
                        echo '<div style="background: #f9fafb; padding: 15px; border-radius: 8px; margin: 15px 0; border: 1px solid #e5e7eb; max-width: 100%; overflow: hidden;">';
                        echo '<h3 style="color: #1f2937; margin-top: 0; margin-bottom: 12px; font-size: 16px;">تعليمات الدفع عبر شام كاش</h3>';
                        
                        echo '<div style="background: white; padding: 12px; border-radius: 6px; margin-bottom: 12px; font-size: 14px;">';
                        echo '<p style="margin: 0 0 8px 0; line-height: 1.5;"><strong>رقم الحساب:</strong><br><code style="background: #f3f4f6; padding: 6px 10px; border-radius: 4px; display: inline-block; margin-top: 4px; font-size: 13px; word-break: break-all;">' . esc_html($account_code) . '</code></p>';
                        echo '<p style="margin: 0 0 8px 0; line-height: 1.5;"><strong>المبلغ:</strong><br><span style="font-weight: bold; color: #dc2626; font-size: 16px;">' . wc_price($amount) . '</span></p>';
                        echo '<p style="margin: 0; line-height: 1.5;"><strong>المهلة:</strong><br>' . $this->get_option('time_limit') . ' دقيقة</p>';
                        echo '</div>';
                        
                        echo '</div>';
                    }
                }
            }
        }
    }
}

// 2. إضافة البوابة إلى قائمة بوابات الدفع
add_filter('woocommerce_payment_gateways', 'add_instant_barcode_gateway');
function add_instant_barcode_gateway($gateways) {
    $gateways[] = 'WC_Gateway_Instant_Barcode';
    return $gateways;
}

// 3. AJAX لمعالجة رفع صورة الإشعار
add_action('wp_ajax_upload_payment_proof', 'handle_payment_proof_upload_ajax');
add_action('wp_ajax_nopriv_upload_payment_proof', 'handle_payment_proof_upload_ajax');
function handle_payment_proof_upload_ajax() {
    if (!isset($_POST['order_id']) || !isset($_POST['nonce'])) return;
    $order_id = intval($_POST['order_id']);
    $nonce = $_POST['nonce'];
    
    if (!wp_verify_nonce($nonce, 'upload_payment_proof_' . $order_id)) {
        wp_send_json_error(array('message' => 'رمز التحقق غير صالح'));
    }
    
    $order = wc_get_order($order_id);
    if (!$order) {
        wp_send_json_error(array('message' => 'الطلب غير موجود'));
    }
    
    require_once(ABSPATH . 'wp-admin/includes/file.php');
    require_once(ABSPATH . 'wp-admin/includes/media.php');
    require_once(ABSPATH . 'wp-admin/includes/image.php');
    
    if (empty($_FILES['payment_proof'])) {
        wp_send_json_error(array('message' => 'لم يتم اختيار ملف'));
    }

    $uploadedfile = $_FILES['payment_proof'];
    $upload_overrides = array('test_form' => false);
    
    $movefile = wp_handle_upload($uploadedfile, $upload_overrides);
    
    if ($movefile && !isset($movefile['error'])) {
        // حفظ رابط الصورة
        $order->update_meta_data('_payment_proof_url', $movefile['url']);
        
        // حفظ رقم التحويل إذا وجد
        if (!empty($_POST['transaction_id'])) {
            $order->update_meta_data('_transaction_id', sanitize_text_field($_POST['transaction_id']));
        }
        
        // تحديث حالة الطلب
        $order->update_status('on-hold', 'تم رفع إشعار التحويل. جاري التحقق...');
        
        // إضافة ملاحظة
        $order->add_order_note('تم رفع إشعار التحويل: ' . $movefile['url']);
        
        $order->save();
        
        // إرسال إيميل للمسؤول
        send_proof_notification_email($order, $movefile['url']);
        
        wp_send_json_success(array(
            'message' => 'تم رفع إشعار التحويل بنجاح. سنقوم بالتحقق منه قريباً.'
        ));
    } else {
        wp_send_json_error(array('message' => 'فشل رفع الصورة: ' . ($movefile['error'] ?? 'خطأ غير معروف')));
    }
}

// إرسال إيميل عند رفع إشعار التحويل
function send_proof_notification_email($order, $proof_url) {
    if (!$order) return;
    $to = get_option('admin_email');
    $subject = 'تم رفع إشعار تحويل - طلب #' . $order->get_id();
    
    $message = '
    <!DOCTYPE html>
    <html dir="rtl">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>إشعار تحويل جديد</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="background: #1f2937; color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center;">
                <h1 style="margin: 0; font-size: 24px;">إشعار تحويل جديد</h1>
            </div>
            
            <div style="background: #f9fafb; padding: 20px; border: 1px solid #e5e7eb; border-top: none; border-radius: 0 0 8px 8px;">
                <div style="background: white; padding: 15px; border-radius: 6px; margin-bottom: 20px; border-right: 4px solid #10b981;">
                    <h2 style="color: #1f2937; margin-top: 0; margin-bottom: 15px; font-size: 18px;">تم رفع إشعار التحويل</h2>
                    <table style="width: 100%; border-collapse: collapse;">
                        <tr>
                            <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>رقم الطلب:</strong></td>
                            <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;">#' . $order->get_id() . '</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>العميل:</strong></td>
                            <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;">' . $order->get_billing_first_name() . ' ' . $order->get_billing_last_name() . '</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0; border-bottom: 1px solid #eee;"><strong>رقم التحويل:</strong></td>
                            <td style="padding: 8px 0; border-bottom: 1px solid #eee; text-align: left;">' . $order->get_meta('_transaction_id') . '</td>
                        </tr>
                        <tr>
                            <td style="padding: 8px 0;"><strong>رابط الصورة:</strong></td>
                            <td style="padding: 8px 0; text-align: left;"><a href="' . $proof_url . '" style="color: #dc2626; word-break: break-all;">عرض الصورة</a></td>
                        </tr>
                    </table>
                </div>
                
                <div style="text-align: center; margin-top: 20px;">
                    <a href="' . $proof_url . '" style="background: #10b981; color: white; padding: 12px 20px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block; margin-bottom: 10px;">عرض إشعار التحويل</a>
                    <a href="' . admin_url('post.php?post=' . $order->get_id() . '&action=edit') . '" style="background: #dc2626; color: white; padding: 12px 20px; text-decoration: none; border-radius: 6px; font-weight: bold; display: inline-block; margin-bottom: 10px;">التحقق من الطلب</a>
                </div>
                
                <div style="margin-top: 20px; background: white; padding: 15px; border-radius: 6px; border-left: 4px solid #f59e0b;">
                    <h3 style="color: #1f2937; margin-top: 0; margin-bottom: 10px; font-size: 16px;">إجراءات سريعة:</h3>
                    <ul style="margin: 0; padding-right: 20px; color: #4b5563; font-size: 14px;">
                        <li style="margin-bottom: 5px;">تحقق من صحة التحويل مع البنك</li>
                        <li style="margin-bottom: 5px;">تأكد من تطابق المبلغ</li>
                        <li>قم بتحديث حالة الطلب بعد التحقق</li>
                    </ul>
                </div>
            </div>
        </div>
    </body>
    </html>
    ';
    
    $headers = array(
        'Content-Type: text/html; charset=UTF-8',
        'From: ' . get_bloginfo('name') . ' <' . get_option('admin_email') . '>'
    );
    
    wp_mail($to, $subject, $message, $headers);
}

// 4. إضافة صفحة إدارة الدفعات
add_action('admin_menu', 'add_sham_cash_payments_menu');
function add_sham_cash_payments_menu() {
    add_submenu_page(
        'dms-store-main',
        'مدفوعات شام كاش',
        'شام كاش',
        'manage_woocommerce',
        'sham-cash-payments',
        'display_sham_cash_payments_page'
    );
}

function display_sham_cash_payments_page() {
    ?>
    <div class="wrap">
        <h1 style="background: #1f2937; color: white; padding: 20px; border-radius: 8px; margin: 0 0 30px 0;">
            إدارة مدفوعات شام كاش
        </h1>
        
        <?php
        // إحصائيات
        $args_all = array(
            'limit'        => -1,
            'status'       => 'any',
            'meta_key'     => '_sham_cash_method',
            'meta_value'   => 'barcode_transfer',
            'meta_compare' => '=',
        );
        
        $args_pending = array(
            'limit'        => -1,
            'status'       => 'pending',
            'meta_key'     => '_sham_cash_method',
            'meta_value'   => 'barcode_transfer',
            'meta_compare' => '=',
        );
        
        $args_onhold = array(
            'limit'        => -1,
            'status'       => 'on-hold',
            'meta_key'     => '_sham_cash_method',
            'meta_value'   => 'barcode_transfer',
            'meta_compare' => '=',
        );
        
        $all_orders = wc_get_orders($args_all);
        $pending_orders = wc_get_orders($args_pending);
        $onhold_orders = wc_get_orders($args_onhold);
        
        $total_amount = 0;
        foreach ($all_orders as $order) {
            $total_amount += $order->get_total();
        }
        ?>
        
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 15px; margin-bottom: 30px;">
            <div style="background: white; padding: 15px; border-radius: 8px; border-top: 4px solid #1f2937; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
                <div style="font-size: 28px; color: #1f2937; font-weight: 700; margin-bottom: 8px;"><?php echo count($all_orders); ?></div>
                <div style="font-size: 14px; color: #6b7280;">إجمالي الطلبات</div>
            </div>
            
            <div style="background: white; padding: 15px; border-radius: 8px; border-top: 4px solid #f59e0b; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
                <div style="font-size: 28px; color: #f59e0b; font-weight: 700; margin-bottom: 8px;"><?php echo count($pending_orders); ?></div>
                <div style="font-size: 14px; color: #6b7280;">بانتظار الدفع</div>
            </div>
            
            <div style="background: white; padding: 15px; border-radius: 8px; border-top: 4px solid #f59e0b; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
                <div style="font-size: 28px; color: #f59e0b; font-weight: 700; margin-bottom: 8px;"><?php echo count($onhold_orders); ?></div>
                <div style="font-size: 14px; color: #6b7280;">بانتظار التحقق</div>
            </div>
            
            <div style="background: white; padding: 15px; border-radius: 8px; border-top: 4px solid #dc2626; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.05);">
                <div style="font-size: 28px; color: #dc2626; font-weight: 700; margin-bottom: 8px;"><?php echo wc_price($total_amount); ?></div>
                <div style="font-size: 14px; color: #6b7280;">إجمالي المبالغ</div>
            </div>
        </div>
        
        <div style="background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); margin-bottom: 30px;">
            <h2 style="margin: 0 0 20px 0; color: #1f2937;">طلبات شام كاش</h2>
            
            <?php if ($all_orders): ?>
            <div style="overflow-x: auto;">
                <table class="wp-list-table widefat fixed striped" style="width: 100%; min-width: 800px;">
                    <thead>
                        <tr style="background: #f9fafb;">
                            <th style="padding: 12px 8px; font-size: 14px;">رقم الطلب</th>
                            <th style="padding: 12px 8px; font-size: 14px;">العميل</th>
                            <th style="padding: 12px 8px; font-size: 14px;">المبلغ</th>
                            <th style="padding: 12px 8px; font-size: 14px;">رقم التحويل</th>
                            <th style="padding: 12px 8px; font-size: 14px;">إشعار الدفع</th>
                            <th style="padding: 12px 8px; font-size: 14px;">الحالة</th>
                            <th style="padding: 12px 8px; font-size: 14px;">التاريخ</th>
                            <th style="padding: 12px 8px; font-size: 14px;">الإجراءات</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($all_orders as $order): 
                            $transaction_id = $order->get_meta('_transaction_id');
                            $proof_url = $order->get_meta('_payment_proof_url');
                            $status = $order->get_status();
                            
                            $status_badge = array(
                                'pending' => '<span style="background: #f59e0b; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">بانتظار الدفع</span>',
                                'on-hold' => '<span style="background: #f59e0b; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">بانتظار التحقق</span>',
                                'processing' => '<span style="background: #10b981; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">تم الدفع</span>',
                                'completed' => '<span style="background: #059669; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">مكتمل</span>',
                                'cancelled' => '<span style="background: #6b7280; color: white; padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600;">ملغي</span>'
                            );
                        ?>
                        <tr>
                            <td style="padding: 10px 8px;"><strong>#<?php echo $order->get_id(); ?></strong></td>
                            <td style="padding: 10px 8px; font-size: 13px;"><?php echo $order->get_billing_first_name() . ' ' . $order->get_billing_last_name(); ?></td>
                            <td style="padding: 10px 8px;"><strong style="font-size: 14px;"><?php echo $order->get_formatted_order_total(); ?></strong></td>
                            <td style="padding: 10px 8px; font-size: 13px;">
                                <?php echo $transaction_id ?: '<span style="color: #9ca3af; font-size: 12px;">لم يتم إدخاله</span>'; ?>
                            </td>
                            <td style="padding: 10px 8px;">
                                <?php if ($proof_url): ?>
                                    <a href="<?php echo $proof_url; ?>" target="_blank" style="color: #dc2626; text-decoration: none; font-size: 13px;">عرض الإشعار</a>
                                <?php else: ?>
                                    <span style="color: #9ca3af; font-size: 12px;">لم يتم الرفع</span>
                                <?php endif; ?>
                            </td>
                            <td style="padding: 10px 8px;"><?php echo $status_badge[$status] ?? $status; ?></td>
                            <td style="padding: 10px 8px; font-size: 13px;"><?php echo $order->get_date_created()->date('Y-m-d H:i'); ?></td>
                            <td style="padding: 10px 8px;">
                                <a href="<?php echo get_edit_post_link($order->get_id()); ?>" class="button button-small" style="font-size: 12px; padding: 5px 10px;">
                                    عرض التفاصيل
                                </a>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <?php else: ?>
            <div style="text-align: center; padding: 30px; color: #9ca3af;">
                <div style="font-size: 40px; margin-bottom: 15px;">📭</div>
                <h3 style="color: #6b7280; margin-bottom: 10px;">لا توجد طلبات شام كاش</h3>
                <p style="font-size: 14px;">لم يتم إنشاء أي طلبات دفع عبر شام كاش حتى الآن.</p>
            </div>
            <?php endif; ?>
        </div>
        
        <div style="background: white; padding: 20px; border-radius: 8px; margin-bottom: 30px; border: 2px solid #dc2626;">
            <h3 style="margin: 0 0 15px 0; color: #1f2937; font-size: 18px;">معلومات حساب شام كاش</h3>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px;">
                <div>
                    <h4 style="margin: 0 0 12px 0; color: #1f2937; font-size: 16px;">لبكو المحدودة المسؤولية</h4>
                    <p style="margin: 0 0 8px 0; color: #6b7280; font-size: 14px;">رقم الحساب:</p>
                    <div style="background: #f9fafb; padding: 12px; border-radius: 6px; border: 1px solid #e5e7eb; font-family: monospace; font-size: 14px; color: #1f2937; word-break: break-all;">
                        2f3b91dd0befb9f619ef06697e7a1dc8
                    </div>
                </div>
                <div>
                    <h4 style="margin: 0 0 12px 0; color: #1f2937; font-size: 16px;">إحصائيات</h4>
                    <div style="background: #f9fafb; padding: 12px; border-radius: 6px; border: 1px solid #e5e7eb;">
                        <p style="margin: 0 0 8px 0; color: #4b5563; font-size: 14px;">
                            <strong>إجمالي الطلبات:</strong> <?php echo count($all_orders); ?>
                        </p>
                        <p style="margin: 0 0 8px 0; color: #4b5563; font-size: 14px;">
                            <strong>المبلغ الإجمالي:</strong> <?php echo wc_price($total_amount); ?>
                        </p>
                        <p style="margin: 0; color: #4b5563; font-size: 14px;">
                            <strong>الإيميل المسؤول:</strong> <?php echo get_option('admin_email'); ?>
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <?php
}

// 5. ويدجت للإحصائيات في لوحة التحكم
add_action('wp_dashboard_setup', 'add_sham_cash_dashboard_widget');
function add_sham_cash_dashboard_widget() {
    wp_add_dashboard_widget(
        'sham_cash_stats',
        'إحصائيات شام كاش',
        'display_sham_cash_stats'
    );
}

function display_sham_cash_stats() {
    $args = array(
        'limit'        => -1,
        'status'       => array('pending', 'on-hold'),
        'meta_key'     => '_sham_cash_method',
        'meta_value'   => 'barcode_transfer',
        'meta_compare' => '=',
    );
    
    $pending_orders = wc_get_orders($args);
    
    ?>
    <div style="padding: 10px;">
        <div style="text-align: center; background: #1f2937; color: white; padding: 12px; border-radius: 6px; margin-bottom: 15px;">
            <div style="font-size: 20px; font-weight: 700;"><?php echo count($pending_orders); ?></div>
            <div style="font-size: 11px; opacity: 0.8;">طلبات تحتاج متابعة</div>
        </div>
        
        <?php if ($pending_orders): ?>
        <div style="margin-bottom: 15px;">
            <h4 style="margin: 0 0 10px 0; font-size: 13px; color: #1f2937;">الطلبات الأخيرة:</h4>
            <div style="max-height: 180px; overflow-y: auto;">
                <?php foreach (array_slice($pending_orders, 0, 5) as $order): ?>
                <div style="background: #f9fafb; padding: 8px; margin-bottom: 8px; border-radius: 6px; border-left: 3px solid #f59e0b;">
                    <div style="display: flex; justify-content: space-between; margin-bottom: 5px;">
                        <strong style="color: #1f2937; font-size: 12px;">#<?php echo $order->get_id(); ?></strong>
                        <span style="color: #dc2626; font-weight: 600; font-size: 12px;"><?php echo $order->get_formatted_order_total(); ?></span>
                    </div>
                    <div style="font-size: 11px; color: #6b7280;">
                        <?php echo $order->get_billing_first_name() . ' ' . $order->get_billing_last_name(); ?>
                    </div>
                    <a href="<?php echo get_edit_post_link($order->get_id()); ?>" style="font-size: 10px; color: #dc2626; text-decoration: none; display: block; margin-top: 5px;">
                        عرض الطلب →
                    </a>
                </div>
                <?php endforeach; ?>
            </div>
        </div>
        <?php endif; ?>
        
        <div style="text-align: center; margin-top: 15px;">
            <a href="<?php echo admin_url('admin.php?page=sham-cash-payments'); ?>" class="button button-primary" style="width: 100%; text-align: center; background: #dc2626; border-color: #dc2626; font-size: 12px; padding: 8px;">
                عرض جميع طلبات شام كاش
            </a>
        </div>
        
        <div style="margin-top: 15px; font-size: 10px; color: #6b7280; text-align: center; padding-top: 10px; border-top: 1px solid #e5e7eb;">
            <p style="margin: 0; word-break: break-all;">الحساب: 2f3b91dd0befb9f619ef06697e7a1dc8</p>
        </div>
    </div>
    <?php
}

// 6. إضافة CSS
add_action('wp_head', 'add_instant_barcode_styles');
function add_instant_barcode_styles() {
    if (is_checkout() || is_order_received_page()) {
        ?>
        <style>
            .wc_payment_method.payment_method_instant_barcode {
                background: white;
                border: 2px solid #dc2626;
                border-radius: 10px;
                padding: 15px;
                margin: 15px 0;
                max-width: 100%;
                overflow: hidden;
            }
            
            .wc_payment_method.payment_method_instant_barcode label {
                font-weight: 700;
                color: #1f2937;
                font-size: 16px;
                display: flex;
                align-items: center;
                flex-wrap: wrap;
            }
            
            .wc_payment_method.payment_method_instant_barcode input[type="radio"] {
                margin-left: 10px;
            }
            
            @media (max-width: 768px) {
                .instant-payment-container,
                .wc_payment_method.payment_method_instant_barcode {
                    padding: 12px !important;
                    margin: 10px 0 !important;
                }
            }
        </style>
        <?php
    }
}
