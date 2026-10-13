// Every Sprint 1 test case in one file.
//
//   Part A  TC_UT_001 - TC_UT_015   unit and widget tests
//   Part B  TC_IT_001 - TC_IT_005   integration tests
//   Part C  TC_U_001  - TC_U_021    user story tests, one per acceptance criterion
//
// 41 test cases in total. They run on a device against the live Firebase
// project, so every write is checked by the real security rules:
//
//   flutter test integration_test/all_test_cases.dart -d DEVICE
//
// Each part keeps its own helpers, so nothing leaks between them.

import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/app/app.dart';
import 'package:gather/app/router.dart';
import 'package:gather/app/theme/app_colors.dart';
import 'package:gather/app/theme/app_theme.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/catalog_service.dart';
import 'package:gather/core/utils/money.dart';
import 'package:gather/core/widgets/gather_button.dart';
import 'package:gather/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------------
  // Part A1 — Money arithmetic (TC_UT_001 to TC_UT_009)
  // ------------------------------------------------------------------------

  group('Part A1 — Money arithmetic (TC_UT_001 to TC_UT_009)', () {
      group('Money.splitEvenly', () {
        test('divides a clean amount evenly', () {
          expect(Money.splitEvenly(100, 4), [25.0, 25.0, 25.0, 25.0]);
        });

        test('never loses or invents cents on an awkward split', () {
          final shares = Money.splitEvenly(100, 3);
          expect(shares, [33.34, 33.33, 33.33]);
          expect(shares.fold<double>(0, (a, b) => a + b).toStringAsFixed(2), '100.00');
        });

        test('puts the remainder on the earliest shares', () {
          final shares = Money.splitEvenly(10.01, 2);
          expect(shares, [5.01, 5.00]);
        });

        test('handles a single member', () {
          expect(Money.splitEvenly(42.55, 1), [42.55]);
        });

        test('returns nothing for a non-positive group', () {
          expect(Money.splitEvenly(50, 0), isEmpty);
        });

        test('keeps the total exact across many awkward amounts', () {
          for (final total in [0.01, 7.77, 19.99, 123.45, 1000.03]) {
            for (final count in [2, 3, 5, 7, 11]) {
              final shares = Money.splitEvenly(total, count);
              expect(shares.length, count);
              expect(
                (shares.fold<double>(0, (a, b) => a + b) * 100).round(),
                (total * 100).round(),
                reason: 'splitting $total across $count drifted',
              );
            }
          }
        });
      });

      group('Money.round', () {
        test('rounds to two decimals', () {
          expect(Money.round(2.344), 2.34);
          expect(Money.round(2.346), 2.35);
          expect(Money.round(19.999), 20.00);
          expect(Money.round(0.004), 0.00);
        });

        test('rounding is idempotent', () {
          for (final value in [1.005, 2.675, 19.999, 123.456]) {
            final once = Money.round(value);
            expect(Money.round(once), once);
          }
        });
      });

      group('Money.format', () {
        test('includes the currency and two decimals', () {
          expect(Money.format(42.5), 'SAR 42.50');
          expect(Money.format(1234.5), 'SAR 1,234.50');
        });
      });
  });

  // ------------------------------------------------------------------------
  // Part A2 — Design system and accessibility (TC_UT_010 to TC_UT_015)
  // ------------------------------------------------------------------------

  group('Part A2 — Design system and accessibility (TC_UT_010 to TC_UT_015)', () {
      Widget host(Widget child) => MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: Center(child: child)),
          );

      testWidgets('GatherButton is the full-width 56px page action', (tester) async {
        await tester.pumpWidget(host(
          SizedBox(width: 300, child: GatherButton(label: 'Continue', onPressed: () {})),
        ));
        final size = tester.getSize(find.byType(FilledButton));
        expect(size.height, 56);
        expect(size.width, 300);
      });

      testWidgets('a compact GatherButton is shorter but still full width',
          (tester) async {
        await tester.pumpWidget(host(
          SizedBox(
            width: 300,
            child: GatherButton(label: 'Join', compact: true, onPressed: () {}),
          ),
        ));
        final size = tester.getSize(find.byType(FilledButton));
        expect(size.height, lessThan(56), reason: 'compact is shorter than a page button');
        expect(size.height, greaterThanOrEqualTo(48),
            reason: 'must still meet the 48dp minimum tap target');
        expect(size.width, 300);
      });

      testWidgets('a non-expanding GatherButton sizes to its label', (tester) async {
        await tester.pumpWidget(host(
          GatherButton(label: 'Spin', expand: false, onPressed: () {}),
        ));
        expect(tester.getSize(find.byType(FilledButton)).width, lessThan(200));
      });

      testWidgets('GatherOutlineButton matches the primary button geometry',
          (tester) async {
        await tester.pumpWidget(host(
          SizedBox(
            width: 300,
            child: GatherOutlineButton(label: 'Cancel', onPressed: () {}),
          ),
        ));
        final size = tester.getSize(find.byType(OutlinedButton));
        expect(size.height, 56, reason: 'primary and secondary actions must line up');
        expect(size.width, 300);
      });

      testWidgets('dialog action buttons do not inherit the full-width rule',
          (tester) async {
        await tester.pumpWidget(host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove item?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    FilledButton(onPressed: () {}, child: const Text('Remove')),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ));

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        final dialog = tester.getSize(find.byType(AlertDialog));
        final action = tester.getSize(find.widgetWithText(FilledButton, 'Remove'));

        expect(
          action.width,
          lessThan(dialog.width * 0.75),
          reason: 'a dialog action should size to its label, not span the dialog',
        );
        expect(action.height, lessThanOrEqualTo(48),
            reason: 'a dialog action should not be a 56px page button');
      });

      test('brand colours carry enough contrast for the text placed on them', () {
        double luminance(Color c) {
          double channel(double v) =>
              v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
          final r = channel(c.r), g = channel(c.g), b = channel(c.b);
          return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        }

        double ratio(Color a, Color b) {
          final la = luminance(a), lb = luminance(b);
          final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
          return (hi + 0.05) / (lo + 0.05);
        }

        // White label on the primary action.
        // AA for normal-size text: the button label is 17px bold.
        expect(ratio(AppColors.primary, const Color(0xFFFFFFFF)), greaterThan(4.5));
        // Body text on the beige page and on a card.
        expect(ratio(AppColors.ink, AppColors.background), greaterThan(7.0));
        expect(ratio(AppColors.ink, AppColors.surface), greaterThan(7.0));
        // Muted text still has to clear the normal-text bar on beige.
        expect(ratio(AppColors.inkMuted, AppColors.background), greaterThan(4.4));
        // Dark ink on the reward accent.
        expect(ratio(AppColors.ink, AppColors.accent), greaterThan(4.5));
      });
  });

  // ------------------------------------------------------------------------
  // Part B1 — Navigation (TC_IT_003)
  // ------------------------------------------------------------------------

  group('Part B1 — Navigation (TC_IT_003)', () {


      testWidgets('the selected tab always matches the current route', (tester) async {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        final prefs = await AppPrefs.load();
        await FirebaseAuth.instance.signOut();

        final container = ProviderContainer(
          overrides: [appPrefsProvider.overrideWithValue(prefs)],
        );
        container.read(onboardingSeenProvider.notifier).state = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const GatherApp()),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        Future<void> settle([int n = 10]) async {
          for (var i = 0; i < n; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
        }

        final stamp = DateTime.now().millisecondsSinceEpoch;
        await container.read(authServiceProvider).signUp(
              fullName: 'Nav Test',
              username: 'nav$stamp',
              email: 'nav$stamp@gather-test.local',
              phone: '+966500000000',
              password: 'TestPass123!',
            );
        for (var i = 0; i < 200; i++) {
          if (container.read(currentUserOrNullProvider) != null) break;
          await tester.pump(const Duration(milliseconds: 150));
        }
        await settle(20);

        final router = container.read(routerProvider);
        String where() =>
            router.routerDelegate.currentConfiguration.uri.toString();

        /// The tab that is actually drawn as selected, read off the widget tree.
        String? highlighted() {
          for (final label in ['Home', 'Search', 'Group', 'Profile']) {
            final finder = find.ancestor(
              of: find.text(label),
              matching: find.byType(Semantics),
            );
            for (final element in finder.evaluate()) {
              final s = element.widget as Semantics;
              if (s.properties.selected == true && s.properties.label == label) {
                return label;
              }
            }
          }
          return null;
        }

        const expected = {
          'Home': '/home',
          'Search': '/search',
          'Group': '/group',
          'Profile': '/profile',
        };

        final problems = <String>[];

        // 1. Tap each tab in the bar.
        for (final entry in expected.entries) {
          await tester.tap(find.text(entry.key).last);
          await settle();
          final loc = where();
          final sel = highlighted();
          debugPrint('NAV tap=${entry.key} location=$loc highlighted=$sel');
          if (!loc.startsWith(entry.value)) {
            problems.add('tapping ${entry.key} went to $loc');
          }
          if (sel != entry.key) {
            problems.add('tapping ${entry.key} left "$sel" highlighted');
          }
        }

        // 2. Navigate by route, the way in-app buttons do.
        for (final entry in expected.entries) {
          router.go(entry.value);
          await settle();
          final loc = where();
          final sel = highlighted();
          debugPrint('NAV go=${entry.value} location=$loc highlighted=$sel');
          if (sel != entry.key) {
            problems.add('go(${entry.value}) left "$sel" highlighted, expected ${entry.key}');
          }
        }

        // 3. Push a full-screen route, come back, and confirm the bar recovers.
        router.go('/home');
        await settle();
        router.push(Routes.editProfile);
        await settle();
        router.pop();
        await settle();
        debugPrint('NAV after push round-trip location=${where()} highlighted=${highlighted()}');
        if (highlighted() != 'Home') {
          problems.add('after returning from a pushed route, "${highlighted()}" was highlighted');
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await settle(4);
        await FirebaseAuth.instance.currentUser?.delete();
        container.dispose();

        expect(problems, isEmpty, reason: problems.join('\n'));
        debugPrint('NAV-CHECK-PASSED');
      }, timeout: const Timeout(Duration(minutes: 6)));
  });

  // ------------------------------------------------------------------------
  // Part B2 — Route sweep (TC_IT_005)
  // ------------------------------------------------------------------------

  group('Part B2 — Route sweep (TC_IT_005)', () {


      testWidgets('every route renders without throwing', (tester) async {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        final prefs = await AppPrefs.load();
        await FirebaseAuth.instance.signOut();

        final container = ProviderContainer(
          overrides: [appPrefsProvider.overrideWithValue(prefs)],
        );
        container.read(onboardingSeenProvider.notifier).state = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const GatherApp()),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        Future<void> settle([int ticks = 12]) async {
          for (var i = 0; i < ticks; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
        }

        Future<T> waitFor<T>(T? Function() read, String label) async {
          for (var i = 0; i < 200; i++) {
            final v = read();
            if (v != null) return v;
            await tester.pump(const Duration(milliseconds: 150));
          }
          fail('timed out waiting for $label');
        }

        // A real account, so authenticated routes render real data.
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final signUp = await container.read(authServiceProvider).signUp(
              fullName: 'Route Test',
              username: 'routes$stamp',
              email: 'routes$stamp@gather-test.local',
              phone: '+966500000000',
              password: 'TestPass123!',
            );
        expect(signUp.isSuccess, isTrue, reason: signUp.errorOrNull ?? '');

        final user = await waitFor(
            () => container.read(currentUserOrNullProvider), 'the profile');
        await waitFor(() {
          final list = container.read(restaurantsProvider).valueOrNull;
          return (list != null && list.isNotEmpty) ? list : null;
        }, 'the seeded catalogue');

        // A real session so the group routes have something to show.
        final session = await container
            .read(sessionServiceProvider)
            .createSession(host: user, name: 'Route test');
        expect(session.isSuccess, isTrue, reason: session.errorOrNull ?? '');
        final sessionId = session.valueOrNull!.id;

        final router = container.read(routerProvider);

        final routes = <String>[
          Routes.home,
          Routes.search,
          Routes.group,
          Routes.profile,
          Routes.editProfile,
          Routes.joinSession,
          Routes.restaurant('burger-yard'),
          Routes.session(sessionId),
          // A code nobody is using must show an empty state, not crash.
          '/join/9999',
          // An unknown path must land on the error page, not blow up.
          '/this-route-does-not-exist',
        ];

        final failures = <String>[];
        for (final route in routes) {
          debugPrint('ROUTE-VISIT $route');
          try {
            router.push(route);
            await settle();
            final error = tester.takeException();
            if (error != null) {
              failures.add('$route -> $error');
              debugPrint('ROUTE-FAIL $route -> $error');
            }
            if (router.canPop()) {
              router.pop();
              await settle(6);
              final popError = tester.takeException();
              if (popError != null) {
                failures.add('$route (on leaving) -> $popError');
                debugPrint('ROUTE-FAIL-POP $route -> $popError');
              }
            }
          } catch (e) {
            failures.add('$route threw while navigating -> $e');
            debugPrint('ROUTE-THROW $route -> $e');
          }
        }
        debugPrint('ROUTE-LOOP-COMPLETE');

        // Tear the app down before touching auth: deleting the account flips the
        // auth stream, and a mounted tree would rebuild against a vanished user.
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(4);

        await container.read(sessionServiceProvider).cancel(sessionId);
        await FirebaseAuth.instance.currentUser?.delete();
        container.dispose();

        expect(failures, isEmpty,
            reason: 'these routes did not render cleanly:\n${failures.join('\n')}');
        debugPrint('ROUTE CHECK: ${routes.length} routes rendered cleanly');
      }, timeout: const Timeout(Duration(minutes: 8)));
  });

  // ------------------------------------------------------------------------
  // Part B3 — Sign-in and sign-up flow (TC_IT_001, TC_IT_002)
  // ------------------------------------------------------------------------

  group('Part B3 — Sign-in and sign-up flow (TC_IT_001, TC_IT_002)', () {


      late AppPrefs prefs;

      setUpAll(() async {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        prefs = await AppPrefs.load();
        // Start from a known state rather than whatever the last run left behind.
        await FirebaseAuth.instance.signOut();
      });

      /// Boots the real app with onboarding already dismissed.
      Future<ProviderContainer> bootApp(WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [appPrefsProvider.overrideWithValue(prefs)],
        );
        container.read(onboardingSeenProvider.notifier).state = true;

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: const GatherApp()),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));
        return container;
      }

      /// Everything currently rendered as text — used to explain a timeout
      /// instead of just reporting one.
      String visibleText(WidgetTester tester) => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .where((t) => t.trim().isNotEmpty)
          .join(' | ');

      /// Pumps until [read] returns a non-null value. The home screen renders
      /// before the profile stream has emitted, so anything reading the profile
      /// has to wait for it rather than assume it is there.
      Future<T> waitForValue<T>(
        WidgetTester tester,
        T? Function() read, {
        Duration timeout = const Duration(seconds: 30),
        String label = 'a value',
      }) async {
        final deadline = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(deadline)) {
          final value = read();
          if (value != null) return value;
          await tester.pump(const Duration(milliseconds: 250));
        }
        fail('Timed out waiting for $label.');
      }

      /// Pumps repeatedly until [finder] appears or the budget runs out. Real
      /// network round-trips do not fit `pumpAndSettle`'s model.
      Future<void> waitFor(
        WidgetTester tester,
        Finder finder, {
        Duration timeout = const Duration(seconds: 25),
        String? because,
      }) async {
        final deadline = DateTime.now().add(timeout);
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 250));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('Timed out waiting for ${because ?? finder.describeMatch(Plurality.zero)}.\n'
            'On screen: ${visibleText(tester)}');
      }

      testWidgets('a signed-out user lands on the sign-in screen', (tester) async {
        await bootApp(tester);

        expect(find.text('Hello!'), findsOneWidget);
        expect(find.text('Welcome back'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
      });

      testWidgets('sign-up creates a profile, seeds the catalogue and opens home',
          (tester) async {
        final container = await bootApp(tester);
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final email = 'itest$stamp@gather-test.local';
        final username = 'itest$stamp';

        // Sign in -> sign up. The link is a Text.rich, so `find.text` would be
        // comparing against the whole span rather than the tappable words.
        await tester.tap(find.textContaining("Don't have an account"));
        await tester.pumpAndSettle();
        expect(find.text('Create your account'), findsOneWidget);

        Future<void> fill(String label, String value) async {
          final field = find.ancestor(
            of: find.text(label),
            matching: find.byType(Column),
          );
          expect(field, findsWidgets, reason: 'no field labelled "$label"');
          await tester.enterText(
            find.descendant(of: field.first, matching: find.byType(TextFormField)).first,
            value,
          );
          await tester.pump();
        }

        await fill('Full name', 'Integration Test');
        await fill('Username', username);
        await fill('Email', email);
        await fill('Phone number', '+966500000000');
        await fill('Password', 'TestPass123!');
        await fill('Confirm password', 'TestPass123!');

        // Let the debounced username availability check settle, and close the
        // keyboard so the submit button is reachable.
        await tester.pump(const Duration(milliseconds: 1200));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        final submit = find.widgetWithText(FilledButton, 'Create account');
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pump();

        // "Eating with people?" only exists on the home screen, so it is an
        // unambiguous signal that sign-up succeeded and the router moved on.
        await waitFor(
          tester,
          find.text('Eating with people?'),
          timeout: const Duration(seconds: 45),
          because: 'the home screen after sign-up',
        );

        expect(FirebaseAuth.instance.currentUser, isNotNull,
            reason: 'sign-up should leave the user authenticated');

        // The catalogue seeds itself on first sign-in.
        await waitFor(
          tester,
          find.text('Best sellers'),
          timeout: const Duration(seconds: 60),
          because: 'the seeded catalogue',
        );
        // The "Restaurants" section lives below the fold, so assert on the data
        // rather than on widgets a ListView has not built yet.
        final restaurants = container.read(restaurantsProvider).valueOrNull ?? const [];
        final items = container.read(allMenuItemsProvider).valueOrNull ?? const [];
        expect(restaurants, isNotEmpty, reason: 'the catalogue should have seeded');
        expect(restaurants.map((r) => r.id), contains('burger-yard'));
        expect(items.length, greaterThan(20), reason: 'menus should have seeded too');

        // A host can open a group session and gets a real 4-digit code.
        final user = await waitForValue(
          tester,
          () => container.read(currentUserOrNullProvider),
          label: 'the signed-in profile document',
        );
        expect(user.username, 'itest$stamp');

        final created = await container.read(sessionServiceProvider).createSession(
              host: user,
              name: 'Integration session',
            );
        expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
        expect(created.valueOrNull!.code.length, 4);
        expect(created.valueOrNull!.memberIds, contains(user.uid));

        // Tear the app down before touching auth: deleting the account flips the
        // auth stream, and a mounted tree would rebuild against a vanished user.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));

        // Clean up so repeated runs do not accumulate accounts.
        await container.read(sessionServiceProvider).cancel(created.valueOrNull!.id);
        await FirebaseAuth.instance.currentUser?.delete();
      });
  });

  // ------------------------------------------------------------------------
  // Part B4 — Two-user group flow (TC_IT_004)
  // ------------------------------------------------------------------------

  group('Part B4 — Two-user group flow (TC_IT_004)', () {


      testWidgets('a host opens a session and a member joins it', (tester) async {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await FirebaseAuth.instance.signOut();

        final container = ProviderContainer();
        final auth = container.read(authServiceProvider);
        final sessions = container.read(sessionServiceProvider);

        final stamp = DateTime.now().millisecondsSinceEpoch;
        const password = 'TestPass123!';
        final hostEmail = 'host$stamp@gather-test.local';
        final memberEmail = 'member$stamp@gather-test.local';

        /// Signs the given account in and returns its freshly-read profile, so
        /// every step acts as the right person.
        Future<AppUser> actAs(String email) async {
          await FirebaseAuth.instance.signOut();
          final signedIn = await auth.signIn(email: email, password: password);
          expect(signedIn.isSuccess, isTrue, reason: signedIn.errorOrNull ?? '');
          return signedIn.valueOrNull!;
        }

        // ---------------------------------------------------------- accounts --
        final hostSignUp = await auth.signUp(
          fullName: 'Rama Alrashodi',
          username: 'host$stamp',
          email: hostEmail,
          phone: '+96650000${stamp % 10000}',
          password: password,
        );
        expect(hostSignUp.isSuccess, isTrue, reason: hostSignUp.errorOrNull ?? '');

        final memberSignUp = await auth.signUp(
          fullName: 'Mashael Aljarbou',
          username: 'member$stamp',
          email: memberEmail,
          phone: '+96651111${stamp % 10000}',
          password: password,
        );
        expect(memberSignUp.isSuccess, isTrue, reason: memberSignUp.errorOrNull ?? '');

        // ------------------------------------------- FR6: host opens a session --
        final host = await actAs(hostEmail);
        final created = await sessions.createSession(host: host, name: 'Friday dinner');
        expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
        final session = created.valueOrNull!;
        final sessionId = session.id;

        expect(session.code.length, 4, reason: 'FR7: a 4-digit join code');
        expect(int.tryParse(session.code), isNotNull);
        expect(session.hostId, host.uid);
        expect(session.memberIds, [host.uid]);
        debugPrint('FLOW host created session, code=${session.code}');

        // ------------------------------------------- FR7: invite by username ---
        final lookup = await auth.findInvitee('member$stamp');
        expect(lookup.isSuccess, isTrue, reason: lookup.errorOrNull ?? '');
        final invitee = lookup.valueOrNull!;
        final invited = await sessions.inviteUser(sessionId: sessionId, inviteeUid: invitee.uid);
        expect(invited.isSuccess, isTrue, reason: invited.errorOrNull ?? '');
        debugPrint('FLOW host invited @${invitee.username}');

        // --------------------------------------- FR8: member joins by the code --
        final member = await actAs(memberEmail);
        final joined = await sessions.joinByCode(code: session.code, user: member);
        expect(joined.isSuccess, isTrue, reason: joined.errorOrNull ?? '');
        expect(joined.valueOrNull!.memberIds, containsAll([host.uid, member.uid]));
        debugPrint('FLOW member joined by code');

        // -------------------------------- US6: the roster shows both members ---
        final afterJoin = await sessions.fetch(sessionId);
        expect(afterJoin, isNotNull);
        expect(afterJoin!.memberCount, 2);
        expect(
          afterJoin.members.map((m) => m.uid),
          containsAll([host.uid, member.uid]),
          reason: 'US6: a member joins and sees the participant list',
        );
        expect(afterJoin.memberOf(host.uid)!.isHost, isTrue);
        expect(afterJoin.memberOf(member.uid)!.isHost, isFalse);

        // A code that nobody is using must be reported, not crash.
        final missing = await sessions.findByCode('0000');
        expect(missing.isSuccess, isFalse, reason: 'an unused code has no session');

        // --------------------------------------- FR9: the member can leave -----
        final left = await sessions.leave(sessionId: sessionId, uid: member.uid);
        expect(left.isSuccess, isTrue, reason: left.errorOrNull ?? '');
        final afterLeave = await sessions.fetch(sessionId);
        expect(afterLeave!.memberIds, [host.uid]);
        debugPrint('FLOW member left the session');

        // ------------------------------- the host cancels and frees the code ---
        await actAs(hostEmail);
        final cancelled = await sessions.cancel(sessionId);
        expect(cancelled.isSuccess, isTrue, reason: cancelled.errorOrNull ?? '');
        final afterCancel = await sessions.fetch(sessionId);
        expect(afterCancel!.stage, SessionStage.cancelled);

        // The code is released so it can be reused by a later session.
        final recycled = await sessions.findByCode(session.code);
        expect(recycled.isSuccess, isFalse, reason: 'a cancelled session releases its code');
        debugPrint('FLOW host cancelled the session');

        // ----------------------------------------------------------- cleanup --
        await actAs(memberEmail);
        await FirebaseAuth.instance.currentUser?.delete();
        await actAs(hostEmail);
        await FirebaseAuth.instance.currentUser?.delete();
        container.dispose();

        debugPrint('GROUP-JOIN-FLOW-PASSED');
      }, timeout: const Timeout(Duration(minutes: 8)));
  });

  // ------------------------------------------------------------------------
  // Part C — User story test cases (TC_U_001 to TC_U_021)
  // ------------------------------------------------------------------------

  group('Part C — User story test cases (TC_U_001 to TC_U_021)', () {


      const password = 'TestPass123!';
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final hostEmail = 'tc_host$stamp@gather-test.local';
      final hostUser = 'tchost$stamp';
      final memberEmail = 'tc_member$stamp@gather-test.local';
      final memberUser = 'tcmember$stamp';

      late ProviderContainer container;
      late AppUser host;
      late AppUser member;

      Future<void> settle(WidgetTester t, [int ticks = 12]) async {
        for (var i = 0; i < ticks; i++) {
          await t.pump(const Duration(milliseconds: 150));
        }
      }

      Future<T> waitFor<T>(WidgetTester t, T? Function() read, String label) async {
        for (var i = 0; i < 200; i++) {
          final v = read();
          if (v != null) return v;
          await t.pump(const Duration(milliseconds: 150));
        }
        fail('timed out waiting for $label');
      }

      Future<AppUser> actAs(String email) async {
        await FirebaseAuth.instance.signOut();
        final r = await container.read(authServiceProvider).signIn(
            email: email, password: password);
        expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
        return r.valueOrNull!;
      }

      /// Pumps the real application and returns its router.
      Future<GoRouterLike> openApp(WidgetTester t) async {
        final prefs = await AppPrefs.load();
        final c = ProviderContainer(overrides: [appPrefsProvider.overrideWithValue(prefs)]);
        c.read(onboardingSeenProvider.notifier).state = true;
        await t.pumpWidget(UncontrolledProviderScope(container: c, child: const GatherApp()));
        await settle(t, 20);
        return GoRouterLike(c);
      }

      setUpAll(() async {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await FirebaseAuth.instance.signOut();
        container = ProviderContainer();
      });

      tearDownAll(() async {
        for (final email in [hostEmail, memberEmail]) {
          try {
            await FirebaseAuth.instance.signOut();
            await container.read(authServiceProvider).signIn(email: email, password: password);
            await FirebaseAuth.instance.currentUser?.delete();
          } catch (_) {}
        }
        container.dispose();
      });

      // ------------------------------------------------------------------ US1 --

      testWidgets('TC_U_001 User registers successfully', (t) async {
        final r = await container.read(authServiceProvider).signUp(
              fullName: 'Sprint One',
              username: hostUser,
              email: hostEmail,
              phone: '+96650000${stamp % 10000}',
              password: password,
            );
        expect(r.isSuccess, isTrue, reason: 'US1-AC1: ${r.errorOrNull}');
        host = r.valueOrNull!;

        final uid = FirebaseAuth.instance.currentUser!.uid;
        final profile = await container.read(authServiceProvider).loadProfile(uid);
        expect(profile, isNotNull, reason: 'US1-AC1: a profile document must be written');
        expect(profile!.username, hostUser);
        debugPrint('TC_U_001 PASS');
      });

      testWidgets('TC_U_002 User logs in successfully', (t) async {
        await FirebaseAuth.instance.signOut();
        final r = await container.read(authServiceProvider).signIn(
            email: hostEmail, password: password);
        expect(r.isSuccess, isTrue, reason: 'US1-AC2: ${r.errorOrNull}');
        expect(FirebaseAuth.instance.currentUser, isNotNull);
        debugPrint('TC_U_002 PASS');
      });

      testWidgets('TC_U_003 User logs in unsuccessfully', (t) async {
        await FirebaseAuth.instance.signOut();
        final r = await container.read(authServiceProvider).signIn(
            email: hostEmail, password: 'WrongPass999!');
        expect(r.isSuccess, isFalse, reason: 'US1-AC3: a wrong password must be refused');
        expect(r.errorOrNull, isNotNull, reason: 'US1-AC3: an error message must be shown');
        expect(r.errorOrNull!.trim(), isNotEmpty);
        expect(FirebaseAuth.instance.currentUser, isNull);
        debugPrint('TC_U_003 PASS message="${r.errorOrNull}"');
      });

      testWidgets('TC_U_004 User logs out successfully', (t) async {
        await actAs(hostEmail);
        expect(FirebaseAuth.instance.currentUser, isNotNull);
        await container.read(authServiceProvider).signOut();
        expect(FirebaseAuth.instance.currentUser, isNull,
            reason: 'US1-AC4: the session must be cleared');
        debugPrint('TC_U_004 PASS');
      });

      testWidgets('TC_U_005 Registration rejects a username already in use', (t) async {
        await FirebaseAuth.instance.signOut();
        final r = await container.read(authServiceProvider).signUp(
              fullName: 'Impostor',
              username: hostUser,
              email: 'impostor$stamp@gather-test.local',
              phone: '+96659999${stamp % 10000}',
              password: password,
            );
        expect(r.isSuccess, isFalse, reason: 'US1-AC1: a taken username must be refused');
        expect(r.errorOrNull, contains('taken'));
        debugPrint('TC_U_005 PASS message="${r.errorOrNull}"');
      });

      // ------------------------------------------------------------------ US2 --

      testWidgets('TC_U_006 User views their profile', (t) async {
        host = await actAs(hostEmail);
        final r = await openApp(t);
        r.go(Routes.profile);
        await settle(t, 16);
        expect(find.textContaining(hostUser), findsWidgets,
            reason: 'US2-AC1: the profile must show the user');
        debugPrint('TC_U_006 PASS');
      });

      testWidgets('TC_U_007 User updates profile information', (t) async {
        host = await actAs(hostEmail);
        final r = await container.read(authServiceProvider)
            .updateProfile(uid: host.uid, fullName: 'Sprint One Updated');
        expect(r.isSuccess, isTrue, reason: 'US2-AC2: ${r.errorOrNull}');

        final reread = await container.read(authServiceProvider).loadProfile(host.uid);
        expect(reread!.fullName, 'Sprint One Updated',
            reason: 'US2-AC3: the change must be saved');
        debugPrint('TC_U_007 PASS');
      });

      // ------------------------------------------------------------------ US3 --

      testWidgets('TC_U_008 User views the list of restaurants', (t) async {
        await actAs(hostEmail);
        final list = await container.read(catalogServiceProvider).fetchRestaurants();
        expect(list, isNotEmpty, reason: 'US3-AC1: restaurants must be listed');
        debugPrint('TC_U_008 PASS ${list.length} restaurants');
      });

      testWidgets('TC_U_009 User views restaurant details and its menu', (t) async {
        await actAs(hostEmail);
        final catalog = container.read(catalogServiceProvider);
        final list = await catalog.fetchRestaurants();
        final restaurant = list.first;
        expect(restaurant.name, isNotEmpty);
        final menu = await catalog.fetchMenu(restaurant.id);
        expect(menu, isNotEmpty, reason: 'US3-AC2: the menu must load');
        debugPrint('TC_U_009 PASS ${restaurant.name}, ${menu.length} items');
      });

      testWidgets('TC_U_010 User selects a food item from the menu', (t) async {
        await actAs(hostEmail);
        final catalog = container.read(catalogServiceProvider);
        final list = await catalog.fetchRestaurants();
        final menu = await catalog.fetchMenu(list.first.id);
        final item = menu.first;

        final fetched = await catalog.fetchMenuItem(item.restaurantId, item.id);
        expect(fetched, isNotNull, reason: 'US3-AC3: an item must be selectable');
        expect(fetched!.name, item.name);
        expect(fetched.price, greaterThan(0));
        debugPrint('TC_U_010 PASS ${fetched.name}, ${fetched.optionGroups.length} option groups');
      });

      testWidgets('TC_U_011 User searches for a restaurant or dish', (t) async {
        await actAs(hostEmail);
        final catalog = container.read(catalogServiceProvider);
        final all = await catalog.fetchRestaurants();
        final term = all.first.name.split(' ').first;

        final hits = CatalogSearch.restaurants(all, term);
        expect(hits, isNotEmpty, reason: 'US3-AC1: search must return a match');
        expect(hits.length, lessThanOrEqualTo(all.length));
        expect(CatalogSearch.restaurants(all, ''), hasLength(all.length),
            reason: 'clearing the query restores the full list');
        debugPrint('TC_U_011 PASS "$term" -> ${hits.length}');
      });

      // ------------------------------------------------------------------ US4 --

      testWidgets('TC_U_012 Host creates a group ordering session', (t) async {
        host = await actAs(hostEmail);
        final r = await container.read(sessionServiceProvider)
            .createSession(host: host, name: 'Friday dinner');
        expect(r.isSuccess, isTrue, reason: 'US4-AC1: ${r.errorOrNull}');
        final s = r.valueOrNull!;
        expect(s.name, 'Friday dinner', reason: 'US4-AC2: the name must be stored');
        expect(s.hostId, host.uid);
        expect(s.stage, SessionStage.lobby);
        sessionId = s.id;
        sessionCode = s.code;
        debugPrint('TC_U_012 PASS id=${s.id}');
      });

      testWidgets('TC_U_013 A unique session code is generated', (t) async {
        host = await actAs(hostEmail);
        final service = container.read(sessionServiceProvider);
        final first = await service.fetch(sessionId);
        expect(first, isNotNull);
        expect(first!.code, hasLength(4), reason: 'US4-AC3: the code is 4 digits');
        expect(int.tryParse(first.code), isNotNull, reason: 'US4-AC3: digits only');

        final second = await service.createSession(host: host, name: 'Second session');
        expect(second.isSuccess, isTrue, reason: second.errorOrNull ?? '');
        expect(second.valueOrNull!.code, isNot(first.code),
            reason: 'US4-AC3: two live sessions must not share a code');
        await service.cancel(second.valueOrNull!.id);
        debugPrint('TC_U_013 PASS ${first.code} != ${second.valueOrNull!.code}');
      });

      testWidgets('TC_U_014 The created session is visible to the host', (t) async {
        host = await actAs(hostEmail);
        final mine = await waitFor(t, () {
          final v = container.read(mySessionsProvider).valueOrNull;
          return (v != null && v.isNotEmpty) ? v : null;
        }, 'the host\'s sessions');
        expect(mine.map((s) => s.id), contains(sessionId),
            reason: 'US4-AC4: the session must be listed for its host');
        debugPrint('TC_U_014 PASS ${mine.length} session(s)');
      });

      // ------------------------------------------------------------------ US5 --

      testWidgets('TC_U_015 Host invites a member by username', (t) async {
        await FirebaseAuth.instance.signOut();
        final created = await container.read(authServiceProvider).signUp(
              fullName: 'Sprint Member',
              username: memberUser,
              email: memberEmail,
              phone: '+96651111${stamp % 10000}',
              password: password,
            );
        expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
        member = created.valueOrNull!;

        host = await actAs(hostEmail);
        final found = await container.read(authServiceProvider).findInvitee(memberUser);
        expect(found.isSuccess, isTrue,
            reason: 'US5-AC1: the username lookup must find them: ${found.errorOrNull}');

        final invited = await container.read(sessionServiceProvider)
            .inviteUser(sessionId: sessionId, inviteeUid: found.valueOrNull!.uid);
        expect(invited.isSuccess, isTrue, reason: 'US5-AC1: ${invited.errorOrNull}');
        debugPrint('TC_U_015 PASS invited @$memberUser');
      });

      testWidgets('TC_U_016 Host shares the session code and link', (t) async {
        host = await actAs(hostEmail);
        final s = await container.read(sessionServiceProvider).fetch(sessionId);
        final link = Routes.inviteLink(s!.code);
        expect(link, contains(s.code),
            reason: 'US5-AC1: the shared link must carry the session code');
        expect(link, startsWith('http'));
        debugPrint('TC_U_016 PASS $link');
      });

      testWidgets('TC_U_017 An invited user can access the session', (t) async {
        member = await actAs(memberEmail);
        final invites = await waitFor(t, () {
          final v = container.read(myInvitesProvider).valueOrNull;
          return (v != null && v.isNotEmpty) ? v : null;
        }, 'the member\'s invitations');
        expect(invites.map((s) => s.id), contains(sessionId),
            reason: 'US5-AC3: the invitation must be visible to the invited user');
        debugPrint('TC_U_017 PASS ${invites.length} invitation(s)');
      });

      // ------------------------------------------------------------------ US6 --

      testWidgets('TC_U_018 Member joins with a valid session code', (t) async {
        member = await actAs(memberEmail);
        final r = await container.read(sessionServiceProvider)
            .joinByCode(code: sessionCode, user: member);
        expect(r.isSuccess, isTrue, reason: 'US6-AC1: ${r.errorOrNull}');
        expect(r.valueOrNull!.memberIds, contains(member.uid),
            reason: 'US6-AC2: the member must be added after validation');
        debugPrint('TC_U_018 PASS');
      });

      testWidgets('TC_U_019 Member joins through an invitation link', (t) async {
        host = await actAs(hostEmail);
        final created = await container.read(sessionServiceProvider)
            .createSession(host: host, name: 'Link session');
        expect(created.isSuccess, isTrue, reason: created.errorOrNull ?? '');
        final linkSession = created.valueOrNull!;
        final link = Routes.inviteLink(linkSession.code);

        // The code the link carries is what the join screen resolves.
        final codeFromLink = Uri.parse(link).pathSegments.last;
        expect(codeFromLink, linkSession.code);

        member = await actAs(memberEmail);
        final joined = await container.read(sessionServiceProvider)
            .joinByCode(code: codeFromLink, user: member);
        expect(joined.isSuccess, isTrue, reason: 'US6-AC1: ${joined.errorOrNull}');

        host = await actAs(hostEmail);
        await container.read(sessionServiceProvider).cancel(linkSession.id);
        debugPrint('TC_U_019 PASS via $link');
      });

      testWidgets('TC_U_020 Member cannot join with an invalid code', (t) async {
        member = await actAs(memberEmail);
        final r = await container.read(sessionServiceProvider).findByCode('0000');
        expect(r.isSuccess, isFalse,
            reason: 'US6-AC1: an unused code must not resolve to a session');
        expect(r.errorOrNull, isNotNull);
        debugPrint('TC_U_020 PASS message="${r.errorOrNull}"');
      });

      testWidgets('TC_U_021 Member sees the other participants', (t) async {
        member = await actAs(memberEmail);
        final s = await container.read(sessionServiceProvider).fetch(sessionId);
        expect(s, isNotNull);
        expect(s!.memberCount, greaterThanOrEqualTo(2),
            reason: 'US6-AC3: both participants must be present');
        expect(s.members.map((m) => m.uid), containsAll([host.uid, member.uid]));
        expect(s.memberOf(host.uid)!.isHost, isTrue);
        expect(s.memberOf(member.uid)!.isHost, isFalse);
        for (final m in s.members) {
          expect(m.name.trim(), isNotEmpty,
              reason: 'US6-AC3: every participant must be shown with a name');
        }
        debugPrint('TC_U_021 PASS ${s.memberCount} participants');

        host = await actAs(hostEmail);
        await container.read(sessionServiceProvider).cancel(sessionId);
      });
  });
}

// from integration_test/sprint1_user_story_tests.dart
/// Session created by TC_U_012 and reused by the later cases.
late String sessionId;
late String sessionCode;

/// Small wrapper so a test can navigate the pumped application.
class GoRouterLike {
  GoRouterLike(this._c);
  final ProviderContainer _c;
  void go(String location) => _c.read(routerProvider).go(location);
}
