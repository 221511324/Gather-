import 'package:flutter_test/flutter_test.dart';

import 'package:gather/app/router.dart';
import 'package:gather/core/l10n/tr.dart';
import 'package:gather/core/models/models.dart';
import 'package:gather/features/profile/notification_pop_up.dart';

/// US16 — the order-progress notifications and when they pop up,
/// TC_UN_001 to TC_UN_006.
void main() {
  AppNotification note(String id,
          {bool read = false, DateTime? at, String? orderId, String? sessionId}) =>
      AppNotification(
        id: id,
        title: 't',
        body: 'b',
        kind: NotificationKind.order,
        read: read,
        createdAt: at,
        orderId: orderId,
        sessionId: sessionId,
      );

  test('TC_UN_001 an order goes confirmed, preparing, ready, on its way, delivered', () {
    expect(OrderStatusX.timeline, [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.ready,
      OrderStatus.onTheWay,
      OrderStatus.delivered,
    ]);
    var s = OrderStatus.confirmed;
    final walked = [s];
    while (s.next != null) {
      s = s.next!;
      walked.add(s);
    }
    expect(walked, OrderStatusX.timeline);
    expect(OrderStatus.cancelled.next, isNull);
    expect(OrderStatus.ready.isActive, isTrue);
    expect(OrderStatus.ready.label, 'Ready for pickup');
  });

  test('TC_UN_002 each step has its own message naming the restaurant', () {
    final titles = {for (final s in OrderStatus.values) s.alertTitle};
    expect(titles, hasLength(OrderStatus.values.length), reason: 'no two steps read the same');
    for (final s in OrderStatus.values) {
      expect(s.alertBody('Kudu'), contains('Kudu'));
      expect(s.alertBody('Kudu'), isNot(contains('{')));
    }
    expect(OrderStatus.ready.alertTitle, 'Your order is ready');
    expect(OrderStatus.ready.alertBody('Kudu'),
        'Ready for pickup. A rider is collecting it from Kudu.');
  });

  test('TC_UN_003 every message reads in Arabic and keeps the restaurant name', () {
    for (final s in OrderStatus.values) {
      final title = translate('ar', s.alertTitle);
      expect(title, isNot(s.alertTitle), reason: '${s.name} title');
      final body = translate('ar', s.alertBody('Kudu'));
      expect(body, isNot(s.alertBody('Kudu')), reason: '${s.name} body');
      expect(body, contains('Kudu'));
      expect(RegExp('[A-Za-z]').allMatches(body.replaceAll('Kudu', '')), isEmpty,
          reason: 'no English left in ${s.name}: $body');
    }
    expect(translate('ar', 'Ready for pickup'), 'جاهز للاستلام');
  });

  test('TC_UN_004 only new, unread, recent notifications pop up', () {
    final now = DateTime(2026, 11, 4, 12);
    final list = [
      note('new', at: now.subtract(const Duration(seconds: 5))),
      note('pending'), // written a moment ago, no server time yet
      note('seen', at: now),
      note('read', read: true, at: now),
      note('old', at: now.subtract(const Duration(hours: 2))),
    ];
    final fresh = AlertRules.fresh({'seen'}, list, now);
    expect(fresh.map((n) => n.id), ['new', 'pending']);
  });

  test('TC_UN_005 nothing pops up from the history loaded at sign-in', () {
    final now = DateTime(2026, 11, 4, 12);
    final history = [note('a', at: now), note('b', at: now)];
    final seen = {for (final n in history) n.id};
    expect(AlertRules.fresh(seen, history, now), isEmpty);
  });

  test('TC_UN_006 tapping one opens the order, the session, or the list', () {
    expect(AlertRules.routeFor(note('1', orderId: 'o1')), Routes.trackOrder('o1'));
    expect(AlertRules.routeFor(note('2', sessionId: 's1')), Routes.session('s1'));
    expect(AlertRules.routeFor(note('3')), Routes.notifications);
  });
}
