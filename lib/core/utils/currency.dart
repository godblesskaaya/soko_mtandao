import 'package:intl/intl.dart';

String formatTzs(num? amount, {int decimalDigits = 0}) {
  final value = amount ?? 0;
  return NumberFormat.currency(
    symbol: 'TZS ',
    decimalDigits: decimalDigits,
  ).format(value);
}
