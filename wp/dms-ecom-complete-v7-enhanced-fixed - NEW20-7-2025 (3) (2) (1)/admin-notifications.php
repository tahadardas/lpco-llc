<?php
/**
 * Admin notifications manager: list + bulk delete (soft/hard).
 */

if (!defined('ABSPATH')) {
    exit;
}

class DMS_App_Notifications_Admin {
    private $notice = '';

    public function __construct() {
        add_action('admin_menu', array($this, 'register_menu'), 20);
        add_action('admin_init', array($this, 'handle_bulk_actions'));
    }

    public function register_menu() {
        $parent_slug = $this->resolve_parent_slug();
        add_submenu_page(
            $parent_slug,
            __('إشعارات تطبيق الموبايل', 'dms'),
            __('إشعارات التطبيق', 'dms'),
            'manage_options',
            'dms-app-notifications',
            array($this, 'render_page')
        );
    }

    private function resolve_parent_slug() {
        global $submenu;
        if (isset($submenu['dms-app-main'])) {
            return 'dms-app-main';
        }
        return 'options-general.php';
    }

    public function handle_bulk_actions() {
        if (empty($_POST['dms_notifications_action']) || empty($_POST['dms_notifications_nonce'])) {
            return;
        }
        if (!current_user_can('manage_options')) {
            return;
        }

        check_admin_referer('dms_notifications_bulk_action', 'dms_notifications_nonce');

        $action = sanitize_text_field(wp_unslash($_POST['dms_notifications_action']));
        $ids = isset($_POST['dms_notification_ids']) ? (array) $_POST['dms_notification_ids'] : array();
        $ids = array_values(array_filter(array_map('intval', $ids)));

        if (empty($ids)) {
            $this->notice = __('لم يتم تحديد أي إشعار.', 'dms');
            return;
        }

        if (!function_exists('dms_notifications_tables')) {
            $this->notice = __('تعذر تحميل جداول الإشعارات.', 'dms');
            return;
        }

        if (function_exists('dms_notifications_maybe_add_is_deleted')) {
            dms_notifications_maybe_add_is_deleted();
        }

        global $wpdb;
        $tables = dms_notifications_tables();
        $placeholders = implode(',', array_fill(0, count($ids), '%d'));

        if ($action === 'delete') {
            $wpdb->query($wpdb->prepare(
                "UPDATE {$tables['notifications']} SET is_deleted = 1 WHERE id IN ($placeholders)",
                $ids
            ));
            $this->notice = __('تم إخفاء الإشعارات المحددة.', 'dms');
            return;
        }

        if ($action === 'hard_delete') {
            $wpdb->query($wpdb->prepare(
                "DELETE FROM {$tables['notifications']} WHERE id IN ($placeholders)",
                $ids
            ));
            $this->notice = __('تم حذف الإشعارات المحددة نهائياً.', 'dms');
            return;
        }

        $this->notice = __('لم يتم اختيار إجراء صالح.', 'dms');
    }

    private function format_audience($row) {
        $audience = isset($row['audience']) ? $row['audience'] : 'all';
        $target = isset($row['target_user_id']) ? intval($row['target_user_id']) : 0;

        switch ($audience) {
            case 'single_user':
                if ($target) {
                    return sprintf(__('مستخدم #%d', 'dms'), $target);
                }
                return __('مستخدم محدد', 'dms');
            case 'guests':
                return __('الضيوف', 'dms');
            case 'logged_in':
                return __('المسجلين', 'dms');
            case 'all':
            default:
                return __('الكل', 'dms');
        }
    }

    private function render_status($row) {
        if (!empty($row['is_deleted'])) {
            return '<span style="color:#777;">' . esc_html__('محذوف', 'dms') . '</span>';
        }
        $has_unread = !empty($row['has_unread']);
        if ($has_unread) {
            return '<span style="color:#c62828;font-weight:600;">' . esc_html__('غير مقروء', 'dms') . '</span>';
        }
        return '<span style="color:#2e7d32;font-weight:600;">' . esc_html__('مقروء', 'dms') . '</span>';
    }

    public function render_page() {
        if (!current_user_can('manage_options')) {
            wp_die(__('Unauthorized', 'dms'));
        }
        if (!function_exists('dms_notifications_tables')) {
            wp_die(__('تعذر تحميل جداول الإشعارات.', 'dms'));
        }

        if (function_exists('dms_notifications_maybe_add_is_deleted')) {
            dms_notifications_maybe_add_is_deleted();
        }

        global $wpdb;
        $tables = dms_notifications_tables();
        $limit = 200;

        $sql = $wpdb->prepare(
            "SELECT n.id, n.title, n.body, n.audience, n.target_user_id, n.created_at, n.is_deleted,
                    MAX(CASE WHEN r.is_read = 0 AND r.deleted_at IS NULL THEN 1 ELSE 0 END) AS has_unread
             FROM {$tables['notifications']} n
             LEFT JOIN {$tables['receipts']} r ON r.notification_id = n.id
             GROUP BY n.id
             ORDER BY n.created_at DESC
             LIMIT %d",
            $limit
        );
        $rows = $wpdb->get_results($sql, ARRAY_A);

        ?>
        <div class="wrap">
            <h1><?php echo esc_html__('إشعارات تطبيق الموبايل', 'dms'); ?></h1>
            <?php if (!empty($this->notice)) : ?>
                <div class="notice notice-success"><p><?php echo esc_html($this->notice); ?></p></div>
            <?php endif; ?>

            <form method="post">
                <?php wp_nonce_field('dms_notifications_bulk_action', 'dms_notifications_nonce'); ?>

                <div style="margin:12px 0;display:flex;gap:8px;align-items:center;">
                    <select name="dms_notifications_action">
                        <option value=""><?php echo esc_html__('اختر إجراء', 'dms'); ?></option>
                        <option value="delete"><?php echo esc_html__('حذف (إخفاء)', 'dms'); ?></option>
                        <option value="hard_delete"><?php echo esc_html__('حذف نهائي', 'dms'); ?></option>
                    </select>
                    <button type="submit" class="button button-primary"><?php echo esc_html__('تنفيذ على المحدد', 'dms'); ?></button>
                </div>

                <table class="widefat fixed striped">
                    <thead>
                        <tr>
                            <th style="width:32px;">
                                <input type="checkbox" id="dmsNotificationsSelectAll" aria-label="<?php echo esc_attr__('تحديد الكل', 'dms'); ?>">
                            </th>
                            <th style="width:60px;"><?php echo esc_html__('الرقم', 'dms'); ?></th>
                            <th style="width:180px;"><?php echo esc_html__('العنوان', 'dms'); ?></th>
                            <th><?php echo esc_html__('الرسالة', 'dms'); ?></th>
                            <th style="width:140px;"><?php echo esc_html__('مُرسل إلى', 'dms'); ?></th>
                            <th style="width:140px;"><?php echo esc_html__('التاريخ', 'dms'); ?></th>
                            <th style="width:110px;"><?php echo esc_html__('الحالة', 'dms'); ?></th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php if (empty($rows)) : ?>
                            <tr>
                                <td colspan="7"><?php echo esc_html__('لا توجد إشعارات لعرضها.', 'dms'); ?></td>
                            </tr>
                        <?php else : ?>
                            <?php foreach ($rows as $row) : ?>
                                <tr>
                                    <td>
                                        <input type="checkbox" class="dms-notification-checkbox" name="dms_notification_ids[]" value="<?php echo esc_attr($row['id']); ?>">
                                    </td>
                                    <td><?php echo esc_html($row['id']); ?></td>
                                    <td><?php echo esc_html($row['title']); ?></td>
                                    <td>
                                        <div style="max-width:420px;white-space:normal;direction:rtl;">
                                            <?php echo esc_html($row['body']); ?>
                                        </div>
                                    </td>
                                    <td><?php echo esc_html($this->format_audience($row)); ?></td>
                                    <td><?php echo esc_html(mysql2date('Y-m-d H:i', $row['created_at'])); ?></td>
                                    <td><?php echo $this->render_status($row); ?></td>
                                </tr>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </tbody>
                </table>
            </form>
        </div>
        <script>
            (function() {
                var selectAll = document.getElementById('dmsNotificationsSelectAll');
                if (!selectAll) return;
                selectAll.addEventListener('change', function() {
                    var boxes = document.querySelectorAll('.dms-notification-checkbox');
                    boxes.forEach(function(box) { box.checked = selectAll.checked; });
                });
            })();
        </script>
        <?php
    }
}

