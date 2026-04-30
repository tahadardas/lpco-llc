import 'package:lpco_llc/core/config/app_config.dart';
import 'package:lpco_llc/core/utils/text_sanitizer.dart';

class UserModel {
  final int? id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final String userNicename;
  final String group;
  final String currency;
  final String currencySymbol;
  final String status;
  final String companyName;
  final String phone;
  final String address;
  final String city;
  final List<String> roles;
  final bool isGuest;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.userNicename,
    this.group = 'default',
    this.currency = 'syp',
    this.currencySymbol = '\u0644.\u0633',
    this.status = 'نشط',
    this.companyName = '',
    this.phone = '',
    this.address = '',
    this.city = '',
    this.roles = const [],
    this.isGuest = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final dynamic rawRoles = json['roles'];
    final normalizedCurrency = AppCurrencies.normalizeCode(
      json['currency'] ?? json['currency_code'] ?? json['currencySymbol'],
    );

    return UserModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? json['ID'] ?? ''}'),
      username: TextSanitizer.fix(json['username'] ?? json['user_login']),
      email: TextSanitizer.fix(json['email'] ?? json['user_email']),
      firstName: TextSanitizer.fix(json['first_name']),
      lastName: TextSanitizer.fix(json['last_name']),
      displayName: TextSanitizer.fix(
        json['display_name'] ?? json['user_nicename'],
      ),
      userNicename: TextSanitizer.fix(json['user_nicename']),
      group: TextSanitizer.fix(json['group'] ?? 'default').toLowerCase(),
      currency: normalizedCurrency,
      currencySymbol: AppCurrencies.resolve(normalizedCurrency).symbol,
      status: TextSanitizer.fix(json['status'] ?? 'نشط'),
      companyName: TextSanitizer.fix(
        json['companyName'] ?? json['company_name'],
      ),
      phone: TextSanitizer.fix(json['phone']),
      address: TextSanitizer.fix(json['address']),
      city: TextSanitizer.fix(json['city']),
      roles: rawRoles is List
          ? rawRoles.map((e) => TextSanitizer.fix(e)).toList()
          : const <String>[],
      isGuest: json['isGuest'] == true || json['is_guest'] == true,
    );
  }

  factory UserModel.guest() {
    return UserModel(
      id: null,
      username: 'guest',
      email: '',
      firstName: '',
      lastName: '',
      displayName: 'زائر',
      userNicename: 'guest',
      group: 'default',
      currency: 'syp',
      currencySymbol: '\u0644.\u0633',
      status: 'ضيف',
      roles: const <String>[],
      isGuest: true,
    );
  }

  String get fullName {
    final value = '$firstName $lastName'.trim();
    if (value.isNotEmpty) return value;
    if (displayName.isNotEmpty) return displayName;
    return username;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'display_name': displayName,
      'user_nicename': userNicename,
      'group': group,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'status': status,
      'companyName': companyName,
      'phone': phone,
      'address': address,
      'city': city,
      'roles': roles,
      'isGuest': isGuest,
    };
  }
}
