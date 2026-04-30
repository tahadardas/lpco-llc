import 'package:lpco_llc/core/utils/text_sanitizer.dart';

double _toDouble(dynamic value) => double.tryParse('$value') ?? 0;
int _toInt(dynamic value) => int.tryParse('$value') ?? 0;
bool _toBool(dynamic value) {
  if (value is bool) return value;
  final normalized = TextSanitizer.fix(value).toLowerCase();
  return normalized == '1' ||
      normalized == 'true' ||
      normalized == 'yes' ||
      normalized == 'on';
}

class AdminPagedResponse<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const AdminPagedResponse({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  factory AdminPagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItem,
  ) {
    final meta = Map<String, dynamic>.from(
      (json['meta'] as Map?) ?? const <String, dynamic>{},
    );
    final rawItems = (json['items'] as List?) ?? const <dynamic>[];

    return AdminPagedResponse<T>(
      items: rawItems
          .whereType<Map>()
          .map((item) => fromItem(Map<String, dynamic>.from(item)))
          .toList(),
      page: _toInt(meta['page']) == 0 ? 1 : _toInt(meta['page']),
      perPage: _toInt(meta['per_page']) == 0
          ? rawItems.length
          : _toInt(meta['per_page']),
      total: _toInt(meta['total']),
      totalPages: _toInt(meta['total_pages']) == 0
          ? 1
          : _toInt(meta['total_pages']),
    );
  }
}

class AdminTermModel {
  final int id;
  final String name;
  final String slug;
  final String imageUrl;
  final bool showInApp;
  final bool hidden;

  const AdminTermModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    this.showInApp = true,
    this.hidden = false,
  });

  factory AdminTermModel.fromJson(Map<String, dynamic> json) {
    return AdminTermModel(
      id: _toInt(json['id']),
      name: TextSanitizer.fix(json['name']),
      slug: TextSanitizer.fix(json['slug']),
      imageUrl: TextSanitizer.fix(json['image_url']),
      showInApp: json.containsKey('show_in_app')
          ? _toBool(json['show_in_app'])
          : (json.containsKey('hidden') ? !_toBool(json['hidden']) : true),
      hidden: json.containsKey('hidden')
          ? _toBool(json['hidden'])
          : (json.containsKey('show_in_app')
                ? !_toBool(json['show_in_app'])
                : false),
    );
  }
}

class AdminOrderSummaryModel {
  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final double total;
  final String currency;
  final String date;
  final String customer;
  final String phone;
  final int customerId;
  final String invoiceUrl;
  final String warehouseCode;
  final String warehouseLabel;
  final List<String> warehouseCodes;

  const AdminOrderSummaryModel({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.total,
    required this.currency,
    required this.date,
    required this.customer,
    required this.phone,
    required this.customerId,
    required this.invoiceUrl,
    this.warehouseCode = '',
    this.warehouseLabel = '',
    this.warehouseCodes = const <String>[],
  });

  factory AdminOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    return AdminOrderSummaryModel(
      id: _toInt(json['id']),
      number: TextSanitizer.fix(json['number'] ?? json['id']),
      status: TextSanitizer.fix(json['status']),
      statusLabel: TextSanitizer.fix(json['status_label'] ?? json['status']),
      total: _toDouble(json['total']),
      currency: TextSanitizer.fix(json['currency']).toLowerCase(),
      date: TextSanitizer.fix(json['date'] ?? json['date_created']),
      customer: TextSanitizer.fix(json['customer']),
      phone: TextSanitizer.fix(json['phone']),
      customerId: _toInt(json['customer_id']),
      invoiceUrl: TextSanitizer.fix(json['invoice_url']),
      warehouseCode: TextSanitizer.fix(json['warehouse_code']),
      warehouseLabel: TextSanitizer.fix(json['warehouse_label']),
      warehouseCodes: ((json['warehouse_codes'] as List?) ?? const <dynamic>[])
          .map((entry) => TextSanitizer.fix(entry))
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class AdminUserModel {
  final int id;
  final String username;
  final String email;
  final String displayName;
  final List<String> roles;
  final String registeredAt;
  final String group;
  final String accountStatus;
  final String phone;
  final String governorate;
  final AdminMemberModel? memberProfile;

  const AdminUserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.roles,
    required this.registeredAt,
    required this.group,
    required this.accountStatus,
    required this.phone,
    required this.governorate,
    this.memberProfile,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final memberProfileRaw = json['member_profile'];
    return AdminUserModel(
      id: _toInt(json['id']),
      username: TextSanitizer.fix(json['username']),
      email: TextSanitizer.fix(json['email']),
      displayName: TextSanitizer.fix(json['display_name']),
      roles: ((json['roles'] as List?) ?? const <dynamic>[])
          .map((role) => TextSanitizer.fix(role))
          .where((role) => role.isNotEmpty)
          .toList(),
      registeredAt: TextSanitizer.fix(json['registered_at']),
      group: TextSanitizer.fix(json['dms_user_group'] ?? json['group']),
      accountStatus: TextSanitizer.fix(json['account_status']),
      phone: TextSanitizer.fix(json['phone']),
      governorate: TextSanitizer.fix(json['governorate']),
      memberProfile: memberProfileRaw is Map
          ? AdminMemberModel.fromJson(
              Map<String, dynamic>.from(memberProfileRaw),
            )
          : null,
    );
  }
}

class AdminMemberModel {
  final int id;
  final String name;
  final String username;
  final String email;
  final String company;
  final String phone;
  final String governorate;
  final String address;
  final String group;
  final String currency;
  final String accountStatus;
  final List<String> roles;
  final String registeredAt;

  const AdminMemberModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.company,
    required this.phone,
    required this.governorate,
    required this.address,
    required this.group,
    required this.currency,
    required this.accountStatus,
    required this.roles,
    required this.registeredAt,
  });

  factory AdminMemberModel.fromJson(Map<String, dynamic> json) {
    return AdminMemberModel(
      id: _toInt(json['id']),
      name: TextSanitizer.fix(json['name']),
      username: TextSanitizer.fix(json['username']),
      email: TextSanitizer.fix(json['email']),
      company: TextSanitizer.fix(json['company']),
      phone: TextSanitizer.fix(json['phone']),
      governorate: TextSanitizer.fix(json['governorate']),
      address: TextSanitizer.fix(json['address']),
      group: TextSanitizer.fix(json['group']),
      currency: TextSanitizer.fix(json['currency']).toLowerCase(),
      accountStatus: TextSanitizer.fix(json['account_status']),
      roles: ((json['roles'] as List?) ?? const <dynamic>[])
          .map((role) => TextSanitizer.fix(role))
          .where((role) => role.isNotEmpty)
          .toList(),
      registeredAt: TextSanitizer.fix(json['registered_at']),
    );
  }
}

class AdminSettingsModel {
  final double exchangeRateUsdSyp;
  final String defaultCurrency;
  final bool allowGuestCheckout;
  final bool enableDebugLogs;
  final List<String> corsAllowedOrigins;
  final String turnstileSiteKey;
  final String turnstileSecretKey;
  final String recaptchaSiteKey;
  final String recaptchaSecretKey;
  final String notificationEmails;

  const AdminSettingsModel({
    required this.exchangeRateUsdSyp,
    required this.defaultCurrency,
    required this.allowGuestCheckout,
    required this.enableDebugLogs,
    required this.corsAllowedOrigins,
    required this.turnstileSiteKey,
    required this.turnstileSecretKey,
    required this.recaptchaSiteKey,
    required this.recaptchaSecretKey,
    required this.notificationEmails,
  });

  factory AdminSettingsModel.fromJson(Map<String, dynamic> json) {
    return AdminSettingsModel(
      exchangeRateUsdSyp: _toDouble(json['exchange_rate_usd_syp']),
      defaultCurrency: TextSanitizer.fix(
        json['default_currency'],
      ).toLowerCase(),
      allowGuestCheckout: _toBool(json['allow_guest_checkout']),
      enableDebugLogs: _toBool(json['enable_debug_logs']),
      corsAllowedOrigins:
          ((json['cors_allowed_origins'] as List?) ?? const <dynamic>[])
              .map((origin) => TextSanitizer.fix(origin))
              .where((origin) => origin.isNotEmpty)
              .toList(),
      turnstileSiteKey: TextSanitizer.fix(json['turnstile_site_key']),
      turnstileSecretKey: TextSanitizer.fix(json['turnstile_secret_key']),
      recaptchaSiteKey: TextSanitizer.fix(json['recaptcha_site_key']),
      recaptchaSecretKey: TextSanitizer.fix(json['recaptcha_secret_key']),
      notificationEmails: TextSanitizer.fix(json['notification_emails']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exchange_rate_usd_syp': exchangeRateUsdSyp,
      'default_currency': defaultCurrency,
      'allow_guest_checkout': allowGuestCheckout,
      'enable_debug_logs': enableDebugLogs,
      'cors_allowed_origins': corsAllowedOrigins,
      'turnstile_site_key': turnstileSiteKey,
      'turnstile_secret_key': turnstileSecretKey,
      'recaptcha_site_key': recaptchaSiteKey,
      'recaptcha_secret_key': recaptchaSecretKey,
      'notification_emails': notificationEmails,
    };
  }
}

class AdminNotificationHistoryModel {
  final int id;
  final String title;
  final String body;
  final String imageUrl;
  final String deepLink;
  final String audience;
  final int targetUserId;
  final String createdAt;
  final bool isDeleted;
  final int receiptsTotal;
  final int deliveredCount;
  final int readCount;
  final int unreadCount;

  const AdminNotificationHistoryModel({
    required this.id,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.deepLink,
    required this.audience,
    required this.targetUserId,
    required this.createdAt,
    required this.isDeleted,
    required this.receiptsTotal,
    required this.deliveredCount,
    required this.readCount,
    required this.unreadCount,
  });

  factory AdminNotificationHistoryModel.fromJson(Map<String, dynamic> json) {
    return AdminNotificationHistoryModel(
      id: _toInt(json['id']),
      title: TextSanitizer.fix(json['title']),
      body: TextSanitizer.fix(json['body']),
      imageUrl: TextSanitizer.fix(json['image_url']),
      deepLink: TextSanitizer.fix(json['deep_link']),
      audience: TextSanitizer.fix(json['audience']),
      targetUserId: _toInt(json['target_user_id']),
      createdAt: TextSanitizer.fix(json['created_at']),
      isDeleted: _toBool(json['is_deleted']),
      receiptsTotal: _toInt(json['receipts_total']),
      deliveredCount: _toInt(json['delivered_count']),
      readCount: _toInt(json['read_count']),
      unreadCount: _toInt(json['unread_count']),
    );
  }
}

class AdminProductModel {
  final int id;
  final String name;
  final String sku;
  final String regularPrice;
  final String salePrice;
  final String effectivePrice;
  final int? stockQuantity;
  final String stockStatus;
  final String imageUrl;
  final List<AdminTermModel> categories;
  final List<AdminTermModel> brands;
  final String status;
  final bool featured;
  final String permalink;
  final int homeOrder;

  const AdminProductModel({
    required this.id,
    required this.name,
    required this.sku,
    required this.regularPrice,
    required this.salePrice,
    required this.effectivePrice,
    required this.stockQuantity,
    required this.stockStatus,
    required this.imageUrl,
    required this.categories,
    required this.brands,
    required this.status,
    required this.featured,
    required this.permalink,
    required this.homeOrder,
  });

  factory AdminProductModel.fromJson(Map<String, dynamic> json) {
    final stockRaw = json['stock_quantity'];
    return AdminProductModel(
      id: _toInt(json['id']),
      name: TextSanitizer.fix(json['name']),
      sku: TextSanitizer.fix(json['sku']),
      regularPrice: TextSanitizer.fix(json['regular_price']),
      salePrice: TextSanitizer.fix(json['sale_price']),
      effectivePrice: TextSanitizer.fix(json['effective_price']),
      stockQuantity: stockRaw == null || '$stockRaw'.isEmpty
          ? null
          : _toInt(stockRaw),
      stockStatus: TextSanitizer.fix(json['stock_status']),
      imageUrl: TextSanitizer.fix(json['image_url']),
      categories: ((json['categories'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AdminTermModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      brands: ((json['brands'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AdminTermModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      status: TextSanitizer.fix(json['status']),
      featured: _toBool(json['featured']),
      permalink: TextSanitizer.fix(json['permalink']),
      homeOrder: _toInt(json['home_order']),
    );
  }
}

class AdminReviewModel {
  final int id;
  final String user;
  final int rating;
  final String content;
  final String date;
  final String status;
  final int productId;
  final String productName;

  const AdminReviewModel({
    required this.id,
    required this.user,
    required this.rating,
    required this.content,
    required this.date,
    required this.status,
    required this.productId,
    required this.productName,
  });

  factory AdminReviewModel.fromJson(Map<String, dynamic> json) {
    final product = Map<String, dynamic>.from(
      (json['product'] as Map?) ?? const <String, dynamic>{},
    );
    return AdminReviewModel(
      id: _toInt(json['id']),
      user: TextSanitizer.fix(json['user']),
      rating: _toInt(json['rating']),
      content: TextSanitizer.fix(json['content']),
      date: TextSanitizer.fix(json['date']),
      status: TextSanitizer.fix(json['status']),
      productId: _toInt(product['id']),
      productName: TextSanitizer.fix(product['name']),
    );
  }
}

class AdminHomeBannerModel {
  final bool enabled;
  final int imageId;
  final String imageUrl;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final String buttonLink;
  final List<int> productIds;

  const AdminHomeBannerModel({
    required this.enabled,
    required this.imageId,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonLink,
    required this.productIds,
  });

  factory AdminHomeBannerModel.fromJson(Map<String, dynamic> json) {
    return AdminHomeBannerModel(
      enabled: _toBool(json['enabled']),
      imageId: _toInt(json['image_id']),
      imageUrl: TextSanitizer.fix(json['image_url']),
      title: TextSanitizer.fix(json['title']),
      subtitle: TextSanitizer.fix(json['subtitle']),
      buttonLabel: TextSanitizer.fix(json['button_label']),
      buttonLink: TextSanitizer.fix(json['button_link']),
      productIds: ((json['product_ids'] as List?) ?? const <dynamic>[])
          .map(_toInt)
          .where((id) => id > 0)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'image_id': imageId,
      'image_url': imageUrl,
      'title': title,
      'subtitle': subtitle,
      'button_label': buttonLabel,
      'button_link': buttonLink,
      'product_ids': productIds,
    };
  }
}

class AdminHomeLayoutModel {
  final String version;
  final int cacheTtl;
  final List<Map<String, dynamic>> sections;
  final String raw;
  final String updatedAt;

  const AdminHomeLayoutModel({
    required this.version,
    required this.cacheTtl,
    required this.sections,
    required this.raw,
    required this.updatedAt,
  });

  factory AdminHomeLayoutModel.fromJson(Map<String, dynamic> json) {
    return AdminHomeLayoutModel(
      version: TextSanitizer.fix(json['version']),
      cacheTtl: _toInt(json['cache_ttl']),
      sections: ((json['sections'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((section) => Map<String, dynamic>.from(section))
          .toList(),
      raw: TextSanitizer.fix(json['raw']),
      updatedAt: TextSanitizer.fix(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'cache_ttl': cacheTtl,
      'sections': sections,
    };
  }
}

class AdminThemeModel {
  final bool enabled;
  final Map<String, String> colors;
  final String updatedAt;

  const AdminThemeModel({
    required this.enabled,
    required this.colors,
    required this.updatedAt,
  });

  factory AdminThemeModel.fromJson(Map<String, dynamic> json) {
    final colors = Map<String, dynamic>.from((json['colors'] as Map?) ?? json);
    colors.remove('enabled');
    final updatedAt = TextSanitizer.fix(
      colors.remove('updated_at') ?? json['updated_at'],
    );
    return AdminThemeModel(
      enabled: _toBool(json['enabled'] ?? true),
      colors: colors.map(
        (key, value) => MapEntry(key, TextSanitizer.fix(value)),
      ),
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'enabled': enabled, ...colors};
  }
}

class AdminPopupConfigModel {
  final bool enabled;
  final String imageUrl;
  final String actionType;
  final String actionValue;

  const AdminPopupConfigModel({
    required this.enabled,
    required this.imageUrl,
    required this.actionType,
    required this.actionValue,
  });

  factory AdminPopupConfigModel.fromJson(Map<String, dynamic> json) {
    return AdminPopupConfigModel(
      enabled: _toBool(json['enabled']),
      imageUrl: TextSanitizer.fix(json['image_url']),
      actionType: TextSanitizer.fix(json['action_type']),
      actionValue: TextSanitizer.fix(json['action_value']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'image_url': imageUrl,
      'action_type': actionType,
      'action_value': actionValue,
    };
  }
}

class AdminOrderingConfigModel {
  final List<int> categories;
  final List<int> brands;
  final List<int> hiddenCategories;
  final List<int> hiddenBrands;
  final List<int> featuredProducts;
  final String updatedAt;
  final List<AdminTermModel> availableCategories;
  final List<AdminTermModel> availableBrands;
  final List<AdminProductOrderOptionModel> availableFeaturedProducts;

  const AdminOrderingConfigModel({
    required this.categories,
    required this.brands,
    required this.hiddenCategories,
    required this.hiddenBrands,
    required this.featuredProducts,
    required this.updatedAt,
    required this.availableCategories,
    required this.availableBrands,
    required this.availableFeaturedProducts,
  });

  factory AdminOrderingConfigModel.fromJson(Map<String, dynamic> json) {
    final config = Map<String, dynamic>.from(
      (json['config'] as Map?) ?? const <String, dynamic>{},
    );
    final available = Map<String, dynamic>.from(
      (json['available'] as Map?) ?? const <String, dynamic>{},
    );
    return AdminOrderingConfigModel(
      categories: ((config['categories'] as List?) ?? const <dynamic>[])
          .map(_toInt)
          .where((id) => id > 0)
          .toList(),
      brands: ((config['brands'] as List?) ?? const <dynamic>[])
          .map(_toInt)
          .where((id) => id > 0)
          .toList(),
      hiddenCategories:
          ((config['hidden_categories'] as List?) ?? const <dynamic>[])
              .map(_toInt)
              .where((id) => id > 0)
              .toList(),
      hiddenBrands: ((config['hidden_brands'] as List?) ?? const <dynamic>[])
          .map(_toInt)
          .where((id) => id > 0)
          .toList(),
      featuredProducts:
          ((config['featured_products'] as List?) ?? const <dynamic>[])
              .map(_toInt)
              .where((id) => id > 0)
              .toList(),
      updatedAt: TextSanitizer.fix(config['updated_at']),
      availableCategories:
          ((available['categories'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) =>
                    AdminTermModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
      availableBrands: ((available['brands'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AdminTermModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      availableFeaturedProducts:
          ((available['featured_products'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => AdminProductOrderOptionModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'categories': categories,
      'brands': brands,
      'hidden_categories': hiddenCategories,
      'hidden_brands': hiddenBrands,
      'featured_products': featuredProducts,
    };
  }

  AdminOrderingConfigModel copyWith({
    List<int>? categories,
    List<int>? brands,
    List<int>? hiddenCategories,
    List<int>? hiddenBrands,
    List<int>? featuredProducts,
    String? updatedAt,
    List<AdminTermModel>? availableCategories,
    List<AdminTermModel>? availableBrands,
    List<AdminProductOrderOptionModel>? availableFeaturedProducts,
  }) {
    return AdminOrderingConfigModel(
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      hiddenCategories: hiddenCategories ?? this.hiddenCategories,
      hiddenBrands: hiddenBrands ?? this.hiddenBrands,
      featuredProducts: featuredProducts ?? this.featuredProducts,
      updatedAt: updatedAt ?? this.updatedAt,
      availableCategories: availableCategories ?? this.availableCategories,
      availableBrands: availableBrands ?? this.availableBrands,
      availableFeaturedProducts:
          availableFeaturedProducts ?? this.availableFeaturedProducts,
    );
  }
}

class AdminProductOrderOptionModel {
  final int id;
  final String name;
  final String imageUrl;

  const AdminProductOrderOptionModel({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory AdminProductOrderOptionModel.fromJson(Map<String, dynamic> json) {
    return AdminProductOrderOptionModel(
      id: _toInt(json['id']),
      name: TextSanitizer.fix(json['name']),
      imageUrl: TextSanitizer.fix(json['image_url']),
    );
  }
}

class AdminDiagnosticItemModel {
  final String id;
  final String label;
  final String status;
  final String value;
  final String details;

  const AdminDiagnosticItemModel({
    required this.id,
    required this.label,
    required this.status,
    required this.value,
    required this.details,
  });

  factory AdminDiagnosticItemModel.fromJson(Map<String, dynamic> json) {
    return AdminDiagnosticItemModel(
      id: TextSanitizer.fix(json['id']),
      label: TextSanitizer.fix(json['label']),
      status: TextSanitizer.fix(json['status']),
      value: TextSanitizer.fix(json['value']),
      details: TextSanitizer.fix(json['details']),
    );
  }
}

class AdminDiagnosticSectionModel {
  final String id;
  final String title;
  final List<AdminDiagnosticItemModel> items;

  const AdminDiagnosticSectionModel({
    required this.id,
    required this.title,
    required this.items,
  });

  factory AdminDiagnosticSectionModel.fromJson(Map<String, dynamic> json) {
    return AdminDiagnosticSectionModel(
      id: TextSanitizer.fix(json['id']),
      title: TextSanitizer.fix(json['title']),
      items: ((json['items'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AdminDiagnosticItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class AdminDiagnosticsModel {
  final String generatedAt;
  final List<AdminDiagnosticSectionModel> sections;
  final List<String> warnings;
  final List<AdminNotificationHistoryModel> latestNotifications;

  const AdminDiagnosticsModel({
    required this.generatedAt,
    required this.sections,
    required this.warnings,
    required this.latestNotifications,
  });

  factory AdminDiagnosticsModel.fromJson(Map<String, dynamic> json) {
    return AdminDiagnosticsModel(
      generatedAt: TextSanitizer.fix(json['generated_at']),
      sections: ((json['sections'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AdminDiagnosticSectionModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const <dynamic>[])
          .map((item) => TextSanitizer.fix(item))
          .where((item) => item.isNotEmpty)
          .toList(),
      latestNotifications:
          ((json['latest_notifications'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => AdminNotificationHistoryModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
    );
  }
}

class AdminDashboardModel {
  final int ordersToday;
  final int ordersMonth;
  final double revenueMonth;
  final int totalMembers;
  final int pendingOrders;
  final int completedOrders;
  final int unreadNotificationsCount;
  final int deviceTokensCount;
  final int lowStockProductsCount;
  final List<AdminOrderSummaryModel> latestOrders;
  final List<AdminMemberModel> latestMembers;
  final List<AdminNotificationHistoryModel> latestNotifications;
  final List<String> warnings;

  const AdminDashboardModel({
    required this.ordersToday,
    required this.ordersMonth,
    required this.revenueMonth,
    required this.totalMembers,
    required this.pendingOrders,
    required this.completedOrders,
    required this.unreadNotificationsCount,
    required this.deviceTokensCount,
    required this.lowStockProductsCount,
    required this.latestOrders,
    required this.latestMembers,
    required this.latestNotifications,
    required this.warnings,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    return AdminDashboardModel(
      ordersToday: _toInt(json['orders_today']),
      ordersMonth: _toInt(json['orders_month']),
      revenueMonth: _toDouble(json['revenue_month']),
      totalMembers: _toInt(json['total_members']),
      pendingOrders: _toInt(json['pending_orders']),
      completedOrders: _toInt(json['completed_orders']),
      unreadNotificationsCount: _toInt(json['unread_notifications_count']),
      deviceTokensCount: _toInt(json['device_tokens_count']),
      lowStockProductsCount: _toInt(json['low_stock_products_count']),
      latestOrders: ((json['latest_orders'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) => AdminOrderSummaryModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      latestMembers: ((json['latest_members'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (item) =>
                AdminMemberModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      latestNotifications:
          ((json['latest_notifications'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => AdminNotificationHistoryModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      warnings: ((json['warnings'] as List?) ?? const <dynamic>[])
          .map((item) => TextSanitizer.fix(item))
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }
}
