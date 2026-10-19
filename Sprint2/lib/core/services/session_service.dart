import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/cart_line.dart';
import '../models/group_session.dart';
import '../models/restaurant.dart';
import '../utils/money.dart';
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

  // ------------------------------------------------- restaurant selection --

  /// The host chooses between spinning the wheel over everyone's suggestions
  /// and simply picking the restaurant themselves (US8).
  Future<Result<void>> setDecisionMode({
    required String sessionId,
    required RestaurantDecisionMode mode,
  }) async {
    try {
      await refs.session(sessionId).update({
        'decisionMode': mode.name,
        'stage': SessionStage.choosingRestaurant.name,
        // Switching to host choice drops the suggestions: they were only ever
        // input for the wheel.
        if (mode == RestaurantDecisionMode.hostChoice) 'suggestions': <Object>[],
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not set how the restaurant is chosen');
    }
  }

  Future<Result<void>> suggestRestaurant({
    required String sessionId,
    required Restaurant restaurant,
    required AppUser by,
  }) async {
    try {
      final result = await refs.db.runTransaction<String?>((tx) async {
        final doc = await tx.get(refs.session(sessionId));
        if (!doc.exists) return 'Session not found';
        final session = GroupSession.fromMap(doc.id, doc.data() ?? {});

        // The host decides how the restaurant is chosen. If they are picking
        // it themselves, nobody is asked to suggest.
        if (session.decisionMode == RestaurantDecisionMode.hostChoice) {
          return 'The host is choosing the restaurant for this order';
        }

        // US8: one suggestion each. Three ways this can be refused, and the
        // member should be told which one applies.
        final existing = session.suggestionBy(by.uid);
        if (existing?.restaurantId == restaurant.id) {
          return '${restaurant.name} has already been suggested — by you';
        }
        if (existing != null) {
          return 'You have already suggested ${existing.restaurantName}. '
              'Withdraw it first if you want to put forward a different one.';
        }

        // US8-AC3: the same restaurant cannot be suggested twice.
        if (session.suggestions.any((s) => s.restaurantId == restaurant.id)) {
          return '${restaurant.name} has already been suggested';
        }
        if (session.suggestions.length >= 12) {
          return 'The wheel is full — remove a suggestion first';
        }

        final suggestion = RestaurantSuggestion(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
          imageUrl: restaurant.imageUrl,
          suggestedBy: by.uid,
          suggestedByName: by.fullName.isEmpty ? by.username : by.fullName,
          votes: [by.uid],
          suggestedAt: DateTime.now(),
        );
        tx.update(refs.session(sessionId), {
          'suggestions': [...session.suggestions, suggestion].map((s) => s.toMap()).toList(),
          'stage': SessionStage.choosingRestaurant.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return null;
      });
      return result == null ? const Ok(null) : Err(result);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not add that suggestion');
    }
  }

  Future<Result<void>> toggleVote({
    required String sessionId,
    required String restaurantId,
    required String uid,
  }) async {
    try {
      await refs.db.runTransaction((tx) async {
        final doc = await tx.get(refs.session(sessionId));
        if (!doc.exists) return;
        final session = GroupSession.fromMap(doc.id, doc.data() ?? {});
        final updated = session.suggestions.map((s) {
          if (s.restaurantId != restaurantId) return s;
          final votes = s.votes.contains(uid)
              ? (s.votes.where((v) => v != uid).toList())
              : [...s.votes, uid];
          return RestaurantSuggestion(
            restaurantId: s.restaurantId,
            restaurantName: s.restaurantName,
            imageUrl: s.imageUrl,
            suggestedBy: s.suggestedBy,
            suggestedByName: s.suggestedByName,
            votes: votes,
            suggestedAt: s.suggestedAt,
          );
        }).toList();
        tx.update(refs.session(sessionId), {
          'suggestions': updated.map((s) => s.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not record that vote');
    }
  }

  /// Withdraws a suggestion. A member may take back their own pick so they can
  /// put a different restaurant forward; the host may clear any of them.
  Future<Result<void>> removeSuggestion({
    required String sessionId,
    required String restaurantId,
    required String byUid,
  }) async {
    try {
      final session = await fetch(sessionId);
      if (session == null) return const Err('Session not found');

      final target = session.suggestions
          .where((s) => s.restaurantId == restaurantId)
          .firstOrNull;
      if (target == null) return const Err('That suggestion is no longer there');
      if (!session.isHostOf(byUid) && target.suggestedBy != byUid) {
        return const Err('Only the host can remove someone else\'s suggestion');
      }

      await refs.session(sessionId).update({
        'suggestions': session.suggestions
            .where((s) => s.restaurantId != restaurantId)
            .map((s) => s.toMap())
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not remove that suggestion');
    }
  }

  /// Locks the restaurant for the session and moves everyone to ordering.
  ///
  /// [bySpin] records that Restaurant Spin made the call rather than the host,
  /// which the session header shows back to the group.
  Future<Result<void>> chooseRestaurant({
    required String sessionId,
    required Restaurant restaurant,
    bool bySpin = false,
  }) async {
    try {
      final session = await fetch(sessionId);
      if (session == null) return const Err('Session not found');

      // Switching restaurants mid-session would leave the shared cart holding
      // food nobody can order, so the cart is emptied with the change.
      final batch = refs.db.batch();
      if (session.restaurantId != null && session.restaurantId != restaurant.id) {
        final lines = await refs.sessionLines(sessionId).get();
        for (final doc in lines.docs) {
          batch.delete(doc.reference);
        }
      }
      batch.update(refs.session(sessionId), {
        'restaurantId': restaurant.id,
        'restaurantName': restaurant.name,
        'restaurantImageUrl': restaurant.imageUrl,
        'decidedBySpin': bySpin,
        'stage': SessionStage.ordering.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not set the restaurant');
    }
  }

  // ---------------------------------------------------------- shared cart --

  Stream<List<CartLine>> watchLines(String sessionId) => refs
      .sessionLines(sessionId)
      .snapshots()
      .map((s) => s.docs.map((d) => CartLine.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (a.addedAt ?? DateTime(0)).compareTo(b.addedAt ?? DateTime(0))));

  /// Every other method here returns a [Result] rather than throwing. This one
  /// did not, so a caller reading a session they are not a member of got an
  /// uncaught permission error instead of a message it could show.
  Future<Result<List<CartLine>>> fetchLines(String sessionId) async {
    try {
      final snapshot = await refs.sessionLines(sessionId).get();
      return Ok(snapshot.docs.map((d) => CartLine.fromMap(d.id, d.data())).toList());
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not read the shared cart');
    }
  }

  Future<Result<void>> addLine({
    required String sessionId,
    required MenuItem item,
    required AppUser owner,
    required int quantity,
    List<SelectedOption> options = const [],
    String note = '',
  }) async {
    final ownerName = owner.fullName.isEmpty ? owner.username : owner.fullName;
    final candidate = CartLine.fromMenuItem(
      item,
      id: _uuid.v4(),
      quantity: quantity,
      options: options,
      note: note,
      ownerId: owner.uid,
      ownerName: ownerName,
    );

    try {
      // The shared cart belongs to the restaurant the group chose. Without this
      // an order could carry items that restaurant does not sell, priced
      // against the wrong delivery fee and minimum.
      final session = await fetch(sessionId);
      if (session == null) return const Err('Session not found');
      if (session.restaurantId != null && session.restaurantId != item.restaurantId) {
        return Err('${session.restaurantName ?? 'This group'} is the restaurant '
            'for this order — that item is from somewhere else');
      }

      // Merge into this member's matching line rather than stacking duplicates.
      final mine = await refs.sessionLines(sessionId).where('ownerId', isEqualTo: owner.uid).get();
      for (final doc in mine.docs) {
        final line = CartLine.fromMap(doc.id, doc.data());
        if (line.signature == candidate.signature) {
          await doc.reference.update({'quantity': line.quantity + quantity});
          await _touch(sessionId);
          return const Ok(null);
        }
      }
      await refs.sessionLines(sessionId).doc(candidate.id).set({
        ...candidate.toMap(),
        'addedAt': FieldValue.serverTimestamp(),
      });
      await _touch(sessionId);
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not add that item');
    }
  }

  Future<Result<void>> setLineQuantity({
    required String sessionId,
    required String lineId,
    required int quantity,
  }) async {
    try {
      if (quantity <= 0) {
        await refs.sessionLines(sessionId).doc(lineId).delete();
      } else {
        await refs.sessionLines(sessionId).doc(lineId).update({'quantity': quantity});
      }
      await _touch(sessionId);
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that item');
    }
  }

  Future<Result<void>> removeLine({required String sessionId, required String lineId}) async {
    try {
      await refs.sessionLines(sessionId).doc(lineId).delete();
      await _touch(sessionId);
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not remove that item');
    }
  }

  /// A member signals they have finished choosing (FR13), which is what the
  /// host watches before locking the cart.
  Future<Result<void>> setItemsConfirmed({
    required String sessionId,
    required String uid,
    required bool confirmed,
  }) =>
      _updateMember(sessionId, uid, (m) => m.copyWith(hasConfirmedItems: confirmed));

  Future<Result<void>> _updateMember(
    String sessionId,
    String uid,
    SessionMember Function(SessionMember) transform,
  ) async {
    try {
      await refs.db.runTransaction((tx) async {
        final doc = await tx.get(refs.session(sessionId));
        if (!doc.exists) return;
        final session = GroupSession.fromMap(doc.id, doc.data() ?? {});
        final members = session.members.map((m) => m.uid == uid ? transform(m) : m).toList();
        tx.update(refs.session(sessionId), {
          'members': members.map((m) => m.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update the session');
    }
  }

  Future<void> _touch(String sessionId) =>
      refs.session(sessionId).update({'updatedAt': FieldValue.serverTimestamp()}).catchError((_) {});

  // ------------------------------------------------------- group payment ---

  /// Splits [totals] across the roster according to [mode] and moves the
  /// session into its payment stage (FR14, FR16).
  ///
  /// - individual: each member pays for their own items plus an equal share of
  ///   the delivery and service fees, since those are incurred once for the
  ///   whole group.
  /// - equalSplit: the grand total divided evenly, cents included.
  /// - hostPays: the host owes everything and nobody else is asked.
  Future<Result<void>> setPaymentMode({
    required String sessionId,
    required PaymentMode mode,
    required CartTotals totals,
    required List<CartLine> lines,
  }) async {
    try {
      final session = await fetch(sessionId);
      if (session == null) return const Err('Session not found');
      if (session.members.isEmpty) return const Err('This session has no members');

      final members = allocate(session, mode, totals, lines);
      await refs.session(sessionId).update({
        'paymentMode': mode.name,
        'members': members.map((m) => m.toMap()).toList(),
        'stage': SessionStage.payment.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not set the payment option');
    }
  }

  @visibleForTesting
  static List<SessionMember> allocate(
    GroupSession session,
    PaymentMode mode,
    CartTotals totals,
    List<CartLine> lines,
  ) {
    final members = session.members;
    switch (mode) {
      case PaymentMode.hostPays:
        return members
            .map((m) => m.copyWith(
                  amountDue: m.isHost ? Money.round(totals.total) : 0,
                  paymentStatus:
                      m.isHost ? MemberPaymentStatus.pending : MemberPaymentStatus.notRequired,
                ))
            .toList();

      case PaymentMode.equalSplit:
        final shares = Money.splitEvenly(totals.total, members.length);
        return [
          for (var i = 0; i < members.length; i++)
            members[i].copyWith(amountDue: shares[i], paymentStatus: MemberPaymentStatus.pending),
        ];

      case PaymentMode.individual:
        final shared = totals.deliveryFee + totals.serviceFee - totals.discount;
        final sharedShares = Money.splitEvenly(shared, members.length);
        return [
          for (var i = 0; i < members.length; i++)
            () {
              final own = lines
                  .where((l) => l.ownerId == members[i].uid)
                  .fold<double>(0, (acc, l) => acc + l.lineTotal);
              final due = Money.round(own + sharedShares[i]);
              return members[i].copyWith(
                amountDue: due < 0 ? 0 : due,
                // Someone who added nothing still owes their share of delivery,
                // but if that nets to zero they have nothing to settle.
                paymentStatus:
                    due <= 0 ? MemberPaymentStatus.notRequired : MemberPaymentStatus.pending,
              );
            }(),
        ];
    }
  }

  Future<Result<void>> markPaid({required String sessionId, required String uid}) =>
      _updateMember(sessionId, uid, (m) => m.copyWith(paymentStatus: MemberPaymentStatus.paid));

  /// Host steps the session back to ordering (for example to switch payment
  /// mode after someone changed their items).
  Future<Result<void>> reopenOrdering(String sessionId) async {
    try {
      final session = await fetch(sessionId);
      if (session == null) return const Err('Session not found');
      final members = session.members
          .map((m) => m.copyWith(paymentStatus: MemberPaymentStatus.pending, amountDue: 0))
          .toList();
      await refs.session(sessionId).update({
        'stage': SessionStage.ordering.name,
        'paymentMode': null,
        'members': members.map((m) => m.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not reopen the session');
    }
  }

  Future<Result<void>> setDeliveryAddress({required String sessionId, required String address}) async {
    try {
      await refs.session(sessionId).update({
        'deliveryAddress': address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not set the address');
    }
  }

  // ----------------------------------------------------------- completion --

  /// Marks the session complete once the order exists, and releases its code.
  Future<void> markPlaced({required String sessionId, required String orderId}) async {
    final session = await fetch(sessionId);
    await refs.session(sessionId).update({
      'stage': SessionStage.placed.name,
      'orderId': orderId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (session != null) {
      await refs.sessionCode(session.code).delete().catchError((_) {});
    }
  }

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

  /// Saves the roster so the same people can be pulled into a future order in
  /// one tap (FR20).
  Future<Result<SavedSession>> saveAsGroup({
    required GroupSession session,
    required String ownerId,
    String? name,
  }) async {
    try {
      final id = _uuid.v4();
      final saved = SavedSession(
        id: id,
        name: (name ?? session.name).trim(),
        ownerId: ownerId,
        members: session.members,
        lastRestaurantName: session.restaurantName,
        createdAt: DateTime.now(),
      );
      await refs.savedSessions(ownerId).doc(id).set({
        ...saved.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return Ok(saved);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not save this group');
    }
  }

  Stream<List<SavedSession>> watchSavedSessions(String uid) => refs
      .savedSessions(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => SavedSession.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.lastUsedAt ?? b.createdAt ?? DateTime(0))
            .compareTo(a.lastUsedAt ?? a.createdAt ?? DateTime(0))));

  Future<void> deleteSavedSession(String uid, String savedId) =>
      refs.savedSessions(uid).doc(savedId).delete();

  Future<void> renameSavedSession(String uid, String savedId, String name) =>
      refs.savedSessions(uid).doc(savedId).update({'name': name.trim()});

  /// Starts a fresh session from a saved group, re-inviting everyone (FR21).
  Future<Result<GroupSession>> startFromSaved({
    required AppUser host,
    required SavedSession saved,
  }) async {
    final created = await createSession(
      host: host,
      name: saved.name,
      inviteMembers: saved.members.where((m) => m.uid != host.uid).toList(),
    );
    if (created case Ok(:final value)) {
      await refs.savedSessions(host.uid).doc(saved.id).update({
        'timesUsed': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }).catchError((_) {});
      return Ok(value);
    }
    return created;
  }
}
