import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Date and time formatting in the app's language.
///
/// Every date on screen goes through here, so it is written with the locale
/// chosen in settings rather than intl's default. Digits stay Western in both
/// languages, matching prices (`Money`) and the counts in translated copy, so
/// a list never mixes "قبل 5 د" with "٣١/١٠".
abstract final class Dates {
  /// "31/10" — a short date where the year is obvious.
  static String dayMonth(BuildContext context, DateTime date) =>
      _format(context, 'd/M', date);

  /// "31/10/2026".
  static String dayMonthYear(BuildContext context, DateTime date) =>
      _format(context, 'd/M/y', date);

  /// "09:05" — a 24-hour clock time.
  static String time(BuildContext context, DateTime date) =>
      _format(context, 'HH:mm', date);

  static String _format(BuildContext context, String pattern, DateTime date) =>
      (DateFormat(pattern, Localizations.localeOf(context).toLanguageTag())
            ..useNativeDigits = false)
          .format(date);
}
