import '../utils/parse.dart';

enum TicketStatus { open, inProgress, resolved, closed }

extension TicketStatusX on TicketStatus {
  String get label => switch (this) {
        TicketStatus.open => 'Open',
        TicketStatus.inProgress => 'In progress',
        TicketStatus.resolved => 'Resolved',
        TicketStatus.closed => 'Closed',
      };
}

enum TicketCategory { order, payment, delivery, account, session, other }

extension TicketCategoryX on TicketCategory {
  String get label => switch (this) {
        TicketCategory.order => 'Order issue',
        TicketCategory.payment => 'Payment issue',
        TicketCategory.delivery => 'Delivery issue',
        TicketCategory.account => 'Account issue',
        TicketCategory.session => 'Group session issue',
        TicketCategory.other => 'Something else',
      };
}

/// An issue raised from Help & Support. Admins triage these (US17-AC3/AC4).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.message,
    required this.category,
    this.status = TicketStatus.open,
    this.orderId,
    this.adminReply,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String userName;
  final String subject;
  final String message;
  final TicketCategory category;
  final TicketStatus status;
  final String? orderId;
  final String? adminReply;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SupportTicket.fromMap(String id, Map<String, dynamic> m) => SupportTicket(
        id: id,
        userId: Parse.str(m['userId']),
        userName: Parse.str(m['userName']),
        subject: Parse.str(m['subject']),
        message: Parse.str(m['message']),
        category: Parse.enumOf(TicketCategory.values, m['category'], TicketCategory.other),
        status: Parse.enumOf(TicketStatus.values, m['status'], TicketStatus.open),
        orderId: Parse.strOrNull(m['orderId']),
        adminReply: Parse.strOrNull(m['adminReply']),
        createdAt: Parse.dateOrNull(m['createdAt']),
        updatedAt: Parse.dateOrNull(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'subject': subject,
        'message': message,
        'category': category.name,
        'status': status.name,
        'orderId': orderId,
        'adminReply': adminReply,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}
