import 'dart:io';

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

/// Walks the Sprint 1 app and writes a screenshot of each screen, so the test
/// report can show the "actual result" for every user-story test case.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture every Sprint 1 screen', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    await FirebaseAuth.instance.signOut();

    final container = ProviderContainer(
      overrides: [appPrefsProvider.overrideWithValue(prefs)],
    );

    // Android renders Flutter into a surface the test process cannot read
    // until it is converted into an image.
    await binding.convertFlutterSurfaceToImage();

    final dir = Directory('/sdcard/Download/gather-shots');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var n = 0;

    Future<void> settle([int ticks = 14]) async {
      for (var i = 0; i < ticks; i++) {
        await tester.pump(const Duration(milliseconds: 160));
      }
    }

    Future<void> shot(String name) async {
      await settle();
      n++;
      final bytes = await binding.takeScreenshot('${n.toString().padLeft(2, '0')}-$name');
      File('${dir.path}/${n.toString().padLeft(2, '0')}-$name.png')
          .writeAsBytesSync(bytes);
      debugPrint('SHOT ${n.toString().padLeft(2, '0')}-$name');
    }

    // ---- signed out ----
    container.read(onboardingSeenProvider.notifier).state = false;
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GatherApp()),
    );
    await settle(20);
    await shot('onboarding');                       // US1

    container.read(onboardingSeenProvider.notifier).state = true;
    await settle();
    final router = container.read(routerProvider);

    router.go(Routes.login);
    await shot('login');                            // US1-AC2, US1-AC3
    router.go(Routes.register);
    await shot('register');                         // US1-AC1

    // ---- a real account so the rest has data ----
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final signUp = await container.read(authServiceProvider).signUp(
          fullName: 'Sprint One',
          username: 'tour$stamp',
          email: 'tour$stamp@gather-test.local',
          phone: '+96650000${stamp % 10000}',
          password: 'TestPass123!',
        );
    expect(signUp.isSuccess, isTrue, reason: signUp.errorOrNull ?? '');
    for (var i = 0; i < 120; i++) {
      if (container.read(currentUserOrNullProvider) != null) break;
      await tester.pump(const Duration(milliseconds: 150));
    }
    final user = container.read(currentUserOrNullProvider)!;

    for (var i = 0; i < 160; i++) {
      final list = container.read(restaurantsProvider).valueOrNull;
      if (list != null && list.isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 150));
    }

    router.go(Routes.home);
    await shot('home');                             // US3-AC1
    router.go(Routes.search);
    await shot('search');                           // US3-AC1

    final restaurants = container.read(restaurantsProvider).valueOrNull ?? const [];
    if (restaurants.isNotEmpty) {
      router.push(Routes.restaurant(restaurants.first.id));
      await shot('restaurant-detail');              // US3-AC2, US3-AC3
      router.pop();
      await settle(6);
    }

    // ---- group ----
    router.go(Routes.group);
    await shot('group-hub');                        // US4-AC1

    final created = await container.read(sessionServiceProvider)
        .createSession(host: user, name: 'Friday dinner');
    expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
    final session = created.valueOrNull!;
    container.read(activeSessionIdProvider.notifier).state = session.id;

    router.go(Routes.group);
    await shot('group-hub-with-session');           // US4-AC4

    router.push(Routes.session(session.id));
    await shot('session-lobby');                    // US4-AC3, US6-AC3

    router.go(Routes.joinSession);
    await shot('join-session');                     // US6-AC1

    // ---- profile ----
    router.go(Routes.profile);
    await shot('profile');                          // US2-AC1
    router.push(Routes.editProfile);
    await shot('edit-profile');                     // US2-AC2

    debugPrint('TOUR-COMPLETE $n screens -> ${dir.path}');

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(4);
    await container.read(sessionServiceProvider).cancel(session.id);
    await FirebaseAuth.instance.currentUser?.delete();
    container.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
