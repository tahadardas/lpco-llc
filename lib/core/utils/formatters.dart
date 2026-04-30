import 'package:intl/intl.dart';
import 'package:lpco_llc/core/config/app_config.dart';

class PriceFormatter {
  static String format(num value, {String currencyCode = 'syp'}) {
    final currency = AppCurrencies.resolve(currencyCode);
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      decimalDigits: currency.decimals,
      symbol: '',
    );
    final amount = formatter.format(value);

    if (currency.code == 'usd') {
      return '${currency.symbol}$amount';
    }

    return '$amount ${currency.symbol}';
  }
}
