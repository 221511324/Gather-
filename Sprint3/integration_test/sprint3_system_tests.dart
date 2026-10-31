import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/order_service.dart';
import 'package:gather/core/services/session_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 3 system tests, TC_S_001 to TC_S_004.
///
/// The unit tests check one rule and the integration tests check one feature.
/// These walk a whole journey the way a real group would, end to end, and only
/// pass if every part works together: registering, gathering a group, deciding
/// a restaurant, filling a shared cart, paying with an administrator-managed
/// payment method, placing the order, and following it to the door.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final hostEmail = 's3host$stamp@gather-test.local';
  final guestEmail = 's3guest$stamp@gather-test.local';

  late ProviderContainer c;
  late SessionService sessions;
  late OrderService orders;
  late AppUser host, guest;
  late Restaurant restaurant;
  late List<MenuItem> menu;

  Future<AppUser> actAs(String email, [String pw = password]) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: pw);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    c = ProviderContainer();
    sessions = c.read(sessionServiceProvider);
    orders = c.read(orderServiceProvider);
    final auth = c.read(authServiceProvider);

    for (final (email, name, i) in [(hostEmail, 'S3 Host', 0), (guestEmail, 'S3 Guest', 1)]) {
      final r = await auth.signUp(
          fullName: name, username: 's3u$i$stamp', email: email,
          phone: '+9665800$i${stamp % 10000}', password: password);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      if (i == 0) {
        host = r.valueOrNull!;
      } else {
        guest = r.valueOrNull!;
      }
    }

    host = await actAs(hostEmail);
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    restaurant = all.firstWhere((r) => r.isOpen, orElse: () => all.first);
    menu = await catalog.fetchMenu(restaurant.id);
    expect(menu, isNotEmpty, reason: 'the catalogue must be seeded');
  });

  tearDownAll(() => c.dispose());

  testWidgets('TC_S_001 A group orders together from start to finish', (t) async {
    // --- the host opens a session -----------------------------------------
    host = await actAs(hostEmail);
    final made = await sessions.createSession(host: host, name: 'System test lunch');
    expect(made.isSuccess, isTrue, reason: made.errorOrNull ?? '');
    final session = made.valueOrNull!;
    debugPrint('TC_S_001   session ${session.code} opened');

    // --- a friend joins with the code -------------------------------------
    guest = await actAs(guestEmail);
    final joined = await sessions.joinByCode(code: session.code, user: guest);
    expect(joined.isSuccess, isTrue, reason: joined.errorOrNull ?? '');
    expect(joined.valueOrNull!.members, hasLength(2));
    debugPrint('TC_S_001   guest joined, 2 members');

    // --- the group decides where to eat -----------------------------------
    final suggested = await sessions.suggestRestaurant(
        sessionId: session.id, restaurant: restaurant, by: guest);
    expect(suggested.isSuccess, isTrue, reason: suggested.errorOrNull ?? '');

    host = await actAs(hostEmail);
    final chosen = await sessions.chooseRestaurant(
        sessionId: session.id, restaurant: restaurant);
    expect(chosen.isSuccess, isTrue, reason: chosen.errorOrNull ?? '');
    debugPrint('TC_S_001   restaurant chosen: ${restaurant.name}');

    // --- both fill the shared cart ----------------------------------------
    // Enough of each to clear the restaurant's minimum order.
    final added = await sessions.addLine(
        sessionId: session.id, item: menu.first, owner: host, quantity: 3);
    expect(added.isSuccess, isTrue, reason: added.errorOrNull ?? '');

    guest = await actAs(guestEmail);
    final added2 = await sessions.addLine(
        sessionId: session.id, item: menu.last, owner: guest, quantity: 3);
    expect(added2.isSuccess, isTrue, reason: added2.errorOrNull ?? '');

    final linesResult = await sessions.fetchLines(session.id);
    expect(linesResult.isSuccess, isTrue, reason: linesResult.errorOrNull ?? '');
    final lines = linesResult.valueOrNull!;
    expect(lines, hasLength(2), reason: 'both members should see both lines');
    debugPrint('TC_S_001   shared cart has ${lines.length} lines');

    // --- the host picks how to split it -----------------------------------
    host = await actAs(hostEmail);
    final totals = OrderService.totalsFor(lines: lines, restaurant: restaurant);
    final mode = await sessions.setPaymentMode(
        sessionId: session.id, mode: PaymentMode.equalSplit,
        totals: totals, lines: lines);
    expect(mode.isSuccess, isTrue, reason: mode.errorOrNull ?? '');

    // --- the order cannot go in until everybody has paid ------------------
    var current = await sessions.fetch(session.id);
    final tooEarly = await orders.placeGroupOrder(
        session: current!, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    expect(tooEarly.isSuccess, isFalse,
        reason: 'an unpaid group must not be able to order');
    debugPrint('TC_S_001   refused while unpaid: "${tooEarly.errorOrNull}"');

    // --- everyone pays ----------------------------------------------------
    expect((await sessions.markPaid(sessionId: session.id, uid: host.uid)).isSuccess, isTrue);
    guest = await actAs(guestEmail);
    expect((await sessions.markPaid(sessionId: session.id, uid: guest.uid)).isSuccess, isTrue);

    // --- and the order goes in --------------------------------------------
    host = await actAs(hostEmail);
    current = await sessions.fetch(session.id);
    expect(current!.everyonePaid, isTrue);
    final placed = await orders.placeGroupOrder(
        session: current, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    expect(placed.isSuccess, isTrue, reason: placed.errorOrNull ?? '');

    final order = placed.valueOrNull!;
    expect(order.isGroupOrder, isTrue);
    expect(order.participants, hasLength(2));
    expect(order.total, closeTo(totals.total, 0.01));
    debugPrint('TC_S_001 PASS order ${order.id} total ${order.total} '
        'for ${order.participants.length} people');
  });

  testWidgets('TC_S_002 The bill splits without losing or inventing money', (t) async {
    host = await actAs(hostEmail);
    final mine = await orders.watchMyOrders(host.uid).first;
    final group = mine.where((o) => o.isGroupOrder).toList();
    expect(group, isNotEmpty, reason: 'TC_S_001 should have left one');

    for (final order in group) {
      final shares = order.participants.fold<double>(0, (a, p) => a + p.amount);
      expect(shares, closeTo(order.total, 0.01),
          reason: 'the shares must add back to the total for order ${order.id}');
    }
    debugPrint('TC_S_002 PASS ${group.length} group order(s), every split balances');
  });

  testWidgets('TC_S_003 A customer pays with a method the admin configured', (t) async {
    // The administrator adds one.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: adminEmail, password: adminPassword);
    final pay = c.read(paymentServiceProvider);
    final created = await pay.upsertOption(
        PaymentOption(id: '', name: 'SystemTestPay$stamp'));
    expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');

    // The customer sees it and sets it up.
    guest = await actAs(guestEmail);
    final offered = await pay.watchEnabledOptions().first;
    final option = offered.firstWhere((o) => o.name == 'SystemTestPay$stamp');
    final saved = await pay.addOption(uid: guest.uid, option: option);
    expect(saved.isSuccess, isTrue, reason: saved.errorOrNull ?? '');
    expect(saved.valueOrNull!.label, 'SystemTestPay$stamp');

    // The administrator hides it; the customer is no longer offered it.
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: adminEmail, password: adminPassword);
    expect((await pay.setOptionEnabled(created.valueOrNull!.id, false)).isSuccess, isTrue);
    final afterHiding = await pay.watchEnabledOptions().first;
    expect(afterHiding.map((o) => o.name), isNot(contains('SystemTestPay$stamp')));

    await pay.deleteOption(created.valueOrNull!.id);
    debugPrint('TC_S_003 PASS admin added it, customer used it, admin hid it');
  });

  testWidgets('TC_S_004 Cash is not offered anywhere', (t) async {
    guest = await actAs(guestEmail);
    final offered = await c.read(paymentServiceProvider).watchEnabledOptions().first;
    for (final option in offered) {
      expect(option.name.toLowerCase(), isNot(contains('cash')),
          reason: 'cash was removed from the platform');
    }
    expect(PaymentMethodType.values.map((t) => t.name), isNot(contains('cash')));
    debugPrint('TC_S_004 PASS ${offered.length} methods offered, none is cash');
  });
}
