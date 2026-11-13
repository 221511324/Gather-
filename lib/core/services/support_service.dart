import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/support_ticket.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// Help & support (FR28 help options, US17 admin issue handling).
class SupportService {
  SupportService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();

  Future<Result<SupportTicket>> submit({
    required AppUser user,
    required String subject,
    required String message,
    required TicketCategory category,
    String? orderId,
  }) async {
    if (subject.trim().length < 3) return const Err('Give your issue a short subject');
    if (message.trim().length < 10) {
      return const Err('Add a little more detail so we can help');
    }

    try {
      final id = _uuid.v4();
      final ticket = SupportTicket(
        id: id,
        userId: user.uid,
        userName: user.fullName.isEmpty ? user.username : user.fullName,
        subject: subject.trim(),
        message: message.trim(),
        category: category,
        orderId: orderId,
        createdAt: DateTime.now(),
      );
      await refs.ticket(id).set({
        ...ticket.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Ok(ticket);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not send your message');
    }
  }

  Stream<List<SupportTicket>> watchMyTickets(String uid) => refs.tickets
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => SupportTicket.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))));

  Stream<List<SupportTicket>> watchAllTickets() => refs.tickets
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map((d) => SupportTicket.fromMap(d.id, d.data())).toList());

  Future<Result<void>> respond({
    required String ticketId,
    required String reply,
    required TicketStatus status,
  }) async {
    try {
      await refs.ticket(ticketId).update({
        'adminReply': reply.trim(),
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that ticket');
    }
  }

  Future<Result<void>> setStatus(String ticketId, TicketStatus status) async {
    try {
      await refs.ticket(ticketId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that ticket');
    }
  }
}
