<?php
/**
 * Notifications: tables, admin UI, and REST endpoints (tokens + inbox)
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Table names
 */
function dms_notifications_tables() {
    global $wpdb;
    return array(
        'tokens'        => $wpdb->prefix . 'dms_device_tokens',
        'notifications' => $wpdb->prefix . 'dms_notifications',
        'receipts'      => $wpdb->prefix . 'dms_notification_receipts',
    );
}

/**
 * Create DB tables on activation
 */
function dms_notifications_activate() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $charset_collate = $wpdb->get_charset_collate();
    $tables = dms_notifications_tables();

    $sql_tokens = "CREATE TABLE {$tables['tokens']} (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        token VARCHAR(255) NOT NULL UNIQUE,
        platform VARCHAR(20) NOT NULL DEFAULT 'android',
        app_version VARCHAR(30) NULL,
        user_id BIGINT UNSIGNED NULL,
        is_guest TINYINT(1) NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen_at DATETIME NULL,
        PRIMARY KEY (id),
        KEY user_id (user_id)
    ) $charset_collate;";

    $sql_notifications = "CREATE TABLE {$tables['notifications']} (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        title VARCHAR(140) NOT NULL DEFAULT 'LPCO',
        body TEXT NOT NULL,
        image_url TEXT NULL,
        deep_link TEXT NULL,
        audience VARCHAR(20) NOT NULL DEFAULT 'all',
        target_user_id BIGINT UNSIGNED NULL,
        created_by BIGINT UNSIGNED NULL,
        is_deleted TINYINT(1) NOT NULL DEFAULT 0,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY audience (audience),
        KEY target_user_id (target_user_id)
    ) $charset_collate;";

    $sql_receipts = "CREATE TABLE {$tables['receipts']} (
        id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        notification_id BIGINT UNSIGNED NOT NULL,
        token_id BIGINT UNSIGNED NULL,
        user_id BIGINT UNSIGNED NULL,
        is_read TINYINT(1) NOT NULL DEFAULT 0,
        deleted_at DATETIME NULL,
        delivered_at DATETIME NULL,
        read_at DATETIME NULL,
        PRIMARY KEY (id),
        KEY notification_id (notification_id),
        KEY token_id (token_id),
        KEY user_id (user_id),
        KEY is_read (is_read)
    ) $charset_collate;";

    dbDelta($sql_tokens);
    dbDelta($sql_notifications);
    dbDelta($sql_receipts);

    dms_notifications_maybe_add_is_deleted();
    dms_notifications_maybe_add_deleted_at();
}

/**
 * Ensure deleted_at column exists on receipts table for soft deletes.
 */
function dms_notifications_maybe_add_deleted_at() {
    global $wpdb;
    $tables = dms_notifications_tables();
    $col = $wpdb->get_var($wpdb->prepare("SHOW COLUMNS FROM {$tables['receipts']} LIKE %s", 'deleted_at'));
    if (!$col) {
        $wpdb->query("ALTER TABLE {$tables['receipts']} ADD COLUMN deleted_at DATETIME NULL DEFAULT NULL");
    }
}

/**
 * Ensure is_deleted column exists on notifications table for admin soft deletes.
 */
function dms_notifications_maybe_add_is_deleted() {
    global $wpdb;
    $tables = dms_notifications_tables();
    $col = $wpdb->get_var($wpdb->prepare("SHOW COLUMNS FROM {$tables['notifications']} LIKE %s", 'is_deleted'));
    if (!$col) {
        $wpdb->query("ALTER TABLE {$tables['notifications']} ADD COLUMN is_deleted TINYINT(1) NOT NULL DEFAULT 0");
    }
}

/**
 * Admin: settings + sender page
 */
add_action('admin_menu', function () {
    if (function_exists('add_submenu_page')) {
        add_submenu_page(
            'dms-app-main',
            'إشعارات التطبيق',
            'إشعارات التطبيق',
            'manage_woocommerce',
            'dms-notifications',
            'dms_notifications_render_admin'
        );
        add_submenu_page(
            'dms-app-main',
            'إعدادات إشعارات FCM',
            'إعدادات إشعارات FCM',
            'manage_options',
            'dms-fcm-settings',
            'dms_fcm_settings_render_admin'
        );
    }
});

/**
 * Resolve the FCM server key (notifications settings with fallback to app settings)
 */
function dms_notifications_resolve_server_key() {
    $settings = get_option('dms_notifications_settings', array());
    $server_key = $settings['fcm_server_key'] ?? '';

    if (empty($server_key)) {
        $app_settings = function_exists('dms_app_get_settings') ? dms_app_get_settings() : get_option('dms_app_settings', array());
        $server_key = $app_settings['fcm_server_key'] ?? '';
    }

    return $server_key;
}

/**
 * Admin page to configure FCM HTTP v1
 */
function dms_fcm_settings_render_admin() {
    if (!current_user_can('manage_options')) {
        wp_die(__('Unauthorized', 'dms'));
    }

    $saved = false;
    $error = '';
    if (isset($_POST['dms_fcm_settings_nonce']) && wp_verify_nonce($_POST['dms_fcm_settings_nonce'], 'dms_fcm_settings')) {
        $project_id = sanitize_text_field($_POST['dms_fcm_project_id'] ?? '');
        $default_icon = esc_url_raw($_POST['dms_fcm_default_icon'] ?? '');
        $default_channel = sanitize_text_field($_POST['dms_fcm_default_channel'] ?? 'LPCO_Notifications');
        $sa_json_raw = trim(stripslashes($_POST['dms_fcm_service_account_json'] ?? ''));
        $decoded = json_decode($sa_json_raw, true);
        if (empty($project_id) || empty($sa_json_raw)) {
            $error = 'يرجى إدخال معرف المشروع وملف الحساب الخدمي.';
        } elseif (!is_array($decoded) || empty($decoded['client_email']) || empty($decoded['private_key']) || empty($decoded['token_uri'])) {
            $error = 'صيغة الحساب الخدمي غير صحيحة أو ينقصها client_email / private_key / token_uri.';
        } else {
            update_option('dms_fcm_project_id', $project_id, false);
            update_option('dms_fcm_service_account_json', wp_json_encode($decoded), false);
            update_option('dms_fcm_default_icon', $default_icon, false);
            update_option('dms_fcm_default_channel', $default_channel ?: 'LPCO_Notifications', false);
            delete_transient('dms_fcm_httpv1_access_token');
            $saved = true;
        }
    }

    $project_id = dms_fcm_project_id();
    $default_icon = dms_fcm_default_icon();
    $default_channel = dms_fcm_default_channel();
    $sa_raw = dms_fcm_service_account_raw();
    ?>
    <div class="wrap">
        <h1>إعدادات إشعارات FCM (HTTP v1)</h1>
        <?php if ($saved): ?>
            <div class="notice notice-success"><p>تم حفظ الإعدادات.</p></div>
        <?php endif; ?>
        <?php if (!empty($error)): ?>
            <div class="notice notice-error"><p><?php echo esc_html($error); ?></p></div>
        <?php endif; ?>
        <form method="post">
            <?php wp_nonce_field('dms_fcm_settings', 'dms_fcm_settings_nonce'); ?>
            <table class="form-table">
                <tr>
                    <th scope="row"><label for="dms_fcm_project_id">Firebase Project ID</label></th>
                    <td><input type="text" name="dms_fcm_project_id" id="dms_fcm_project_id" class="regular-text" value="<?php echo esc_attr($project_id); ?>" required></td>
                </tr>
                <tr>
                    <th scope="row"><label for="dms_fcm_service_account_json">Service Account JSON</label></th>
                    <td>
                        <textarea name="dms_fcm_service_account_json" id="dms_fcm_service_account_json" rows="10" class="large-text code" placeholder="{ &quot;type&quot;: &quot;service_account&quot;, ... }" required><?php echo esc_textarea($sa_raw); ?></textarea>
                        <p class="description">لن يُعرض هذا في الواجهة الأمامية. تأكد من نسخه من حساب الخدمة بصلاحية Firebase Admin SDK.</p>
                    </td>
                </tr>
                <tr>
                    <th scope="row"><label for="dms_fcm_default_icon">أيقونة الإشعار (اختياري)</label></th>
                    <td><input type="text" name="dms_fcm_default_icon" id="dms_fcm_default_icon" class="regular-text" value="<?php echo esc_attr($default_icon); ?>" placeholder="https://example.com/icon.png"></td>
                </tr>
                <tr>
                    <th scope="row"><label for="dms_fcm_default_channel">معرّف قناة الإشعار</label></th>
                    <td><input type="text" name="dms_fcm_default_channel" id="dms_fcm_default_channel" class="regular-text" value="<?php echo esc_attr($default_channel); ?>" placeholder="LPCO_Notifications"></td>
                </tr>
            </table>
            <?php submit_button('حفظ الإعدادات'); ?>
        </form>
    </div>
    <?php
}

function dms_notifications_render_admin() {
    if (!current_user_can('manage_woocommerce')) {
        wp_die(__('Unauthorized', 'dms'));
    }

    $server_key = dms_notifications_resolve_server_key();
    $audience = 'all';
    $title = 'LPCO';
    $body = '';
    $image_url = '';
    $deep_link = '';
    $target_user_id = '';
    $message = '';
    $has_fcm = dms_fcm_is_configured();

    // Send notification
    if (isset($_POST['dms_notifications_send_nonce']) && wp_verify_nonce($_POST['dms_notifications_send_nonce'], 'dms_notifications_send')) {
        if (!$has_fcm) {
            $message = 'يرجى إضافة إعدادات FCM HTTP v1 أولاً.';
        } else {
            $title = sanitize_text_field($_POST['title'] ?? 'LPCO');
            $body = wp_kses_post($_POST['body'] ?? '');
            $image_url = esc_url_raw($_POST['image_url'] ?? '');
            $deep_link = sanitize_text_field($_POST['deep_link'] ?? '');
            $audience = sanitize_text_field($_POST['audience'] ?? 'all');
            $target_user_id = isset($_POST['target_user_id']) ? intval($_POST['target_user_id']) : 0;

            $result = dms_notifications_send($title, $body, $image_url, $deep_link, $audience, $target_user_id);
            if (is_wp_error($result)) {
                $message = 'فشل الإرسال: ' . $result->get_error_message();
            } else {
                $message = sprintf('تم إرسال الإشعار إلى %d جهاز', intval($result['sent'] ?? 0));
            }
        }
    }

    ?>
    <div class="wrap">
        <h1>إشعارات التطبيق</h1>
        <?php if ($message): ?>
            <div class="notice notice-success"><p><?php echo esc_html($message); ?></p></div>
        <?php endif; ?>
        <?php if (!$has_fcm): ?>
            <div class="notice notice-error"><p>يرجى إضافة إعدادات FCM HTTP v1 من صفحة "إعدادات إشعارات FCM".</p></div>
        <?php else: ?>
            <div class="notice notice-success"><p>إعدادات FCM HTTP v1 جاهزة.</p></div>
        <?php endif; ?>
        <p><a class="button" href="<?php echo esc_url(admin_url('admin.php?page=dms-fcm-settings')); ?>">فتح إعدادات FCM</a></p>
        <h2>إرسال إشعار</h2>
        <form method="post">
            <?php wp_nonce_field('dms_notifications_send', 'dms_notifications_send_nonce'); ?>
            <table class="form-table">
                <tr><th>العنوان</th><td><input type="text" name="title" value="<?php echo esc_attr($title); ?>" style="width: 420px;"></td></tr>
                <tr><th>النص</th><td><textarea name="body" rows="4" style="width: 420px;"><?php echo esc_textarea($body); ?></textarea></td></tr>
                <tr><th>رابط صورة (اختياري)</th><td><input type="text" name="image_url" value="<?php echo esc_attr($image_url); ?>" style="width: 420px;"></td></tr>
                <tr><th>رابط عميق (اختياري)</th><td><input type="text" name="deep_link" value="<?php echo esc_attr($deep_link); ?>" style="width: 420px;" placeholder="مثال: product:123 أو /notifications"></td></tr>
                <tr>
                    <th>الجمهور</th>
                    <td>
                        <select name="audience" id="dms_audience">
                            <option value="all" <?php selected($audience, 'all'); ?>>الجميع</option>
                            <option value="guests" <?php selected($audience, 'guests'); ?>>الضيوف فقط</option>
                            <option value="logged_in" <?php selected($audience, 'logged_in'); ?>>المسجلين فقط</option>
                            <option value="single_user" <?php selected($audience, 'single_user'); ?>>مستخدم محدد</option>
                        </select>
                        <input type="number" name="target_user_id" id="dms_target_user" value="<?php echo esc_attr($target_user_id); ?>" placeholder="User ID" <?php echo $audience === 'single_user' ? '' : 'style="display:none"'; ?>>
                    </td>
                </tr>
            </table>
            <p><input type="submit" class="button button-primary" value="إرسال"></p>
        </form>
        <script>
            (function(){
                const sel=document.getElementById('dms_audience');
                const tgt=document.getElementById('dms_target_user');
                if(!sel||!tgt)return;
                const toggle=()=>{tgt.style.display=sel.value==='single_user'?'inline-block':'none';}
                sel.addEventListener('change',toggle);toggle();
            })();
        </script>
    </div>
    <?php
}

/**
 * Resolve token ID by header
 */
function dms_notifications_extract_device_token(WP_REST_Request $request) {
    $token = trim((string) $request->get_header('X-Device-Token'));
    if ($token !== '') {
        return sanitize_text_field($token);
    }

    $token = trim((string) $request->get_param('device_token'));
    if ($token !== '') {
        return sanitize_text_field($token);
    }

    $body = $request->get_json_params();
    if (is_array($body)) {
        $fallback = trim((string) ($body['device_token'] ?? ''));
        if ($fallback !== '') {
            return sanitize_text_field($fallback);
        }
    }

    return '';
}

function dms_notifications_require_token($request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    $token = dms_notifications_extract_device_token($request);
    if (empty($token)) {
        return new WP_Error('token_missing', 'Device token is required', array('status' => 401));
    }
    $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM {$tables['tokens']} WHERE token = %s", $token), ARRAY_A);
    if (!$row) {
        return new WP_Error('token_not_found', 'Unknown device token', array('status' => 401));
    }
    return $row;
}

/**
 * REST routes
 */
function dms_notifications_permission_register(WP_REST_Request $request) {
    $body = $request->get_json_params();
    $claimed_user_id = intval($body['user_id'] ?? 0);

    // Guest/device bootstrap is allowed without JWT.
    if ($claimed_user_id <= 0) {
        return true;
    }

    if (!function_exists('dms_validate_jwt_request')) {
        return new WP_Error('auth_unavailable', 'JWT validation is unavailable', array('status' => 500));
    }

    $auth = dms_validate_jwt_request($request);
    if (is_wp_error($auth)) {
        return $auth;
    }

    $current_user_id = get_current_user_id();
    if ($current_user_id <= 0 || $current_user_id !== $claimed_user_id) {
        return new WP_Error('forbidden_user_binding', 'Authenticated user does not match payload user.', array('status' => 403));
    }

    return true;
}

function dms_notifications_permission_with_token(WP_REST_Request $request) {
    $token = dms_notifications_extract_device_token($request);
    if (empty($token)) {
        return new WP_Error('token_missing', 'Device token is required', array('status' => 401));
    }
    return true;
}

function dms_notifications_permission_admin() {
    if (function_exists('dms_admin_permissions')) {
        return dms_admin_permissions();
    }
    if (!is_user_logged_in()) {
        return new WP_Error('rest_forbidden', __('Login required', 'dms-ecom'), array('status' => 401));
    }
    if (!current_user_can('manage_options')) {
        return new WP_Error('rest_forbidden', __('Insufficient permissions', 'dms-ecom'), array('status' => 403));
    }
    return true;
}

add_action('rest_api_init', function () {
    register_rest_route('dms/v1', '/device/register', array(
        'methods' => 'POST',
        'callback' => 'dms_device_register',
        'permission_callback' => 'dms_notifications_permission_register'
    ));
    register_rest_route('dms/v1', '/device/ping', array(
        'methods' => 'POST',
        'callback' => 'dms_device_ping',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications', array(
        'methods' => 'GET',
        'callback' => 'dms_notifications_list',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications/unread-count', array(
        'methods' => 'GET',
        'callback' => 'dms_notifications_unread',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications/read', array(
        'methods' => 'POST',
        'callback' => 'dms_notifications_mark_read',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications/unread', array(
        'methods' => 'POST',
        'callback' => 'dms_notifications_mark_unread',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications/read-all', array(
        'methods' => 'POST',
        'callback' => 'dms_notifications_mark_all',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications/delete', array(
        'methods' => 'POST',
        'callback' => 'dms_notifications_delete_one',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/notifications/delete-all', array(
        'methods' => 'POST',
        'callback' => 'dms_notifications_delete_all',
        'permission_callback' => 'dms_notifications_permission_with_token'
    ));
    register_rest_route('dms/v1', '/admin/users/search', array(
        'methods' => 'GET',
        'callback' => 'dms_notifications_user_search',
        'permission_callback' => 'dms_admin_permissions',
    ));
    register_rest_route('dms/v1/admin', '/notifications/history', array(
        'methods' => 'GET',
        'callback' => 'dms_admin_notifications_history',
        'permission_callback' => 'dms_notifications_permission_admin'
    ));
    register_rest_route('dms/v1/admin', '/notifications/send', array(
        'methods' => 'POST',
        'callback' => 'dms_admin_notifications_send',
        'permission_callback' => 'dms_notifications_permission_admin'
    ));
});

function dms_device_register(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    $body = $request->get_json_params();
    $token = sanitize_text_field($body['token'] ?? '');
    $platform = sanitize_text_field($body['platform'] ?? 'android');
    $app_version = sanitize_text_field($body['app_version'] ?? '');
    $user_id = intval($body['user_id'] ?? 0) ?: null;
    $is_guest = isset($body['is_guest']) ? (bool)$body['is_guest'] : empty($user_id);

    if ($user_id) {
        $current_user_id = get_current_user_id();
        if ($current_user_id <= 0 || $current_user_id !== $user_id) {
            return new WP_Error('forbidden_user_binding', 'Authenticated user does not match payload user.', array('status' => 403));
        }
        $is_guest = false;
    }

    if (empty($token)) {
        return new WP_Error('invalid_token', 'Token required', array('status' => 400));
    }

    $existing_id = $wpdb->get_var($wpdb->prepare("SELECT id FROM {$tables['tokens']} WHERE token = %s", $token));
    if ($existing_id) {
        $wpdb->update(
            $tables['tokens'],
            array(
                'platform' => $platform,
                'app_version' => $app_version,
                'user_id' => $user_id,
                'is_guest' => $is_guest ? 1 : 0,
                'last_seen_at' => current_time('mysql')
            ),
            array('id' => $existing_id)
        );
        $id = $existing_id;
    } else {
        $wpdb->insert(
            $tables['tokens'],
            array(
                'token' => $token,
                'platform' => $platform,
                'app_version' => $app_version,
                'user_id' => $user_id,
                'is_guest' => $is_guest ? 1 : 0,
                'created_at' => current_time('mysql'),
                'last_seen_at' => current_time('mysql')
            )
        );
        $id = $wpdb->insert_id;
    }

    return array('success' => true, 'id' => intval($id), 'is_guest' => $is_guest);
}

function dms_device_ping(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    $token = $request->get_header('X-Device-Token');
    if (empty($token)) {
        return new WP_Error('token_missing', 'Device token required', array('status' => 401));
    }
    $wpdb->update($tables['tokens'], array('last_seen_at' => current_time('mysql')), array('token' => $token));
    return array('success' => true);
}

function dms_notifications_scope_sql($token_row, $alias = 'r') {
    global $wpdb;
    $alias = preg_replace('/[^a-zA-Z0-9_]/', '', (string) $alias);
    if ($alias === '') {
        $alias = 'r';
    }

    $user_id = intval($token_row['user_id'] ?: 0);
    $token_id = intval($token_row['id']);

    if ($user_id > 0) {
        return $wpdb->prepare("({$alias}.user_id = %d OR {$alias}.token_id = %d)", $user_id, $token_id);
    }

    return $wpdb->prepare("{$alias}.token_id = %d", $token_id);
}

function dms_notifications_list(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    dms_notifications_maybe_add_is_deleted();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $limit = max(1, intval($request->get_param('limit') ?: 30));
    $since_id = intval($request->get_param('since_id') ?: 0);

    $where = dms_notifications_scope_sql($token_row, 'r');
    if ($since_id > 0) {
        $where .= $wpdb->prepare(" AND n.id > %d", $since_id);
    }
    $where .= " AND (r.deleted_at IS NULL) AND n.is_deleted = 0";

    $sql = "SELECT n.id, n.title, n.body, n.image_url, n.deep_link, n.created_at,
                   MIN(CASE WHEN r.is_read = 1 THEN 1 ELSE 0 END) AS is_read
            FROM {$tables['receipts']} r
            INNER JOIN {$tables['notifications']} n ON n.id = r.notification_id
            WHERE $where
            GROUP BY n.id, n.title, n.body, n.image_url, n.deep_link, n.created_at
            ORDER BY n.id DESC
            LIMIT %d";

    $rows = $wpdb->get_results($wpdb->prepare($sql, $limit), ARRAY_A);
    return array_map(function ($row) {
        return array(
            'id' => intval($row['id']),
            'title' => $row['title'],
            'body' => $row['body'],
            'image_url' => $row['image_url'],
            'deep_link' => $row['deep_link'],
            'created_at' => $row['created_at'],
            'is_read' => (bool)$row['is_read']
        );
    }, $rows);
}

function dms_notifications_unread(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    dms_notifications_maybe_add_is_deleted();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $where = dms_notifications_scope_sql($token_row, 'r');
    $count = $wpdb->get_var(
        "SELECT COUNT(DISTINCT r.notification_id) FROM {$tables['receipts']} r
         INNER JOIN {$tables['notifications']} n ON n.id = r.notification_id
         WHERE r.is_read = 0 AND r.deleted_at IS NULL AND n.is_deleted = 0 AND {$where}"
    );
    return array('count' => intval($count));
}

function dms_notifications_mark_read(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $body = $request->get_json_params();
    $notification_id = intval($body['notification_id'] ?? ($body['id'] ?? 0));
    if ($notification_id <= 0) {
        return new WP_Error('invalid_param', 'notification_id required', array('status' => 400));
    }

    $user_id = intval($token_row['user_id'] ?: 0);
    $token_id = intval($token_row['id']);
    $now = current_time('mysql');
    $wpdb->query($wpdb->prepare(
        "UPDATE {$tables['receipts']} SET is_read = 1, read_at = %s WHERE notification_id = %d AND token_id = %d AND deleted_at IS NULL",
        $now,
        $notification_id,
        $token_id
    ));
    if ($user_id) {
        $wpdb->query($wpdb->prepare(
            "UPDATE {$tables['receipts']} SET is_read = 1, read_at = %s WHERE notification_id = %d AND user_id = %d AND deleted_at IS NULL",
            $now,
            $notification_id,
            $user_id
        ));
    }
    return array(
        'success' => true,
        'message' => 'Notification marked as read'
    );
}

function dms_notifications_mark_unread(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $body = $request->get_json_params();
    $notification_id = intval($body['notification_id'] ?? ($body['id'] ?? 0));
    if ($notification_id <= 0) {
        return new WP_Error('invalid_param', 'notification_id required', array('status' => 400));
    }

    $user_id = intval($token_row['user_id'] ?: 0);
    $token_id = intval($token_row['id']);
    $wpdb->query($wpdb->prepare(
        "UPDATE {$tables['receipts']} SET is_read = 0, read_at = NULL WHERE notification_id = %d AND token_id = %d AND deleted_at IS NULL",
        $notification_id,
        $token_id
    ));
    if ($user_id) {
        $wpdb->query($wpdb->prepare(
            "UPDATE {$tables['receipts']} SET is_read = 0, read_at = NULL WHERE notification_id = %d AND user_id = %d AND deleted_at IS NULL",
            $notification_id,
            $user_id
        ));
    }

    return array(
        'success' => true,
        'message' => 'Notification marked as unread'
    );
}

function dms_notifications_mark_all(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $user_id = intval($token_row['user_id'] ?: 0);
    $token_id = intval($token_row['id']);
    $now = current_time('mysql');
    $wpdb->query($wpdb->prepare(
        "UPDATE {$tables['receipts']} SET is_read = 1, read_at = %s WHERE token_id = %d AND deleted_at IS NULL",
        $now,
        $token_id
    ));
    if ($user_id) {
        $wpdb->query($wpdb->prepare(
            "UPDATE {$tables['receipts']} SET is_read = 1, read_at = %s WHERE user_id = %d AND deleted_at IS NULL",
            $now,
            $user_id
        ));
    }
    return array(
        'success' => true,
        'message' => 'All notifications marked as read'
    );
}

/**
 * Soft delete a single notification receipt for the current device/user
 */
function dms_notifications_delete_one(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $body = $request->get_json_params();
    $notification_id = intval($body['notification_id'] ?? 0);
    if ($notification_id <= 0) {
        return new WP_Error('invalid_param', 'notification_id required', array('status' => 400));
    }

    $user_id = intval($token_row['user_id'] ?: 0);
    $token_id = intval($token_row['id']);
    $now = current_time('mysql');
    $wpdb->update(
        $tables['receipts'],
        array('deleted_at' => $now, 'is_read' => 1, 'read_at' => $now),
        array('notification_id' => $notification_id, 'token_id' => $token_id)
    );
    if ($user_id) {
        $wpdb->update(
            $tables['receipts'],
            array('deleted_at' => $now, 'is_read' => 1, 'read_at' => $now),
            array('notification_id' => $notification_id, 'user_id' => $user_id)
        );
    }

    return array('success' => true);
}

/**
 * Soft delete all notifications for current device/user
 */
function dms_notifications_delete_all(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    $token_row = dms_notifications_require_token($request);
    if (is_wp_error($token_row)) return $token_row;

    $user_id = intval($token_row['user_id'] ?: 0);
    $token_id = intval($token_row['id']);
    $now = current_time('mysql');
    $wpdb->update(
        $tables['receipts'],
        array('deleted_at' => $now, 'is_read' => 1, 'read_at' => $now),
        array('token_id' => $token_id)
    );
    if ($user_id) {
        $wpdb->update(
            $tables['receipts'],
            array('deleted_at' => $now, 'is_read' => 1, 'read_at' => $now),
            array('user_id' => $user_id)
        );
    }
    return array('success' => true);
}

function dms_notifications_user_search(WP_REST_Request $request) {
    $q = sanitize_text_field($request->get_param('q') ?: '');
    $args = array(
        'number' => 20,
        'search' => '*' . esc_attr($q) . '*',
        'search_columns' => array('user_login', 'user_nicename', 'display_name'),
    );
    $users = get_users($args);
    $items = array_map(function ($u) {
        return array(
            'id' => $u->ID,
            'username' => $u->user_login,
            'display_name' => $u->display_name,
            'email' => $u->user_email,
        );
    }, $users);

    if (function_exists('dms_api_list_response') && function_exists('dms_api_pagination_meta')) {
        return dms_api_list_response($items, dms_api_pagination_meta(1, 20, count($items), 1));
    }

    return array(
        'items' => $items,
        'meta' => array(
            'page' => 1,
            'per_page' => 20,
            'total' => count($items),
            'total_pages' => 1,
        ),
    );
}

function dms_notifications_normalize_audience($audience) {
    $value = strtolower(trim((string) $audience));
    switch ($value) {
        case 'guests':
        case 'guest':
            return 'guests';
        case 'logged_in':
        case 'loggedin':
        case 'customers':
        case 'admins':
            return 'logged_in';
        case 'single_user':
        case 'single':
        case 'user':
            return 'single_user';
        case 'all':
        default:
            return 'all';
    }
}

function dms_admin_notifications_history(WP_REST_Request $request) {
    global $wpdb;
    $tables = dms_notifications_tables();
    dms_notifications_maybe_add_deleted_at();
    dms_notifications_maybe_add_is_deleted();

    $per_page = max(1, min(100, intval($request->get_param('per_page') ?: ($request->get_param('limit') ?: 30))));
    $page = max(1, intval($request->get_param('page') ?: 1));
    $offset = ($page - 1) * $per_page;
    $search = sanitize_text_field((string) $request->get_param('search'));
    $audience = sanitize_text_field((string) $request->get_param('audience'));
    $date_from = sanitize_text_field((string) $request->get_param('date_from'));
    $date_to = sanitize_text_field((string) $request->get_param('date_to'));

    $where = array('1=1');
    $params = array();
    if ($search !== '') {
        $like = '%' . $wpdb->esc_like($search) . '%';
        $where[] = '(n.title LIKE %s OR n.body LIKE %s)';
        $params[] = $like;
        $params[] = $like;
    }
    if ($audience !== '') {
        $where[] = 'n.audience = %s';
        $params[] = $audience;
    }
    if ($date_from !== '') {
        $where[] = 'DATE(n.created_at) >= %s';
        $params[] = $date_from;
    }
    if ($date_to !== '') {
        $where[] = 'DATE(n.created_at) <= %s';
        $params[] = $date_to;
    }
    $where_sql = implode(' AND ', $where);

    $count_sql = "SELECT COUNT(*) FROM {$tables['notifications']} n WHERE {$where_sql}";
    $prepared_count_sql = !empty($params)
        ? $wpdb->prepare($count_sql, $params)
        : $count_sql;
    $total = intval($wpdb->get_var($prepared_count_sql));

    $sql = "SELECT n.id, n.title, n.body, n.image_url, n.deep_link, n.audience, n.target_user_id, n.created_at, n.is_deleted,
                   COUNT(r.id) AS receipts_total,
                   SUM(CASE WHEN r.deleted_at IS NULL THEN 1 ELSE 0 END) AS delivered_count,
                   SUM(CASE WHEN r.deleted_at IS NULL AND r.is_read = 1 THEN 1 ELSE 0 END) AS read_count,
                   SUM(CASE WHEN r.deleted_at IS NULL AND r.is_read = 0 THEN 1 ELSE 0 END) AS unread_count
            FROM {$tables['notifications']} n
            LEFT JOIN {$tables['receipts']} r ON r.notification_id = n.id
            WHERE {$where_sql}
            GROUP BY n.id, n.title, n.body, n.image_url, n.deep_link, n.audience, n.target_user_id, n.created_at, n.is_deleted
            ORDER BY n.id DESC
            LIMIT %d OFFSET %d";

    $query_params = $params;
    $query_params[] = $per_page;
    $query_params[] = $offset;
    $rows = $wpdb->get_results($wpdb->prepare($sql, $query_params), ARRAY_A);
    $items = array_map(function ($row) {
        return array(
            'id' => intval($row['id']),
            'title' => (string) $row['title'],
            'body' => (string) $row['body'],
            'image_url' => (string) ($row['image_url'] ?? ''),
            'deep_link' => (string) ($row['deep_link'] ?? ''),
            'audience' => (string) ($row['audience'] ?? 'all'),
            'target_user_id' => intval($row['target_user_id'] ?? 0),
            'created_at' => (string) ($row['created_at'] ?? ''),
            'is_deleted' => !empty($row['is_deleted']),
            'receipts_total' => intval($row['receipts_total'] ?? 0),
            'delivered_count' => intval($row['delivered_count'] ?? 0),
            'read_count' => intval($row['read_count'] ?? 0),
            'unread_count' => intval($row['unread_count'] ?? 0),
        );
    }, $rows ?: array());

    if (function_exists('dms_api_list_response') && function_exists('dms_api_pagination_meta')) {
        return dms_api_list_response(
            $items,
            dms_api_pagination_meta($page, $per_page, $total)
        );
    }

    return array(
        'items' => $items,
        'meta' => array(
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => max(1, (int) ceil($total / max(1, $per_page))),
        ),
    );
}

function dms_admin_notifications_send(WP_REST_Request $request) {
    $body = $request->get_json_params();
    $title = sanitize_text_field($body['title'] ?? 'LPCO');
    $message = wp_kses_post($body['body'] ?? '');
    $image_url = esc_url_raw($body['image_url'] ?? '');
    $deep_link = sanitize_text_field($body['deep_link'] ?? '');
    $audience = dms_notifications_normalize_audience($body['audience'] ?? 'all');
    $target_user_id = intval($body['target_user_id'] ?? 0);

    if ($title === '' || trim($message) === '') {
        return new WP_Error('invalid_payload', 'title and body are required', array('status' => 400));
    }
    if ($audience === 'single_user' && $target_user_id <= 0) {
        return new WP_Error('invalid_payload', 'target_user_id is required for single_user audience', array('status' => 400));
    }

    $result = dms_notifications_send($title, $message, $image_url, $deep_link, $audience, $target_user_id);
    if (is_wp_error($result)) {
        return $result;
    }

    $payload = array(
        'notification_id' => intval($result['notification_id'] ?? 0),
        'sent' => intval($result['sent'] ?? 0),
        'total' => intval($result['total'] ?? 0),
    );

    if (function_exists('dms_api_action_response')) {
        return dms_api_action_response('تم إرسال الإشعار بنجاح.', $payload);
    }

    return array(
        'success' => true,
        'message' => 'تم إرسال الإشعار بنجاح.',
        'data' => $payload,
    );
}

/**
 * Sending logic
 */
function dms_notifications_send($title, $body, $image_url, $deep_link, $audience, $target_user_id = 0) {
    global $wpdb;

    $fcm_configured = dms_fcm_is_configured();
    if (!$fcm_configured && function_exists('dms_ecom_log')) {
        dms_ecom_log('warning', 'Notifications saved without push delivery because FCM is not configured.', array());
    }

    $audience = dms_notifications_normalize_audience($audience);
    $target_user_id = intval($target_user_id);
    if ($audience === 'single_user' && $target_user_id <= 0) {
        return new WP_Error('invalid_target_user', 'معرّف المستخدم مطلوب عند الإرسال لمستخدم محدد.', array('status' => 400));
    }

    $tables = dms_notifications_tables();
    $wpdb->insert($tables['notifications'], array(
        'title' => $title,
        'body' => $body,
        'image_url' => $image_url,
        'deep_link' => $deep_link,
        'audience' => $audience,
        'target_user_id' => $target_user_id ?: null,
        'created_by' => get_current_user_id(),
        'created_at' => current_time('mysql')
    ));
    $notification_id = $wpdb->insert_id;

    // Determine targets
    $where = '1=1';
    if ($audience === 'guests') {
        $where = 'is_guest = 1';
    } elseif ($audience === 'logged_in') {
        $where = 'is_guest = 0 AND user_id IS NOT NULL';
    } elseif ($audience === 'single_user' && $target_user_id) {
        $where = $wpdb->prepare('user_id = %d', $target_user_id);
    }
    $tokens = $wpdb->get_results("SELECT * FROM {$tables['tokens']} WHERE {$where}", ARRAY_A);
    $total = count($tokens);

    $receipts_batch = array();
    foreach ($tokens as $t) {
        $receipts_batch[] = array(
            'notification_id' => $notification_id,
            'token_id' => $t['id'],
            'user_id' => $t['user_id'] ?: null,
            'is_read' => 0,
            'delivered_at' => current_time('mysql')
        );
    }
    if (!empty($receipts_batch)) {
        foreach (array_chunk($receipts_batch, 100) as $chunk) {
            $values = array();
            foreach ($chunk as $row) {
                $values[] = $wpdb->prepare('(%d,%d,%s,%s,%s)',
                    $row['notification_id'],
                    $row['token_id'],
                    $row['user_id'],
                    $row['is_read'],
                    $row['delivered_at']
                );
            }
            $sql = "INSERT INTO {$tables['receipts']} (notification_id, token_id, user_id, is_read, delivered_at) VALUES " . implode(',', $values);
            $wpdb->query($sql);
        }
    }

    // Send push batches (best effort). Inbox records remain available even if FCM is disabled.
    $sent = 0;
    $invalid_tokens = array();

    if ($fcm_configured) {
        foreach (array_chunk($tokens, 200) as $batch) {
            foreach ($batch as $t) {
                $data = array(
                    'notification_id' => $notification_id,
                    'deep_link' => $deep_link,
                    'image_url' => $image_url
                );
                $result = dms_fcm_send_message($t['token'], $title, $body, $data, $image_url);
                if (is_wp_error($result)) {
                    $status = strtoupper($result->get_error_data()['fcm_status'] ?? '');
                    $http_code = $result->get_error_data()['http_code'] ?? null;
                    if (in_array($status, array('NOT_FOUND', 'NOT_FOUND_ERROR', 'UNREGISTERED'), true) || $http_code === 404) {
                        $invalid_tokens[] = $t['token'];
                    }
                    continue;
                }
                $sent++;
            }
        }
    }

    if (!empty($invalid_tokens)) {
        foreach ($invalid_tokens as $bad) {
            $wpdb->delete($tables['tokens'], array('token' => $bad));
        }
    }

    return array(
        'sent' => $sent,
        'notification_id' => $notification_id,
        'total' => $total,
        'push_enabled' => $fcm_configured,
    );
}

if (!function_exists('dms_notifications_order_status_label')) {
function dms_notifications_order_status_label($status) {
    $status = sanitize_key((string) $status);
    $labels = array(
        'pending' => 'قيد الانتظار',
        'processing' => 'قيد المعالجة',
        'on-hold' => 'قيد المراجعة',
        'completed' => 'مكتمل',
        'cancelled' => 'ملغي',
        'refunded' => 'مسترجع',
        'failed' => 'فاشل',
    );
    return $labels[$status] ?? $status;
}
}

if (!function_exists('dms_notifications_send_order_event')) {
function dms_notifications_send_order_event($user_id, $title, $body, $deep_link, $order_id = 0, $event_key = '') {
    $user_id = absint($user_id);
    if ($user_id <= 0 || !function_exists('dms_notifications_send')) {
        return;
    }

    $result = dms_notifications_send(
        sanitize_text_field($title),
        wp_kses_post($body),
        '',
        sanitize_text_field($deep_link),
        'single_user',
        $user_id
    );

    if (is_wp_error($result) && function_exists('dms_ecom_log')) {
        dms_ecom_log('warning', 'Order notification delivery failed', array(
            'order_id' => absint($order_id),
            'user_id' => $user_id,
            'event' => sanitize_key((string) $event_key),
            'error' => $result->get_error_code(),
            'message' => $result->get_error_message(),
        ));
    }
}
}

add_action('woocommerce_new_order', function ($order_id) {
    if (!function_exists('wc_get_order')) {
        return;
    }
    $order = wc_get_order($order_id);
    if (!$order) {
        return;
    }

    $customer_id = absint($order->get_customer_id());
    if ($customer_id <= 0) {
        return;
    }

    $order_number = $order->get_order_number();
    $title = 'تم استلام طلبك';
    $body = sprintf('تم استلام الطلب رقم #%s وسيتم مراجعته قريباً.', $order_number);
    dms_notifications_send_order_event(
        $customer_id,
        $title,
        $body,
        'notifications',
        $order_id,
        'new_order'
    );
}, 30, 1);

add_action('woocommerce_order_status_changed', function ($order_id, $from, $to, $order) {
    if (!$order instanceof WC_Order) {
        $order = function_exists('wc_get_order') ? wc_get_order($order_id) : null;
    }
    if (!$order) {
        return;
    }

    $customer_id = absint($order->get_customer_id());
    if ($customer_id <= 0) {
        return;
    }

    $from = sanitize_key((string) $from);
    $to = sanitize_key((string) $to);
    if ($from === $to) {
        return;
    }

    $order_number = $order->get_order_number();
    $to_label = dms_notifications_order_status_label($to);
    $title = 'تحديث حالة الطلب';
    $body = sprintf('تم تحديث حالة الطلب رقم #%s إلى: %s.', $order_number, $to_label);
    dms_notifications_send_order_event(
        $customer_id,
        $title,
        $body,
        'notifications',
        $order_id,
        'order_status_' . $to
    );
}, 30, 4);

