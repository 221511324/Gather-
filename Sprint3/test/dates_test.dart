import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/utils/dates.dart';
import 'package:intl/intl.dart';

/// Renders [builder]'s text inside an app in [language], the way the real app
/// sets its locale and delegates.
Future<String> _render(
  WidgetTester tester,
  String language,
  String Function(BuildContext) builder,
) async {
  await tester.pumpWidget(MaterialApp(
    locale: Locale(language),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(builder: (context) => Text(builder(context))),
  ));
  await tester.pumpAndSettle();
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  final date = DateTime(2026, 10, 7, 9, 5);

  testWidgets('English output is unchanged', (tester) async {
    expect(await _render(tester, 'en', (c) => Dates.dayMonth(c, date)), '7/10');
    expect(await _render(tester, 'en', (c) => Dates.dayMonthYear(c, date)), '7/10/2026');
    expect(await _render(tester, 'en', (c) => Dates.time(c, date)), '09:05');
  });

  testWidgets('Arabic keeps Western digits', (tester) async {
    expect(await _render(tester, 'ar', (c) => Dates.dayMonth(c, date)), '7/10');
    expect(await _render(tester, 'ar', (c) => Dates.dayMonthYear(c, date)), '7/10/2026');
    expect(await _render(tester, 'ar', (c) => Dates.time(c, date)), '09:05');
  });

  testWidgets('Arabic date symbols are loaded by the app delegates', (tester) async {
    final month = await _render(
      tester,
      'ar',
      (c) => DateFormat('MMMM', Localizations.localeOf(c).toLanguageTag()).format(date),
    );
    expect(month, 'أكتوبر');
  });
}
