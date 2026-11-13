import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// US16 — keeps people informed about invitations, sessions, payments, orders
/// and deliveries.
///
/// Notifications are written into the recipient's own account. Anyone signed
/// in may deliver one, because that is how an invitation from a host reaches
/// a member; only the recipient can read, mark or delete theirs. The rules
/// enforce both halves.
class NotificationService {
  NotificationService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();

  /// Newest first, which is the order the centre reads in.
  Stream<List<AppNotification>> watch(String uid) => refs
      .notifications(uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.id != '_schema')
          .map((d) => AppNotification.fromMap(d.id, d.data()))
          .toList());

  Stream<int> watchUnreadCount(String uid) =>
      watch(uid).map((all) => all.where((n) => !n.read).length);

  /// Sends one, unless the recipient has turned that kind off.
  ///
  /// The check belongs here rather than at each call site: there are several
  /// places that notify, and a preference honoured in only some of them is
  /// worse than one honoured nowhere, because it looks like it works.
  Future<Result<void>> send({
    required AppUser to,
    required String title,
    required String body,
    required NotificationKind kind,
    String? orderId,
    String? sessionId,
  }) async {
    if (!_wants(to.settings, kind)) return const Ok(null);
    try {
      await refs.notifications(to.uid).doc(_uuid.v4()).set({
        ...AppNotification(
          id: '',
          title: title,
          body: body,
          kind: kind,
          orderId: orderId,
          sessionId: sessionId,
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not send that notification');
    }
  }

  /// Sends the same thing to several people, each still subject to their own
  /// preferences. Failing to notify one person must not stop the others.
  Future<void> sendToAll({
    required List<AppUser> to,
    required String title,
    required String body,
    required NotificationKind kind,
    String? orderId,
    String? sessionId,
  }) async {
    for (final person in to) {
      await send(
        to: person,
        title: title,
        body: body,
        kind: kind,
        orderId: orderId,
        sessionId: sessionId,
      );
    }
  }

  static bool _wants(UserSettings s, NotificationKind kind) {
    if (!s.pushNotifications) return false;
    return switch (kind) {
      NotificationKind.groupInvite => s.groupInvites,
      NotificationKind.promotion => s.promotions,
      NotificationKind.order ||
      NotificationKind.delivery ||
      NotificationKind.payment =>
        s.orderUpdates,
      // A session update is the running commentary of a group someone is
      // already in, so it follows the master switch alone.
      NotificationKind.session => true,
    };
  }

  Future<Result<void>> markRead(String uid, String id) async {
    try {
      await refs.notifications(uid).doc(id).update({'read': true});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that notification');
    }
  }

  Future<Result<void>> markAllRead(String uid) async {
    try {
      final unread = await refs.notifications(uid).where('read', isEqualTo: false).get();
      if (unread.docs.isEmpty) return const Ok(null);
      final batch = refs.db.batch();
      for (final d in unread.docs) {
        if (d.id != '_schema') batch.update(d.reference, {'read': true});
      }
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update your notifications');
    }
  }

  Future<Result<void>> remove(String uid, String id) async {
    try {
      await refs.notifications(uid).doc(id).delete();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not remove that notification');
    }
  }

  Future<Result<void>> clear(String uid) async {
    try {
      final all = await refs.notifications(uid).get();
      final batch = refs.db.batch();
      for (final d in all.docs) {
        if (d.id != '_schema') batch.delete(d.reference);
      }
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not clear your notifications');
    }
  }
}
