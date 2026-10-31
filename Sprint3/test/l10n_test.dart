import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/l10n/arabic.dart';
import 'package:gather/core/l10n/tr.dart';

void main() {
  group('translate', () {
    test('returns the English in English', () {
      expect(translate('en', 'Settings'), 'Settings');
    });

    test('returns the Arabic in Arabic', () {
      expect(translate('ar', 'Settings'), 'الإعدادات');
    });

    test('falls back to the English when there is no entry', () {
      expect(translate('ar', 'Pizza Palace'), 'Pizza Palace');
    });

    test('a noted key shows only the word, and has its own Arabic', () {
      expect(translate('en', 'Home|address'), 'Home');
      expect(translate('ar', 'Home|address'), 'المنزل');
      expect(translate('ar', 'Home'), 'الرئيسية');
    });

    test('a noted key with no entry of its own uses the plain word', () {
      expect(translate('ar', 'Settings|address'), 'الإعدادات');
      expect(translate('ar', "Mum's place|address"), "Mum's place");
    });

    test('a sentence finished in code matches its template', () {
      expect(translate('ar', 'Rama invited you'), contains('Rama'));
      expect(translate('ar', 'Rama invited you'), isNot(contains('invited')));
    });

    test('template matching leaves data alone', () {
      expect(translate('ar', 'Burger Barn · Riyadh'), 'Burger Barn · Riyadh');
      expect(translate('en', 'Rama invited you'), 'Rama invited you');
    });

    test('data kept inside Arabic is isolated, and isolated data is never a key', () {
      expect(translate('ar', 'Rama invited you'), contains('\u2068Rama\u2069'));
      expect(translate('ar', '\u2068Settings\u2069'), '\u2068Settings\u2069');
    });

    test('fills placeholders in either language', () {
      expect(translate('en', '{n} left', {'n': 3}), '3 left');
    });

    // Arabic may drop a count it spells out ("عضو واحد" for "{count} member"),
    // but a placeholder the English never fills would show up as raw braces.
    test('no Arabic entry uses a placeholder its English key does not', () {
      final placeholder = RegExp(r'\{\w+\}');
      for (final MapEntry(:key, :value) in arabic.entries) {
        final english = placeholder.allMatches(key).map((m) => m[0]).toSet();
        final translated = placeholder.allMatches(value).map((m) => m[0]).toSet();
        expect(english.containsAll(translated), isTrue, reason: key);
      }
    });
  });

  // The exact English the services build, with names, codes and amounts
  // already in it. Once translated, the only Latin left should be the data.
  group('sentences finished in services', () {
    String withoutData(String text, List<String> data) {
      for (final d in data) {
        text = text.replaceAll(d, '');
      }
      return text;
    }

    void expectArabic(String english, List<String> data) {
      final arabic = translate('ar', english);
      for (final d in data) {
        expect(arabic, contains(d), reason: english);
      }
      expect(withoutData(arabic, [...data, 'SAR']), isNot(matches(RegExp('[A-Za-z]'))),
          reason: '$english -> $arabic');
    }

    test('service errors', () {
      expectArabic('Pizza Palace has a minimum order of SAR 42.50', ['Pizza Palace', 'SAR 42.50']);
      expectArabic('This session is full — it already has 20 people', ['20']);
      expectArabic('WELCOME10 has expired', ['WELCOME10']);
      expectArabic('WELCOME10 is not available', ['WELCOME10']);
      expectArabic('They already have WELCOME10', ['WELCOME10']);
      expectArabic('No reward found for FREEDEL', ['FREEDEL']);
      expectArabic('WELCOME10 needs an order of at least 50 SAR', ['WELCOME10', '50']);
      expectArabic('Apple Pay is already set up', ['Apple Pay']);
      expectArabic('Bank transfer is already on the list', ['Bank transfer']);
      expectArabic('Kudu has already been suggested — by you', ['Kudu']);
      expectArabic('Kudu has already been suggested', ['Kudu']);
      expectArabic(
          'You have already suggested Kudu. Withdraw it first if you want to put forward a different one.',
          ['Kudu']);
      expectArabic(
          'This group is the restaurant for this order — that item is from somewhere else', []);
    });

    test('stored notifications', () {
      expectArabic('Rama invited you', ['Rama']);
      expectArabic('Join "Team lunch" with code 4821.', ['Team lunch', '4821']);
    });

    test('assistant replies, lists and all', () {
      expectArabic('Quickest right now: Kudu (about 20 min), Al Baik (about 25 min), Herfy (about 30 min).',
          ['Kudu', 'Al Baik', 'Herfy', '20', '25', '30']);
      expectArabic('Quickest right now: Kudu (about 20 min).', ['Kudu', '20']);
      expectArabic('Nothing vegan under 30 SAR is available right now.', ['30']);
      expectArabic('For something sweet: Kunafa at Kudu (18 SAR), Basbousa at Herfy (12 SAR).',
          ['Kunafa', 'Kudu', 'Basbousa', 'Herfy', '18', '12']);
      expectArabic('Here is what I would order: Kabsa at Najd Village (45 SAR).',
          ['Kabsa', 'Najd Village', '45']);
      expectArabic(
          'Kudu is closed at the moment — Burgers, rated 4.5, about 25 minutes. The best rated there: '
          'Burger (24 SAR), Fries (9 SAR), Shake (12 SAR).',
          ['Kudu', 'Burgers', '4.5', '25', 'Burger', 'Fries', 'Shake']);
      expectArabic('Kudu has nothing on the menu right now.', ['Kudu']);
    });
  });

  testWidgets('context.tr follows the app locale', (tester) async {
    Widget app(Locale locale) => MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(builder: (context) => Text(context.tr('Settings'))),
        );

    await tester.pumpWidget(app(const Locale('en')));
    expect(find.text('Settings'), findsOneWidget);

    await tester.pumpWidget(app(const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text('الإعدادات'), findsOneWidget);
  });
}
