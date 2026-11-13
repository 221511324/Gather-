import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/app/router.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// The bottom bar has to stay in step with the location. This taps every tab,
/// and also navigates by route (the way in-app buttons do), checking each time
/// that the highlighted tab matches where the router actually is.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the selected tab always matches the current route', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    await FirebaseAuth.instance.signOut();

    final container = ProviderContainer(
      overrides: [appPrefsProvider.overrideWithValue(prefs)],
    );
    container.read(onboardingSeenProvider.notifier).state = true;

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GatherApp()),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    Future<void> settle([int n = 10]) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    await container.read(authServiceProvider).signUp(
          fullName: 'Nav Test',
          username: 'nav$stamp',
          email: 'nav$stamp@gather-test.local',
          phone: '+966500000000',
          password: 'TestPass123!',
        );
    for (var i = 0; i < 200; i++) {
      if (container.read(currentUserOrNullProvider) != null) break;
      await tester.pump(const Duration(milliseconds: 150));
    }
    await settle(20);

    final router = container.read(routerProvider);
    String where() =>
        router.routerDelegate.currentConfiguration.uri.toString();

    /// The tab that is actually drawn as selected, read off the widget tree.
    String? highlighted() {
      for (final label in ['Home', 'Search', 'Group', 'Orders', 'Profile']) {
        final finder = find.ancestor(
          of: find.text(label),
          matching: find.byType(Semantics),
        );
        for (final element in finder.evaluate()) {
          final s = element.widget as Semantics;
          if (s.properties.selected == true && s.properties.label == label) {
            return label;
          }
        }
      }
      return null;
    }

    const expected = {
      'Home': '/home',
      'Search': '/search',
      'Group': '/group',
      'Orders': '/orders',
      'Profile': '/profile',
    };

    final problems = <String>[];

    // 1. Tap each tab in the bar.
    for (final entry in expected.entries) {
      await tester.tap(find.text(entry.key).last);
      await settle();
      final loc = where();
      final sel = highlighted();
      debugPrint('NAV tap=${entry.key} location=$loc highlighted=$sel');
      if (!loc.startsWith(entry.value)) {
        problems.add('tapping ${entry.key} went to $loc');
      }
      if (sel != entry.key) {
        problems.add('tapping ${entry.key} left "$sel" highlighted');
      }
    }

    // 2. Navigate by route, the way in-app buttons do.
    for (final entry in expected.entries) {
      router.go(entry.value);
      await settle();
      final loc = where();
      final sel = highlighted();
      debugPrint('NAV go=${entry.value} location=$loc highlighted=$sel');
      if (sel != entry.key) {
        problems.add('go(${entry.value}) left "$sel" highlighted, expected ${entry.key}');
      }
    }

    // 3. Push a full-screen route, come back, and confirm the bar recovers.
    router.go('/home');
    await settle();
    router.push(Routes.cart);
    await settle();
    router.pop();
    await settle();
    debugPrint('NAV after cart round-trip location=${where()} highlighted=${highlighted()}');
    if (highlighted() != 'Home') {
      problems.add('after returning from the cart, "${highlighted()}" was highlighted');
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(4);
    await FirebaseAuth.instance.currentUser?.delete();
    container.dispose();

    expect(problems, isEmpty, reason: problems.join('\n'));
    debugPrint('NAV-CHECK-PASSED');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
