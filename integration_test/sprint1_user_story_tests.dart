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
import 'package:gather/core/services/catalog_service.dart';
import 'package:gather/firebase_options.dart';

/// The Sprint 1 user-story test cases, TC_U_001 to TC_U_021.
///
/// Each one verifies an acceptance criterion from the project charter They run against
/// the live Firebase project, so every write is evaluated by the real security
/// rules as the user who would be making it.
///
///   flutter test integration_test/sprint1_user_story_tests.dart -d DEVICE
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
}

/// Session created by TC_U_012 and reused by the later cases.
late String sessionId;
late String sessionCode;

/// Small wrapper so a test can navigate the pumped application.
class GoRouterLike {
  GoRouterLike(this._c);
  final ProviderContainer _c;
  void go(String location) => _c.read(routerProvider).go(location);
}
