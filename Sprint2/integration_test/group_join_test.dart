import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// The Phase 1 group journey, driven by two real accounts against the live
/// Firebase project: a host opens a session, invites by username, a member
/// joins with the 4-digit code, and both can leave or cancel.
///
/// Authentication is switched between the host and the member at each step
/// rather than faked, so every write is evaluated by the security rules as
/// the user who would really be making it. This is the closest a single
/// machine can get to the two-phone demo, and it covers US4, US5 and US6
/// (FR6, FR7, FR8 and FR9).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
}
