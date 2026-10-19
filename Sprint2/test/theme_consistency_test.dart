import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/app/theme/app_colors.dart';
import 'package:gather/app/theme/app_theme.dart';
import 'package:gather/core/widgets/gather_button.dart';

/// The theme forces a full-width, 56px-tall shape onto every FilledButton so
/// the app's primary actions look identical everywhere. These tests check that
/// the same rule does not leak into places where it would be wrong — dialog
/// actions in particular.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('GatherButton is the full-width 56px page action', (tester) async {
    await tester.pumpWidget(host(
      SizedBox(width: 300, child: GatherButton(label: 'Continue', onPressed: () {})),
    ));
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, 56);
    expect(size.width, 300);
  });

  testWidgets('a compact GatherButton is shorter but still full width',
      (tester) async {
    await tester.pumpWidget(host(
      SizedBox(
        width: 300,
        child: GatherButton(label: 'Join', compact: true, onPressed: () {}),
      ),
    ));
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.height, lessThan(56), reason: 'compact is shorter than a page button');
    expect(size.height, greaterThanOrEqualTo(48),
        reason: 'must still meet the 48dp minimum tap target');
    expect(size.width, 300);
  });

  testWidgets('a non-expanding GatherButton sizes to its label', (tester) async {
    await tester.pumpWidget(host(
      GatherButton(label: 'Spin', expand: false, onPressed: () {}),
    ));
    expect(tester.getSize(find.byType(FilledButton)).width, lessThan(200));
  });

  testWidgets('GatherOutlineButton matches the primary button geometry',
      (tester) async {
    await tester.pumpWidget(host(
      SizedBox(
        width: 300,
        child: GatherOutlineButton(label: 'Cancel', onPressed: () {}),
      ),
    ));
    final size = tester.getSize(find.byType(OutlinedButton));
    expect(size.height, 56, reason: 'primary and secondary actions must line up');
    expect(size.width, 300);
  });

  testWidgets('dialog action buttons do not inherit the full-width rule',
      (tester) async {
    await tester.pumpWidget(host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove item?'),
              content: const Text('This cannot be undone.'),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Cancel')),
                FilledButton(onPressed: () {}, child: const Text('Remove')),
              ],
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final dialog = tester.getSize(find.byType(AlertDialog));
    final action = tester.getSize(find.widgetWithText(FilledButton, 'Remove'));

    expect(
      action.width,
      lessThan(dialog.width * 0.75),
      reason: 'a dialog action should size to its label, not span the dialog',
    );
    expect(action.height, lessThanOrEqualTo(48),
        reason: 'a dialog action should not be a 56px page button');
  });

  test('brand colours carry enough contrast for the text placed on them', () {
    double luminance(Color c) {
      double channel(double v) =>
          v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      final r = channel(c.r), g = channel(c.g), b = channel(c.b);
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    double ratio(Color a, Color b) {
      final la = luminance(a), lb = luminance(b);
      final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    // White label on the primary action.
    // AA for normal-size text: the button label is 17px bold.
    expect(ratio(AppColors.primary, const Color(0xFFFFFFFF)), greaterThan(4.5));
    // Body text on the beige page and on a card.
    expect(ratio(AppColors.ink, AppColors.background), greaterThan(7.0));
    expect(ratio(AppColors.ink, AppColors.surface), greaterThan(7.0));
    // Muted text still has to clear the normal-text bar on beige.
    expect(ratio(AppColors.inkMuted, AppColors.background), greaterThan(4.4));
    // Dark ink on the reward accent.
    expect(ratio(AppColors.ink, AppColors.accent), greaterThan(4.5));
  });
}
