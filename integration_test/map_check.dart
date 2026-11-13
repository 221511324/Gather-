import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/app/router.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/driver_simulator.dart';
import 'package:gather/core/services/order_service.dart';
import 'package:gather/firebase_options.dart';

/// Places an order, steps a simulated driver along the route and captures the
/// tracking screen, so the map can be shown to work rather than asserted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the driver map renders on the tracking screen', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();

    final c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    const pw = 'TestPass123!';
    final email = 'map$stamp@gather-test.local';
    final up = await c.read(authServiceProvider).signUp(
        fullName: 'Map Check', username: 'map$stamp', email: email,
        phone: '+96658000${stamp % 10000}', password: pw);
    expect(up.isSuccess, isTrue, reason: up.errorOrNull ?? '');
    final user = up.valueOrNull!;

    final catalog = c.read(catalogServiceProvider);
    final restaurant = (await catalog.fetchRestaurants()).first;
    final menu = await catalog.fetchMenu(restaurant.id);

    // a solo order is enough to reach the tracking screen
    final cart = c.read(cartServiceProvider);
    await cart.add(user.uid, menu.first, quantity: 4);
    // the cart arrives on a stream, so wait for it rather than reading once
    var lines = <CartLine>[];
    for (var i = 0; i < 60; i++) {
      lines = await cart.watch(user.uid).first;
      if (lines.isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(lines, isNotEmpty, reason: 'the cart should have the item by now');
    final totals = OrderService.totalsFor(
        lines: lines, restaurant: restaurant, discount: 0);
    final placed = await c.read(orderServiceProvider).placeIndividualOrder(
          user: user, restaurant: restaurant, lines: lines, totals: totals,
          paymentMethodLabel: 'Visa •••• 4242',
          deliveryAddress: 'Building 7, King Fahd Road, Riyadh',
        );
    expect(placed.isSuccess, isTrue, reason: placed.errorOrNull ?? '');
    var order = placed.valueOrNull!;

    // walk the driver up to carrying the order
    for (var i = 0; i < 4; i++) {
      final step = await DriverSimulator.step(
          service: c.read(orderServiceProvider), order: order);
      expect(step.isSuccess, isTrue, reason: step.errorOrNull ?? '');
      order = (await c.read(orderServiceProvider).fetchOrder(order.id))!;
      debugPrint('MAP driver stage=${order.driverStage?.name} '
          'at=${order.driverLat},${order.driverLng}');
    }
    expect(order.hasDriverPosition, isTrue, reason: 'the driver must have a position');

    await t.pumpWidget(
        UncontrolledProviderScope(container: c, child: const GatherApp()));
    for (var i = 0; i < 26; i++) {
      await t.pump(const Duration(milliseconds: 180));
    }
    c.read(routerProvider).go(Routes.trackOrder(order.id));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(FlutterMap), findsOneWidget,
        reason: 'the map must be on the tracking screen');

    final dir = Directory('/sdcard/Download/gather-map');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final bytes = await binding.takeScreenshot('driver-map');
    File('${dir.path}/driver-map.png').writeAsBytesSync(bytes);
    debugPrint('MAP-CAPTURED stage=${order.driverStage?.name}');

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    await FirebaseAuth.instance.currentUser?.delete();
    c.dispose();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
