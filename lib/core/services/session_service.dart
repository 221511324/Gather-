import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/group_session.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// Group ordering sessions — creation, invitations, the shared cart, the
/// restaurant decision and group payment (FR6–FR14, FR16, FR17, FR20, FR21).
///
/// Every member writes to the same `sessions/{id}` document and its `lines`
/// subcollection, and every screen reads those through snapshot streams, which
/// is what gives the real-time synchronisation NFR7 asks for.
class SessionService {
  SessionService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();
  static final _random = Random.secure();

  // ------------------------------------------------------------- creation --

  /// Allocates a 4-digit code that no live session is currently using.
  ///
  /// `sessionCodes/{code}` acts as the registry; the document is removed when
  /// the session finishes so codes recycle.
  Future<String?> _reserveCode(String sessionId) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final code = (_random.nextInt(9000) + 1000).toString();
      try {
        final taken = await refs.db.runTransaction<bool>((tx) async {
          final doc = await tx.get(refs.sessionCode(code));
          if (doc.exists) return true;
          tx.set(refs.sessionCode(code), {
            'sessionId': sessionId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return false;
        });
        if (!taken) return code;
      } on FirebaseException {
        // Contended write — try another code.
      }
    }
    return null;
  }

  Future<Result<GroupSession>> createSession({
    required AppUser host,
    required String name,
    List<SessionMember> inviteMembers = const [],
  }) async {
    final sessionId = _uuid.v4();
    final code = await _reserveCode(sessionId);
    if (code == null) {
      return const Err('Could not generate a session code. Please try again.');
    }

    final hostMember = SessionMember(
      uid: host.uid,
      name: host.fullName.isEmpty ? host.username : host.fullName,
      username: host.username,
      photoUrl: host.photoUrl,
      isHost: true,
      joinedAt: DateTime.now(),
    );

    final session = GroupSession(
      id: sessionId,
      code: code,
      name: name.trim().isEmpty ? 'Group order' : name.trim(),
      hostId: host.uid,
      hostName: hostMember.name,
      members: [hostMember],
      memberIds: [host.uid],
      deliveryAddress: host.defaultAddress?.oneLine,
      createdAt: DateTime.now(),
    );

    try {
      await refs.session(sessionId).set({
        ...session.toMap(),
        'invitedIds': inviteMembers.map((m) => m.uid).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Ok(session);
    } on FirebaseException catch (e) {
      await refs.sessionCode(code).delete().catchError((_) {});
      return Err(e.message ?? 'Could not create the session');
    }
  }

  // -------------------------------------------------------------- reading --

  Stream<GroupSession?> watch(String sessionId) => refs
      .session(sessionId)
      .snapshots()
      .map((d) => d.exists ? GroupSession.fromMap(d.id, d.data() ?? {}) : null);

  Future<GroupSession?> fetch(String sessionId) async {
    final doc = await refs.session(sessionId).get();
    return doc.exists ? GroupSession.fromMap(doc.id, doc.data() ?? {}) : null;
  }

  /// Live sessions this user belongs to, newest first.
  Stream<List<GroupSession>> watchMySessions(String uid) => refs.sessions
      .where('memberIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => GroupSession.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.updatedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0))));

  /// Sessions this user has been invited to but has not joined yet.
  Stream<List<GroupSession>> watchMyInvites(String uid) => refs.sessions
      .where('invitedIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs
          .map((d) => GroupSession.fromMap(d.id, d.data()))
          .where((session) => !session.hasMember(uid) && session.stage.isLive)
          .toList());

  Future<Result<GroupSession>> findByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.length != 4) return const Err('Session codes are 4 digits');
    final pointer = await refs.sessionCode(trimmed).get();
    if (!pointer.exists) return const Err('No active session with that code');
    final sessionId = (pointer.data() ?? {})['sessionId'];
    if (sessionId is! String) return const Err('No active session with that code');
    final session = await fetch(sessionId);
    if (session == null) return const Err('That session is no longer available');
    if (!session.stage.isLive) return const Err('That session has already finished');
    return Ok(session);
  }

  // -------------------------------------------------------- joining/roster --

  Future<Result<GroupSession>> joinByCode({required String code, required AppUser user}) async {
    final found = await findByCode(code);
    return switch (found) {
      Err(:final message) => Err(message),
      Ok(:final value) => join(sessionId: value.id, user: user),
    };
  }

  /// Adds [user] to the session. Safe to call when already a member — the
  /// transaction simply returns the current state, which is what happens when
  /// someone taps an invite link twice.
  Future<Result<GroupSession>> join({required String sessionId, required AppUser user}) async {
    try {
      final joined = await refs.db.runTransaction<GroupSession>((tx) async {
        final doc = await tx.get(refs.session(sessionId));
        if (!doc.exists) {
          throw FirebaseException(plugin: 'gather', code: 'not-found', message: 'Session not found');
        }
        final session = GroupSession.fromMap(doc.id, doc.data() ?? {});
        if (!session.stage.isLive) {
          throw FirebaseException(
              plugin: 'gather', code: 'closed', message: 'That session has already finished');
        }
        if (session.hasMember(user.uid)) return session;

        final member = SessionMember(
          uid: user.uid,
          name: user.fullName.isEmpty ? user.username : user.fullName,
          username: user.username,
          photoUrl: user.settings.shareProfileWithGroup ? user.photoUrl : null,
          joinedAt: DateTime.now(),
        );
        final members = [...session.members, member];
        tx.update(refs.session(sessionId), {
          'members': members.map((m) => m.toMap()).toList(),
          'memberIds': FieldValue.arrayUnion([user.uid]),
          'invitedIds': FieldValue.arrayRemove([user.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return GroupSession.fromMap(session.id, {
          ...session.toMap(),
          'members': members.map((m) => m.toMap()).toList(),
          'memberIds': [...session.memberIds, user.uid],
        });
      });
      return Ok(joined);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not join that session');
    }
  }

  /// Records an invitation so the invitee sees the session in their invites
  /// list and can join in one tap.
  Future<Result<void>> inviteUser({required String sessionId, required String inviteeUid}) async {
    try {
      await refs.session(sessionId).update({
        'invitedIds': FieldValue.arrayUnion([inviteeUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not send that invite');
    }
  }

  /// Host removes a member (FR9). Their items leave the shared cart with them.
  Future<Result<void>> removeMember({required String sessionId, required String memberUid}) async {
    try {
      final session = await fetch(sessionId);
      if (session == null) return const Err('Session not found');
      if (session.hostId == memberUid) return const Err('The host cannot be removed');

      final members = session.members.where((m) => m.uid != memberUid).toList();
      final lines = await refs.sessionLines(sessionId).where('ownerId', isEqualTo: memberUid).get();

      final batch = refs.db.batch();
      batch.update(refs.session(sessionId), {
        'members': members.map((m) => m.toMap()).toList(),
        'memberIds': FieldValue.arrayRemove([memberUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      for (final doc in lines.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not remove that member');
    }
  }

  /// A member leaves voluntarily. If the host leaves, the session is cancelled
  /// rather than left without an owner.
  Future<Result<void>> leave({required String sessionId, required String uid}) async {
    final session = await fetch(sessionId);
    if (session == null) return const Err('Session not found');
    if (session.hostId == uid) return cancel(sessionId);
    return removeMember(sessionId: sessionId, memberUid: uid);
  }

  // ----------------------------------------------------------- completion --

  Future<Result<void>> cancel(String sessionId) async {
    try {
      final session = await fetch(sessionId);
      await refs.session(sessionId).update({
        'stage': SessionStage.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (session != null) {
        await refs.sessionCode(session.code).delete().catchError((_) {});
      }
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not cancel the session');
    }
  }

  // -------------------------------------------------------- saved groups ---

}
