import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/notification_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 3 — settings and notifications, TC_N_001 to TC_N_009.
///
/// US16  Keeps users informed about group invitations, session, payment,
///       order and delivery updates.
/// US17  Allows users to manage language, notification, privacy and support
///       preferences.
///
/// The two stories are tested together because the point of US17 is that it
/// changes what US16 does — a preference nothing honours is not a feature.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final meEmail = 'n3me$stamp@gather-test.local';
  final hostEmail = 'n3host$stamp@gather-test.local';

  late ProviderContainer c;
  late NotificationService notifications;
  late AppUser me, host;

  Future<AppUser> actAs(String email) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: password);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    c = ProviderContainer();
    notifications = c.read(notificationServiceProvider);
    final auth = c.read(authServiceProvider);

    for (final (email, name, i) in [(meEmail, 'N Me', 0), (hostEmail, 'N Host', 1)]) {
      final r = await auth.signUp(
          fullName: name, username: 'n3u$i$stamp', email: email,
          phone: '+9665100$i${stamp % 10000}', password: password);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      if (i == 0) me = r.valueOrNull!;
      if (i == 1) host = r.valueOrNull!;
    }
    me = await actAs(meEmail);
  });

  tearDownAll(() async {
    me = await actAs(meEmail);
    await notifications.clear(me.uid);
    c.dispose();
  });

  // ------------------------------------------------------------- US17 ---

  testWidgets('TC_N_001 Settings save and come back', (t) async {
    me = await actAs(meEmail);
    final changed = me.settings.copyWith(
        language: 'ar', promotions: false, discoverableByPhone: false);
    final r = await c.read(authServiceProvider).saveSettings(me.uid, changed);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final reloaded = await c.read(authServiceProvider).loadProfile(me.uid);
    expect(reloaded!.settings.language, 'ar');
    expect(reloaded.settings.promotions, isFalse);
    expect(reloaded.settings.discoverableByPhone, isFalse);
    expect(reloaded.settings.orderUpdates, isTrue, reason: 'untouched settings must survive');
    debugPrint('TC_N_001 PASS language=ar, promotions off, phone hidden');
  });

  testWidgets('TC_N_002 Hiding yourself stops a host finding you', (t) async {
    // Discoverable by username to begin with.
    me = await actAs(meEmail);
    await c.read(authServiceProvider).saveSettings(
        me.uid, me.settings.copyWith(discoverableByUsername: true));

    host = await actAs(hostEmail);
    final found = await c.read(authServiceProvider).findInvitee('n3u0$stamp');
    expect(found.isSuccess, isTrue, reason: 'should be findable while discoverable');

    me = await actAs(meEmail);
    await c.read(authServiceProvider).saveSettings(
        me.uid, me.settings.copyWith(discoverableByUsername: false));

    host = await actAs(hostEmail);
    final hidden = await c.read(authServiceProvider).findInvitee('n3u0$stamp');
    expect(hidden.isSuccess, isFalse,
        reason: 'turning discoverability off must actually hide the account');
    debugPrint('TC_N_002 PASS refused="${hidden.errorOrNull}"');
  });

  // ------------------------------------------------------------- US16 ---

  testWidgets('TC_N_003 A notification arrives and is unread', (t) async {
    me = await actAs(meEmail);
    final fresh = await c.read(authServiceProvider).loadProfile(me.uid);
    final r = await notifications.send(
        to: fresh!, title: 'Order confirmed', body: 'Beirut Table is preparing it.',
        kind: NotificationKind.order, orderId: 'test-order');
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final all = await notifications.watch(me.uid).first;
    expect(all, isNotEmpty);
    expect(all.first.title, 'Order confirmed');
    expect(all.first.read, isFalse);
    expect(all.first.orderId, 'test-order');
    debugPrint('TC_N_003 PASS ${all.length} notification(s), unread');
  });

  testWidgets('TC_N_004 Marking read sticks', (t) async {
    final before = await notifications.watch(me.uid).first;
    final target = before.firstWhere((n) => !n.read);
    expect((await notifications.markRead(me.uid, target.id)).isSuccess, isTrue);

    final after = await notifications.watch(me.uid).first;
    expect(after.firstWhere((n) => n.id == target.id).read, isTrue);
    debugPrint('TC_N_004 PASS');
  });

  testWidgets('TC_N_005 Turning a kind off silences it', (t) async {
    me = await actAs(meEmail);
    final profile = await c.read(authServiceProvider).loadProfile(me.uid);
    await c.read(authServiceProvider)
        .saveSettings(me.uid, profile!.settings.copyWith(promotions: false));
    final updated = await c.read(authServiceProvider).loadProfile(me.uid);

    final countBefore = (await notifications.watch(me.uid).first).length;
    await notifications.send(
        to: updated!, title: 'Half price Friday', body: 'Everything at Olive Grove.',
        kind: NotificationKind.promotion);
    final countAfter = (await notifications.watch(me.uid).first).length;

    expect(countAfter, countBefore, reason: 'an offer must not arrive when offers are off');
    debugPrint('TC_N_005 PASS offer suppressed, still $countAfter');
  });

  testWidgets('TC_N_006 The master switch silences everything', (t) async {
    me = await actAs(meEmail);
    final profile = await c.read(authServiceProvider).loadProfile(me.uid);
    await c.read(authServiceProvider)
        .saveSettings(me.uid, profile!.settings.copyWith(pushNotifications: false));
    final off = await c.read(authServiceProvider).loadProfile(me.uid);

    final countBefore = (await notifications.watch(me.uid).first).length;
    for (final kind in NotificationKind.values) {
      await notifications.send(
          to: off!, title: 'Should not arrive', body: kind.name, kind: kind);
    }
    final countAfter = (await notifications.watch(me.uid).first).length;
    expect(countAfter, countBefore,
        reason: 'nothing at all may arrive while push is off');

    // Put it back for the remaining cases.
    await c.read(authServiceProvider)
        .saveSettings(me.uid, off!.settings.copyWith(pushNotifications: true));
    debugPrint('TC_N_006 PASS all ${NotificationKind.values.length} kinds suppressed');
  });

  testWidgets('TC_N_007 An invitation notifies the person invited', (t) async {
    host = await actAs(hostEmail);
    final sessions = c.read(sessionServiceProvider);
    final made = await sessions.createSession(host: host, name: 'Notify test');
    expect(made.isSuccess, isTrue, reason: made.errorOrNull ?? '');

    final invited = await sessions.inviteUser(
        sessionId: made.valueOrNull!.id, inviteeUid: me.uid);
    expect(invited.isSuccess, isTrue, reason: invited.errorOrNull ?? '');

    me = await actAs(meEmail);
    final mine = await notifications.watch(me.uid).first;
    final invite = mine.where((n) => n.kind == NotificationKind.groupInvite).toList();
    expect(invite, isNotEmpty, reason: 'being invited should tell you');
    expect(invite.first.sessionId, made.valueOrNull!.id);
    debugPrint('TC_N_007 PASS "${invite.first.title}" / "${invite.first.body}"');

    host = await actAs(hostEmail);
    await sessions.cancel(made.valueOrNull!.id);
  });

  testWidgets('TC_N_008 Mark all read clears the badge', (t) async {
    me = await actAs(meEmail);
    final profile = await c.read(authServiceProvider).loadProfile(me.uid);
    await notifications.send(
        to: profile!, title: 'One', body: 'x', kind: NotificationKind.session);
    await notifications.send(
        to: profile, title: 'Two', body: 'y', kind: NotificationKind.session);

    expect((await notifications.watchUnreadCount(me.uid).first), greaterThan(0));
    expect((await notifications.markAllRead(me.uid)).isSuccess, isTrue);
    expect(await notifications.watchUnreadCount(me.uid).first, 0);
    debugPrint('TC_N_008 PASS badge cleared');
  });

  testWidgets('TC_N_009 Nobody can read your notifications', (t) async {
    host = await actAs(hostEmail);
    var refused = false;
    try {
      await c.read(firestoreRefsProvider).notifications(me.uid)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      refused = true;
    }
    expect(refused, isTrue, reason: 'notifications are private to their owner');
    debugPrint('TC_N_009 PASS the database refused the read');
  });
}
