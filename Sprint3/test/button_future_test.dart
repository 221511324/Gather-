import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/widgets/gather_button.dart';

/// Regression test for BUG-015 — the button that appeared to hang.
///
/// GatherButton awaits whatever its callback returns and shows a spinner until
/// it completes. Dart lets a callback declared `void` return a Future without
/// complaint, so `onPressed: () => openASheet()` silently handed the button a
/// future that only completed when the sheet closed. These two tests pin the
/// difference between the shape that caused it and the shape that fixes it.
void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('TC_UB_001 an arrow callback returning a Future leaves the button busy',
      (tester) async {
    final opened = Completer<void>();

    await tester.pumpWidget(host(GatherButton(
      label: 'Add card',
      // The shape that caused BUG-015.
      onPressed: () => opened.future,
    )));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Add card'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'the button is waiting on a future it should never have been given');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull,
        reason: 'and is disabled while it waits');

    opened.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('TC_UB_002 a block body discards the Future and the button stays usable',
      (tester) async {
    final opened = Completer<void>();

    await tester.pumpWidget(host(GatherButton(
      label: 'Add card',
      // The fix.
      onPressed: () {
        opened.future;
      },
    )));

    await tester.tap(find.text('Add card'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'opening a sheet must not put the button into its loading state');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull,
        reason: 'and it must still be tappable');

    opened.complete();
  });

  testWidgets('TC_UB_003 a genuine async action still shows progress', (tester) async {
    final work = Completer<void>();

    await tester.pumpWidget(host(GatherButton(
      label: 'Save',
      onPressed: () async => work.future,
    )));

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: 'real work should still spin — the fix must not remove that');

    work.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
