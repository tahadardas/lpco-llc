<?php
// إضافة صفحة إدارة الأعضاء إلى قائمة لوحة التحكم
add_action('admin_menu', function() {
    add_menu_page('إدارة الأعضاء', 'إدارة الأعضاء', 'manage_options', 'dms_members', 'dms_render_members_page');
});

// دالة لعرض صفحة إدارة الأعضاء
function dms_render_members_page() {
    // جلب تصنيفات الأسعار والعملات وحالات الحساب
    $all_cats = get_option('dms_price_categories', []);
    $currencies = ['syp' => 'ل.س', 'usd' => '$'];
    $account_statuses = ['جديد', 'مؤكد'];
    $overall_statuses = ['الكل', 'البيانات غير مكتملة']; // حالة شاملة جديدة للفلترة

    // استقبل قيم البحث والفلترة من GET
    $search = isset($_GET['search']) ? sanitize_text_field($_GET['search']) : '';
    $filter_group = isset($_GET['filter_group']) ? sanitize_text_field($_GET['filter_group']) : '';
    $filter_currency = isset($_GET['filter_currency']) ? sanitize_text_field($_GET['filter_currency']) : '';
    $filter_status = isset($_GET['filter_status']) ? sanitize_text_field($_GET['filter_status']) : '';
    $filter_overall_status = isset($_GET['filter_overall_status']) ? sanitize_text_field($_GET['filter_overall_status']) : ''; // فلتر الحالة الشاملة

    // إعدادات عرض المستخدمين
    $per_page = 10; // عدد المستخدمين المعروضين لكل طلب AJAX

    echo '<div class="wrap"><h2>إدارة الأعضاء</h2>';
    echo '<form method="post" action="' . admin_url('admin-post.php') . '">
        <input type="hidden" name="action" value="dms_fix_missing_members">
        ' . wp_nonce_field('dms_fix_missing_members_nonce', '_wpnonce', true, false) . '
        <p><button type="submit" class="button button-secondary">مزامنة الأعضاء</button></p>
    </form>';

    // نموذج البحث والفلترة
    echo '<form method="get">';
    echo '<input type="hidden" name="page" value="dms_members" />';
    echo '<p>
        <label for="search">بحث: </label>
        <input type="search" id="search" name="search" value="' . esc_attr($search) . '" placeholder="ابحث بالاسم، البريد، الاسم التجاري، الواتساب...">
        &nbsp;&nbsp;
        <label for="filter_group">فلتر حسب التصنيف: </label>
        <select id="filter_group" name="filter_group">
            <option value="">الكل</option>';
            foreach ($all_cats as $cat) {
                printf('<option value="%s" %s>%s</option>',
                    esc_attr($cat),
                    selected($filter_group, $cat, false),
                    esc_html($cat)
                );
            }
    echo '</select>
        &nbsp;&nbsp;
        <label for="filter_currency">فلتر حسب العملة: </label>
        <select id="filter_currency" name="filter_currency">
            <option value="">الكل</option>';
            foreach ($currencies as $code => $label) {
                printf('<option value="%s" %s>%s</option>',
                    esc_attr($code),
                    selected($filter_currency, $code, false),
                    esc_html($label)
                );
            }
    echo '</select>
        &nbsp;&nbsp;
        <label for="filter_status">فلتر حسب الحالة: </label>
        <select id="filter_status" name="filter_status">
            <option value="">الكل</option>';
            foreach ($account_statuses as $status) {
                printf('<option value="%s" %s>%s</option>',
                    esc_attr($status),
                    selected($filter_status, $status, false),
                    esc_html($status)
                );
            }
    echo '</select>
        &nbsp;&nbsp;
        <label for="filter_overall_status">الحالة الشاملة: </label>
        <select id="filter_overall_status" name="filter_overall_status">
            <option value="">الكل</option>
            <option value="incomplete_data" ' . selected($filter_overall_status, 'incomplete_data', false) . '>البيانات غير مكتملة</option>
        </select>
        &nbsp;&nbsp;
        <button type="submit" class="button">تصفية</button>
    </p>';
    echo '</form>';

    // زر تصنيف الأعضاء تلقائياً
    echo '<form method="post" action="' . admin_url('admin-post.php') . '">
        <input type="hidden" name="action" value="dms_classify_members">
        ' . wp_nonce_field('dms_classify_members_nonce', '_wpnonce', true, false) . '
        <p><button type="submit" class="button button-secondary">تصنيف الأعضاء تلقائياً</button></p>
    </form>';

    // زر تصدير بيانات الأعضاء إلى CSV
    echo '<form method="post" action="' . admin_url('admin-post.php') . '">
        <input type="hidden" name="action" value="dms_export_members">
        ' . wp_nonce_field('dms_export_members_nonce', '_wpnonce', true, false) . '
        <p><button type="submit" class="button button-primary">📊 تصدير الأعضاء إلى CSV</button></p>
    </form>';


    // جدول الأعضاء
    // تم إضافة حقل المحافظة في الرأس
    echo '<form method="post" id="dms-members-form" action="' . admin_url('admin-post.php') . '">'; // تحديث هنا: تحديد الأكشن لنموذج الحفظ
    echo '<input type="hidden" name="action" value="dms_save_member_details" />'; // إضافة حقل مخفي لتحديد الأكشن
    echo wp_nonce_field('dms_save_member_details_nonce', '_wpnonce', true, false); // إضافة النونص للحفظ
    echo '<table class="widefat" style="direction: rtl;" id="dms-members-table">
        <thead><tr>
            <th>الاسم</th>
            <th>البريد</th>
            <th>الاسم التجاري</th>
            <th>رقم الواتساب</th>
            <th>المحافظة</th> <th>التصنيف</th>
            <th>العملة</th>
            <th>الحالة</th>
            <th>تحكم</th>
        </tr></thead><tbody id="the-list">'; // تم تغيير id لـ the-list ليناسب AJAX
    
    // سيتم تحميل المستخدمين الأوائل بواسطة AJAX أو مباشرة إذا لم يكن هناك AJAX
    // For initial load, we call the AJAX function directly for consistency.
    // In a real scenario, you might want to render first N items directly on page load.
    // Here, we ensure the JS handles initial load as well by immediately triggering.
    echo '</tbody></table></form>';

    // زر "تحميل المزيد"
    echo '<div class="tablenav"><div class="tablenav-pages" style="margin-top:10px;">';
    echo '<button id="dms-load-more-members" class="button button-secondary">تحميل المزيد من الأعضاء</button>';
    echo '<span id="dms-loading-spinner" style="display:none;">جاري التحميل...</span>';
    echo '</div></div>';

    ?>
    <script type="text/javascript">
    jQuery(document).ready(function($) {
        let currentPage = 0; // تبدأ من 0 لتحميل الصفحة الأولى (صفحة 1)
        const perPage = <?php echo $per_page; ?>;
        const loadMoreButton = $('#dms-load-more-members');
        const loadingSpinner = $('#dms-loading-spinner');
        const membersTableBody = $('#the-list'); // tbody id

        // دالة لجلب المستخدمين عبر AJAX
        function loadMembers(append = true) {
            loadingSpinner.show();
            loadMoreButton.prop('disabled', true); // تعطيل الزر أثناء التحميل

            const search = $('input[name="search"]').val();
            const filter_group = $('select[name="filter_group"]').val();
            const filter_currency = $('select[name="filter_currency"]').val();
            const filter_status = $('select[name="filter_status"]').val();
            const filter_overall_status = $('select[name="filter_overall_status"]').val(); // جلب قيمة الفلتر الجديد

            $.ajax({
                url: ajaxurl, // متغير WordPress AJAX العام
                type: 'POST',
                data: {
                    action: 'dms_load_more_members',
                    paged: currentPage + 1, // طلب الصفحة التالية
                    per_page: perPage,
                    search: search,
                    filter_group: filter_group,
                    filter_currency: filter_currency,
                    filter_status: filter_status,
                    filter_overall_status: filter_overall_status, // تمرير الفلتر الجديد
                    _wpnonce: '<?php echo wp_create_nonce("dms_load_more_members_nonce"); ?>'
                },
                success: function(response) {
                    loadingSpinner.hide();
                    loadMoreButton.prop('disabled', false); // تفعيل الزر

                    if (response.success) {
                        if (append) {
                            membersTableBody.append(response.data.html);
                        } else {
                            membersTableBody.html(response.data.html); // استبدال المحتوى في حالة الفلترة/البحث
                        }
                        
                        if (!response.data.has_more) {
                            loadMoreButton.hide(); // إخفاء الزر إذا لم يكن هناك المزيد من الصفحات
                        } else {
                            loadMoreButton.show();
                        }
                        currentPage++; // زيادة رقم الصفحة فقط عند النجاح والإضافة

                        // إعادة ربط أحداث الأزرار بعد إضافة عناصر جديدة
                        rebindEditSaveCancelButtons();
                        rebindDeleteButtons(); // أعد ربط أزرار الحذف
                    } else {
                        console.error('AJAX Error:', response.data);
                        // عرض رسالة خطأ للمستخدم
                        // alert('حدث خطأ أثناء تحميل الأعضاء. الرجاء المحاولة مرة أخرى.');
                    }
                },
                error: function(xhr, status, error) {
                    loadingSpinner.hide();
                    loadMoreButton.prop('disabled', false);
                    console.error('AJAX request failed:', status, error, xhr.responseText);
                    // alert('حدث خطأ في الاتصال بالخادم. الرجاء المحاولة مرة أخرى.');
                }
            });
        }

        // دالة لإعادة ربط الأحداث بأزرار التعديل والحفظ والإلغاء
        function rebindEditSaveCancelButtons() {
            const editButtons = document.querySelectorAll('.edit-btn');
            const saveButtons = document.querySelectorAll('.save-btn');
            const cancelButtons = document.querySelectorAll('.cancel-btn');

            editButtons.forEach(btn => {
                btn.onclick = function() {
                    const userId = this.dataset.userid;
                    document.getElementById('row_' + userId).style.display = 'none';
                    document.getElementById('edit_row_' + userId).style.display = 'table-row';
                };
            });

            cancelButtons.forEach(btn => {
                btn.onclick = function() {
                    const userId = this.dataset.userid;
                    document.getElementById('edit_row_' + userId).style.display = 'none';
                    document.getElementById('row_' + userId).style.display = 'table-row';
                };
            });

            saveButtons.forEach(btn => {
                btn.onclick = function() {
                    document.getElementById('dms-members-form').submit();
                };
            });
        }

        // دالة جديدة لإعادة ربط أحداث أزرار الحذف
        function rebindDeleteButtons() {
            const deleteButtons = document.querySelectorAll('.delete-btn');

            deleteButtons.forEach(btn => {
                btn.onclick = function() {
                    const userId = this.dataset.userid;
                    const confirmationState = this.dataset.confirm === 'true';

                    if (confirmationState) {
                        // تأكيد ثانٍ، أرسل طلب الحذف
                        loadingSpinner.show();
                        $(this).prop('disabled', true); // تعطيل زر الحذف

                        $.ajax({
                            url: ajaxurl,
                            type: 'POST',
                            data: {
                                action: 'dms_delete_member',
                                user_id: userId,
                                _wpnonce: '<?php echo wp_create_nonce("dms_delete_member_nonce"); ?>'
                            },
                            success: function(response) {
                                loadingSpinner.hide();
                                if (response.success) {
                                    $('#row_' + userId).remove(); // إزالة الصف من الجدول
                                    $('#edit_row_' + userId).remove(); // إزالة صف التعديل أيضاً
                                } else {
                                    console.error('AJAX Delete Error:', response.data);
                                    // إعادة تفعيل الزر وعرض رسالة خطأ
                                    $(btn).prop('disabled', false);
                                    $(btn).text('❌ حذف');
                                    $(btn).data('confirm', 'false');
                                    alert('حدث خطأ أثناء حذف العضو: ' + response.data); // استخدام alert هنا لتبسيط عرض الخطأ
                                }
                            },
                            error: function(xhr, status, error) {
                                loadingSpinner.hide();
                                $(btn).prop('disabled', false);
                                console.error('AJAX Delete request failed:', status, error, xhr.responseText);
                                $(btn).text('❌ حذف');
                                $(btn).data('confirm', 'false');
                                alert('فشل طلب الحذف: ' + error); // استخدام alert هنا لتبسيط عرض الخطأ
                            }
                        });

                    } else {
                        // تأكيد أول، اطلب من المستخدم التأكيد مرة أخرى
                        $(this).text('هل أنت متأكد؟');
                        $(this).data('confirm', 'true');

                        // إعادة الزر لحالته الأصلية بعد فترة وجيزة إذا لم يتم النقر مرة أخرى
                        setTimeout(() => {
                            if ($(this).data('confirm') === 'true') {
                                $(this).text('❌ حذف');
                                $(this).data('confirm', 'false');
                            }
                        }, 3000); // 3 ثوانٍ
                    }
                };
            });
        }

        // تحميل الأعضاء عند تحميل الصفحة لأول مرة
        loadMembers(false);

        // ربط حدث النقر بزر "تحميل المزيد"
        loadMoreButton.on('click', function() {
            loadMembers(true);
        });

        // عند تغيير أي من فلاتر البحث/التصفية، أعد تحميل القائمة من البداية
        $('form[method="get"]').on('submit', function(e) {
            e.preventDefault();
            currentPage = 0;
            loadMoreButton.show();
            loadMembers(false);
        });
    });
    </script>
    <?php
}

// معالج AJAX لجلب المزيد من الأعضاء
add_action('wp_ajax_dms_load_more_members', 'dms_load_more_members_callback');
function dms_load_more_members_callback() {
    // التحقق من صلاحيات المستخدم و nonce
    check_ajax_referer('dms_load_more_members_nonce', '_wpnonce');
    if (!current_user_can('manage_options')) {
        wp_send_json_error('ليس لديك صلاحية للقيام بهذا الإجراء.');
    }

    $paged = isset($_POST['paged']) ? max(1, intval($_POST['paged'])) : 1;
    $per_page = isset($_POST['per_page']) ? intval($_POST['per_page']) : 10;
    $search = isset($_POST['search']) ? sanitize_text_field($_POST['search']) : '';
    $filter_group = isset($_POST['filter_group']) ? sanitize_text_field($_POST['filter_group']) : '';
    $filter_currency = isset($_POST['filter_currency']) ? sanitize_text_field($_POST['filter_currency']) : '';
    $filter_status = isset($_POST['filter_status']) ? sanitize_text_field($_POST['filter_status']) : '';
    $filter_overall_status = isset($_POST['filter_overall_status']) ? sanitize_text_field($_POST['filter_overall_status']) : '';

    $meta_query = [];

    if ($filter_group) {
        $meta_query[] = [
            'key' => 'dms_user_group',
            'value' => $filter_group,
            'compare' => '=',
        ];
    }
    if ($filter_currency) {
        $meta_query[] = [
            'key' => 'dms_user_currency',
            'value' => $filter_currency,
            'compare' => '=',
        ];
    }
    if ($filter_status) {
        $meta_query[] = [
            'key' => 'dms_account_status',
            'value' => $filter_status,
            'compare' => '=',
        ];
    }

    $args = [
        'role' => 'customer',
        'number' => -1, // جلب جميع المستخدمين أولاً للفلترة الدقيقة
        'offset' => 0,
        'meta_query' => $meta_query ? $meta_query : '',
    ];

    $html = '';
    
    $all_users = get_users($args);
    $filtered_users = [];

    // المفاتيح التي يجب التحقق من اكتمالها: إذا كان أي منها فارغًا أو كانت الحالة "جديد"
    // تم إضافة 'account_governorate' هنا
    $all_completeness_keys = [
        'account_company_name',
        'account_whatsapp_country_code',
        'account_whatsapp',
        'account_governorate', // مفتاح المحافظة الجديد
        'dms_user_group',
        'dms_user_currency',
        'dms_account_status' // تضمين الحالة في التحقق الشامل
    ];

    foreach($all_users as $user) {
        $matches_search = true;
        if ($search) {
            $search_lower = mb_strtolower($search);
            $name = mb_strtolower($user->display_name);
            $email = mb_strtolower($user->user_email);
            $company = mb_strtolower(get_user_meta($user->ID, 'account_company_name', true));
            $whatsapp_num = mb_strtolower(get_user_meta($user->ID, 'account_whatsapp', true));
            $whatsapp_code = mb_strtolower(get_user_meta($user->ID, 'account_whatsapp_country_code', true));
            $governorate = mb_strtolower(get_user_meta($user->ID, 'account_governorate', true)); // جلب المحافظة للبحث

            $text_match = (strpos($name, $search_lower) !== false) ||
                          (strpos($email, $search_lower) !== false) ||
                          (strpos($company, $search_lower) !== false) ||
                          (strpos($whatsapp_num, $search_lower) !== false) ||
                          (strpos($whatsapp_code, $search_lower) !== false) ||
                          (strpos($governorate, $search_lower) !== false); // إضافة المحافظة للبحث
            
            if (!$text_match) {
                $matches_search = false;
            }
        }

        $is_incomplete = false;
        if ($filter_overall_status === 'incomplete_data') {
            // تحقق من الاسم التجاري ورقم الواتساب فقط لهذا الفلتر
            $user_company_name = get_user_meta($user->ID, 'account_company_name', true);
            $user_whatsapp = get_user_meta($user->ID, 'account_whatsapp', true);
            
            // يعتبر المستخدم غير مكتمل البيانات إذا كان الاسم التجاري أو رقم الواتساب فارغًا
            if (empty($user_company_name) || empty($user_whatsapp)) {
                $is_incomplete = true;
            }
            // ملاحظة: هذا الفلتر يركز فقط على الاسم التجاري ورقم الواتساب كما طلب المستخدم.
            // إذا كان المستخدم "جديد" بسبب نقص بيانات أخرى (مثل المحافظة فقط) ولم يكن الاسم التجاري أو الواتساب فارغين، فلن يظهر هنا.
        }

        // تحديد ما إذا كان يجب إضافة المستخدم إلى القائمة المفلترة
        $should_add_user = false;
        if ($filter_overall_status === 'incomplete_data') {
            if ($is_incomplete) {
                $should_add_user = true;
            }
        } else {
            // إذا لم يكن فلتر الحالة الشاملة هو "البيانات غير مكتملة" (أي "الكل" أو فلتر حالة محدد)، أضف المستخدم إذا كان يطابق البحث والفلاتر الأخرى
            $should_add_user = true;
        }

        if ($matches_search && $should_add_user) {
            $filtered_users[] = $user;
        }
    }

    $total_users = count($filtered_users);
    $paged_users = array_slice($filtered_users, ($paged - 1) * $per_page, $per_page);

    // جلب تصنيفات الأسعار والعملات وحالات الحساب داخل دالة AJAX
    $all_cats = get_option('dms_price_categories', []);
    $currencies = ['syp' => 'ل.س', 'usd' => '$'];
    $account_statuses = ['جديد', 'مؤكد'];

    // جلب المحافظات السورية
    // التأكد من أن دالة dms_get_syrian_governorates() متاحة
    if (!function_exists('dms_get_syrian_governorates')) {
        // يمكنك تضمين الملف هنا إذا لم يكن مضمناً بالفعل عبر dms-ecom.php
        // require_once DMS_ECOM_PATH . 'includes/registration-fields.php'; // تأكد من المسار الصحيح
        // كحل مؤقت إذا لم تكن الدالة موجودة، يمكنك تعريفها هنا أو التأكد من تضمين ملفها.
        // في هذا السيناريو، سأفترض أنها موجودة أو ستضيفها.
        // مثال بسيط:
        function dms_get_syrian_governorates() {
            return [
                'دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس', 'دير الزور',
                'الرقة', 'الحسكة', 'درعا', 'السويداء', 'القنيطرة', 'إدلب'
            ];
        }
    }
    $governorates = dms_get_syrian_governorates();


    foreach ($paged_users as $user) {
        $company_name = get_user_meta($user->ID, 'account_company_name', true);
        $whatsapp = get_user_meta($user->ID, 'account_whatsapp', true);
        $whatsapp_country_code = get_user_meta($user->ID, 'account_whatsapp_country_code', true);
        $user_governorate = get_user_meta($user->ID, 'account_governorate', true); // جلب قيمة المحافظة
        $group = get_user_meta($user->ID, 'dms_user_group', true);
        $currency = get_user_meta($user->ID, 'dms_user_currency', true);
        $status = get_user_meta($user->ID, 'dms_account_status', true);

        ob_start(); // ابدأ تخزين الإخراج في المخزن المؤقت
        ?>
        <tr id='row_<?php echo esc_attr($user->ID); ?>'>
            <td class='view-mode'><?php echo esc_html($user->display_name); ?></td>
            <td class='view-mode'><?php echo esc_html($user->user_email); ?></td>
            <td class='view-mode'><?php echo esc_html($company_name); ?></td>
            <td class='view-mode'><?php echo esc_html($whatsapp_country_code . ' ' . $whatsapp); ?></td>
            <td class='view-mode'><?php echo esc_html($user_governorate); ?></td> <td class='view-mode'><?php echo esc_html($group); ?></td>
            <td class='view-mode'><?php echo esc_html($currency); ?></td>
            <td class='view-mode'><?php echo esc_html($status); ?></td>
            <td class='view-mode'>
                <button type='button' class='button edit-btn' data-userid='<?php echo esc_attr($user->ID); ?>'>✏️ تعديل</button>
                <button type='button' class='button delete-btn' data-userid='<?php echo esc_attr($user->ID); ?>' data-confirm="false">❌ حذف</button>
            </td>
        </tr>
        <tr id='edit_row_<?php echo esc_attr($user->ID); ?>' style='display:none;'>
            <td><input type='text' name='display_name_<?php echo esc_attr($user->ID); ?>' value='<?php echo esc_attr($user->display_name); ?>' disabled style='width:120px;' /></td>
            <td><input type='email' value='<?php echo esc_attr($user->user_email); ?>' disabled style='width:180px;' /></td>
            <td><input type='text' name='company_name_<?php echo esc_attr($user->ID); ?>' value='<?php echo esc_attr($company_name); ?>' style='width:120px;' /></td>
            <td>
                <input type='text' name='whatsapp_country_code_<?php echo esc_attr($user->ID); ?>' value='<?php echo esc_attr($whatsapp_country_code); ?>' style='width:60px; display:inline-block;' placeholder='+XXX' />
                <input type='text' name='whatsapp_<?php echo esc_attr($user->ID); ?>' value='<?php echo esc_attr($whatsapp); ?>' style='width:120px; display:inline-block;' />
            </td>
            <td>
                <select name='governorate_<?php echo esc_attr($user->ID); ?>' style='width:120px;'> <option value="">-- اختر محافظته --</option>
                    <?php
                    foreach ($governorates as $gov) {
                        echo '<option value="' . esc_attr($gov) . '"' . selected($user_governorate, $gov, false) . '>' . esc_html($gov) . '</option>';
                    }
                    ?>
                </select>
            </td>
            <td>
                <select name='group_<?php echo esc_attr($user->ID); ?>'>
                <?php foreach ($all_cats as $cat) : // استخدم المتغير الجديد هنا ?>
                    <option value='<?php echo esc_attr($cat); ?>' <?php selected($group, $cat); ?>><?php echo esc_html($cat); ?></option>
                <?php endforeach; ?>
                </select>
            </td>
            <td>
                <select name='currency_<?php echo esc_attr($user->ID); ?>'>
                <?php foreach ($currencies as $code => $label) : // استخدم المتغير الجديد هنا ?>
                    <option value='<?php echo esc_attr($code); ?>' <?php selected($currency, $code); ?>><?php echo esc_html($label); ?></option>
                <?php endforeach; ?>
                </select>
            </td>
            <td>
                <select name='status_<?php echo esc_attr($user->ID); ?>'>
                <?php foreach ($account_statuses as $s) : ?>
                    <option value='<?php echo esc_attr($s); ?>' <?php selected($status, $s); ?>><?php echo esc_html($s); ?></option>
                <?php endforeach; ?>
                </select>
            </td>
            <td>
                <button type='button' class='button save-btn' data-userid='<?php echo esc_attr($user->ID); ?>'>💾 حفظ</button>
                <button type='button' class='button cancel-btn' data-userid='<?php echo esc_attr($user->ID); ?>'>❌ إلغاء</button>
            </td>
        </tr>
        <?php
        $html .= ob_get_clean(); // الحصول على المحتوى المخزن وإفراغ المخزن
    }

    // تحديد ما إذا كان هناك المزيد من المستخدمين
    $has_more = ($paged * $per_page) < $total_users;

    // إرسال الاستجابة كـ JSON
    wp_send_json_success([
        'html' => $html,
        'has_more' => $has_more,
        'total_users' => $total_users,
        'current_page' => $paged
    ]);
}

// معالج زر تصنيف الأعضاء
add_action('admin_post_dms_classify_members', 'dms_handle_classify_members');
function dms_handle_classify_members() {
    // التحقق من صلاحيات المستخدم
    if (!current_user_can('manage_options')) {
        wp_die('ليس لديك صلاحية للقيام بهذا الإجراء.');
    }

    // التحقق من nonce
    check_admin_referer('dms_classify_members_nonce');

    // جلب جميع العملاء
    $customers = get_users(['role' => 'customer']);

    foreach ($customers as $customer) {
        $company_name = get_user_meta($customer->ID, 'account_company_name', true);
        $whatsapp = get_user_meta($customer->ID, 'account_whatsapp', true);
        $governorate = get_user_meta($customer->ID, 'account_governorate', true); // جلب المحافظة

        // أضف التحقق من المحافظة لاكتمال البيانات
        if (!empty($company_name) && !empty($whatsapp) && !empty($governorate)) {
            // إذا كان لديه اسم تجاري ورقم واتساب ومحافظة، صنفه "مؤكد"
            update_user_meta($customer->ID, 'dms_account_status', 'مؤكد');
        } else {
            // بخلاف ذلك، صنفه "جديد"
            update_user_meta($customer->ID, 'dms_account_status', 'جديد');
        }
    }

    // إعادة التوجيه مع رسالة نجاح
    wp_redirect(add_query_arg('classified', 'true', admin_url('admin.php?page=dms_members')));
    exit;
}

// معالج زر تصدير الأعضاء إلى CSV
add_action('admin_post_dms_export_members', 'dms_handle_export_members');
function dms_handle_export_members() {
    // التحقق من صلاحيات المستخدم
    if (!current_user_can('manage_options')) {
        wp_die('ليس لديك صلاحية للقيام بهذا الإجراء.');
    }

    // التحقق من nonce
    check_admin_referer('dms_export_members_nonce');

    $filename = 'members-export-' . date('Y-m-d') . '.csv';

    header('Content-Type: text/csv; charset=UTF-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('Pragma: no-cache');
    header('Expires: 0');

    $output = fopen('php://output', 'w');

    // إضافة UTF-8 BOM لضمان عرض الحروف العربية بشكل صحيح في Excel
    fprintf($output, chr(0xEF) . chr(0xBB) . chr(0xBF));

    // إضافة رأس الأعمدة - تم إضافة 'المحافظة'
    fputcsv($output, [
        'اسم المستخدم',
        'البريد الإلكتروني',
        'الاسم التجاري',
        'رمز الواتساب',
        'رقم الواتساب',
        'المحافظة', // تم إضافة المحافظة هنا
        'التصنيف',
        'العملة',
        'الحالة'
    ]);

    // جلب جميع العملاء (بدون تحديد صفحات)
    $customers = get_users(['role' => 'customer', 'number' => -1]); // جلب كل العملاء

    foreach ($customers as $customer) {
        $company_name = get_user_meta($customer->ID, 'account_company_name', true);
        $whatsapp_country_code = get_user_meta($customer->ID, 'account_whatsapp_country_code', true);
        $whatsapp = get_user_meta($customer->ID, 'account_whatsapp', true);
        $governorate = get_user_meta($customer->ID, 'account_governorate', true); // جلب المحافظة
        $group = get_user_meta($customer->ID, 'dms_user_group', true);
        $currency = get_user_meta($customer->ID, 'dms_user_currency', true);
        $status = get_user_meta($customer->ID, 'dms_account_status', true);

        fputcsv($output, [
            $customer->display_name,
            $customer->user_email,
            $company_name,
            $whatsapp_country_code,
            $whatsapp,
            $governorate, // تم تمرير المحافظة هنا
            $group,
            $currency,
            $status
        ]);
    }

    fclose($output);
    exit;
}

// معالج AJAX لحذف عضو
add_action('wp_ajax_dms_delete_member', 'dms_handle_delete_member_callback');
function dms_handle_delete_member_callback() {
    // التحقق من صلاحيات المستخدم و nonce
    check_ajax_referer('dms_delete_member_nonce', '_wpnonce');
    if (!current_user_can('manage_options')) {
        wp_send_json_error('ليس لديك صلاحية لحذف الأعضاء.');
    }

    $user_id = isset($_POST['user_id']) ? intval($_POST['user_id']) : 0;

    if ($user_id > 0) {
        // لا تحذف المستخدمين المسؤولين أو المستخدم الحالي عن طريق الخطأ
        if (user_can($user_id, 'manage_options') && $user_id !== get_current_user_id()) {
            wp_send_json_error('لا يمكن حذف المستخدمين ذوي صلاحيات المسؤول.');
        }

        // حذف المستخدم
        require_once(ABSPATH . 'wp-admin/includes/user.php');
        $deleted = wp_delete_user($user_id);

        if (is_wp_error($deleted)) {
            wp_send_json_error($deleted->get_error_message());
        } else {
            wp_send_json_success('تم حذف العضو بنجاح.');
        }
    } else {
        wp_send_json_error('معرف مستخدم غير صالح.');
    }
}

// معالج لحفظ تفاصيل العضو عند الإرسال من جدول إدارة الأعضاء
add_action('admin_post_dms_save_member_details', 'dms_handle_save_member_details');
function dms_handle_save_member_details() {
    // التحقق من صلاحيات المستخدم
    if (!current_user_can('manage_options')) {
        wp_die('ليس لديك صلاحية لحفظ الأعضاء.');
    }

    // التحقق من nonce
    check_admin_referer('dms_save_member_details_nonce');

    foreach ($_POST as $key => $value) {
        // ابحث عن الحقول التي تبدأ بـ 'company_name_', 'whatsapp_', 'whatsapp_country_code_', 'governorate_', 'group_', 'currency_', 'status_'
        // ثم استخرج معرف المستخدم
        if (preg_match('/^(company_name|whatsapp|whatsapp_country_code|governorate|group|currency|status)_(\d+)$/', $key, $matches)) {
            $field_name = $matches[1];
            $user_id = intval($matches[2]);

            // التأكد من أن معرف المستخدم صالح وأن الحقل ليس الاسم المعروض (لأنه معطل)
            if ($user_id > 0 && $field_name !== 'display_name') {
                $sanitized_value = sanitize_text_field($value);
                update_user_meta($user_id, 'account_' . $field_name, $sanitized_value);
                
                // تحديث حقول group, currency, status مباشرة
                if (in_array($field_name, ['group', 'currency', 'status'])) {
                    update_user_meta($user_id, 'dms_user_' . $field_name, $sanitized_value);
                }
                // تحديث حالة الحساب بشكل خاص
                if ($field_name === 'status') {
                    update_user_meta($user_id, 'dms_account_status', $sanitized_value);
                }
            }
        }
    }

    // إعادة التوجيه إلى نفس الصفحة بعد الحفظ
    wp_redirect(admin_url('admin.php?page=dms_members&saved=true'));
    exit;
}

// عرض رسالة النجاح بعد التصنيف أو الحفظ
add_action('admin_notices', function() {
    if (isset($_GET['fixed']) && $_GET['fixed'] !== '') {
        $fixed = absint($_GET['fixed']);
        echo '<div class="notice notice-success is-dismissible"><p>تمت مزامنة الأعضاء (' . esc_html($fixed) . ')</p></div>';
    }
    if (isset($_GET['classified']) && $_GET['classified'] === 'true') {
        echo '<div class="notice notice-success is-dismissible"><p>تم تصنيف الأعضاء بنجاح!</p></div>';
    }
    if (isset($_GET['saved']) && $_GET['saved'] === 'true') {
        echo '<div class="notice notice-success is-dismissible"><p>تم حفظ بيانات العضو بنجاح!</p></div>';
    }
});
