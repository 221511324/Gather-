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

/// Signs in as the administrator and captures every admin screen, so the code
/// guide can show what the dashboard actually looks like.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture the admin dashboard', (tester) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    await FirebaseAuth.instance.signOut();

    final container = ProviderContainer(
      overrides: [appPrefsProvider.overrideWithValue(prefs)],
    );
    container.read(onboardingSeenProvider.notifier).state = true;

    await binding.convertFlutterSurfaceToImage();
    final dir = Directory('/sdcard/Download/gather-admin');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    var n = 0;

    Future<void> settle([int ticks = 16]) async {
      for (var i = 0; i < ticks; i++) {
        await tester.pump(const Duration(milliseconds: 170));
      }
    }

    Future<void> shot(String name) async {
      await settle();
      n++;
      final id = '${n.toString().padLeft(2, '0')}-$name';
      final bytes = await binding.takeScreenshot(id);
      File('${dir.path}/$id.png').writeAsBytesSync(bytes);
      debugPrint('ADMINSHOT $id');
    }

    final signedIn = await container.read(authServiceProvider).signIn(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    expect(signedIn.isSuccess, isTrue, reason: signedIn.errorOrNull ?? '');
    expect(signedIn.valueOrNull!.isAdmin, isTrue, reason: 'account is not an admin');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GatherApp()),
    );
    await settle(24);

    final router = container.read(routerProvider);
    router.go(Routes.profile);
    await shot('profile-admin-entry');

    for (final (route, name) in <(String, String)>[
      (Routes.admin, 'dashboard'),
      (Routes.adminRestaurants, 'restaurants'),
      (Routes.adminUsers, 'users'),
      (Routes.adminOrders, 'orders'),
      (Routes.adminSessions, 'sessions'),
      (Routes.adminTickets, 'tickets'),
    ]) {
      router.go(route);
      await shot(name);
    }

    final restaurants = container.read(restaurantsProvider).valueOrNull ?? const [];
    if (restaurants.isNotEmpty) {
      router.go(Routes.adminMenu(restaurants.first.id));
      await shot('menu-management');
    }

    debugPrint('ADMIN-TOUR-COMPLETE $n screens');
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(4);
    await FirebaseAuth.instance.signOut();
    container.dispose();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
