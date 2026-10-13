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

/// Visits every route in the app against the live project and fails if any of
/// them throws while building. This is the check that a route is not just
/// registered but actually reachable and renderable.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every route renders without throwing', (tester) async {
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

    Future<void> settle([int ticks = 12]) async {
      for (var i = 0; i < ticks; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    Future<T> waitFor<T>(T? Function() read, String label) async {
      for (var i = 0; i < 200; i++) {
        final v = read();
        if (v != null) return v;
        await tester.pump(const Duration(milliseconds: 150));
      }
      fail('timed out waiting for $label');
    }

    // A real account, so authenticated routes render real data.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final signUp = await container.read(authServiceProvider).signUp(
          fullName: 'Route Test',
          username: 'routes$stamp',
          email: 'routes$stamp@gather-test.local',
          phone: '+966500000000',
          password: 'TestPass123!',
        );
    expect(signUp.isSuccess, isTrue, reason: signUp.errorOrNull ?? '');

    final user = await waitFor(
        () => container.read(currentUserOrNullProvider), 'the profile');
    await waitFor(() {
      final list = container.read(restaurantsProvider).valueOrNull;
      return (list != null && list.isNotEmpty) ? list : null;
    }, 'the seeded catalogue');

    // A real session so the group routes have something to show.
    final session = await container
        .read(sessionServiceProvider)
        .createSession(host: user, name: 'Route test');
    expect(session.isSuccess, isTrue, reason: session.errorOrNull ?? '');
    final sessionId = session.valueOrNull!.id;

    final router = container.read(routerProvider);

    final routes = <String>[
      Routes.home,
      Routes.search,
      Routes.group,
      Routes.profile,
      Routes.editProfile,
      Routes.joinSession,
      Routes.restaurant('burger-yard'),
      Routes.session(sessionId),
      // A code nobody is using must show an empty state, not crash.
      '/join/9999',
      // An unknown path must land on the error page, not blow up.
      '/this-route-does-not-exist',
    ];

    final failures = <String>[];
    for (final route in routes) {
      debugPrint('ROUTE-VISIT $route');
      try {
        router.push(route);
        await settle();
        final error = tester.takeException();
        if (error != null) {
          failures.add('$route -> $error');
          debugPrint('ROUTE-FAIL $route -> $error');
        }
        if (router.canPop()) {
          router.pop();
          await settle(6);
          final popError = tester.takeException();
          if (popError != null) {
            failures.add('$route (on leaving) -> $popError');
            debugPrint('ROUTE-FAIL-POP $route -> $popError');
          }
        }
      } catch (e) {
        failures.add('$route threw while navigating -> $e');
        debugPrint('ROUTE-THROW $route -> $e');
      }
    }
    debugPrint('ROUTE-LOOP-COMPLETE');

    // Tear the app down before touching auth: deleting the account flips the
    // auth stream, and a mounted tree would rebuild against a vanished user.
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(4);

    await container.read(sessionServiceProvider).cancel(sessionId);
    await FirebaseAuth.instance.currentUser?.delete();
    container.dispose();

    expect(failures, isEmpty,
        reason: 'these routes did not render cleanly:\n${failures.join('\n')}');
    debugPrint('ROUTE CHECK: ${routes.length} routes rendered cleanly');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
