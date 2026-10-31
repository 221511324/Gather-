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
import 'package:gather/core/services/order_service.dart';
import 'package:gather/core/widgets/gather_button.dart';
import 'package:gather/features/home/main_shell.dart';
import 'package:gather/features/restaurant/item_sheet.dart';
import 'package:gather/firebase_options.dart';

/// Walks every screen with the app in Arabic, saves a screenshot of each, and
/// prints every piece of visible text that still contains English words as
/// `EN|<screen>|<text>`. Restaurant, menu and user names are data and are
/// expected to stay as entered; everything else on that list is a missed
/// translation.
///
///   flutter test integration_test/arabic_tour.dart -d emulator-5554
///   adb pull /sdcard/Download/gather-ar
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late Directory dir;
  var n = 0;
  final dataNames = <String>{};

  Future<void> settle(WidgetTester tester, [int ticks = 16]) async {
    for (var i = 0; i < ticks; i++) {
      await tester.pump(const Duration(milliseconds: 170));
    }
  }

  final latinWord = RegExp(r'[A-Za-z]{2,}');

  /// Screenshots the screen and reports its English.
  Future<void> visit(WidgetTester tester, String name) async {
    await settle(tester);
    n++;
    final id = '${n.toString().padLeft(2, '0')}-$name';
    final bytes = await binding.takeScreenshot(id);
    File('${dir.path}/$id.png').writeAsBytesSync(bytes);

    final seen = <String>{};
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      seen.add(w.text.toPlainText());
    }
    for (final w in tester.widgetList<EditableText>(find.byType(EditableText))) {
      seen.add(w.controller.text);
    }
    for (final text in seen) {
      var rest = text;
      for (final d in dataNames) {
        rest = rest.replaceAll(d, '');
      }
      rest = rest.replaceAll(RegExp(r'SAR|Gather|@\S+|\S+@\S+'), '');
      if (latinWord.hasMatch(rest)) {
        debugPrint('EN|$name|${text.replaceAll('\n', ' ⏎ ')}');
      }
    }
    debugPrint('ARSHOT $id');
  }

  Future<void> boot(WidgetTester tester, String folder) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final prefs = await AppPrefs.load();
    await FirebaseAuth.instance.signOut();
    container = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
    container.read(onboardingSeenProvider.notifier).state = true;
    await binding.convertFlutterSurfaceToImage();
    dir = Directory('/sdcard/Download/gather-ar/$folder');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    n = 0;
  }

  Future<AppUser> waitForUser(WidgetTester tester) async {
    for (var i = 0; i < 160; i++) {
      final user = container.read(currentUserOrNullProvider);
      if (user != null) return user;
      await tester.pump(const Duration(milliseconds: 150));
    }
    fail('the signed-in user never loaded');
  }

  Future<List<Restaurant>> waitForRestaurants(WidgetTester tester) async {
    for (var i = 0; i < 160; i++) {
      final list = container.read(restaurantsProvider).valueOrNull;
      if (list != null && list.isNotEmpty) return list;
      await tester.pump(const Duration(milliseconds: 150));
    }
    return const [];
  }

  Future<void> setLanguage(String uid, AppUser user, String language) async {
    final saved = await container
        .read(authServiceProvider)
        .saveSettings(uid, user.settings.copyWith(language: language));
    expect(saved.isSuccess, isTrue, reason: saved.errorOrNull ?? '');
  }

  testWidgets('customer screens in Arabic', (tester) async {
    await boot(tester, 'customer');

    // Signed-out screens follow the device locale, not a saved setting, so
    // they are covered by the signed-in walk's settings check instead.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final signUp = await container.read(authServiceProvider).signUp(
          fullName: 'Arabic Tour',
          username: 'artour$stamp',
          email: 'artour$stamp@gather-test.local',
          phone: '+96655${stamp % 10000000}',
          password: 'TestPass123!',
        );
    expect(signUp.isSuccess, isTrue, reason: signUp.errorOrNull ?? '');
    var user = await waitForUser(tester);
    await setLanguage(user.uid, user, 'ar');
    dataNames.addAll(['Arabic Tour', 'artour$stamp', 'Friday dinner']);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GatherApp()),
    );
    await settle(tester, 24);
    final router = container.read(routerProvider);

    final restaurants = await waitForRestaurants(tester);
    for (final r in restaurants) {
      dataNames.addAll([r.name, r.cuisine, r.description, ...r.tags]);
    }

    // A cart and an order, so the cart, checkout and order screens have rows.
    FoodOrder? order;
    if (restaurants.isNotEmpty) {
      final r = restaurants.first;
      final menu = await container.read(catalogServiceProvider).watchMenu(r.id).first;
      for (final m in menu) {
        dataNames.addAll([m.name, m.description]);
        for (final g in m.optionGroups) {
          dataNames.add(g.name);
          for (final o in g.choices) {
            dataNames.add(o.name);
          }
        }
      }
      if (menu.isNotEmpty) {
        final item = menu.first;
        final cart = container.read(cartServiceProvider);
        await cart.add(user.uid, item, quantity: 3);
        final lines = await cart.fetch(user.uid);
        final totals = OrderService.totalsFor(lines: lines, restaurant: r, discount: 0);
        final placed = await container.read(orderServiceProvider).placeIndividualOrder(
              user: user,
              restaurant: r,
              lines: lines,
              totals: totals,
              paymentMethodLabel: 'Visa •••• 4242',
              deliveryAddress: 'King Saud University',
            );
        order = placed.valueOrNull;
        await cart.add(user.uid, item, quantity: 2);
      }
    }
    dataNames.addAll(['King Saud University', 'Visa']);

    for (final (route, name) in <(String, String)>[
      (Routes.home, 'home'),
      (Routes.search, 'search'),
      (Routes.group, 'group-hub'),
      (Routes.orders, 'orders'),
      (Routes.profile, 'profile'),
      (Routes.favorites, 'favorites'),
      (Routes.cart, 'cart'),
      (Routes.checkout, 'checkout'),
      (Routes.editProfile, 'edit-profile'),
      (Routes.addresses, 'addresses'),
      (Routes.paymentMethods, 'payment-methods'),
      (Routes.help, 'help'),
      (Routes.faq, 'faq'),
      (Routes.contact, 'contact'),
      (Routes.joinSession, 'join-session'),
      (Routes.assistant, 'assistant'),
      (Routes.settings, 'settings'),
      (Routes.notifications, 'notifications'),
      (Routes.rewards, 'rewards'),
      (Routes.stories, 'stories'),
      (Routes.spin, 'spin'),
      (Routes.adminsOnly, 'admins-only'),
    ]) {
      router.go(route);
      await visit(tester, name);
    }

    if (restaurants.isNotEmpty) {
      router.go(Routes.restaurant(restaurants.first.id));
      await visit(tester, 'restaurant');
    }

    // A dish opened from inside a tab must sit above the floating nav bar,
    // or its add button is hidden behind it.
    final dish = restaurants.isEmpty
        ? null
        : (await container.read(catalogServiceProvider).watchMenu(restaurants.first.id).first)
            .firstOrNull;
    if (dish != null) {
      router.go(Routes.home);
      await settle(tester);
      ItemSheet.show(tester.element(find.byType(MainShell)), dish);
      await visit(tester, 'item-sheet-from-tab');
      final add = find.descendant(of: find.byType(ItemSheet), matching: find.byType(GatherButton));
      expect(add, findsOneWidget);
      expect(tester.getRect(add).bottom, lessThanOrEqualTo(tester.view.physicalSize.height / tester.view.devicePixelRatio));
      expect(add.hitTestable(), findsOneWidget, reason: 'the add button is covered');
      Navigator.of(tester.element(find.byType(ItemSheet))).pop();
      await settle(tester, 6);
    }
    if (order != null) {
      router.go(Routes.order(order.id));
      await visit(tester, 'order-detail');
      router.go(Routes.trackOrder(order.id));
      await visit(tester, 'order-tracking');
    }

    // A group session through its stages.
    user = container.read(currentUserOrNullProvider)!;
    final sessions = container.read(sessionServiceProvider);
    final created = await sessions.createSession(host: user, name: 'Friday dinner');
    expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
    final session = created.valueOrNull!;
    container.read(activeSessionIdProvider.notifier).state = session.id;

    router.go(Routes.group);
    await visit(tester, 'group-hub-active');
    router.go(Routes.session(session.id));
    await visit(tester, 'session-lobby');
    router.go(Routes.sessionSpin(session.id));
    await visit(tester, 'session-spin');
    if (restaurants.isNotEmpty) {
      await sessions.chooseRestaurant(sessionId: session.id, restaurant: restaurants.first);
      router.go(Routes.session(session.id));
      await visit(tester, 'session-ordering');
      router.go(Routes.sessionCart(session.id));
      await visit(tester, 'session-cart');
      router.go(Routes.sessionPayment(session.id));
      await visit(tester, 'session-payment');
    }

    debugPrint('AR-TOUR-COMPLETE customer $n screens');

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester, 4);
    await sessions.cancel(session.id);
    await container.read(cartServiceProvider).clear(user.uid);
    await FirebaseAuth.instance.currentUser?.delete();
    container.dispose();
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('admin screens in Arabic', (tester) async {
    await boot(tester, 'admin');

    final signedIn = await container
        .read(authServiceProvider)
        .signIn(email: 'admin@gather.app', password: 'GatherAdmin2026!');
    expect(signedIn.isSuccess, isTrue, reason: signedIn.errorOrNull ?? '');
    final admin = await waitForUser(tester);
    final previous = admin.settings.language;
    await setLanguage(admin.uid, admin, 'ar');

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const GatherApp()),
      );
      await settle(tester, 24);
      final router = container.read(routerProvider);
      final restaurants = await waitForRestaurants(tester);
      for (final r in restaurants) {
        dataNames.addAll([r.name, r.cuisine, r.description, ...r.tags]);
      }

      for (final (route, name) in <(String, String)>[
        (Routes.admin, 'dashboard'),
        (Routes.adminRestaurants, 'restaurants'),
        (Routes.adminUsers, 'users'),
        (Routes.adminOrders, 'orders'),
        (Routes.adminSessions, 'sessions'),
        (Routes.adminTickets, 'tickets'),
        (Routes.adminPayments, 'payments'),
        (Routes.adminRewards, 'rewards'),
      ]) {
        router.go(route);
        await visit(tester, name);
      }
      if (restaurants.isNotEmpty) {
        router.go(Routes.adminMenu(restaurants.first.id));
        await visit(tester, 'menu');
      }
      debugPrint('AR-TOUR-COMPLETE admin $n screens');
    } finally {
      // The admin account is shared, so put its language back.
      await setLanguage(admin.uid, admin, previous);
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester, 4);
      container.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
