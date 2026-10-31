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
import 'package:gather/core/services/order_service.dart';
import 'package:gather/core/services/session_service.dart';
import 'package:gather/core/widgets/gather_button.dart';
import 'package:gather/core/widgets/gather_field.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 2 edge cases, TC_E_001 to TC_E_016.
///
/// The user-story tests check that the features work. These check that they
/// refuse what they should: one member editing another's items, a non-host
/// taking host decisions, an order placed below the minimum or before everyone
/// has paid, a suspended account still acting.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final hostEmail = 'e2host$stamp@gather-test.local';
  final memberEmail = 'e2member$stamp@gather-test.local';
  final outsiderEmail = 'e2out$stamp@gather-test.local';

  late ProviderContainer c;
  late AppUser host, member, outsider;
  late Restaurant restaurant, otherRestaurant;
  late List<MenuItem> menu;
  late String sessionId;

  Future<AppUser> actAs(String email, [String pw = password]) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: pw);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  Future<GroupSession> session() async =>
      (await c.read(sessionServiceProvider).fetch(sessionId))!;

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signOut();
    c = ProviderContainer();
    final auth = c.read(authServiceProvider);

    for (final (email, name, i) in [
      (hostEmail, 'E Host', 0), (memberEmail, 'E Member', 1), (outsiderEmail, 'E Outsider', 2)
    ]) {
      final r = await auth.signUp(
          fullName: name, username: 'e2u$i$stamp', email: email,
          phone: '+9665700$i${stamp % 10000}', password: password);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      if (i == 0) host = r.valueOrNull!;
      if (i == 1) member = r.valueOrNull!;
      if (i == 2) outsider = r.valueOrNull!;
    }

    host = await actAs(hostEmail);
    final all = await c.read(catalogServiceProvider).fetchRestaurants();
    restaurant = all.first;
    otherRestaurant = all.firstWhere((r) => r.id != restaurant.id);
    menu = await c.read(catalogServiceProvider).fetchMenu(restaurant.id);

    final created = await c.read(sessionServiceProvider)
        .createSession(host: host, name: 'Edge case session');
    sessionId = created.valueOrNull!.id;
    await c.read(sessionServiceProvider)
        .chooseRestaurant(sessionId: sessionId, restaurant: restaurant);

    member = await actAs(memberEmail);
    await c.read(sessionServiceProvider)
        .joinByCode(code: created.valueOrNull!.code, user: member);
  });

  tearDownAll(() async {
    try {
      await actAs(hostEmail);
      await c.read(sessionServiceProvider).cancel(sessionId);
    } catch (_) {}
    for (final e in [hostEmail, memberEmail, outsiderEmail]) {
      try {
        await actAs(e);
        await FirebaseAuth.instance.currentUser?.delete();
      } catch (_) {}
    }
    c.dispose();
  });

  testWidgets('TC_E_001 A member cannot edit another member\'s cart line', (t) async {
    host = await actAs(hostEmail);
    await c.read(sessionServiceProvider)
        .addLine(sessionId: sessionId, item: menu.first, owner: host, quantity: 1);
    final hostLine = ((await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[])
        .firstWhere((l) => l.ownerId == host.uid);

    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .setLineQuantity(sessionId: sessionId, lineId: hostLine.id, quantity: 99);
    expect(r.isSuccess, isFalse,
        reason: 'FR12: a member must not be able to change someone else\'s item');
    final after = ((await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[])
        .firstWhere((l) => l.id == hostLine.id);
    expect(after.quantity, 1, reason: 'the quantity must be unchanged');
    debugPrint('TC_E_001 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_002 A member cannot delete another member\'s cart line', (t) async {
    final hostLine = ((await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[])
        .firstWhere((l) => l.ownerId == host.uid);
    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .removeLine(sessionId: sessionId, lineId: hostLine.id);
    expect(r.isSuccess, isFalse, reason: 'FR12: only the owner may remove their line');
    expect(((await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[])
        .any((l) => l.id == hostLine.id), isTrue);
    debugPrint('TC_E_002 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_003 An item from another restaurant is refused', (t) async {
    member = await actAs(memberEmail);
    final otherMenu = await c.read(catalogServiceProvider).fetchMenu(otherRestaurant.id);
    final r = await c.read(sessionServiceProvider)
        .addLine(sessionId: sessionId, item: otherMenu.first, owner: member, quantity: 1);
    expect(r.isSuccess, isFalse,
        reason: 'a shared cart holds one restaurant\'s food');
    debugPrint('TC_E_003 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_004 An outsider cannot read the shared cart', (t) async {
    outsider = await actAs(outsiderEmail);
    final r = await c.read(sessionServiceProvider).fetchLines(sessionId);
    expect(r.isSuccess, isFalse,
        reason: 'someone who never joined must not read the shared cart');
    expect(r.errorOrNull, isNotNull,
        reason: 'and must get a message rather than an uncaught exception');
    debugPrint('TC_E_004 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_005 An outsider cannot add to the shared cart', (t) async {
    outsider = await actAs(outsiderEmail);
    final r = await c.read(sessionServiceProvider)
        .addLine(sessionId: sessionId, item: menu.first, owner: outsider, quantity: 1);
    expect(r.isSuccess, isFalse, reason: 'only members may add to the cart');
    debugPrint('TC_E_005 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_006 A member cannot choose the restaurant', (t) async {
    member = await actAs(memberEmail);
    final r = await c.read(sessionServiceProvider)
        .chooseRestaurant(sessionId: sessionId, restaurant: otherRestaurant);
    expect(r.isSuccess, isFalse, reason: 'choosing the restaurant is the host\'s decision');
    expect((await session()).restaurantId, restaurant.id);
    debugPrint('TC_E_006 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_007 A member cannot set the payment mode', (t) async {
    member = await actAs(memberEmail);
    final lines = (await c.read(sessionServiceProvider).fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final totals = OrderService.totalsFor(
        lines: lines, restaurant: restaurant, discount: 0);
    final r = await c.read(sessionServiceProvider).setPaymentMode(
        sessionId: sessionId, mode: PaymentMode.hostPays, totals: totals, lines: lines);
    expect(r.isSuccess, isFalse, reason: 'US10: the host chooses how the group pays');
    debugPrint('TC_E_007 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_008 An order cannot be placed before everyone has paid', (t) async {
    host = await actAs(hostEmail);
    final service = c.read(sessionServiceProvider);
    final lines = (await service.fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final totals = OrderService.totalsFor(
        lines: lines, restaurant: restaurant, discount: 0);
    await service.setPaymentMode(
        sessionId: sessionId, mode: PaymentMode.individual, totals: totals, lines: lines);

    final r = await c.read(orderServiceProvider).placeGroupOrder(
        session: await session(), restaurant: restaurant, lines: lines,
        totals: totals, paymentMethodLabel: 'Visa', deliveryAddress: 'Riyadh');
    expect(r.isSuccess, isFalse, reason: 'everyone must have settled first');
    expect(r.errorOrNull, contains('pending'));
    debugPrint('TC_E_008 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_009 An order below the minimum is refused', (t) async {
    host = await actAs(hostEmail);
    final service = c.read(sessionServiceProvider);
    for (final m in (await session()).members) {
      await service.markPaid(sessionId: sessionId, uid: m.uid);
    }
    final lines = (await service.fetchLines(sessionId)).valueOrNull ?? const <CartLine>[];
    final tiny = OrderService.totalsFor(lines: const [], restaurant: restaurant, discount: 0);
    final r = await c.read(orderServiceProvider).placeGroupOrder(
        session: await session(), restaurant: restaurant, lines: lines,
        totals: tiny, paymentMethodLabel: 'Visa', deliveryAddress: 'Riyadh');
    expect(r.isSuccess, isFalse, reason: 'the restaurant minimum must be enforced');
    debugPrint('TC_E_009 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_010 An equal split across one member gives them the total',
      (t) async {
    final solo = GroupSession(
      id: 'x', code: '1234', name: 'solo',
      hostId: host.uid, hostName: 'E Host',
      members: [SessionMember(uid: host.uid, name: 'E Host', username: 'ehost', isHost: true)],
      memberIds: [host.uid],
    );
    final totals = OrderService.totalsFor(
        lines: const [], restaurant: restaurant, discount: 0);
    final allocated =
        SessionService.allocate(solo, PaymentMode.equalSplit, totals, const []);
    expect(allocated.length, 1);
    expect((allocated.first.amountDue * 100).round(), (totals.total * 100).round(),
        reason: 'a group of one owes the whole total');
    debugPrint('TC_E_010 PASS ${allocated.first.amountDue}');
  });

  testWidgets('TC_E_011 A suspended account cannot sign in', (t) async {
    await actAs(adminEmail, adminPassword);
    final suspend = await c.read(adminServiceProvider)
        .setAccountStatus(uid: member.uid, status: AccountStatus.suspended);
    expect(suspend.isSuccess, isTrue, reason: suspend.errorOrNull ?? '');

    await FirebaseAuth.instance.signOut();
    final attempt = await c.read(authServiceProvider)
        .signIn(email: memberEmail, password: password);
    expect(attempt.isSuccess, isFalse,
        reason: 'US18-AC5: suspending an account must actually stop it being used');
    expect(attempt.errorOrNull, contains('suspended'));
    debugPrint('TC_E_011 PASS refused="${attempt.errorOrNull}"');

    // put the account back so the rest of the run can use it
    await actAs(adminEmail, adminPassword);
    await c.read(adminServiceProvider)
        .setAccountStatus(uid: member.uid, status: AccountStatus.active);
    final back = await actAs(memberEmail);
    expect(back.uid, member.uid, reason: 'restoring must let them back in');
  });

  testWidgets('TC_E_013 A member cannot remove someone else\'s suggestion',
      (t) async {
    final service = c.read(sessionServiceProvider);
    host = await actAs(hostEmail);
    await service.setDecisionMode(
        sessionId: sessionId, mode: RestaurantDecisionMode.spin);
    final hostPick = await service.suggestRestaurant(
        sessionId: sessionId, restaurant: otherRestaurant, by: host);
    expect(hostPick.isSuccess, isTrue, reason: hostPick.errorOrNull ?? '');

    member = await actAs(memberEmail);
    final r = await service.removeSuggestion(
        sessionId: sessionId, restaurantId: otherRestaurant.id, byUid: member.uid);
    expect(r.isSuccess, isFalse,
        reason: 'US8: only the host may clear someone else\'s pick');
    final still = (await c.read(sessionServiceProvider).fetch(sessionId))!;
    expect(still.suggestions.map((x) => x.restaurantId), contains(otherRestaurant.id));
    debugPrint('TC_E_013 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_014 The host can clear any suggestion', (t) async {
    host = await actAs(hostEmail);
    final r = await c.read(sessionServiceProvider).removeSuggestion(
        sessionId: sessionId, restaurantId: otherRestaurant.id, byUid: host.uid);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    final after = (await c.read(sessionServiceProvider).fetch(sessionId))!;
    expect(after.suggestions.map((x) => x.restaurantId),
        isNot(contains(otherRestaurant.id)));
    debugPrint('TC_E_014 PASS');
  });

  testWidgets('TC_E_012 An outsider cannot save someone else\'s session as a group',
      (t) async {
    outsider = await actAs(outsiderEmail);
    final s = await c.read(sessionServiceProvider).fetch(sessionId);
    if (s == null) {
      debugPrint('TC_E_012 PASS the session is not even readable');
      return;
    }
    final r = await c.read(sessionServiceProvider)
        .saveAsGroup(session: s, ownerId: host.uid, name: 'Stolen group');
    expect(r.isSuccess, isFalse,
        reason: 'US12: a saved group belongs to the person saving it');
    debugPrint('TC_E_012 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_016 A session cannot take more than 20 people', (t) async {
    final service = c.read(sessionServiceProvider);
    host = await actAs(hostEmail);
    final created = await service.createSession(host: host, name: 'Capacity');
    expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
    final full = created.valueOrNull!;

    // Fill the roster up to the ceiling. The host may write the member list,
    // so this stands in for nineteen more people joining.
    final padded = [
      ...full.members,
      for (var i = full.members.length; i < GroupSession.maxMembers; i++)
        SessionMember(uid: 'filler-$i-$stamp', name: 'Filler $i',
            username: 'filler$i', joinedAt: DateTime.now()),
    ];
    await c.read(firestoreRefsProvider).session(full.id).update({
      'members': padded.map((m) => m.toMap()).toList(),
      'memberIds': padded.map((m) => m.uid).toList(),
    });

    final atCeiling = await service.fetch(full.id);
    expect(atCeiling!.members, hasLength(GroupSession.maxMembers));
    expect(atCeiling.isFull, isTrue);
    expect(atCeiling.placesLeft, 0);

    // The twenty-first person is refused.
    member = await actAs(memberEmail);
    final r = await service.joinByCode(code: full.code, user: member);
    expect(r.isSuccess, isFalse,
        reason: 'a session must not take more than ${GroupSession.maxMembers}');
    expect(r.errorOrNull, contains('full'));

    final after = await service.fetch(full.id);
    expect(after!.members, hasLength(GroupSession.maxMembers),
        reason: 'and the roster must be unchanged');

    host = await actAs(hostEmail);
    await service.cancel(full.id);
    debugPrint('TC_E_016 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_E_015 Leaving a session still allows joining another one',
      (t) async {
    // Reported from two devices: after leaving a session, the Join button on
    // the group hub sat on a spinner and could not be tapped again. It is a
    // UI-state failure, so this case drives the real screens rather than the
    // service.
    host = await actAs(hostEmail);
    final service = c.read(sessionServiceProvider);
    final first = (await service.createSession(host: host, name: 'Nights')).valueOrNull!;
    final second =
        (await service.createSession(host: host, name: 'Late dinner')).valueOrNull!;

    member = await actAs(memberEmail);

    final prefs = await AppPrefs.load();
    final app = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    app.read(onboardingSeenProvider.notifier).state = true;

    /// Real network round-trips do not fit `pumpAndSettle`'s model, so the
    /// helpers below pump against a deadline instead.
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await t.pump(const Duration(milliseconds: 180));
      }
    }

    String onScreen() => t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .join(' | ');

    Future<void> waitFor(Finder finder, String what) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        await t.pump(const Duration(milliseconds: 220));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('Timed out waiting for $what.\nOn screen: ${onScreen()}');
    }

    // The band's Join button. While a GatherButton is busy it renders a
    // spinner in place of its label, so the label going missing is itself the
    // symptom the client reported.
    final joinButton = find.widgetWithText(GatherButton, 'Join');
    final buttonSpinner = find.descendant(
      of: find.byType(GatherButton),
      matching: find.byType(CircularProgressIndicator),
    );
    final codeField =
        find.descendant(of: find.byType(CodeInput), matching: find.byType(TextField));

    Future<void> joinByCodeThroughTheUi(String code, String sessionName) async {
      await waitFor(joinButton, 'the Join button on the group hub');
      expect(buttonSpinner, findsNothing,
          reason: 'no button on the group hub should be loading before it is tapped');
      await t.tap(joinButton);
      await settle();
      await waitFor(codeField, 'the 4-digit code screen');
      await t.enterText(codeField, code);
      await waitFor(find.text(sessionName), 'the "$sessionName" session screen');
    }

    await t.pumpWidget(
      UncontrolledProviderScope(container: app, child: const GatherApp()),
    );
    await settle(30);
    app.read(routerProvider).go(Routes.group);
    await settle();

    await joinByCodeThroughTheUi(first.code, 'Nights');
    expect((await service.fetch(first.id))!.hasMember(member.uid), isTrue,
        reason: 'the code screen should have put the member in the session');

    // Leave it the way a member does: the session menu, then the confirmation.
    await t.tap(find.byTooltip('Session options'));
    await settle(8);
    await t.tap(find.text('Leave session'));
    await settle(8);
    await t.tap(find.widgetWithText(FilledButton, 'Leave'));
    await settle();

    expect((await service.fetch(first.id))!.hasMember(member.uid), isFalse,
        reason: 'FR9: leaving must remove the member');
    expect(app.read(activeSessionIdProvider), isNull,
        reason: 'the session just left must not stay the active one');

    // The bug: this is where the Join button was stuck on its spinner.
    await joinByCodeThroughTheUi(second.code, 'Late dinner');
    expect((await service.fetch(second.id))!.hasMember(member.uid), isTrue,
        reason: 'the member must be able to join a second session after leaving the first');
    debugPrint('TC_E_015 PASS joined ${first.code}, left it, joined ${second.code}');

    // ------------------------------------------------------------ cleanup --
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(milliseconds: 300));
    app.dispose();
    await actAs(memberEmail);
    await c.read(sessionServiceProvider).leave(sessionId: second.id, uid: member.uid);
    host = await actAs(hostEmail);
    for (final id in [first.id, second.id]) {
      await c.read(sessionServiceProvider).cancel(id);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
