<?php

class DMS_User_Account_Api_Test extends WP_UnitTestCase {
    public function test_registration_accepts_missing_phone() {
        $request = new WP_REST_Request('POST', '/dms/v1/register');
        $request->set_body(wp_json_encode(array(
            'username' => 'no_phone_customer',
            'password' => 'secure-password',
            'email' => 'no-phone@example.com',
            'company' => 'شركة اختبار',
        )));
        $request->set_header('Content-Type', 'application/json');

        $result = dms_register_user($request);
        $this->assertIsArray($result);
        $this->assertNotEmpty($result['id']);
        $this->assertSame('', get_user_meta($result['id'], 'billing_phone', true));
        wp_delete_user($result['id']);
    }

    public function test_profile_update_can_clear_phone_with_null() {
        $user_id = self::factory()->user->create(array('role' => 'customer'));
        update_user_meta($user_id, 'billing_phone', '+963944611303');
        wp_set_current_user($user_id);

        $request = new WP_REST_Request('POST', '/dms/v1/user/' . $user_id);
        $request->set_param('id', $user_id);
        $request->set_body(wp_json_encode(array('phone' => null)));
        $request->set_header('Content-Type', 'application/json');
        $result = dms_update_user_profile($request);

        $this->assertTrue($result['success']);
        $this->assertSame('', get_user_meta($user_id, 'billing_phone', true));
    }

    public function test_delete_endpoint_ignores_foreign_user_id() {
        $password = 'secure-password';
        $current_id = self::factory()->user->create(array(
            'role' => 'customer',
            'user_pass' => $password,
        ));
        $other_id = self::factory()->user->create(array('role' => 'customer'));
        wp_set_current_user($current_id);

        $request = new WP_REST_Request('DELETE', '/dms/v1/account');
        $request->set_body(wp_json_encode(array(
            'password' => $password,
            'user_id' => $other_id,
        )));
        $request->set_header('Content-Type', 'application/json');
        $response = dms_delete_current_account($request);

        $this->assertInstanceOf(WP_REST_Response::class, $response);
        $this->assertFalse(get_userdata($current_id));
        $this->assertNotFalse(get_userdata($other_id));
    }
}
