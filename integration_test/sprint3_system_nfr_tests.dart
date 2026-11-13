import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/assistant_service.dart';
import 'package:gather/core/services/firestore_refs.dart';
import 'package:gather/core/services/gemini_brain.dart';
import 'package:gather/core/services/order_service.dart';
import 'package:gather/core/services/payment_service.dart';
import 'package:gather/core/services/result.dart';
import 'package:gather/core/services/session_service.dart';
import 'package:gather/firebase_options.dart';

/// System tests against the non-functional requirements, TC_SN_001 to TC_SN_013.
///
/// Numbered after the requirement: TC_SN_004 is NFR4. Every figure is measured
/// on the device against the live Firebase project and printed as `MEASURE`,
/// so the testing document can quote it. NFR9 (maintainability) and NFR11
/// (availability) are not device tests; the document says how each was treated.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final aEmail = 'sna$stamp@gather-test.local';
  final bEmail = 'snb$stamp@gather-test.local';

  late ProviderContainer c;
  late SessionService sessions;
  late OrderService orders;
  late AppUser a, b;
  late Restaurant restaurant;
  late List<MenuItem> menu;
  late FirebaseApp secondApp;
  late FirebaseAuth secondAuth;
  late FirebaseFirestore secondDb;

  void ok(dynamic result) =>
      expect(result.isSuccess, isTrue, reason: result.errorOrNull ?? '');

  Future<AppUser> actAs(String email) async {
    await FirebaseAuth.instance.signOut();
    var r = await c.read(authServiceProvider).signIn(email: email, password: password);
    // The emulator's network sometimes drops a fresh connection; that is not
    // what these cases measure, so sign-in gets one more try.
    if (!r.isSuccess && (r.errorOrNull ?? '').contains('connection abort')) {
      await Future<void>.delayed(const Duration(seconds: 2));
      r = await c.read(authServiceProvider).signIn(email: email, password: password);
    }
    ok(r);
    return r.valueOrNull!;
  }

  Future<int> timed(String what, Future<void> Function() action) async {
    final clock = Stopwatch()..start();
    await action();
    final ms = clock.elapsedMilliseconds;
    debugPrint('MEASURE $what ${ms}ms');
    return ms;
  }

  Future<void> denied(String what, Future<Object?> Function() read) async {
    try {
      await read();
    } on FirebaseException catch (e) {
      expect(e.code, 'permission-denied', reason: what);
      debugPrint('MEASURE refused $what');
      return;
    }
    fail('$what was not refused');
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;
    sessions = c.read(sessionServiceProvider);
    orders = c.read(orderServiceProvider);
    final auth = c.read(authServiceProvider);
    await FirebaseAuth.instance.signOut();
    final rb = await auth.signUp(fullName: 'NFR Two', username: 'snb$stamp', email: bEmail,
        phone: '+9665900${stamp % 100000}', password: password);
    ok(rb);
    b = rb.valueOrNull!;
    await auth.saveAddresses(b.uid, const [
      Address(id: 'x', label: 'Home', line: 'Private street', city: 'Riyadh', isDefault: true),
    ]);
    await FirebaseAuth.instance.signOut();
    final ra = await auth.signUp(fullName: 'NFR One', username: 'sna$stamp', email: aEmail,
        phone: '+9665901${stamp % 100000}', password: password);
    ok(ra);
    a = ra.valueOrNull!;
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    restaurant = all.firstWhere((r) => r.isOpen, orElse: () => all.first);
    menu = await catalog.fetchMenu(restaurant.id);

    // A second, fully separate Firebase client: in effect another phone.
    secondApp = await Firebase.initializeApp(
        name: 'second', options: DefaultFirebaseOptions.currentPlatform);
    secondAuth = FirebaseAuth.instanceFor(app: secondApp);
    secondDb = FirebaseFirestore.instanceFor(app: secondApp);
    await secondAuth.signInWithEmailAndPassword(email: bEmail, password: password);
  });

  tearDownAll(() async {
    await secondApp.delete();
    c.dispose();
  });

  testWidgets('TC_SN_001 NFR1 User actions answer within 3 seconds', (t) async {
    a = await actAs(aEmail);
    final catalog = c.read(catalogServiceProvider);
    final cart = c.read(cartServiceProvider);
    final made = await sessions.createSession(host: a, name: 'Timing');
    ok(made);
    final results = {
      'browse restaurants': await timed('browse restaurants', () async {
        await catalog.fetchRestaurants();
      }),
      'open a menu': await timed('open a menu', () async {
        await catalog.fetchMenu(restaurant.id);
      }),
      'add to cart': await timed('add to cart', () async {
        await cart.add(a.uid, menu.first, quantity: 1);
      }),
      'update a group session': await timed('update a group session', () async {
        ok(await sessions.chooseRestaurant(sessionId: made.valueOrNull!.id, restaurant: restaurant));
      }),
      'add to shared cart': await timed('add to shared cart', () async {
        ok(await sessions.addLine(
            sessionId: made.valueOrNull!.id, item: menu.first, owner: a, quantity: 1));
      }),
    };
    await cart.clear(a.uid);
    results.forEach((what, ms) => expect(ms, lessThan(3000), reason: '$what took ${ms}ms'));
    debugPrint('TC_SN_001 PASS slowest ${results.values.reduce((x, y) => x > y ? x : y)}ms of 3000ms');
  });

  testWidgets('TC_SN_002 NFR2 The main actions are one tap from Home, and refusals read as sentences',
      (t) async {
    a = await actAs(aEmail);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
    final start = find.text('Start a group');
    for (var i = 0; i < 120 && start.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(start, findsOneWidget);
    expect(find.text('Join with code'), findsOneWidget);
    expect(find.text('Spin & Win'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());

    await FirebaseAuth.instance.signOut();
    final wrong = await c.read(authServiceProvider).signIn(email: aEmail, password: 'wrong-one');
    expect(wrong.errorOrNull, 'Incorrect email or password');
    a = await actAs(aEmail);
    final code = await sessions.joinByCode(code: '0000', user: a);
    if (!code.isSuccess) {
      expect(code.errorOrNull, isNot(contains('firebase')));
      expect(code.errorOrNull, isNot(contains('PERMISSION')));
    }
    debugPrint('TC_SN_002 PASS actions on Home; refusal: "${wrong.errorOrNull}"');
  });

  testWidgets('TC_SN_003 NFR3 A write made offline survives and is stored exactly once', (t) async {
    a = await actAs(aEmail);
    final db = c.read(firestoreProvider);
    final refs = c.read(firestoreRefsProvider);
    await c.read(cartServiceProvider).clear(a.uid);

    await db.disableNetwork();
    // Whatever happens below, the cases after this one need the network back.
    addTearDown(db.enableNetwork);
    final ref = refs.cart(a.uid).doc('offline$stamp');
    final pending = ref.set(CartLine.fromMenuItem(menu.first,
        id: ref.id, quantity: 2, options: const [], note: '', ownerId: a.uid).toMap());
    var seenOffline = false;
    for (var i = 0; i < 20 && !seenOffline; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      try {
        seenOffline = (await ref.get(const GetOptions(source: Source.cache))).exists;
      } on FirebaseException {
        // Not in the local cache yet.
      }
    }
    expect(seenOffline, isTrue, reason: 'the app keeps working offline');

    await db.enableNetwork();
    await pending.timeout(const Duration(seconds: 30));
    final server = await refs.cart(a.uid).get(const GetOptions(source: Source.server));
    expect(server.docs.where((d) => d.id == ref.id), hasLength(1));
    await c.read(cartServiceProvider).clear(a.uid);
    debugPrint('TC_SN_003 PASS offline write reached the server, once');
  });

  testWidgets('TC_SN_004 NFR4 Accounts and orders are protected from other users', (t) async {
    a = await actAs(aEmail);
    final refs = c.read(firestoreRefsProvider);
    final cart = c.read(cartServiceProvider);
    await cart.add(a.uid, menu.first, quantity: 6);
    final lines = await cart.fetch(a.uid);
    final placed = await orders.placeIndividualOrder(
        user: a, restaurant: restaurant, lines: lines,
        totals: OrderService.totalsFor(lines: lines, restaurant: restaurant),
        paymentMethodLabel: 'Visa •••• 4242', deliveryAddress: 'PSU, Riyadh');
    ok(placed);
    await cart.clear(a.uid);
    final card = await c.read(paymentServiceProvider).addCard(
        uid: a.uid, number: '4242 4242 4242 4242', holderName: 'NFR One',
        expiryMonth: 12, expiryYear: DateTime.now().year + 3, cvv: '123', makeDefault: true);
    ok(card);
    final stored = await refs.paymentMethods(a.uid).doc(card.valueOrNull!.id).get();
    expect(stored.data().toString(), isNot(contains('4242424242424242')), reason: 'no full card number');
    expect(stored.data().toString(), isNot(contains('123')), reason: 'no security code');

    final orderId = placed.valueOrNull!.id;
    await actAs(bEmail);
    await denied("reading someone else's order",
        () => refs.order(orderId).get(const GetOptions(source: Source.server)));
    await denied('making yourself an administrator',
        () => refs.user(b.uid).update({'role': 'admin'}));
    await denied('editing a restaurant',
        () => refs.restaurant(restaurant.id).update({'name': 'Hacked'}));
    await denied("deleting someone else's account", () => refs.user(a.uid).delete());
    debugPrint('TC_SN_004 PASS 4 attempts refused; no full card number or CVV stored');
  });

  testWidgets('TC_SN_005 NFR5 Private data is refused to other users', (t) async {
    await actAs(bEmail);
    final refs = c.read(firestoreRefsProvider);
    const server = GetOptions(source: Source.server);
    await denied('their cart', () => refs.cart(a.uid).get(server));
    await denied('their saved cards', () => refs.paymentMethods(a.uid).get(server));
    await denied('their notifications', () => refs.notifications(a.uid).get(server));
    await denied('their assistant chat', () => refs.aiChat(a.uid).get(server));
    await denied('their saved groups', () => refs.savedSessions(a.uid).get(server));

    // Recorded, not hidden: inviting people needs profiles to be readable, and
    // today the whole profile document comes with it.
    a = await actAs(aEmail);
    final other = (await refs.user(b.uid).get(server)).data() ?? {};
    debugPrint('MEASURE profile fields another user can read: '
        'phone=${(other['phone'] ?? '').toString().isNotEmpty} '
        'addresses=${(other['addresses'] as List? ?? const []).isNotEmpty} '
        'email=${(other['email'] ?? '').toString().isNotEmpty}');
    debugPrint('TC_SN_005 PASS 5 kinds of private data refused; see the profile measure above');
  });

  testWidgets('TC_SN_006 NFR6 Many sessions and cart writes at once all succeed in time', (t) async {
    a = await actAs(aEmail);
    const sessionCount = 10, linesEach = 5;
    late List<Result> made;
    final createMs = await timed('$sessionCount sessions at once', () async {
      made = await Future.wait([
        for (var i = 0; i < sessionCount; i++) sessions.createSession(host: a, name: 'Load $i'),
      ]);
    });
    made.forEach(ok);
    final ids = [for (final r in made) (r.valueOrNull as GroupSession).id];
    late List<Result> added;
    final addMs = await timed('${sessionCount * linesEach} cart writes at once', () async {
      added = await Future.wait([
        for (final id in ids)
          for (var i = 0; i < linesEach; i++)
            sessions.addLine(sessionId: id, item: menu[i % menu.length], owner: a, quantity: 1),
      ]);
    });
    added.forEach(ok);
    for (final id in ids) {
      final lines = await sessions.fetchLines(id);
      expect(lines.valueOrNull, hasLength(linesEach), reason: 'no write may be lost');
      await sessions.cancel(id);
    }
    for (final id in ids) {
      final stored = (await sessions.fetch(id));
      expect(stored?.stage, SessionStage.cancelled);
    }
    // NFR6 gives no figure, so nothing is lost is what is asserted; the time is
    // recorded in the testing document, where its spread between runs is stated.
    debugPrint('TC_SN_006 PASS all stored: sessions ${createMs}ms, writes ${addMs}ms');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_SN_007 NFR7 A change on one phone reaches the other', (t) async {
    a = await actAs(aEmail);
    final made = await sessions.createSession(host: a, name: 'Live');
    ok(made);
    final session = made.valueOrNull!;
    ok(await sessions.chooseRestaurant(sessionId: session.id, restaurant: restaurant));
    final other = SessionService(FirestoreRefs(secondDb));
    // A phone in a session is already connected; opening the connection is
    // not part of what NFR7 asks about.
    await secondDb.collection('restaurants').limit(1).get();

    Future<int> reach(String what, bool Function(GroupSession) seen, Future<void> Function() act) async {
      final done = Completer<void>();
      final sub = sessions.watch(session.id).listen((s) {
        if (s != null && seen(s) && !done.isCompleted) done.complete();
      });
      final ms = await timed(what, () async {
        await act();
        await done.future.timeout(const Duration(seconds: 15));
      });
      await sub.cancel();
      return ms;
    }

    final join = await reach('member joining', (s) => s.members.length == 2, () async {
      ok(await other.joinByCode(code: session.code, user: b));
    });
    final done = Completer<void>();
    final lineSub = sessions.watchLines(session.id).listen((l) {
      if (l.any((x) => x.ownerId == b.uid) && !done.isCompleted) done.complete();
    });
    final line = await timed('shared cart item', () async {
      ok(await other.addLine(sessionId: session.id, item: menu.first, owner: b, quantity: 1));
      await done.future.timeout(const Duration(seconds: 15));
    });
    await lineSub.cancel();
    final paid = await reach('payment status',
        (s) => s.members.any((m) => m.uid == b.uid && m.paymentStatus == MemberPaymentStatus.paid),
        () async {
      ok(await other.markPaid(sessionId: session.id, uid: b.uid));
    });
    for (final ms in [join, line, paid]) {
      expect(ms, lessThan(3000));
    }
    debugPrint('TC_SN_007 PASS member ${join}ms, cart ${line}ms, payment ${paid}ms');
  }, timeout: const Timeout(Duration(minutes: 2)));

  testWidgets('TC_SN_008 NFR8 The app opens and works on this device', (t) async {
    a = await actAs(aEmail);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
    final start = find.text('Start a group');
    for (var i = 0; i < 120 && start.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    expect(start, findsOneWidget);
    final view = t.view;
    debugPrint('MEASURE device ${defaultTargetPlatform.name} '
        '${(view.physicalSize.width / view.devicePixelRatio).round()}x'
        '${(view.physicalSize.height / view.devicePixelRatio).round()}');
    await t.pumpWidget(const SizedBox.shrink());
    debugPrint('TC_SN_008 PASS Home opened on ${defaultTargetPlatform.name}');
  });

  testWidgets('TC_SN_010 NFR10 Payments say clearly whether they worked', (t) async {
    a = await actAs(aEmail);
    final refs = c.read(firestoreRefsProvider);
    final methods = await c.read(paymentServiceProvider).fetchMethods(a.uid);
    final method = methods.first;

    final success = await c.read(paymentServiceProvider)
        .pay(amount: 42.5, method: method, description: 'NFR10');
    ok(success);
    expect(success.valueOrNull!.amount, 42.5);
    expect(success.valueOrNull!.reference, startsWith('GTHR-'));

    final declining = PaymentService(refs: refs, gateway: SimulatedPaymentGateway(failureRate: 1));
    final declined = await declining.pay(amount: 42.5, method: method, description: 'NFR10');
    expect(declined.isSuccess, isFalse);
    expect(declined.errorOrNull, contains('declined'));

    final made = await sessions.createSession(host: a, name: 'Pay');
    ok(made);
    final me = (await sessions.fetch(made.valueOrNull!.id))!
        .members.firstWhere((m) => m.uid == a.uid);
    expect(me.paymentStatus, isNot(MemberPaymentStatus.paid), reason: 'pending until paid');
    ok(await sessions.markPaid(sessionId: made.valueOrNull!.id, uid: a.uid));
    final after = (await sessions.fetch(made.valueOrNull!.id))!
        .members.firstWhere((m) => m.uid == a.uid);
    expect(after.paymentStatus, MemberPaymentStatus.paid);
    debugPrint('TC_SN_010 PASS success ${success.valueOrNull!.reference}, '
        'declined "${declined.errorOrNull}", pending then paid');
  });

  testWidgets('TC_SN_012 NFR12 Home meets Android and iOS accessibility guidelines', (t) async {
    a = await actAs(aEmail);
    final handle = t.ensureSemantics();
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
    final start = find.text('Start a group');
    for (var i = 0; i < 120 && start.evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await t.pumpWidget(const SizedBox.shrink());
    debugPrint('TC_SN_012 PASS tap targets and labels on Home');
  });

  testWidgets('TC_SN_013 NFR13 The assistant answers within 5 seconds', (t) async {
    expect(isUsableGeminiKey(geminiApiKey), isTrue,
        reason: 'run with --dart-define-from-file=config/secrets.json');
    a = await actAs(aEmail);
    final catalog = c.read(catalogServiceProvider);
    final all = await catalog.fetchRestaurants();
    final items = <MenuItem>[for (final r in all) ...await catalog.fetchMenu(r.id)];
    final context = AssistantContext(restaurants: all, items: items);
    final fallback = _CountingBrain();
    final brain = GeminiBrain(apiKey: geminiApiKey, fallback: fallback);
    final known = {for (final i in items) i.id};
    final times = <int>[];
    for (final question in [
      'what is the best dessert?',
      'something under 25 SAR',
      'I want spicy food',
      'which restaurant delivers fastest?',
      'how do I split the bill?',
      'recommend a vegetarian meal',
      'what should I order for four people?',
      'do you have coffee?',
    ]) {
      late AssistantReply reply;
      times.add(await timed('assistant: $question', () async {
        reply = await brain.answer(question, context);
      }));
      expect(reply.text, isNotEmpty);
      expect(known.containsAll(reply.items.map((i) => i.id)), isTrue);
    }
    times.sort();
    final average = times.reduce((x, y) => x + y) ~/ times.length;
    debugPrint('MEASURE assistant average ${average}ms, slowest ${times.last}ms');
    debugPrint('MEASURE assistant fallbacks ${fallback.count} of ${times.length}');
    expect(times.last, lessThan(5000));
    debugPrint('TC_SN_013 PASS average ${average}ms, slowest ${times.last}ms of 5000ms');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

/// The on-device assistant, counting how often Gemini was too slow or failed.
class _CountingBrain implements AssistantBrain {
  int count = 0;

  @override
  FutureOr<AssistantReply> answer(
    String question,
    AssistantContext context, {
    String languageCode = 'en',
    List<AssistantMessage> history = const [],
  }) {
    count++;
    return const RetrievalBrain()
        .answer(question, context, languageCode: languageCode, history: history);
  }
}
