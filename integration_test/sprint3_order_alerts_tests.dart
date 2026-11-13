import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/app/router.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/local_alerts.dart';
import 'package:gather/core/services/order_service.dart';
import 'package:gather/features/orders/order_tracking_screen.dart';
import 'package:gather/firebase_options.dart';

/// US16 — order updates pop up the moment they happen, TC_OA_001 to TC_OA_004.
///
/// The app runs on the emulator as a customer while their order is moved
/// through its steps, exactly as the restaurant and rider would move it, and
/// each step is checked on the screen. Screenshots go to
/// /sdcard/Download/gather-alerts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'alerts$stamp@gather-test.local';

  late ProviderContainer c;
  late Directory dir;
  late AppUser me;
  late Restaurant restaurant;
  late MenuItem dish;
  var n = 0;
  final pop = find.byKey(const ValueKey('notification-pop-up'));

  Future<void> settle(WidgetTester t, [int ticks = 14]) async {
    for (var i = 0; i < ticks; i++) {
      await t.pump(const Duration(milliseconds: 160));
    }
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t, 4);
    n++;
    final id = '${n.toString().padLeft(2, '0')}-$name';
    File('${dir.path}/$id.png').writeAsBytesSync(await binding.takeScreenshot(id));
    debugPrint('OASHOT $id');
  }

  Future<void> waitFor(WidgetTester t, Finder f, String what) async {
    for (var i = 0; i < 120; i++) {
      if (f.evaluate().isNotEmpty) return;
      await t.pump(const Duration(milliseconds: 150));
    }
    fail('timed out waiting for $what');
  }

  Future<GoRouter> launch(WidgetTester t) async {
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
    for (var i = 0; i < 160; i++) {
      final u = c.read(currentUserOrNullProvider);
      if (u != null && u.uid == me.uid) break;
      await t.pump(const Duration(milliseconds: 150));
    }
    // The notifications history loads before anything counts as new.
    for (var i = 0; i < 40 && c.read(notificationsProvider) is! AsyncData; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    await settle(t, 10);
    return c.read(routerProvider);
  }

  Future<FoodOrder> placeOrder() async {
    final cart = c.read(cartServiceProvider);
    await cart.clear(me.uid);
    await cart.add(me.uid, dish, quantity: 4);
    final lines = await cart.fetch(me.uid);
    final placed = await c.read(orderServiceProvider).placeIndividualOrder(
        user: me, restaurant: restaurant, lines: lines,
        totals: OrderService.totalsFor(lines: lines, restaurant: restaurant),
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    expect(placed.isSuccess, isTrue, reason: placed.errorOrNull ?? '');
    await cart.clear(me.uid);
    return placed.valueOrNull!;
  }

  Future<void> advance(FoodOrder order, OrderStatus to) async {
    final r = await c.read(orderServiceProvider).advanceStatus(orderId: order.id, status: to);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
  }

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    // As main() does; this is what lets the pop-up and the phone alerts run.
    await LocalAlerts.instance.init();
    final prefs = await AppPrefs.load();
    c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;
    await binding.convertFlutterSurfaceToImage();
    dir = Directory('/sdcard/Download/gather-alerts');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signUp(
        fullName: 'Alert Tester', username: 'oa$stamp', email: email,
        phone: '+96655${stamp % 10000000}', password: password);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    me = r.valueOrNull!;
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    restaurant = all.firstWhere((x) => x.isOpen, orElse: () => all.first);
    dish = (await catalog.fetchMenu(restaurant.id)).first;
  });

  tearDownAll(() async {
    // Deleting an account needs a fresh sign-in.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    await FirebaseAuth.instance.currentUser?.delete();
    c.dispose();
  });

  testWidgets('TC_OA_001 Each step of an order pops up as it happens', (t) async {
    final order = await placeOrder();
    final router = await launch(t);
    router.go('/home');
    await settle(t);

    for (final step in [
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ]) {
      await advance(order, step);
      final title = find.descendant(of: pop, matching: find.text(step.alertTitle));
      await waitFor(t, title, 'the "${step.alertTitle}" pop-up');
      expect(find.descendant(of: pop, matching: find.text(step.alertBody(restaurant.name))),
          findsOneWidget);
      await shot(t, 'pop-${step.name}');
      debugPrint('TC_OA_001   ${step.name}: "${step.alertTitle}"');
    }

    // And all of them, plus "Order confirmed", are kept in Notifications.
    final kept = await c.read(notificationServiceProvider).watch(me.uid).first;
    final titles = kept.where((x) => x.orderId == order.id).map((x) => x.title).toList();
    expect(titles.toSet(), {
      for (final s in OrderStatusX.timeline) s.alertTitle,
    });
    debugPrint('TC_OA_001 PASS 4 pop-ups, ${titles.length} kept in Notifications');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('TC_OA_002 Tapping the pop-up opens the order tracking', (t) async {
    final order = await placeOrder();
    final router = await launch(t);
    router.go('/home');
    await settle(t);

    await advance(order, OrderStatus.preparing);
    final preparing =
        find.descendant(of: pop, matching: find.text(OrderStatus.preparing.alertTitle));
    await waitFor(t, preparing, 'the pop-up');
    await settle(t, 4); // let it finish sliding in
    await t.tap(preparing);
    await settle(t, 20);
    expect(find.byType(OrderTrackingScreen), findsOneWidget);
    await shot(t, 'tapped-opens-tracking');

    final mine = await c.read(notificationServiceProvider).watch(me.uid).first;
    final tapped = mine.firstWhere(
        (x) => x.orderId == order.id && x.title == OrderStatus.preparing.alertTitle);
    expect(tapped.read, isTrue, reason: 'opening it marks it read');
    await advance(order, OrderStatus.cancelled);
    debugPrint('TC_OA_002 PASS opened tracking, marked read');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_OA_003 The pop-up speaks Arabic when the app is in Arabic', (t) async {
    await c.read(authServiceProvider)
        .saveSettings(me.uid, me.settings.copyWith(language: 'ar'));
    final order = await placeOrder();
    final router = await launch(t);
    router.go('/home');
    await settle(t);

    await advance(order, OrderStatus.preparing);
    await advance(order, OrderStatus.ready);
    final ready = find.descendant(of: pop, matching: find.text('طلبك جاهز'));
    await waitFor(t, ready, 'the Arabic pop-up');
    expect(find.descendant(of: pop, matching: find.textContaining('جاهز للاستلام')),
        findsOneWidget);
    await shot(t, 'pop-arabic');

    await c.read(authServiceProvider)
        .saveSettings(me.uid, me.settings.copyWith(language: 'en'));
    await advance(order, OrderStatus.onTheWay);
    await advance(order, OrderStatus.delivered);
    await settle(t, 10);
    debugPrint('TC_OA_003 PASS "طلبك جاهز"');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_OA_004 In the background it goes to the phone, not the screen',
      (t) async {
    final order = await placeOrder();
    final router = await launch(t);
    router.go('/home');
    await settle(t);
    await t.pump(const Duration(seconds: 6)); // any earlier pop-up has gone

    // Sent to the background, as pressing Home does. No frames are drawn
    // while paused, so the test waits on the clock instead of pumping.
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await advance(order, OrderStatus.preparing);
    final title = OrderStatus.preparing.alertTitle;
    var posted = <String>[];
    await t.runAsync(() async {
      for (var i = 0; i < 40 && !posted.contains(title); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        posted = await LocalAlerts.instance.activeTitles();
      }
    });
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await settle(t, 6);

    expect(posted, contains(title), reason: 'the phone shows it in the status bar');
    expect(pop, findsNothing, reason: 'and it is not drawn over the app afterwards');
    await shot(t, 'back-from-background');
    await advance(order, OrderStatus.cancelled);
    debugPrint('TC_OA_004 PASS status bar shows "$title"; no pop-up on return');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
