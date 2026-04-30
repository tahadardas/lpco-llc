<?php
/**
 * Caching Module - DMS Ecom
 * إدارة الـ Cache المركزية
 */

if (!defined('ABSPATH')) {
    exit;
}

namespace DMS\Ecom;

class CacheManager {
    private static $prefix = 'dms_';
    private static $group = 'dms_api';
    private static $default_expiry = 3600; // 1 hour
    
    /**
     * Set cache with proper prefix
     */
    public static function set($key, $value, $expiry = null) {
        $expiry = $expiry ?? self::$default_expiry;
        $full_key = self::$prefix . sanitize_key($key);
        
        return wp_cache_set($full_key, $value, self::$group, $expiry);
    }
    
    /**
     * Get cache
     */
    public static function get($key) {
        $full_key = self::$prefix . sanitize_key($key);
        $cached = wp_cache_get($full_key, self::$group);
        
        if ($cached === false) {
            // Try transient as fallback
            $cached = get_transient($full_key);
        }
        
        return $cached;
    }
    
    /**
     * Delete cache
     */
    public static function delete($key) {
        $full_key = self::$prefix . sanitize_key($key);
        wp_cache_delete($full_key, self::$group);
        delete_transient($full_key);
        return true;
    }
    
    /**
     * Flush all DMS cache
     */
    public static function flush() {
        global $wpdb;
        
        // Delete all DMS transients
        $wpdb->query(
            "DELETE FROM {$wpdb->options} 
             WHERE option_name LIKE '_transient_%dms_%' 
             OR option_name LIKE '_transient_%lpco_dms_%'
             OR option_name LIKE '_transient_timeout_%dms_%'"
        );

        $wpdb->query(
            "DELETE FROM {$wpdb->options} 
             WHERE option_name LIKE '_transient_timeout_%lpco_dms_%'"
        );
        
        // Also try to flush object cache
        wp_cache_flush();

        if (function_exists('\\lpco_dms_flush_catalog_api_cache')) {
            \lpco_dms_flush_catalog_api_cache();
        }
        
        \dms_ecom_log('info', 'All DMS caches flushed');
        return true;
    }
    
    /**
     * Cache decorator pattern
     */
    public static function remember($key, $callback, $expiry = null) {
        // Try to get from cache
        $cached = self::get($key);
        if ($cached !== false) {
            return $cached;
        }
        
        // Call the callback to get fresh data
        $value = call_user_func($callback);
        
        // Store in cache
        self::set($key, $value, $expiry);
        
        return $value;
    }
    
    /**
     * Cache product data
     */
    public static function cache_product_data($product_id, $expiry = null) {
        return self::remember('product_' . $product_id, function() use ($product_id) {
            $product = wc_get_product($product_id);
            if (!$product) {
                return null;
            }
            
            return [
                'id' => $product->get_id(),
                'name' => $product->get_name(),
                'price' => $product->get_price(),
                'stock' => $product->get_stock_quantity(),
                'description' => $product->get_short_description(),
                'image' => $product->get_image_id()
            ];
        }, $expiry);
    }
    
    /**
     * Cache category data
     */
    public static function cache_category_data($category_id, $expiry = null) {
        return self::remember('category_' . $category_id, function() use ($category_id) {
            $term = get_term($category_id);
            if (!$term || is_wp_error($term)) {
                return null;
            }
            
            return [
                'id' => $term->term_id,
                'name' => $term->name,
                'slug' => $term->slug,
                'description' => $term->description,
                'count' => $term->count
            ];
        }, $expiry);
    }
    
    /**
     * Cache user data
     */
    public static function cache_user_data($user_id, $expiry = null) {
        return self::remember('user_' . $user_id, function() use ($user_id) {
            $user = get_user_by('ID', $user_id);
            if (!$user) {
                return null;
            }
            
            $user_meta = get_user_meta($user_id);
            
            return [
                'id' => $user->ID,
                'email' => $user->user_email,
                'name' => $user->display_name,
                'role' => implode(',', $user->roles),
                'meta' => $user_meta
            ];
        }, $expiry);
    }
    
    /**
     * Cache list of products
     */
    public static function cache_products_list($args = [], $expiry = null) {
        $cache_key = 'products_' . md5(json_encode($args));
        
        return self::remember($cache_key, function() use ($args) {
            $defaults = [
                'post_type' => 'product',
                'posts_per_page' => 50,
                'fields' => 'ids'
            ];
            
            $query_args = wp_parse_args($args, $defaults);
            $query = new \WP_Query($query_args);
            
            return array_map(function($product_id) {
                return self::cache_product_data($product_id);
            }, $query->posts);
        }, $expiry);
    }
    
    /**
     * Cache list of users
     */
    public static function cache_users_list($args = [], $expiry = null) {
        $cache_key = 'users_' . md5(json_encode($args));
        
        return self::remember($cache_key, function() use ($args) {
            $defaults = [
                'number' => 100,
                'fields' => 'ids'
            ];
            
            $query_args = wp_parse_args($args, $defaults);
            $users = get_users($query_args);
            
            return array_map(function($user_id) {
                return self::cache_user_data($user_id);
            }, $users);
        }, $expiry);
    }
    
    /**
     * Get cache statistics
     */
    public static function get_stats() {
        global $wpdb;
        
        $total_cache = $wpdb->get_var(
            "SELECT COUNT(*) FROM {$wpdb->options} 
             WHERE option_name LIKE '_transient_%dms_%'"
        );
        
        return [
            'total_cache_items' => intval($total_cache),
            'cache_prefix' => self::$prefix,
            'default_expiry' => self::$default_expiry,
            'timestamp' => current_time('mysql')
        ];
    }
}
