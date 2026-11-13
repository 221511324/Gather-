import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/models/spin.dart';
import 'package:gather/features/rewards/spin_win_banner.dart';
import 'package:gather/features/rewards/spin_win_screen.dart';

/// FR25 widget tests — the Spin & Win banner, TC_SW_020+.
void main() {
  Widget banner(DateTime? lastSpinAt) => ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('u1'),
          lastSpinAtProvider.overrideWithValue(lastSpinAt),
        ],
        child: const MaterialApp(home: Scaffold(body: SpinWinBanner())),
      );

  testWidgets('TC_SW_020 says the spin is ready when it is', (tester) async {
    await tester.pumpWidget(banner(null));
    expect(find.text('Spin & Win'), findsOneWidget);
    expect(find.text('Your free spin is ready'), findsOneWidget);
  });

  testWidgets('TC_SW_021 counts down when it is not', (tester) async {
    final last = DateTime.now().subtract(const Duration(hours: 10, minutes: 40));
    await tester.pumpWidget(banner(last));
    expect(find.textContaining('Next spin in 13h'), findsOneWidget);

    final recent = DateTime.now().subtract(const Duration(hours: 23, minutes: 59, seconds: 30));
    await tester.pumpWidget(banner(recent));
    expect(find.textContaining('Next spin in 0m'), findsOneWidget,
        reason: 'the last hour counts minutes and seconds');
  });

  Widget screen(DateTime? lastSpinAt) => ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('u1'),
          lastSpinAtProvider.overrideWithValue(lastSpinAt),
          spinWheelProvider.overrideWith((_) => Stream.value(SpinRules.defaultPrizes)),
        ],
        child: const MaterialApp(home: SpinWinScreen()),
      );

  FilledButton spinButton(WidgetTester tester) => tester.widget<FilledButton>(find.descendant(
      of: find.byKey(const ValueKey('spin-button')), matching: find.byType(FilledButton)));

  testWidgets('TC_SW_022 the Spin button is live when a spin is open', (tester) async {
    await tester.pumpWidget(screen(null));
    await tester.pump();
    expect(find.byKey(const ValueKey('spin-countdown')), findsNothing);
    expect(spinButton(tester).onPressed, isNotNull);
  });

  testWidgets('TC_SW_023 the Spin button is off, with a countdown, after a spin', (tester) async {
    await tester.pumpWidget(screen(DateTime.now().subtract(const Duration(hours: 2))));
    await tester.pump();
    expect(find.textContaining('Next spin in 21h'), findsOneWidget);
    expect(spinButton(tester).onPressed, isNull);
  });
}
