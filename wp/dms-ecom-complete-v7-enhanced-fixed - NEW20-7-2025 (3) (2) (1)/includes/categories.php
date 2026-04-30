<?php
// شاشة إدارة التصنيفات
add_action('admin_menu', function() {
    add_menu_page('إدارة التصنيفات', 'إدارة التصنيفات', 'manage_options', 'dms-categories', 'dms_render_categories');
});

function dms_render_categories() {
    ?>
    <div class="wrap"><h2>إدارة التصنيفات</h2>
    <form method="post">
        <input type="text" name="new_category" placeholder="اسم التصنيف" required>
        <button class="button-primary">إضافة</button>
    </form><br>
    <table class="widefat"><thead><tr><th>التصنيف</th><th>حذف</th></tr></thead><tbody>
    <?php
    $cats = get_option('dms_price_categories', []);
    if (!is_array($cats)) $cats = [];
    foreach ($cats as $cat) {
        echo "<tr><td>{$cat}</td><td><a href='?page=dms-categories&delete={$cat}'>❌</a></td></tr>";
    }
    ?>
    </tbody></table>
    <?php
    if (isset($_POST['new_category'])) {
        $cats[] = sanitize_text_field($_POST['new_category']);
        update_option('dms_price_categories', array_unique($cats));
        wp_redirect(admin_url('admin.php?page=dms-categories'));
        exit;
    }
    if (isset($_GET['delete'])) {
        $cats = array_diff($cats, [$_GET['delete']]);
        update_option('dms_price_categories', $cats);
        wp_redirect(admin_url('admin.php?page=dms-categories'));
        exit;
    }
}
