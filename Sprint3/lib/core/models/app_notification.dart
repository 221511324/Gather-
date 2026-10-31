import '../utils/parse.dart';

/// What a notification is about. Decides its icon, and which of the
/// preferences in [UserSettings] silences it.
enum NotificationKind { groupInvite, session, payment, order, delivery, promotion }

extension NotificationKindX on NotificationKind {
  String get label => switch (this) {
        NotificationKind.groupInvite => 'Invitation',
        NotificationKind.session => 'Session',
        NotificationKind.payment => 'Payment',
        NotificationKind.order => 'Order',
        NotificationKind.delivery => 'Delivery',
        NotificationKind.promotion => 'Offer',
      };
}

/// US16 — one entry in the notification centre.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    this.orderId,
    this.sessionId,
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationKind kind;

  /// Where tapping it should go. Both null means it opens nothing.
  final String? orderId;
  final String? sessionId;

  final bool read;
  final DateTime? createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        kind: kind,
        orderId: orderId,
        sessionId: sessionId,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  factory AppNotification.fromMap(String id, Map<String, dynamic> m) => AppNotification(
        id: id,
        title: Parse.str(m['title']),
        body: Parse.str(m['body']),
        kind: Parse.enumOf(NotificationKind.values, m['kind'], NotificationKind.session),
        orderId: Parse.strOrNull(m['orderId']),
        sessionId: Parse.strOrNull(m['sessionId']),
        read: Parse.boolean(m['read']),
        createdAt: Parse.dateOrNull(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'kind': kind.name,
        'orderId': orderId,
        'sessionId': sessionId,
        'read': read,
      };
}
