<?php
/**
 * DMS member sync helpers.
 */

if (!defined('ABSPATH')) {
    exit;
}

/**
 * Default account status for new members.
 *
 * @return string
 */
function dms_get_default_account_status() {
    return 'جديد';
}

/**
 * Fetch the first non-empty value from a list of keys.
 *
 * @param array $source Source data.
 * @param array $keys Keys to check.
 * @return string
 */
function dms_member_pick_value($source, $keys) {
    foreach ($keys as $key) {
        if (!isset($source[$key])) {
            continue;
        }
        $value = is_string($source[$key]) ? trim($source[$key]) : '';
        if ($value !== '') {
            return sanitize_text_field($value);
        }
    }
    return '';
}

/**
 * Ensure the DMS member meta is present for a user.
 *
 * @param int   $user_id User ID.
 * @param array $extra Extra data from registration.
 * @return bool
 */
function dms_sync_member_record($user_id, $extra = array()) {
    $user_id = absint($user_id);
    if ($user_id <= 0) {
        return false;
    }

    $user = get_userdata($user_id);
    if (!$user) {
        return false;
    }

    if (!is_array($extra)) {
        $extra = array();
    }
    if (isset($extra['meta']) && is_array($extra['meta'])) {
        $extra = array_merge($extra['meta'], $extra);
    }

    $updated = false;

    $display_name = dms_member_pick_value($extra, array('display_name', 'name', 'full_name'));
    $first_name = dms_member_pick_value($extra, array('first_name'));
    $last_name = dms_member_pick_value($extra, array('last_name'));
    $update_user = array('ID' => $user_id);
    if ($display_name !== '' && $display_name !== $user->display_name) {
        $update_user['display_name'] = $display_name;
    }
    if ($first_name !== '' && $first_name !== $user->first_name) {
        $update_user['first_name'] = $first_name;
    }
    if ($last_name !== '' && $last_name !== $user->last_name) {
        $update_user['last_name'] = $last_name;
    }
    if (count($update_user) > 1) {
        wp_update_user($update_user);
        $updated = true;
    }

    $company = dms_member_pick_value($extra, array('account_company_name', 'company', 'billing_company'));
    $phone = dms_member_pick_value($extra, array('account_whatsapp', 'whatsapp', 'phone', 'billing_phone'));
    $country_code = dms_member_pick_value($extra, array('account_whatsapp_country_code', 'whatsapp_country_code', 'country_code'));
    $governorate = dms_member_pick_value($extra, array('account_governorate', 'governorate', 'province', 'billing_state'));
    $address = dms_member_pick_value($extra, array('address', 'billing_address_1'));
    if ($company === '') {
        $company = get_user_meta($user_id, 'billing_company', true);
    }
    if ($company === '') {
        $company = get_user_meta($user_id, 'company', true);
    }
    if ($phone === '') {
        $phone = get_user_meta($user_id, 'billing_phone', true);
    }
    if ($phone === '') {
        $phone = get_user_meta($user_id, 'phone', true);
    }
    if ($governorate === '') {
        $governorate = get_user_meta($user_id, 'billing_state', true);
    }
    if ($governorate === '') {
        $governorate = get_user_meta($user_id, 'province', true);
    }
    if ($governorate === '') {
        $governorate = get_user_meta($user_id, 'governorate', true);
    }
    if ($address === '') {
        $address = get_user_meta($user_id, 'billing_address_1', true);
    }
    if ($address === '') {
        $address = get_user_meta($user_id, 'address', true);
    }

    $current_company = get_user_meta($user_id, 'account_company_name', true);
    if ($current_company === '' && $company !== '') {
        update_user_meta($user_id, 'account_company_name', $company);
        $updated = true;
    }

    $current_whatsapp = get_user_meta($user_id, 'account_whatsapp', true);
    if ($current_whatsapp === '' && $phone !== '') {
        update_user_meta($user_id, 'account_whatsapp', $phone);
        $updated = true;
    }

    $current_code = get_user_meta($user_id, 'account_whatsapp_country_code', true);
    if ($current_code === '' && $country_code !== '') {
        update_user_meta($user_id, 'account_whatsapp_country_code', $country_code);
        $updated = true;
    }

    $current_gov = get_user_meta($user_id, 'account_governorate', true);
    if ($current_gov === '' && $governorate !== '') {
        update_user_meta($user_id, 'account_governorate', $governorate);
        $updated = true;
    }

    if (get_user_meta($user_id, 'billing_phone', true) === '' && $phone !== '') {
        update_user_meta($user_id, 'billing_phone', $phone);
        $updated = true;
    }
    if (get_user_meta($user_id, 'billing_company', true) === '' && $company !== '') {
        update_user_meta($user_id, 'billing_company', $company);
        $updated = true;
    }
    if (get_user_meta($user_id, 'billing_state', true) === '' && $governorate !== '') {
        update_user_meta($user_id, 'billing_state', $governorate);
        $updated = true;
    }
    if (get_user_meta($user_id, 'billing_address_1', true) === '' && $address !== '') {
        update_user_meta($user_id, 'billing_address_1', $address);
        $updated = true;
    }

    $group = dms_member_pick_value($extra, array('group', 'dms_user_group'));
    $currency = dms_member_pick_value($extra, array('currency', 'dms_user_currency'));
    $status = dms_member_pick_value($extra, array('status', 'dms_account_status'));

    $current_group = get_user_meta($user_id, 'dms_user_group', true);
    if ($group !== '' && $group !== $current_group) {
        update_user_meta($user_id, 'dms_user_group', $group);
        $updated = true;
    } elseif ($current_group === '') {
        update_user_meta($user_id, 'dms_user_group', 'default');
        $updated = true;
    }

    $current_currency = get_user_meta($user_id, 'dms_user_currency', true);
    if ($currency !== '' && $currency !== $current_currency) {
        update_user_meta($user_id, 'dms_user_currency', $currency);
        $updated = true;
    } elseif ($current_currency === '') {
        update_user_meta($user_id, 'dms_user_currency', 'syp');
        $updated = true;
    }

    $current_status = get_user_meta($user_id, 'dms_account_status', true);
    if ($status !== '' && $status !== $current_status) {
        update_user_meta($user_id, 'dms_account_status', $status);
        $updated = true;
    } elseif ($current_status === '') {
        update_user_meta($user_id, 'dms_account_status', dms_get_default_account_status());
        $updated = true;
    }

    return $updated;
}

/**
 * Repair members by syncing metadata for all customers.
 *
 * @return int
 */
function dms_fix_missing_members() {
    $updated_count = 0;
    $users = get_users(array(
        'role' => 'customer',
        'fields' => array('ID'),
        'number' => -1,
    ));

    foreach ($users as $user) {
        if (dms_sync_member_record($user->ID)) {
            $updated_count++;
        }
    }

    return $updated_count;
}

/**
 * Admin handler for fixing members.
 *
 * @return void
 */
function dms_handle_fix_missing_members() {
    if (!current_user_can('manage_options')) {
        wp_die('Insufficient permissions.');
    }
    check_admin_referer('dms_fix_missing_members_nonce');
    $count = dms_fix_missing_members();
    wp_redirect(admin_url('admin.php?page=dms_members&fixed=' . $count));
    exit;
}
add_action('admin_post_dms_fix_missing_members', 'dms_handle_fix_missing_members');

/**
 * Sync member data after any user registration.
 *
 * @param int $user_id User ID.
 * @return void
 */
function dms_sync_member_record_on_register($user_id) {
    dms_sync_member_record($user_id, array(
        'status' => dms_get_default_account_status()
    ));
}
add_action('user_register', 'dms_sync_member_record_on_register', 20, 1);
