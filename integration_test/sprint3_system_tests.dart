import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/models/reward_rules.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/assistant_service.dart';
import 'package:gather/core/services/order_service.dart';
import 'package:gather/core/services/session_service.dart';
import 'package:gather/firebase_options.dart';

/// System tests against the functional requirements, TC_SF_001 to TC_SF_009.
///
/// Each case walks a whole journey against the live Firebase project and names
/// the requirements of the project document it proves. Together they cover
/// FR1 to FR32. Opening a real verification link needs a real inbox, so that
/// one step is checked by hand and recorded in the testing document as TC_SF_010.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final hostEmail = 'sfhost$stamp@gather-test.local';
  final guestEmail = 'sfguest$stamp@gather-test.local';
  final thirdEmail = 'sfthird$stamp@gather-test.local';

  late ProviderContainer c;
  late SessionService sessions;
  late OrderService orders;
  late AppUser host, guest, third;
  late Restaurant restaurant;
  late List<MenuItem> menu;

  Future<AppUser> actAs(String email, [String pw = password]) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: pw);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  void ok(dynamic result) =>
      expect(result.isSuccess, isTrue, reason: result.errorOrNull ?? '');

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;
    sessions = c.read(sessionServiceProvider);
    orders = c.read(orderServiceProvider);
    final auth = c.read(authServiceProvider);
    var i = 0;
    Future<AppUser> make(String email, String name) async {
      await FirebaseAuth.instance.signOut();
      final r = await auth.signUp(
          fullName: name, username: 'sf${i++}$stamp', email: email,
          phone: '+9665800$i${stamp % 10000}', password: password);
      ok(r);
      return r.valueOrNull!;
    }

    third = await make(thirdEmail, 'SF Third');
    guest = await make(guestEmail, 'SF Guest');
    host = await make(hostEmail, 'SF Host');
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    restaurant = all.firstWhere((r) => r.isOpen, orElse: () => all.first);
    menu = await catalog.fetchMenu(restaurant.id);
    expect(menu, isNotEmpty, reason: 'the catalogue must be seeded');
  });

  tearDownAll(() => c.dispose());

  testWidgets('TC_SF_001 FR1 FR2 A new customer is held until their email is verified, and manages their profile',
      (t) async {
    // An address nobody can receive at: this case proves the door is shut.
    // Opening the real link needs a real inbox and is checked by hand, TC_SF_010.
    final email = 'gather$stamp@example.com';

    // --- sign up: the account exists but is held at the door ----------------
    await FirebaseAuth.instance.signOut();
    final made = await c.read(authServiceProvider).signUp(
        fullName: 'Email Check', username: 'sfv$stamp', email: email,
        phone: '+96654${stamp % 10000000}', password: password);
    ok(made);
    var me = made.valueOrNull!;
    expect(me.mustVerifyEmail, isTrue);

    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
    final gate = find.byKey(const ValueKey('verify-email'));
    for (var i = 0; i < 100 && gate.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(gate, findsOneWidget, reason: 'an unverified account must stop at this screen');

    // --- the database refuses it too, whatever a modified app might try -----
    final cart = c.read(cartServiceProvider);
    await cart.add(me.uid, menu.first, quantity: 4);
    final lines = await cart.fetch(me.uid);
    final totals = OrderService.totalsFor(lines: lines, restaurant: restaurant);
    final early = await orders.placeIndividualOrder(
        user: me, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    expect(early.isSuccess, isFalse, reason: 'no orders before verifying');
    expect((await sessions.createSession(host: me, name: 'Too early')).isSuccess, isFalse,
        reason: 'no group sessions before verifying');
    await expectLater(
        c.read(firestoreRefsProvider).user(me.uid).update({'mustVerifyEmail': false}),
        throwsA(isA<FirebaseException>()),
        reason: 'the flag cannot be cleared by hand');

    // --- pressing the button too soon says so -------------------------------
    await t.tap(find.text("I've verified"));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(gate, findsOneWidget);

    // --- FR2: an account's profile can be changed, and survives signing in ---
    ok(await c.read(authServiceProvider).updateProfile(uid: me.uid, fullName: 'Email Checked'));
    ok(await c.read(authServiceProvider).saveAddresses(me.uid, const [
      Address(id: 'a', label: 'Home', line: 'PSU', city: 'Riyadh', isDefault: true),
    ]));
    await cart.clear(me.uid);
    await t.pumpWidget(const SizedBox.shrink());
    me = await actAs(email);
    expect(me.mustVerifyEmail, isTrue, reason: 'signing in again does not get round it');
    expect(me.fullName, 'Email Checked');
    expect(me.defaultAddress?.city, 'Riyadh');
    await FirebaseAuth.instance.currentUser?.delete();

    debugPrint('TC_SF_001 PASS held at the screen, refused by the database, flag cannot be cleared');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_SF_002 FR3 FR4 FR5 FR11 FR15 FR18 FR19 FR22 One person orders, pays and follows it to the door',
      (t) async {
    guest = await actAs(guestEmail);
    final catalog = c.read(catalogServiceProvider);
    expect(await catalog.fetchRestaurants(), isNotEmpty, reason: 'FR3');

    final cart = c.read(cartServiceProvider);
    await cart.clear(guest.uid);
    await cart.add(guest.uid, menu.first, quantity: 2, note: 'No onions');
    await cart.add(guest.uid, menu.last, quantity: 1);
    var lines = await cart.fetch(guest.uid);
    expect(lines, hasLength(2), reason: 'FR4 FR5');
    await cart.setQuantity(guest.uid, lines.first.id, 6);
    await cart.remove(guest.uid, lines.last.id);
    lines = await cart.fetch(guest.uid);
    expect(lines.single.quantity, 6, reason: 'FR5');

    final pay = c.read(paymentServiceProvider);
    final card = await pay.addCard(
        uid: guest.uid, number: '4242 4242 4242 4242', holderName: 'SF Guest',
        expiryMonth: 12, expiryYear: DateTime.now().year + 3, cvv: '123', makeDefault: true);
    ok(card);
    final totals = OrderService.totalsFor(lines: lines, restaurant: restaurant);
    ok(await pay.pay(amount: totals.total, method: card.valueOrNull!, description: 'FR15'));

    final placed = await orders.placeIndividualOrder(
        user: guest, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: card.valueOrNull!.label, deliveryAddress: 'PSU, Riyadh');
    ok(placed);
    final order = placed.valueOrNull!;
    expect(order.status, OrderStatus.confirmed, reason: 'FR18');
    await cart.clear(guest.uid);

    for (final s in [OrderStatus.preparing, OrderStatus.ready, OrderStatus.onTheWay, OrderStatus.delivered]) {
      ok(await orders.advanceStatus(orderId: order.id, status: s));
    }
    final tracked = (await orders.fetchOrder(order.id))!;
    expect(tracked.status, OrderStatus.delivered, reason: 'FR19');
    expect(tracked.timeline, hasLength(5), reason: 'FR19: every step is recorded');

    final history = await orders.watchMyOrders(guest.uid).first;
    expect(history.map((o) => o.id), contains(order.id), reason: 'FR22');
    debugPrint('TC_SF_002 PASS ordered, paid ${totals.total}, tracked 5 steps, in history');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_SF_003 FR6 FR7 FR8 FR9 FR10 FR12 FR13 FR14 FR16 FR17 A group orders together',
      (t) async {
    host = await actAs(hostEmail);
    final made = await sessions.createSession(host: host, name: 'System test lunch');
    ok(made);
    final session = made.valueOrNull!;
    expect(session.code, hasLength(4), reason: 'FR6');
    ok(await sessions.inviteUser(sessionId: session.id, inviteeUid: guest.uid));

    guest = await actAs(guestEmail);
    final invites = await c.read(notificationServiceProvider).watch(guest.uid).first;
    expect(invites.map((n) => n.sessionId), contains(session.id), reason: 'FR7');
    ok(await sessions.joinByCode(code: session.code, user: guest));
    third = await actAs(thirdEmail);
    ok(await sessions.joinByCode(code: session.code, user: third));
    expect((await sessions.fetch(session.id))!.members, hasLength(3), reason: 'FR8');

    host = await actAs(hostEmail);
    ok(await sessions.removeMember(sessionId: session.id, memberUid: third.uid));
    expect((await sessions.fetch(session.id))!.members, hasLength(2), reason: 'FR9');
    ok(await sessions.setDecisionMode(
        sessionId: session.id, mode: RestaurantDecisionMode.values.first));

    guest = await actAs(guestEmail);
    ok(await sessions.suggestRestaurant(sessionId: session.id, restaurant: restaurant, by: guest));
    host = await actAs(hostEmail);
    ok(await sessions.chooseRestaurant(sessionId: session.id, restaurant: restaurant, bySpin: true));
    expect((await sessions.fetch(session.id))!.restaurantName, restaurant.name, reason: 'FR10');

    ok(await sessions.addLine(sessionId: session.id, item: menu.first, owner: host, quantity: 3));
    guest = await actAs(guestEmail);
    ok(await sessions.addLine(sessionId: session.id, item: menu.last, owner: guest, quantity: 1));
    final mine = (await sessions.fetchLines(session.id)).valueOrNull!
        .firstWhere((l) => l.ownerId == guest.uid);
    ok(await sessions.setLineQuantity(sessionId: session.id, lineId: mine.id, quantity: 3));
    final lines = (await sessions.fetchLines(session.id)).valueOrNull!;
    expect(lines, hasLength(2), reason: 'FR12: both see both');
    expect(lines.firstWhere((l) => l.ownerId == guest.uid).quantity, 3, reason: 'FR13');

    host = await actAs(hostEmail);
    final totals = OrderService.totalsFor(lines: lines, restaurant: restaurant);
    ok(await sessions.setPaymentMode(
        sessionId: session.id, mode: PaymentMode.equalSplit, totals: totals, lines: lines));

    var current = await sessions.fetch(session.id);
    final tooEarly = await orders.placeGroupOrder(
        session: current!, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    expect(tooEarly.isSuccess, isFalse, reason: 'FR16: refused while anyone is unpaid');

    ok(await sessions.markPaid(sessionId: session.id, uid: host.uid));
    guest = await actAs(guestEmail);
    ok(await sessions.markPaid(sessionId: session.id, uid: guest.uid));
    host = await actAs(hostEmail);
    current = await sessions.fetch(session.id);
    expect(current!.everyonePaid, isTrue, reason: 'FR16');
    final placed = await orders.placeGroupOrder(
        session: current, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    ok(placed);
    final order = placed.valueOrNull!;
    expect(order.participants, hasLength(2), reason: 'FR17');
    final shares = order.participants.fold<double>(0, (a, p) => a + p.amount);
    expect(shares, closeTo(order.total, 0.01), reason: 'FR14: nothing lost or invented');
    debugPrint('TC_SF_003 PASS 3 joined, 1 removed, spin, shared cart, refused unpaid, '
        'placed ${order.total} split between 2');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('TC_SF_004 FR20 FR21 FR23 Groups are saved and reused; favourites are kept', (t) async {
    host = await actAs(hostEmail);
    final made = await sessions.createSession(host: host, name: 'Friday crew');
    ok(made);
    final saved = await sessions.saveAsGroup(session: made.valueOrNull!, ownerId: host.uid);
    ok(saved);
    expect((await sessions.watchSavedSessions(host.uid).first).map((s) => s.id),
        contains(saved.valueOrNull!.id), reason: 'FR20');

    await sessions.renameSavedSession(host.uid, saved.valueOrNull!.id, 'Friday lunch');
    final again = await sessions.startFromSaved(host: host, saved: saved.valueOrNull!);
    ok(again);
    await sessions.deleteSavedSession(host.uid, saved.valueOrNull!.id);
    expect((await sessions.watchSavedSessions(host.uid).first).map((s) => s.id),
        isNot(contains(saved.valueOrNull!.id)), reason: 'FR21');

    final catalog = c.read(catalogServiceProvider);
    await catalog.toggleFavoriteRestaurant(host.uid, restaurant.id, true);
    await catalog.toggleFavoriteItem(host.uid, menu.first.id, true);
    final me = (await c.read(authServiceProvider).loadProfile(host.uid))!;
    expect(me.favoriteRestaurantIds, contains(restaurant.id), reason: 'FR23');
    expect(me.favoriteItemIds, contains(menu.first.id), reason: 'FR23');
    debugPrint('TC_SF_004 PASS saved, renamed, reused, deleted; favourites kept');
  });

  testWidgets('TC_SF_005 FR24 The assistant recommends real dishes and explains the app', (t) async {
    guest = await actAs(guestEmail);
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    final items = <MenuItem>[for (final r in all) ...await catalog.fetchMenu(r.id)];
    final context = AssistantContext(restaurants: all, items: items);
    final assistant = c.read(assistantServiceProvider);

    final food = await assistant.ask(uid: guest.uid, question: 'what is the best dessert?', context: context);
    ok(food);
    final known = {for (final i in items) i.id};
    expect(food.valueOrNull!.itemIds, isNotEmpty);
    expect(known.containsAll(food.valueOrNull!.itemIds), isTrue, reason: 'never an invented dish');

    final help = await assistant.ask(uid: guest.uid, question: 'how do I split the bill?', context: context);
    ok(help);
    expect(help.valueOrNull!.text, isNotEmpty);
    debugPrint('TC_SF_005 PASS "${food.valueOrNull!.text}"');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('TC_SF_006 FR25 FR26 A reward won on Spin & Win is spent on an order, once', (t) async {
    guest = await actAs(guestEmail);
    final spins = c.read(spinServiceProvider);
    final vouchers = c.read(voucherServiceProvider);
    await spins.resetSpin(guest.uid);
    final won = await spins.spin(uid: guest.uid, prizes: SpinRules.defaultPrizes);
    ok(won);
    final prize = won.valueOrNull!.voucher;
    final held = (await vouchers.fetchMine(guest.uid)).firstWhere((v) => v.id == prize.id);
    expect(held.isUsable, isTrue, reason: 'FR26');
    expect((await spins.spin(uid: guest.uid, prizes: SpinRules.defaultPrizes)).isSuccess, isFalse,
        reason: 'FR25: one spin every 24 hours');

    final cart = c.read(cartServiceProvider);
    await cart.clear(guest.uid);
    await cart.add(guest.uid, menu.first, quantity: 6);
    final lines = await cart.fetch(guest.uid);
    final before = OrderService.totalsFor(lines: lines, restaurant: restaurant);
    final quote = RewardRules.quote(held, subtotal: before.subtotal, deliveryFee: before.deliveryFee);
    expect(quote.isOk, isTrue, reason: quote.problem ?? '');
    final totals = OrderService.totalsFor(lines: lines, restaurant: restaurant, discount: quote.discount);
    expect(totals.total, lessThan(before.total), reason: 'FR26: the reward lowers the bill');

    final placed = await orders.placeIndividualOrder(
        user: guest, restaurant: restaurant, lines: lines, totals: totals,
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh', voucherCode: held.code);
    ok(placed);
    ok(await vouchers.redeem(uid: guest.uid, held: held, orderId: placed.valueOrNull!.id));
    final used = (await vouchers.fetchMine(guest.uid)).firstWhere((v) => v.id == prize.id);
    expect(used.status, VoucherStatus.used);
    expect((await vouchers.redeem(uid: guest.uid, held: used, orderId: 'second')).isSuccess, isFalse);
    await cart.clear(guest.uid);
    debugPrint('TC_SF_006 PASS saved ${(before.total - totals.total).toStringAsFixed(2)} SAR, '
        'second spin and second use refused');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_SF_007 FR27 FR28 Updates notify the customer until their settings say otherwise',
      (t) async {
    guest = await actAs(guestEmail);
    final cart = c.read(cartServiceProvider);
    await cart.clear(guest.uid);
    await cart.add(guest.uid, menu.first, quantity: 6);
    final lines = await cart.fetch(guest.uid);
    final placed = await orders.placeIndividualOrder(
        user: guest, restaurant: restaurant, lines: lines,
        totals: OrderService.totalsFor(lines: lines, restaurant: restaurant),
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    ok(placed);
    await cart.clear(guest.uid);
    final id = placed.valueOrNull!.id;
    ok(await orders.advanceStatus(orderId: id, status: OrderStatus.preparing));

    Future<List<String>> titles() async => [
          for (final n in await c.read(notificationServiceProvider).watch(guest.uid).first)
            if (n.orderId == id) n.title
        ];
    expect(await titles(), contains(OrderStatus.preparing.alertTitle), reason: 'FR27');

    ok(await c.read(authServiceProvider)
        .saveSettings(guest.uid, guest.settings.copyWith(orderUpdates: false)));
    guest = (await c.read(authServiceProvider).loadProfile(guest.uid))!;
    expect(guest.settings.orderUpdates, isFalse, reason: 'FR28');
    ok(await orders.advanceStatus(orderId: id, status: OrderStatus.ready));
    expect(await titles(), isNot(contains(OrderStatus.ready.alertTitle)),
        reason: 'FR28: a setting that is switched off is obeyed');
    ok(await c.read(authServiceProvider)
        .saveSettings(guest.uid, guest.settings.copyWith(orderUpdates: true)));
    debugPrint('TC_SF_007 PASS notified, then silenced by the setting');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('TC_SF_008 FR29 FR30 FR31 FR32 An administrator runs the platform', (t) async {
    final admin = await actAs(adminEmail, adminPassword);
    expect(admin.isAdmin, isTrue, reason: 'FR29');

    final users = await c.read(adminServiceProvider).watchUsers().first;
    expect(users.map((u) => u.uid), contains(third.uid), reason: 'FR30');
    ok(await c.read(adminServiceProvider)
        .setAccountStatus(uid: third.uid, status: AccountStatus.suspended));
    await FirebaseAuth.instance.signOut();
    final refused = await c.read(authServiceProvider).signIn(email: thirdEmail, password: password);
    expect(refused.errorOrNull, contains('suspended'), reason: 'FR30');

    await actAs(adminEmail, adminPassword);
    ok(await c.read(adminServiceProvider)
        .setAccountStatus(uid: third.uid, status: AccountStatus.active));
    final all = await orders.watchAllOrders(limit: 50).first;
    expect(all.map((o) => o.userId).toSet().length, greaterThan(1),
        reason: 'FR31: orders from different customers are visible');

    final vouchers = c.read(voucherServiceProvider);
    final code = 'SF$stamp';
    final made = await vouchers.upsert(Voucher(
        id: '', code: code, title: 'System test', discountType: DiscountType.percentage,
        discountValue: 10));
    ok(made);
    ok(await vouchers.setActive(made.valueOrNull!.id, false));
    ok(await vouchers.delete(made.valueOrNull!.id));
    debugPrint('TC_SF_008 PASS signed in, suspended and restored, saw ${all.length} orders, '
        'managed a reward');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('TC_SF_009 US20 A payment method the administrator adds reaches customers, and leaves',
      (t) async {
    await actAs(adminEmail, adminPassword);
    final pay = c.read(paymentServiceProvider);
    final created = await pay.upsertOption(PaymentOption(id: '', name: 'SystemTestPay$stamp'));
    ok(created);

    guest = await actAs(guestEmail);
    final offered = await pay.watchEnabledOptions().first;
    final option = offered.firstWhere((o) => o.name == 'SystemTestPay$stamp');
    final saved = await pay.addOption(uid: guest.uid, option: option);
    ok(saved);

    await actAs(adminEmail, adminPassword);
    ok(await pay.setOptionEnabled(created.valueOrNull!.id, false));
    final after = await pay.watchEnabledOptions().first;
    expect(after.map((o) => o.name), isNot(contains('SystemTestPay$stamp')));
    final charge = await pay.pay(amount: 10, method: saved.valueOrNull!, description: 'hidden');
    expect(charge.isSuccess, isFalse, reason: 'a hidden method is refused if charged');
    await pay.deleteOption(created.valueOrNull!.id);
    debugPrint('TC_SF_009 PASS added, used, hidden, refused');
  });
}
