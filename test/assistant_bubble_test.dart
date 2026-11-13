import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/app/router.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/features/assistant/assistant_bubble.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  _widgetTests();

  AssistantBubbleSpot? spot(String location, {bool signedIn = true, bool isWeb = false}) =>
      assistantBubbleSpot(location, signedIn: signedIn, isWeb: isWeb);

  test('tab pages lift the button above the floating nav bar', () {
    for (final tab in [Routes.home, Routes.search, Routes.group, Routes.orders, Routes.profile]) {
      expect(spot(tab), AssistantBubbleSpot.aboveNavBar, reason: tab);
    }
  });

  test('other customer pages show it in the corner', () {
    for (final page in [
      Routes.favorites,
      Routes.help,
      Routes.faq,
      Routes.settings,
      Routes.notifications,
      Routes.rewards,
      Routes.stories,
    ]) {
      expect(spot(page), AssistantBubbleSpot.corner, reason: page);
    }
  });

  test('hidden before sign-in, on the web console and on admin pages', () {
    for (final page in [
      Routes.splash,
      Routes.onboarding,
      Routes.login,
      Routes.register,
      Routes.forgotPassword,
      Routes.adminsOnly,
      Routes.admin,
      Routes.adminUsers,
      Routes.adminMenu('r1'),
    ]) {
      expect(spot(page), isNull, reason: page);
    }
    expect(spot(Routes.home, signedIn: false), isNull);
    expect(spot(Routes.home, isWeb: true), isNull);
    expect(spot(''), isNull);
  });

  test('hidden on the assistant itself and on full-screen viewers', () {
    expect(spot(Routes.assistant), isNull);
    expect(spot('/stories/view'), isNull);
    expect(spot('/stories/view/abc'), isNull);
    expect(spot('/spin'), isNull);
  });

  test('hidden on pages with a primary action along the bottom', () {
    for (final page in [
      Routes.cart,
      Routes.checkout,
      Routes.restaurant('r1'),
      Routes.session('s1'),
      Routes.sessionCart('s1'),
      Routes.sessionSpin('s1'),
      Routes.sessionPayment('s1'),
      Routes.order('o1'),
      Routes.trackOrder('o1'),
      Routes.addresses,
      Routes.paymentMethods,
      Routes.editProfile,
      Routes.contact,
      Routes.joinSession,
      '/join/1234',
    ]) {
      expect(spot(page), isNull, reason: page);
    }
  });
}

class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pumpApp(WidgetTester t, String initial, {TextDirection dir = TextDirection.ltr}) async {
  SharedPreferences.setMockInitialValues({});
  final observer = AssistantBubbleObserver();
  final router = GoRouter(
    initialLocation: initial,
    observers: [observer],
    routes: [
      for (final path in [Routes.home, Routes.favorites, Routes.cart, Routes.assistant])
        GoRoute(path: path, builder: (_, _) => Scaffold(body: Text('page $path'))),
    ],
  );
  await t.pumpWidget(ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => Stream.value(_FakeUser()))],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => Directionality(
        textDirection: dir,
        child: Stack(children: [child!, AssistantBubble(router: router, observer: observer)]),
      ),
    ),
  ));
  await t.pumpAndSettle();
  return router;
}

void _widgetTests() {
  testWidgets('shows on a customer page and opens the assistant', (t) async {
    final router = await _pumpApp(t, Routes.favorites);
    final bubble = find.byKey(AssistantBubble.buttonKey);
    expect(bubble, findsOneWidget);
    // Bottom-right in English.
    expect(t.getCenter(bubble).dx, greaterThan(400));

    await t.tap(bubble);
    await t.pumpAndSettle();
    expect(router.state.matchedLocation, Routes.assistant);
    expect(find.byKey(AssistantBubble.buttonKey), findsNothing);

    router.pop();
    await t.pumpAndSettle();
    expect(find.byKey(AssistantBubble.buttonKey), findsOneWidget);
  });

  testWidgets('sits bottom-left in Arabic', (t) async {
    await _pumpApp(t, Routes.favorites, dir: TextDirection.rtl);
    expect(t.getCenter(find.byKey(AssistantBubble.buttonKey)).dx, lessThan(400));
  });

  testWidgets('hidden on the cart and while a dialog is open', (t) async {
    final router = await _pumpApp(t, Routes.home);
    expect(find.byKey(AssistantBubble.buttonKey), findsOneWidget);

    showDialog<void>(
      context: router.routerDelegate.navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('hi')),
    );
    await t.pumpAndSettle();
    expect(find.byKey(AssistantBubble.buttonKey), findsNothing);
    router.routerDelegate.navigatorKey.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.byKey(AssistantBubble.buttonKey), findsOneWidget);

    router.push(Routes.cart);
    await t.pumpAndSettle();
    expect(find.byKey(AssistantBubble.buttonKey), findsNothing);
  });
}
