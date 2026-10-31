import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/app/router.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// Drives the real session screen as the host, after a member has added
/// items, and checks the shared cart is actually on screen.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the host sees the shared cart on screen', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();

    final c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;
    final auth = c.read(authServiceProvider);
    final sessions = c.read(sessionServiceProvider);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    const pw = 'TestPass123!';
    final hostEmail = 'uh$stamp@gather-test.local';
    final memEmail = 'um$stamp@gather-test.local';

    Future<AppUser> actAs(String e) async {
      await FirebaseAuth.instance.signOut();
      final r = await auth.signIn(email: e, password: pw);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      return r.valueOrNull!;
    }

    final h = await auth.signUp(fullName: 'UI Host', username: 'uh$stamp',
        email: hostEmail, phone: '+96659200${stamp % 10000}', password: pw);
    final m = await auth.signUp(fullName: 'UI Member', username: 'um$stamp',
        email: memEmail, phone: '+96659300${stamp % 10000}', password: pw);
    var host = h.valueOrNull!;
    final member = m.valueOrNull!;

    host = await actAs(hostEmail);
    final created = await sessions.createSession(host: host, name: 'UI repro');
    final sid = created.valueOrNull!.id;
    final restaurant = (await c.read(catalogServiceProvider).fetchRestaurants()).first;
    final menu = await c.read(catalogServiceProvider).fetchMenu(restaurant.id);
    await sessions.chooseRestaurant(sessionId: sid, restaurant: restaurant);
    await sessions.addLine(sessionId: sid, item: menu[0], owner: host, quantity: 1);
    await sessions.addLine(sessionId: sid, item: menu[1], owner: host, quantity: 1);

    await actAs(memEmail);
    await sessions.joinByCode(code: created.valueOrNull!.code, user: member);
    await sessions.addLine(sessionId: sid, item: menu[0], owner: member, quantity: 1);
    await sessions.addLine(sessionId: sid, item: menu[1], owner: member, quantity: 1);

    // back to the host, and open the screen the way the app does
    host = await actAs(hostEmail);
    await t.pumpWidget(
        UncontrolledProviderScope(container: c, child: const GatherApp()));
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }
    c.read(activeSessionIdProvider.notifier).state = sid;
    c.read(routerProvider).push(Routes.session(sid));
    for (var i = 0; i < 45; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }

    // what does the provider the screen reads actually hold?
    final viaProvider = c.read(sessionLinesProvider(sid));
    debugPrint('UIREPRO provider isLoading=${viaProvider.isLoading} '
        'hasError=${viaProvider.hasError} n=${viaProvider.valueOrNull?.length} '
        'err=${viaProvider.error}');
    final direct = await sessions.fetchLines(sid);
    debugPrint('UIREPRO direct n=${direct.valueOrNull?.length}');

    // The capture is a nicety; a sandbox refusing the write must not decide
    // whether the assertions below run.
    try {
      final dir = Directory('/sdcard/Download/gather-uirepro2');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('${dir.path}/host-session.png')
          .writeAsBytesSync(await binding.takeScreenshot('host-session'));
    } catch (e) {
      debugPrint('UIREPRO capture skipped: $e');
    }

    expect(find.textContaining('Nothing added yet'), findsNothing,
        reason: 'the host must not be told the cart is empty when it is not');
    expect(viaProvider.valueOrNull, hasLength(4),
        reason: 'the screen reads this provider; it must hold all four lines');

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    await actAs(hostEmail);
    await sessions.cancel(sid);
    for (final e in [hostEmail, memEmail]) {
      await actAs(e);
      await FirebaseAuth.instance.currentUser?.delete();
    }
    c.dispose();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
