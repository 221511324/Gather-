import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// End-to-end tests that run on a real device against the live Firebase
/// project, covering the paths unit tests cannot reach: sign-up writing a
/// profile under the security rules, the catalogue seeding itself, and a host
/// creating a group session with a real 4-digit code.
///
/// Run with:  `flutter test integration_test/app_flow_test.dart -d <device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppPrefs prefs;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    prefs = await AppPrefs.load();
    // Start from a known state rather than whatever the last run left behind.
    await FirebaseAuth.instance.signOut();
  });

  /// Boots the real app with onboarding already dismissed.
  Future<ProviderContainer> bootApp(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [appPrefsProvider.overrideWithValue(prefs)],
    );
    container.read(onboardingSeenProvider.notifier).state = true;

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GatherApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return container;
  }

  /// Everything currently rendered as text — used to explain a timeout
  /// instead of just reporting one.
  String visibleText(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .where((t) => t.trim().isNotEmpty)
      .join(' | ');

  /// Pumps until [read] returns a non-null value. The home screen renders
  /// before the profile stream has emitted, so anything reading the profile
  /// has to wait for it rather than assume it is there.
  Future<T> waitForValue<T>(
    WidgetTester tester,
    T? Function() read, {
    Duration timeout = const Duration(seconds: 30),
    String label = 'a value',
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final value = read();
      if (value != null) return value;
      await tester.pump(const Duration(milliseconds: 250));
    }
    fail('Timed out waiting for $label.');
  }

  /// Pumps repeatedly until [finder] appears or the budget runs out. Real
  /// network round-trips do not fit `pumpAndSettle`'s model.
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 25),
    String? because,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for ${because ?? finder.describeMatch(Plurality.zero)}.\n'
        'On screen: ${visibleText(tester)}');
  }

  testWidgets('a signed-out user lands on the sign-in screen', (tester) async {
    await bootApp(tester);

    expect(find.text('Hello!'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
  });

  testWidgets('sign-up creates a profile, seeds the catalogue and opens home',
      (tester) async {
    final container = await bootApp(tester);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'itest$stamp@gather-test.local';
    final username = 'itest$stamp';

    // Sign in -> sign up. The link is a Text.rich, so `find.text` would be
    // comparing against the whole span rather than the tappable words.
    await tester.tap(find.textContaining("Don't have an account"));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    Future<void> fill(String label, String value) async {
      final field = find.ancestor(
        of: find.text(label),
        matching: find.byType(Column),
      );
      expect(field, findsWidgets, reason: 'no field labelled "$label"');
      await tester.enterText(
        find.descendant(of: field.first, matching: find.byType(TextFormField)).first,
        value,
      );
      await tester.pump();
    }

    await fill('Full name', 'Integration Test');
    await fill('Username', username);
    await fill('Email', email);
    await fill('Phone number', '+966500000000');
    await fill('Password', 'TestPass123!');
    await fill('Confirm password', 'TestPass123!');

    // Let the debounced username availability check settle, and close the
    // keyboard so the submit button is reachable.
    await tester.pump(const Duration(milliseconds: 1200));
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();

    // "Eating with people?" only exists on the home screen, so it is an
    // unambiguous signal that sign-up succeeded and the router moved on.
    await waitFor(
      tester,
      find.text('Eating with people?'),
      timeout: const Duration(seconds: 45),
      because: 'the home screen after sign-up',
    );

    expect(FirebaseAuth.instance.currentUser, isNotNull,
        reason: 'sign-up should leave the user authenticated');

    // The catalogue seeds itself on first sign-in.
    await waitFor(
      tester,
      find.text('Best sellers'),
      timeout: const Duration(seconds: 60),
      because: 'the seeded catalogue',
    );
    // The "Restaurants" section lives below the fold, so assert on the data
    // rather than on widgets a ListView has not built yet.
    final restaurants = container.read(restaurantsProvider).valueOrNull ?? const [];
    final items = container.read(allMenuItemsProvider).valueOrNull ?? const [];
    expect(restaurants, isNotEmpty, reason: 'the catalogue should have seeded');
    expect(restaurants.map((r) => r.id), contains('burger-yard'));
    expect(items.length, greaterThan(20), reason: 'menus should have seeded too');

    // A host can open a group session and gets a real 4-digit code.
    final user = await waitForValue(
      tester,
      () => container.read(currentUserOrNullProvider),
      label: 'the signed-in profile document',
    );
    expect(user.username, 'itest$stamp');

    final created = await container.read(sessionServiceProvider).createSession(
          host: user,
          name: 'Integration session',
        );
    expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
    expect(created.valueOrNull!.code.length, 4);
    expect(created.valueOrNull!.memberIds, contains(user.uid));

    // Tear the app down before touching auth: deleting the account flips the
    // auth stream, and a mounted tree would rebuild against a vanished user.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));

    // Clean up so repeated runs do not accumulate accounts.
    await container.read(sessionServiceProvider).cancel(created.valueOrNull!.id);
    await FirebaseAuth.instance.currentUser?.delete();
  });
}
