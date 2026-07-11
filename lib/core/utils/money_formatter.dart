import 'package:intl/intl.dart';

class MoneyFormatter {
  const MoneyFormatter._();

  static final NumberFormat _number = NumberFormat.decimalPattern('ar_DZ');

  static String dinar(num value) => '${_number.format(value)} دج';

  static String thousands(num dinarValue) {
    final scaled = dinarValue / 10;
    final text = scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
    return '$text ألف';
  }

  static String format(num value, {required bool useThousands}) =>
      useThousands ? thousands(value) : dinar(value);

  static double thousandsToDinar(num thousandsValue) => thousandsValue * 10;
}
