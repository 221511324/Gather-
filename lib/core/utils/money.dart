import 'package:intl/intl.dart';

/// Currency formatting.
///
/// Gather is built for a Saudi campus, so amounts are in Saudi riyals. The
/// symbol lives in one place: change [currencyCode] and every price, split and
/// total in the app follows.
abstract final class Money {
  static const currencyCode = 'SAR';

  static final _compact = NumberFormat('#,##0.00', 'en');
  static final _whole = NumberFormat('#,##0', 'en');

  /// "SAR 42.50" — the default for prices, totals and split amounts.
  static String format(num value) => '$currencyCode ${_compact.format(value)}';

  /// "42.50" — when the currency is already stated nearby (e.g. a totals row).
  static String plain(num value) => _compact.format(value);

  /// "42" — for badges where space is tight and cents are noise.
  static String whole(num value) => '$currencyCode ${_whole.format(value)}';

  /// Rounds to two decimals so repeated splitting cannot drift.
  static double round(double value) => (value * 100).roundToDouble() / 100;

  /// Splits [total] across [count] people without losing or inventing cents:
  /// the remainder lands on the first shares.
  static List<double> splitEvenly(double total, int count) {
    if (count <= 0) return const [];
    final cents = (total * 100).round();
    final base = cents ~/ count;
    final remainder = cents % count;
    return List.generate(count, (i) => ((base + (i < remainder ? 1 : 0)) / 100));
  }
}
