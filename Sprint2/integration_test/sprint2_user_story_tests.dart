import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/order_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 2 user-story test cases, TC_U_022 to TC_U_050.
///
/// US8  suggest a restaurant     US12 save a group session
/// US9  the shared cart          US13 favourites
/// US10 group payment            US18 administration
/// US11 order tracking
///
/// They run against the live Firebase project, so every write is evaluated by
/// the real security rules as the user making it.
///
///   flutter test integration_test/sprint2_user_story_tests.dart -d DEVICE
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final hostEmail = 's2host$stamp@gather-test.local';
  final memberEmail = 's2member$stamp@gather-test.local';

  late ProviderContainer c;
  late AppUser host;
  late AppUser member;
  late Restaurant restaurant;
  late List<MenuItem> menu;
  late String sessionId;
  String? orderId;

  Future<AppUser> actAs(String email, [String pw = password]) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: pw);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  Future<GroupSession> session() async {
    final s = await c.read(sessionServiceProvider).fetch(sessionId);
    expect(s, isNotNull);
    return s!;
  }

  Future<CartTotals> totals() async {
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    return OrderService.totalsFor(lines: lines, restaurant: restaurant, discount: 0);
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();
    c = ProviderContainer();

    final auth = c.read(authServiceProvider);
    final h = await auth.signUp(
      fullName: 'S2 Host', username: 's2host$stamp', email: hostEmail,
      phone: '+96653000${stamp % 10000}', password: password);
    expect(h.isSuccess, isTrue, reason: h.errorOrNull ?? '');
    final m = await auth.signUp(
      fullName: 'S2 Member', username: 's2member$stamp', email: memberEmail,
      phone: '+96654000${stamp % 10000}', password: password);
    expect(m.isSuccess, isTrue, reason: m.errorOrNull ?? '');

    host = await actAs(hostEmail);
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    expect(all, isNotEmpty, reason: 'the catalogue must be seeded');
    // a restaurant with enough menu items to clear its minimum order
    restaurant = all.firstWhere((r) => r.minimumOrder < 200, orElse: () => all.first);
    menu = await catalog.fetchMenu(restaurant.id);
    expect(menu, isNotEmpty);

    final created = await c.read(sessionServiceProvider)
        .createSession(host: host, name: 'Sprint 2 session');
    expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
    sessionId = created.valueOrNull!.id;

    member = await actAs(memberEmail);
    final joined = await c.read(sessionServiceProvider)
        .joinByCode(code: created.valueOrNull!.code, user: member);
    expect(joined.isSuccess, isTrue, reason: joined.errorOrNull ?? '');
  });

  tearDownAll(() async {
    try {
      await actAs(hostEmail);
      await c.read(sessionServiceProvider).cancel(sessionId);
    } catch (_) {}
    for (final e in [hostEmail, memberEmail]) {
      try {
        await actAs(e);
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
    }
    c.dispose();
  });

  // ---------------------------------------------- US8 suggest a restaurant --

  testWidgets('TC_U_022 A member can suggest a restaurant', (t) async {
    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .suggestRestaurant(sessionId: sessionId, restaurant: restaurant, by: member);
    expect(r.isSuccess, isTrue, reason: 'US8-AC1: ${r.errorOrNull}');
    expect((await session()).suggestions.map((s) => s.restaurantId), contains(restaurant.id));
    debugPrint('TC_U_022 PASS');
  });

  testWidgets('TC_U_023 Every suggestion is visible to the group', (t) async {
    host = await actAs(hostEmail);
    final all = await c.read(catalogServiceProvider).fetchRestaurants();
    final other = all.firstWhere((r) => r.id != restaurant.id);
    final r = await c.read(sessionServiceProvider)
        .suggestRestaurant(sessionId: sessionId, restaurant: other, by: host);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    // read it back as the other member
    member = await actAs(memberEmail);
    final ids = (await session()).suggestions.map((s) => s.restaurantId).toList();
    expect(ids, containsAll([restaurant.id, other.id]),
        reason: 'US8-AC2: both suggestions must be visible to every member');
    debugPrint('TC_U_023 PASS ${ids.length} suggestions');
  });

  testWidgets('TC_U_024 The same restaurant cannot be suggested twice', (t) async {
    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .suggestRestaurant(sessionId: sessionId, restaurant: restaurant, by: member);
    expect(r.isSuccess, isFalse, reason: 'US8-AC3: a duplicate must be refused');
    expect(r.errorOrNull, contains('already been suggested'),
        reason: 'US8-AC3: and it should say who suggested it');
    debugPrint('TC_U_024 PASS message="${r.errorOrNull}"');
  });

  testWidgets('TC_U_025 Suggesting a restaurant counts as backing it', (t) async {
    // The member suggested this one in TC_U_022, so their own vote is already
    // on it: you back what you put forward.
    final s = await session();
    final mine = s.suggestions.firstWhere((x) => x.restaurantId == restaurant.id);
    expect(mine.votes, contains(member.uid),
        reason: 'US8-AC2: the suggester backs their own suggestion');
    debugPrint('TC_U_025 PASS ${mine.votes.length} vote(s)');
  });

  testWidgets('TC_U_025b Another member can vote for a suggestion', (t) async {
    host = await actAs(hostEmail);
    final r = await c.read(sessionServiceProvider)
        .toggleVote(sessionId: sessionId, restaurantId: restaurant.id, uid: host.uid);
    expect(r.isSuccess, isTrue, reason: 'US8-AC2: ${r.errorOrNull}');
    final voted = (await session())
        .suggestions.firstWhere((x) => x.restaurantId == restaurant.id);
    expect(voted.votes, containsAll([member.uid, host.uid]),
        reason: 'US8-AC2: both members back it');
    debugPrint('TC_U_025b PASS ${voted.votes.length} votes');
  });

  testWidgets('TC_U_025c Voting again withdraws the vote', (t) async {
    host = await actAs(hostEmail);
    final r = await c.read(sessionServiceProvider)
        .toggleVote(sessionId: sessionId, restaurantId: restaurant.id, uid: host.uid);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    final voted = (await session())
        .suggestions.firstWhere((x) => x.restaurantId == restaurant.id);
    expect(voted.votes, isNot(contains(host.uid)),
        reason: 'US8-AC2: the control is a toggle');
    expect(voted.votes, contains(member.uid),
        reason: 'withdrawing one vote must not touch anyone else\'s');
    debugPrint('TC_U_025c PASS ${voted.votes.length} vote(s) left');
  });

  testWidgets('TC_U_052 A member can only put one restaurant forward', (t) async {
    member = await actAs(memberEmail);
    final all = await c.read(catalogServiceProvider).fetchRestaurants();
    final taken = (await session()).suggestions.map((x) => x.restaurantId).toSet();
    final third = all.firstWhere((r) => !taken.contains(r.id));
    final r = await c.read(sessionServiceProvider)
        .suggestRestaurant(sessionId: sessionId, restaurant: third, by: member);
    expect(r.isSuccess, isFalse,
        reason: 'US8: each member suggests one restaurant, not several');
    expect(r.errorOrNull, contains('Withdraw it first'),
        reason: 'US8: the member should be told how to swap their pick');
    debugPrint('TC_U_052 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_U_053 A member can withdraw their pick and choose another',
      (t) async {
    member = await actAs(memberEmail);
    final service = c.read(sessionServiceProvider);
    final mine = (await session()).suggestionBy(member.uid)!;

    final removed = await service.removeSuggestion(
        sessionId: sessionId, restaurantId: mine.restaurantId, byUid: member.uid);
    expect(removed.isSuccess, isTrue, reason: 'US8: your own pick is yours to take back');
    expect((await session()).suggestionBy(member.uid), isNull);

    // and the slot is free again
    final again = await service.suggestRestaurant(
        sessionId: sessionId, restaurant: restaurant, by: member);
    expect(again.isSuccess, isTrue, reason: again.errorOrNull ?? '');
    debugPrint('TC_U_053 PASS');
  });

  testWidgets('TC_U_054 The host chooses how the restaurant is decided', (t) async {
    host = await actAs(hostEmail);
    final service = c.read(sessionServiceProvider);

    final spin = await service.setDecisionMode(
        sessionId: sessionId, mode: RestaurantDecisionMode.spin);
    expect(spin.isSuccess, isTrue, reason: 'US8: ${spin.errorOrNull}');
    expect((await session()).decisionMode, RestaurantDecisionMode.spin);

    final mine = await service.setDecisionMode(
        sessionId: sessionId, mode: RestaurantDecisionMode.hostChoice);
    expect(mine.isSuccess, isTrue, reason: mine.errorOrNull ?? '');
    final s = await session();
    expect(s.decisionMode, RestaurantDecisionMode.hostChoice);
    expect(s.suggestions, isEmpty,
        reason: 'choosing to pick yourself clears the wheel\'s input');
    debugPrint('TC_U_054 PASS');
  });

  testWidgets('TC_U_055 Nobody is asked to suggest once the host is choosing',
      (t) async {
    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .suggestRestaurant(sessionId: sessionId, restaurant: restaurant, by: member);
    expect(r.isSuccess, isFalse,
        reason: 'US8: suggestions are only for the wheel');
    expect(r.errorOrNull, contains('host is choosing'));

    // put it back so the cart tests can run
    host = await actAs(hostEmail);
    await c.read(sessionServiceProvider)
        .setDecisionMode(sessionId: sessionId, mode: RestaurantDecisionMode.spin);
    debugPrint('TC_U_055 PASS refused="${r.errorOrNull}"');
  });

  // ------------------------------------------------------ US9 shared cart --

  testWidgets('TC_U_026 The host picks the restaurant for the group', (t) async {
    host = await actAs(hostEmail);
    final r = await c.read(sessionServiceProvider)
        .chooseRestaurant(sessionId: sessionId, restaurant: restaurant);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    final s = await session();
    expect(s.restaurantId, restaurant.id);
    expect(s.stage, SessionStage.ordering);
    debugPrint('TC_U_026 PASS ${restaurant.name}');
  });

  testWidgets('TC_U_027 A member adds an item to the shared cart', (t) async {
    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .addLine(sessionId: sessionId, item: menu.first, owner: member, quantity: 2);
    expect(r.isSuccess, isTrue, reason: 'US9-AC1: ${r.errorOrNull}');
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    expect(lines, isNotEmpty);
    debugPrint('TC_U_027 PASS ${lines.length} line(s)');
  });

  testWidgets('TC_U_028 Every line records the member who added it', (t) async {
    host = await actAs(hostEmail);
    final r = await c.read(sessionServiceProvider).addLine(
        sessionId: sessionId, item: menu.last, owner: host, quantity: 1);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    for (final l in lines) {
      expect(l.ownerId.trim(), isNotEmpty, reason: 'US9-AC2: a line must know its owner');
      expect(l.ownerName.trim(), isNotEmpty);
    }
    expect(lines.map((l) => l.ownerId).toSet(), containsAll([host.uid, member.uid]),
        reason: 'US9-AC1: the cart holds every member\'s items');
    debugPrint('TC_U_028 PASS ${lines.length} lines from '
        '${lines.map((l) => l.ownerId).toSet().length} members');
  });

  testWidgets('TC_U_029 A change to the cart is seen by the other member', (t) async {
    host = await actAs(hostEmail);
    final before = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final mine = before.firstWhere((l) => l.ownerId == host.uid);
    final r = await c.read(sessionServiceProvider)
        .setLineQuantity(sessionId: sessionId, lineId: mine.id, quantity: 3);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    member = await actAs(memberEmail);
    final after = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    expect(after.firstWhere((l) => l.id == mine.id).quantity, 3,
        reason: 'US9-AC3: the change must be visible to every participant');
    debugPrint('TC_U_029 PASS');
  });

  // --------------------------------------------------- US10 group payment --

  testWidgets('TC_U_030 The host can select individual payment', (t) async {
    host = await actAs(hostEmail);
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final r = await c.read(sessionServiceProvider).setPaymentMode(
        sessionId: sessionId, mode: PaymentMode.individual,
        totals: await totals(), lines: lines);
    expect(r.isSuccess, isTrue, reason: 'US10-AC1: ${r.errorOrNull}');
    expect((await session()).paymentMode, PaymentMode.individual);
    debugPrint('TC_U_030 PASS');
  });

  testWidgets('TC_U_031 The host can select an equal split', (t) async {
    host = await actAs(hostEmail);
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final t0 = await totals();
    final r = await c.read(sessionServiceProvider).setPaymentMode(
        sessionId: sessionId, mode: PaymentMode.equalSplit, totals: t0, lines: lines);
    expect(r.isSuccess, isTrue, reason: 'US10-AC2: ${r.errorOrNull}');

    final s = await session();
    expect(s.paymentMode, PaymentMode.equalSplit);
    final amounts = s.members.map((m) => m.amountDue).toList();
    expect(amounts.every((a) => a > 0), isTrue, reason: 'every member owes a share');
    expect((amounts.fold<double>(0, (a, b) => a + b) * 100).round(),
        (t0.total * 100).round(),
        reason: 'US10-AC2: the shares must add back to the total');
    debugPrint('TC_U_031 PASS shares=$amounts total=${t0.total}');
  });

  testWidgets('TC_U_032 The host can select host pays', (t) async {
    host = await actAs(hostEmail);
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final t0 = await totals();
    final r = await c.read(sessionServiceProvider).setPaymentMode(
        sessionId: sessionId, mode: PaymentMode.hostPays, totals: t0, lines: lines);
    expect(r.isSuccess, isTrue, reason: 'US10-AC3: ${r.errorOrNull}');

    final s = await session();
    final hostMember = s.memberOf(host.uid)!;
    expect((hostMember.amountDue * 100).round(), (t0.total * 100).round(),
        reason: 'US10-AC3: the host owes the whole total');
    for (final m in s.members.where((m) => !m.isHost)) {
      expect(m.paymentStatus, MemberPaymentStatus.notRequired,
          reason: 'US10-AC3: nobody else owes anything');
    }
    debugPrint('TC_U_032 PASS host owes ${hostMember.amountDue}');
  });

  testWidgets('TC_U_033 The selected option is visible to the members', (t) async {
    member = await actAs(memberEmail);
    expect((await session()).paymentMode, PaymentMode.hostPays,
        reason: 'US10-AC4: a member must see which option the host chose');
    debugPrint('TC_U_033 PASS');
  });

  testWidgets('TC_U_034 Individual payment charges each member for their own items',
      (t) async {
    host = await actAs(hostEmail);
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final t0 = await totals();
    final r = await c.read(sessionServiceProvider).setPaymentMode(
        sessionId: sessionId, mode: PaymentMode.individual, totals: t0, lines: lines);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final s = await session();
    final sum = s.members.fold<double>(0, (a, m) => a + m.amountDue);
    expect((sum * 100).round(), (t0.total * 100).round(),
        reason: 'US10-AC1: individual amounts must still add up to the total');
    debugPrint('TC_U_034 PASS sum=$sum total=${t0.total}');
  });

  // -------------------------------------------------- US11 order tracking --

  testWidgets('TC_U_035 The group order can be placed', (t) async {
    host = await actAs(hostEmail);
    final service = c.read(sessionServiceProvider);
    for (final m in (await session()).members) {
      await service.markPaid(sessionId: sessionId, uid: m.uid);
    }
    await service.setDeliveryAddress(
        sessionId: sessionId, address: 'Building 7, King Fahd Road, Riyadh');

    final lines = (await service.fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final placed = await c.read(orderServiceProvider).placeGroupOrder(
          session: await session(),
          restaurant: restaurant,
          lines: lines,
          totals: await totals(),
          paymentMethodLabel: 'Visa •••• 4242',
          deliveryAddress: 'Building 7, King Fahd Road, Riyadh',
        );
    expect(placed.isSuccess, isTrue, reason: 'US11-AC1: ${placed.errorOrNull}');
    orderId = placed.valueOrNull!.id;
    await service.markPlaced(sessionId: sessionId, orderId: orderId!);
    debugPrint('TC_U_035 PASS order=$orderId');
  });

  testWidgets('TC_U_036 A participant can view the order status', (t) async {
    member = await actAs(memberEmail);
    final order = await c.read(orderServiceProvider).fetchOrder(orderId!);
    expect(order, isNotNull, reason: 'US11-AC1: a participant must see the order');
    expect(order!.status, OrderStatus.confirmed);
    expect(order.participantIds, contains(member.uid));
    debugPrint('TC_U_036 PASS status=${order.status.name}');
  });

  testWidgets('TC_U_037 Status updates appear as the order progresses', (t) async {
    host = await actAs(hostEmail);
    final orders = c.read(orderServiceProvider);
    for (final s in [OrderStatus.preparing, OrderStatus.onTheWay, OrderStatus.delivered]) {
      final r = await orders.advanceStatus(orderId: orderId!, status: s);
      expect(r.isSuccess, isTrue, reason: 'US11-AC2: ${r.errorOrNull}');
    }
    final order = await orders.fetchOrder(orderId!);
    expect(order!.status, OrderStatus.delivered);
    expect(order.timeline.length, greaterThanOrEqualTo(3),
        reason: 'US11-AC2: every change must be recorded on the timeline');
    debugPrint('TC_U_037 PASS ${order.timeline.length} timeline events');
  });

  testWidgets('TC_U_038 The order carries its delivery information', (t) async {
    member = await actAs(memberEmail);
    final order = await c.read(orderServiceProvider).fetchOrder(orderId!);
    expect(order!.deliveryAddress.trim(), isNotEmpty,
        reason: 'US11-AC3: the delivery address must travel with the order');
    expect(order.restaurantName.trim(), isNotEmpty);
    expect(order.total, greaterThan(0));
    debugPrint('TC_U_038 PASS "${order.deliveryAddress}"');
  });

  // ------------------------------------------------- US12 saved sessions --

  testWidgets('TC_U_039 The host can save a group session', (t) async {
    host = await actAs(hostEmail);
    final r = await c.read(sessionServiceProvider)
        .saveAsGroup(session: await session(), ownerId: host.uid, name: 'Dinner crew');
    expect(r.isSuccess, isTrue, reason: 'US12-AC1: ${r.errorOrNull}');
    expect(r.valueOrNull!.name, 'Dinner crew');
    debugPrint('TC_U_039 PASS');
  });

  testWidgets('TC_U_040 The saved session appears in the saved list', (t) async {
    host = await actAs(hostEmail);
    final saved = await c.read(sessionServiceProvider).watchSavedSessions(host.uid).first;
    expect(saved.map((s) => s.name), contains('Dinner crew'),
        reason: 'US12-AC2: it must be listed for its owner');
    debugPrint('TC_U_040 PASS ${saved.length} saved');
  });

  testWidgets('TC_U_041 The saved session keeps its members', (t) async {
    host = await actAs(hostEmail);
    final saved = await c.read(sessionServiceProvider).watchSavedSessions(host.uid).first;
    final group = saved.firstWhere((s) => s.name == 'Dinner crew');
    expect(group.members.map((m) => m.uid), containsAll([host.uid, member.uid]),
        reason: 'US12-AC3: the members must be retained');
    debugPrint('TC_U_041 PASS ${group.members.length} members');
  });

  // ----------------------------------------------------- US13 favourites --

  testWidgets('TC_U_042 A user can add a restaurant to favourites', (t) async {
    member = await actAs(memberEmail);
    await c.read(catalogServiceProvider)
        .toggleFavoriteRestaurant(member.uid, restaurant.id, true);
    final profile = await c.read(authServiceProvider).loadProfile(member.uid);
    expect(profile!.favoriteRestaurantIds, contains(restaurant.id),
        reason: 'US13-AC1');
    debugPrint('TC_U_042 PASS');
  });

  testWidgets('TC_U_043 A user can add a food item to favourites', (t) async {
    member = await actAs(memberEmail);
    await c.read(catalogServiceProvider)
        .toggleFavoriteItem(member.uid, menu.first.id, true);
    final profile = await c.read(authServiceProvider).loadProfile(member.uid);
    expect(profile!.favoriteItemIds, contains(menu.first.id), reason: 'US13-AC1');
    debugPrint('TC_U_043 PASS');
  });

  testWidgets('TC_U_044 A user can view their saved favourites', (t) async {
    member = await actAs(memberEmail);
    final profile = await c.read(authServiceProvider).loadProfile(member.uid);
    final all = await c.read(catalogServiceProvider).fetchRestaurants();
    final favourites = all.where((r) => profile!.favoriteRestaurantIds.contains(r.id));
    expect(favourites, isNotEmpty, reason: 'US13-AC2: favourites must be listable');
    debugPrint('TC_U_044 PASS ${favourites.length} favourite restaurant(s)');
  });

  testWidgets('TC_U_045 A user can remove a favourite', (t) async {
    member = await actAs(memberEmail);
    final catalog = c.read(catalogServiceProvider);
    await catalog.toggleFavoriteRestaurant(member.uid, restaurant.id, false);
    await catalog.toggleFavoriteItem(member.uid, menu.first.id, false);
    final profile = await c.read(authServiceProvider).loadProfile(member.uid);
    expect(profile!.favoriteRestaurantIds, isNot(contains(restaurant.id)),
        reason: 'US13-AC3');
    expect(profile.favoriteItemIds, isNot(contains(menu.first.id)));
    debugPrint('TC_U_045 PASS');
  });

  // -------------------------------------------------- US18 administration --

  testWidgets('TC_U_046 An administrator can reach the dashboard', (t) async {
    final admin = await actAs(adminEmail, adminPassword);
    expect(admin.isAdmin, isTrue, reason: 'US18-AC1: the account must hold the role');
    debugPrint('TC_U_046 PASS ${admin.email}');
  });

  testWidgets('TC_U_047 An administrator can monitor application activity', (t) async {
    await actAs(adminEmail, adminPassword);
    final stats = await c.read(adminServiceProvider).loadStats();
    expect(stats.totalUsers, greaterThan(0), reason: 'US18-AC2');
    expect(stats.totalOrders, greaterThan(0));

    final users = await c.read(adminServiceProvider).watchUsers().first;
    final sessions = await c.read(adminServiceProvider).watchSessions().first;
    final orders = await c.read(orderServiceProvider).watchAllOrders().first;
    expect(users, isNotEmpty);
    expect(sessions, isNotEmpty);
    expect(orders, isNotEmpty);
    debugPrint('TC_U_047 PASS users=${stats.totalUsers} orders=${stats.totalOrders} '
        'sessions=${sessions.length}');
  });

  testWidgets('TC_U_048 An administrator can view a reported issue', (t) async {
    member = await actAs(memberEmail);
    final raised = await c.read(supportServiceProvider).submit(
          user: member,
          subject: 'Order never arrived',
          message: 'The order was marked delivered but nothing reached us.',
          category: TicketCategory.order,
        );
    expect(raised.isSuccess, isTrue, reason: raised.errorOrNull ?? '');

    await actAs(adminEmail, adminPassword);
    final tickets = await c.read(supportServiceProvider).watchAllTickets().first;
    expect(tickets.map((x) => x.id), contains(raised.valueOrNull!.id),
        reason: 'US18-AC3: a reported issue must be visible to an administrator');
    debugPrint('TC_U_048 PASS ${tickets.length} ticket(s)');
  });

  testWidgets('TC_U_049 An administrator can handle a reported issue', (t) async {
    await actAs(adminEmail, adminPassword);
    final tickets = await c.read(supportServiceProvider).watchAllTickets().first;
    final open = tickets.first;
    final r = await c.read(supportServiceProvider).respond(
        ticketId: open.id, reply: 'Refunded and the courier was contacted.',
        status: TicketStatus.resolved);
    expect(r.isSuccess, isTrue, reason: 'US18-AC4: ${r.errorOrNull}');

    final after = await c.read(supportServiceProvider).watchAllTickets().first;
    final updated = after.firstWhere((x) => x.id == open.id);
    expect(updated.status, TicketStatus.resolved);
    debugPrint('TC_U_049 PASS');
  });

  testWidgets('TC_U_050 An administrator can suspend and restore an account',
      (t) async {
    await actAs(adminEmail, adminPassword);
    final admin = c.read(adminServiceProvider);
    final suspend = await admin.setAccountStatus(
        uid: member.uid, status: AccountStatus.suspended);
    expect(suspend.isSuccess, isTrue, reason: 'US18-AC5: ${suspend.errorOrNull}');
    expect((await c.read(authServiceProvider).loadProfile(member.uid))!.status,
        AccountStatus.suspended);

    final restore = await admin.setAccountStatus(
        uid: member.uid, status: AccountStatus.active);
    expect(restore.isSuccess, isTrue, reason: restore.errorOrNull ?? '');
    debugPrint('TC_U_050 PASS');
  });

  testWidgets('TC_U_051 A non-administrator cannot use administrative functions',
      (t) async {
    member = await actAs(memberEmail);
    final admin = c.read(adminServiceProvider);

    final suspend = await admin.setAccountStatus(
        uid: host.uid, status: AccountStatus.suspended);
    expect(suspend.isSuccess, isFalse,
        reason: 'US18-AC6: a customer must not be able to suspend an account');

    final promote = await admin.setRole(uid: member.uid, role: UserRole.admin);
    expect(promote.isSuccess, isFalse,
        reason: 'US18-AC6: a customer must not be able to grant themselves the role');

    expect((await c.read(authServiceProvider).loadProfile(member.uid))!.isAdmin, isFalse);
    debugPrint('TC_U_051 PASS both refused');
  });
}
