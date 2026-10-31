import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/app/app.dart';
import 'package:gather/app/router.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/result.dart';
import 'package:gather/features/assistant/assistant_bubble.dart';
import 'package:gather/features/assistant/assistant_screen.dart';
import 'package:gather/features/checkout/checkout_screen.dart';
import 'package:gather/firebase_options.dart';

/// The six issues the client raised at the Sprint 3 review, each checked on
/// the device the way the client would meet it:
///
///   TC_CF_001  Spin & Win — one spin every 24 hours, and it wins a reward
///   TC_CF_002  Food stories — a friend's story shows as a circle on home
///   TC_CF_003  A payment option switched off by the admin disappears at once
///   TC_CF_004  One "Add payment method" button instead of two
///   TC_CF_005  The food assistant floats on every customer page
///   TC_CF_006  A won reward can be spent at checkout, and only once
///
/// Arabic (the sixth) is covered screen by screen by arabic_tour.dart.
/// Screenshots go to /sdcard/Download/gather-s3fix.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  const password = 'TestPass123!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final authorEmail = 'cfauthor$stamp@gather-test.local';
  final viewerEmail = 'cfviewer$stamp@gather-test.local';

  late ProviderContainer c;
  late AppPrefs prefs;
  late Directory dir;
  late String authorUid;
  late String viewerUid;
  final stories = <String>[];
  var n = 0;

  Future<void> settle(WidgetTester t, [int ticks = 14]) async {
    for (var i = 0; i < ticks; i++) {
      await t.pump(const Duration(milliseconds: 160));
    }
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t);
    n++;
    final id = '${n.toString().padLeft(2, '0')}-$name';
    File('${dir.path}/$id.png').writeAsBytesSync(await binding.takeScreenshot(id));
    debugPrint('CFSHOT $id');
  }

  Future<void> signIn(String email) async {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: email == adminEmail ? adminPassword : password);
  }

  Future<AppUser> me(WidgetTester t) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    for (var i = 0; i < 160; i++) {
      final user = c.read(currentUserOrNullProvider);
      if (user != null && user.uid == uid) return user;
      await t.pump(const Duration(milliseconds: 150));
    }
    fail('the signed-in user never loaded');
  }

  /// Mounts the app for whoever is signed in and waits for it to settle.
  Future<GoRouter> launch(WidgetTester t) async {
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
    await settle(t, 24);
    await me(t);
    return c.read(routerProvider);
  }

  Future<void> unmount(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await settle(t, 4);
  }

  Future<T> waitFor<T>(WidgetTester t, T? Function() read, String what) async {
    for (var i = 0; i < 160; i++) {
      final v = read();
      if (v != null) return v;
      await t.pump(const Duration(milliseconds: 150));
    }
    fail('timed out waiting for $what');
  }

  setUpAll(() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    prefs = await AppPrefs.load();
    c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;
    await binding.convertFlutterSurfaceToImage();
    dir = Directory('/sdcard/Download/gather-s3fix');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final auth = c.read(authServiceProvider);
    await FirebaseAuth.instance.signOut();
    final a = await auth.signUp(
        fullName: 'Story Author', username: 'cfa$stamp', email: authorEmail,
        phone: '+96656${stamp % 10000000}', password: password);
    expect(a.isSuccess, isTrue, reason: a.errorOrNull ?? '');
    authorUid = a.valueOrNull!.uid;
    await FirebaseAuth.instance.signOut();
    final v = await auth.signUp(
        fullName: 'Story Viewer', username: 'cfv$stamp', email: viewerEmail,
        phone: '+96657${stamp % 10000000}', password: password);
    expect(v.isSuccess, isTrue, reason: v.errorOrNull ?? '');
    viewerUid = v.valueOrNull!.uid;
  });

  tearDownAll(() async {
    for (final (email, uid) in [(authorEmail, authorUid), (viewerEmail, viewerUid)]) {
      await signIn(email);
      if (uid == authorUid) {
        for (final id in stories) {
          await c.read(storyServiceProvider).remove(id);
        }
      }
      await FirebaseAuth.instance.currentUser?.delete();
    }
    c.dispose();
  });

  // Each case starts like a fresh launch of the app. One container kept
  // across the account switches below would hold listeners refused while
  // another account was signed in, which the running app never does.
  setUp(() {
    c.dispose();
    c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    c.read(onboardingSeenProvider.notifier).state = true;
  });

  testWidgets('TC_CF_001 Spin & Win gives one spin every 24 hours and it wins a reward',
      (t) async {
    await signIn(viewerEmail);
    await c.read(spinServiceProvider).resetSpin(viewerUid);
    final router = await launch(t);

    router.go(Routes.home);
    await settle(t);
    expect(find.byKey(const ValueKey('spin-win-banner')), findsOneWidget,
        reason: 'the daily spin is offered on the home page');
    await shot(t, 'home-spin-ready');

    router.go(Routes.spin);
    await shot(t, 'spin-ready');
    await t.tap(find.byKey(const ValueKey('spin-button')));
    for (var i = 0; i < 45; i++) {
      await t.pump(const Duration(milliseconds: 160));
    }
    expect(find.byKey(const ValueKey('spin-prize')), findsOneWidget);
    expect(find.text('Saved to your rewards'), findsOneWidget);
    await shot(t, 'spin-won');

    final held = await c.read(voucherServiceProvider).fetchMine(viewerUid);
    expect(held.where((v) => v.isUsable), isNotEmpty, reason: 'the prize is in their rewards');

    final again = await c.read(spinServiceProvider).spin(
        uid: viewerUid, prizes: c.read(spinWheelProvider).valueOrNull ?? const []);
    expect(again, isA<Err<SpinOutcome>>(), reason: 'a second spin inside 24 hours is refused');

    router.go(Routes.home);
    await settle(t);
    router.go(Routes.spin);
    await settle(t);
    expect(find.byKey(const ValueKey('spin-countdown')), findsOneWidget);
    expect(find.textContaining('Next spin in'), findsWidgets);
    await shot(t, 'spin-countdown');

    router.go(Routes.rewards);
    await shot(t, 'rewards-with-prize');
    await unmount(t);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('TC_CF_002 A story someone posts shows as a circle on everyone\'s home page',
      (t) async {
    await signIn(authorEmail);
    final author = await waitFor(t, () => c.read(currentUserOrNullProvider), 'author');
    final image = (await rootBundle.load('assets/images/logo.jpeg')).buffer.asUint8List();
    final posted = await c.read(storyServiceProvider).post(
        author: author, image: image, caption: 'Client check $stamp');
    expect(posted.isSuccess, isTrue, reason: posted.errorOrNull ?? '');
    stories.add(posted.valueOrNull!.id);

    await signIn(viewerEmail);
    final router = await launch(t);
    router.go(Routes.home);
    final circle = find.byKey(ValueKey('story-circle-$authorUid'));
    await waitFor(t, () => circle.evaluate().isEmpty ? null : true, 'the story circle');
    expect(find.byKey(const ValueKey('story-rail')), findsOneWidget);
    await shot(t, 'home-story-circles');

    await t.tap(circle);
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 160));
    }
    expect(find.byKey(const ValueKey('story-viewer')), findsOneWidget);
    expect(find.textContaining('Client check $stamp'), findsOneWidget);
    await shot(t, 'story-viewer');
    await t.tap(find.byKey(const ValueKey('story-close')));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 160));
    }
    await unmount(t);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('TC_CF_003 A payment option the admin switches off disappears straight away',
      (t) async {
    final pay = c.read(paymentServiceProvider);
    await signIn(viewerEmail);
    final card = await pay.addCard(
        uid: viewerUid, number: '4242 4242 4242 4242', holderName: 'Story Viewer',
        expiryMonth: 12, expiryYear: DateTime.now().year + 3, cvv: '123', makeDefault: true);
    expect(card.isSuccess, isTrue, reason: card.errorOrNull ?? '');

    await signIn(adminEmail);
    final options = await pay.fetchOptions();
    final cardOption = options.firstWhere((o) => o.name.toLowerCase() == 'card');
    final wasEnabled = cardOption.isEnabled;

    try {
      expect((await pay.setOptionEnabled(cardOption.id, false)).isSuccess, isTrue);

      await signIn(viewerEmail);
      final router = await launch(t);
      router.go(Routes.paymentMethods);
      await waitFor(t, () => c.read(paymentCatalogProvider).valueOrNull, 'the catalogue');
      await settle(t);
      expect(find.text('Currently unavailable'), findsOneWidget,
          reason: 'the saved card is marked unavailable');
      expect(c.read(usablePaymentMethodsProvider).any((m) => m.id == card.valueOrNull!.id),
          isFalse, reason: 'the card cannot be chosen to pay');
      await shot(t, 'card-switched-off');

      final charge = await pay.pay(amount: 10, method: card.valueOrNull!, description: 'check');
      expect(charge.isSuccess, isFalse, reason: 'a disabled option cannot be charged');
      await unmount(t);
    } finally {
      await signIn(adminEmail);
      await pay.setOptionEnabled(cardOption.id, wasEnabled);
    }

    // Back on: usable again without restarting anything.
    await signIn(viewerEmail);
    final router = await launch(t);
    router.go(Routes.paymentMethods);
    await settle(t, 20);
    expect(find.text('Currently unavailable'), findsNothing);
    await shot(t, 'card-switched-back-on');
    await unmount(t);
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('TC_CF_004 There is one button for adding any payment method', (t) async {
    await signIn(viewerEmail);
    final router = await launch(t);
    router.go(Routes.paymentMethods);
    await settle(t, 20);
    expect(find.text('Add payment method'), findsOneWidget);
    expect(find.text('Add method'), findsNothing);
    await shot(t, 'one-add-button');

    await t.tap(find.text('Add payment method'));
    await settle(t);
    await shot(t, 'add-method-sheet');
    await t.tapAt(const Offset(10, 10)); // dismiss the sheet
    await settle(t);
    await unmount(t);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_CF_005 The food assistant floats on customer pages and opens the chat',
      (t) async {
    await signIn(viewerEmail);
    final router = await launch(t);
    final bubble = find.byKey(AssistantBubble.buttonKey);

    for (final route in [Routes.home, Routes.orders, Routes.profile, Routes.help]) {
      router.go(route);
      await settle(t);
      expect(bubble, findsOneWidget, reason: 'shown on $route');
      expect(bubble.hitTestable(), findsOneWidget, reason: 'tappable on $route');
    }
    router.go(Routes.home);
    await shot(t, 'assistant-bubble-home');

    router.go(Routes.cart);
    await settle(t);
    expect(bubble, findsNothing, reason: 'kept off screens with their own bottom button');

    router.go(Routes.home);
    await settle(t);
    await t.tap(bubble);
    await settle(t);
    expect(find.byType(AssistantScreen), findsOneWidget, reason: 'the chat opened');
    expect(bubble, findsNothing, reason: 'hidden on the assistant itself');
    await shot(t, 'assistant-opened');
    await unmount(t);
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TC_CF_006 A won reward is spent at checkout and cannot be used twice',
      (t) async {
    await signIn(viewerEmail);
    final vouchers = c.read(voucherServiceProvider);
    // A fresh spin, so this case does not depend on TC_CF_001.
    final spins = c.read(spinServiceProvider);
    await spins.resetSpin(viewerUid);
    final won = await spins.spin(uid: viewerUid, prizes: SpinRules.defaultPrizes);
    expect(won.isSuccess, isTrue, reason: won.errorOrNull ?? '');
    final prize = won.valueOrNull!.voucher;
    if ((await c.read(paymentServiceProvider).fetchMethods(viewerUid)).isEmpty) {
      final card = await c.read(paymentServiceProvider).addCard(
          uid: viewerUid, number: '4242 4242 4242 4242', holderName: 'Story Viewer',
          expiryMonth: 12, expiryYear: DateTime.now().year + 3, cvv: '123', makeDefault: true);
      expect(card.isSuccess, isTrue, reason: card.errorOrNull ?? '');
    }

    // Enough in the cart for any prize's minimum, and somewhere to deliver.
    final restaurant = (await c.read(catalogServiceProvider).watchRestaurants().first).first;
    final item = (await c.read(catalogServiceProvider).watchMenu(restaurant.id).first).first;
    await c.read(cartServiceProvider).add(viewerUid, item, quantity: 6);
    await c.read(authServiceProvider).saveAddresses(viewerUid, const [
      Address(id: 'cf', label: 'Home', line: 'King Saud University', city: 'Riyadh', isDefault: true),
    ]);

    final router = await launch(t);
    await waitFor(t, () => (c.read(cartProvider).valueOrNull?.isNotEmpty ?? false) ? true : null,
        'the cart to reach the app');
    await waitFor(t, () => c.read(cartRestaurantProvider).valueOrNull, 'the cart restaurant');
    router.go(Routes.checkout);
    await settle(t, 20);
    await shot(t, 'checkout');
    // On a small phone the reward row is below the fold.
    await t.scrollUntilVisible(find.text('Use'), 120,
        scrollable: find
            .descendant(of: find.byType(CheckoutScreen), matching: find.byType(Scrollable))
            .first);
    await settle(t, 4);
    await t.tap(find.text('Use'));
    await settle(t);
    expect(find.text('Use a reward'), findsOneWidget);
    await shot(t, 'checkout-reward-picker');
    await t.tap(find.textContaining(prize.title).last);
    await settle(t);
    expect(find.textContaining('Discount (${prize.code})'), findsOneWidget);
    await shot(t, 'checkout-reward-applied');

    await t.tap(find.textContaining('Place order'));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 160));
    }
    await shot(t, 'order-placed-with-reward');

    final spent = (await vouchers.fetchMine(viewerUid)).firstWhere((v) => v.id == prize.id);
    expect(spent.status, VoucherStatus.used, reason: 'the reward is marked used');
    expect(spent.isUsable, isFalse);
    final again = await vouchers.redeem(uid: viewerUid, held: prize, orderId: 'second');
    expect(again.isSuccess, isFalse, reason: 'a used reward cannot be spent again');

    await c.read(cartServiceProvider).clear(viewerUid);
    await unmount(t);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
