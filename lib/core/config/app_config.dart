import 'package:flutter/material.dart';

class AppConfig {
  static String get baseUrl => String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://lpco-llc.com',
  );
  static String get wpApiBase => '$baseUrl/wp-json';
  static String get dmsApiBase => '$baseUrl/wp-json/dms/v1';
  static String get jwtApiBase => '$baseUrl/wp-json/jwt-auth/v1';

  static const int productsPerPage = 12;
  static const int categoriesPerPage = 100;
  static const int brandsPerPage = 50;
}

class AppCurrency {
  final String code;
  final String symbol;
  final int decimals;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.decimals,
  });
}

class AppCurrencies {
  static const AppCurrency syp = AppCurrency(
    code: 'syp',
    symbol: '\u0644.\u0633',
    decimals: 0,
  );

  static const AppCurrency usd = AppCurrency(
    code: 'usd',
    symbol: r'$',
    decimals: 2,
  );

  static String normalizeCode(String? code) {
    final raw = (code ?? '').trim().toLowerCase();
    if (raw.isEmpty) return syp.code;

    final compact = raw.replaceAll(RegExp(r'\s+'), '');

    if (raw == 'usd' ||
        raw == r'$' ||
        compact == 'usd' ||
        raw.contains('dollar') ||
        raw.contains('\u062f\u0648\u0644\u0627\u0631') ||
        raw.contains('\u0623\u0645\u0631\u064a\u0643')) {
      return usd.code;
    }

    if (raw == 'syp' ||
        raw == 'syrian' ||
        compact.contains('\u0644.\u0633') ||
        compact.contains('\u0644\u0633') ||
        raw.contains('\u0633\u0648\u0631') ||
        raw.contains('\u0644\u064a\u0631\u0629')) {
      return syp.code;
    }

    return syp.code;
  }

  static AppCurrency resolve(String? code) {
    final normalized = normalizeCode(code);
    if (normalized == usd.code) return usd;
    return syp;
  }
}

class AppBankAccount {
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String accountType;
  final String transferType;
  final String transferReason;
  final String phone;

  const AppBankAccount({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.accountType,
    required this.transferType,
    required this.transferReason,
    required this.phone,
  });
}

class AppStaticData {
  static const List<String> provinces = <String>[
    '\u062f\u0645\u0634\u0642',
    '\u0631\u064a\u0641 \u062f\u0645\u0634\u0642',
    '\u062d\u0644\u0628',
    '\u062d\u0645\u0635',
    '\u062d\u0645\u0627\u0629',
    '\u0627\u0644\u0644\u0627\u0630\u0642\u064a\u0629',
    '\u0637\u0631\u0637\u0648\u0633',
    '\u0625\u062f\u0644\u0628',
    '\u0627\u0644\u062d\u0633\u0643\u0629',
    '\u0627\u0644\u0631\u0642\u0629',
    '\u062f\u064a\u0631 \u0627\u0644\u0632\u0648\u0631',
    '\u0627\u0644\u0633\u0648\u064a\u062f\u0627\u0621',
    '\u062f\u0631\u0639\u0627',
    '\u0627\u0644\u0642\u0646\u064a\u0637\u0631\u0629',
  ];

  static const List<AppBankAccount> bankAccounts = <AppBankAccount>[
    AppBankAccount(
      bankName:
          '\u0628\u0646\u0643 \u0627\u0644\u0634\u0627\u0645 \u0627\u0644\u0625\u0633\u0644\u0627\u0645\u064a',
      accountNumber: '7008080',
      accountHolder:
          '\u0634\u0631\u0643\u0629 \u0644\u0628\u0643\u0648 \u0627\u0644\u0645\u062d\u062f\u0648\u062f\u0629 \u0627\u0644\u0645\u0633\u0624\u0648\u0644\u064a\u0629',
      accountType: '\u062d\u0633\u0627\u0628 \u062c\u0627\u0631\u064a',
      transferType: '\u0625\u064a\u062f\u0627\u0639 \u0646\u0642\u062f\u064a',
      transferReason:
          '\u062b\u0645\u0646 \u0642\u0631\u0637\u0627\u0633\u064a\u0629 \u0648\u0644\u0648\u0627\u0632\u0645 \u0645\u062f\u0631\u0633\u064a\u0629',
      phone: '0944611303',
    ),
    AppBankAccount(
      bankName:
          '\u0628\u0646\u0643 \u0633\u0648\u0631\u064a\u0627 \u0627\u0644\u062f\u0648\u0644\u064a \u0627\u0644\u0625\u0633\u0644\u0627\u0645\u064a',
      accountNumber: '708080',
      accountHolder:
          '\u0634\u0631\u0643\u0629 \u0644\u0628\u0643\u0648 \u0627\u0644\u0645\u062d\u062f\u0648\u062f\u0629 \u0627\u0644\u0645\u0633\u0624\u0648\u0644\u064a\u0629',
      accountType: '\u062d\u0633\u0627\u0628 \u062c\u0627\u0631\u064a',
      transferType: '\u0625\u064a\u062f\u0627\u0639 \u0646\u0642\u062f\u064a',
      transferReason:
          '\u062b\u0645\u0646 \u0642\u0631\u0637\u0627\u0633\u064a\u0629 \u0648\u0644\u0648\u0627\u0632\u0645 \u0645\u062f\u0631\u0633\u064a\u0629',
      phone: '0944611303',
    ),
    AppBankAccount(
      bankName:
          '\u0628\u0646\u0643 \u0627\u0644\u0628\u0631\u0643\u0629 \u0627\u0644\u0625\u0633\u0644\u0627\u0645\u064a',
      accountNumber: '7128080',
      accountHolder:
          '\u0634\u0631\u0643\u0629 \u0644\u0628\u0643\u0648 \u0627\u0644\u0645\u062d\u062f\u0648\u062f\u0629 \u0627\u0644\u0645\u0633\u0624\u0648\u0644\u064a\u0629',
      accountType: '\u062d\u0633\u0627\u0628 \u062c\u0627\u0631\u064a',
      transferType: '\u0625\u064a\u062f\u0627\u0639 \u0646\u0642\u062f\u064a',
      transferReason:
          '\u062b\u0645\u0646 \u0642\u0631\u0637\u0627\u0633\u064a\u0629 \u0648\u0644\u0648\u0627\u0632\u0645 \u0645\u062f\u0631\u0633\u064a\u0629',
      phone: '0944611303',
    ),
    AppBankAccount(
      bankName:
          '\u0627\u0644\u0628\u0646\u0643 \u0627\u0644\u0648\u0637\u0646\u064a NIB',
      accountNumber: '28080',
      accountHolder:
          '\u0634\u0631\u0643\u0629 \u0644\u0628\u0643\u0648 \u0627\u0644\u0645\u062d\u062f\u0648\u062f\u0629 \u0627\u0644\u0645\u0633\u0624\u0648\u0644\u064a\u0629',
      accountType: '\u062d\u0633\u0627\u0628 \u062c\u0627\u0631\u064a',
      transferType: '\u0625\u064a\u062f\u0627\u0639 \u0646\u0642\u062f\u064a',
      transferReason:
          '\u062b\u0645\u0646 \u0642\u0631\u0637\u0627\u0633\u064a\u0629 \u0648\u0644\u0648\u0627\u0632\u0645 \u0645\u062f\u0631\u0633\u064a\u0629',
      phone: '0944611303',
    ),
  ];

  static const List<String> contactPhones = <String>[
    '00963944611303',
    '00963965433110',
    '0118018',
  ];

  static const String contactEmail = 'info@lpco-llc.com';
  static const String contactAddress =
      '\u062f\u0645\u0634\u0642 - \u062d\u0644\u0628\u0648\u0646\u064a - \u062c\u0627\u062f\u0629 \u0627\u0628\u0646 \u0633\u064a\u0646\u0627';
  static const String mapLabel = 'Halboni, Syria';
}

class UiValues {
  static const EdgeInsets pagePadding = EdgeInsets.all(16);
  static const double cardRadius = 16;
  static const double sectionSpacing = 16;
}
