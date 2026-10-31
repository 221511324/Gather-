import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/cart_line.dart';
import '../models/group_session.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import '../utils/money.dart';
import 'firestore_refs.dart';
import 'notification_service.dart';
import 'result.dart';

/// Placing, tracking and reviewing orders (FR17–FR19, FR22, FR31).
class OrderService {
  OrderService(this.refs, {NotificationService? notifications})
      : notifications = notifications ?? NotificationService(refs);

  final FirestoreRefs refs;

  /// US16 — tells everyone on an order when it moves.
  final NotificationService notifications;
  static const _uuid = Uuid();

  /// Flat fee added to every order, shown as a separate line at checkout.
  static const serviceFee = 3.0;

  static CartTotals totalsFor({
    required List<CartLine> lines,
    required Restaurant? restaurant,
    double discount = 0,
  }) {
    final subtotal = lines.fold<double>(0, (acc, l) => acc + l.lineTotal);
    return CartTotals(
      subtotal: Money.round(subtotal),
      deliveryFee: subtotal <= 0 ? 0 : (restaurant?.deliveryFee ?? 0),
      serviceFee: subtotal <= 0 ? 0 : serviceFee,
      discount: Money.round(discount),
    );
  }

  // ------------------------------------------------------------- creation --

  Future<Result<FoodOrder>> placeIndividualOrder({
    required AppUser user,
    required Restaurant restaurant,
    required List<CartLine> lines,
    required CartTotals totals,
    required String paymentMethodLabel,
    required String deliveryAddress,
    String? voucherCode,
  }) async {
    if (lines.isEmpty) return const Err('Your cart is empty');
    if (totals.subtotal < restaurant.minimumOrder) {
      return Err('${restaurant.name} has a minimum order of ${Money.format(restaurant.minimumOrder)}');
    }

    final name = user.fullName.isEmpty ? user.username : user.fullName;
    final order = _build(
      id: _uuid.v4(),
      userId: user.uid,
      restaurant: restaurant,
      lines: lines.map((l) => l.ownerId.isEmpty ? l : l).toList(),
      totals: totals,
      paymentMethodLabel: paymentMethodLabel,
      deliveryAddress: deliveryAddress,
      voucherCode: voucherCode,
      isGroupOrder: false,
      participants: [OrderParticipant(uid: user.uid, name: name, amount: totals.total, paid: true)],
      participantIds: [user.uid],
    );

    return _write(order);
  }

  Future<Result<FoodOrder>> placeGroupOrder({
    required GroupSession session,
    required Restaurant restaurant,
    required List<CartLine> lines,
    required CartTotals totals,
    required String paymentMethodLabel,
    required String deliveryAddress,
  }) async {
    if (lines.isEmpty) return const Err('The shared cart is empty');
    if (session.paymentMode == null) return const Err('Choose how the group is paying first');
    if (!session.everyonePaid) return const Err('Some members still have a payment pending');
    if (totals.subtotal < restaurant.minimumOrder) {
      return Err('${restaurant.name} has a minimum order of ${Money.format(restaurant.minimumOrder)}');
    }

    final order = _build(
      id: _uuid.v4(),
      userId: session.hostId,
      restaurant: restaurant,
      lines: lines,
      totals: totals,
      paymentMethodLabel: paymentMethodLabel,
      deliveryAddress: deliveryAddress,
      voucherCode: session.voucherCode,
      isGroupOrder: true,
      sessionId: session.id,
      sessionName: session.name,
      paymentMode: session.paymentMode,
      participants: session.members
          .map((m) => OrderParticipant(
                uid: m.uid,
                name: m.name,
                amount: m.amountDue,
                paid: m.paymentStatus != MemberPaymentStatus.pending,
              ))
          .toList(),
      participantIds: session.memberIds,
    );

    return _write(order);
  }

  static FoodOrder _build({
    required String id,
    required String userId,
    required Restaurant restaurant,
    required List<CartLine> lines,
    required CartTotals totals,
    required String paymentMethodLabel,
    required String deliveryAddress,
    required List<OrderParticipant> participants,
    required List<String> participantIds,
    required bool isGroupOrder,
    String? voucherCode,
    String? sessionId,
    String? sessionName,
    PaymentMode? paymentMode,
  }) {
    final now = DateTime.now();
    return FoodOrder(
      id: id,
      userId: userId,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      restaurantImageUrl: restaurant.imageUrl,
      lines: lines,
      subtotal: totals.subtotal,
      deliveryFee: totals.deliveryFee,
      serviceFee: totals.serviceFee,
      discount: totals.discount,
      total: Money.round(totals.total),
      status: OrderStatus.confirmed,
      isGroupOrder: isGroupOrder,
      sessionId: sessionId,
      sessionName: sessionName,
      paymentMode: paymentMode,
      participants: participants,
      participantIds: participantIds,
      paymentMethodLabel: paymentMethodLabel,
      deliveryAddress: deliveryAddress,
      voucherCode: voucherCode,
      timeline: [OrderEvent(status: OrderStatus.confirmed, at: now, note: 'Order placed')],
      placedAt: now,
      estimatedArrival: now.add(Duration(minutes: restaurant.deliveryMinutes)),
    );
  }

  Future<Result<FoodOrder>> _write(FoodOrder order) async {
    try {
      await refs.order(order.id).set({
        ...order.toMap(),
        'placedAt': FieldValue.serverTimestamp(),
      });
      return Ok(order);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not place your order');
    }
  }

  // -------------------------------------------------------------- reading --

  /// Every order this user takes part in — their own and any group order they
  /// were a member of.
  Stream<List<FoodOrder>> watchMyOrders(String uid) => refs.orders
      .where('participantIds', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => FoodOrder.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.placedAt ?? DateTime(0)).compareTo(a.placedAt ?? DateTime(0))));

  Stream<FoodOrder?> watchOrder(String id) => refs
      .order(id)
      .snapshots()
      .map((d) => d.exists ? FoodOrder.fromMap(d.id, d.data() ?? {}) : null);

  Future<FoodOrder?> fetchOrder(String id) async {
    final doc = await refs.order(id).get();
    return doc.exists ? FoodOrder.fromMap(doc.id, doc.data() ?? {}) : null;
  }

  /// Admin view of the whole platform (FR31).
  Stream<List<FoodOrder>> watchAllOrders({int limit = 100}) => refs.orders
      .orderBy('placedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map((d) => FoodOrder.fromMap(d.id, d.data())).toList());

  // ------------------------------------------------------------- updating --

  Future<Result<void>> advanceStatus({
    required String orderId,
    required OrderStatus status,
    String note = '',
  }) async {
    try {
      await refs.order(orderId).update({
        'status': status.name,
        'timeline': FieldValue.arrayUnion([
          OrderEvent(status: status, at: DateTime.now(), note: note).toMap(),
        ]),
      });

      // Everyone who took part is told, not only whoever placed it — on a
      // group order the others are waiting for the same food.
      final order = await fetchOrder(orderId);
      if (order != null) {
        final people = <AppUser>[];
        for (final uid in order.participantIds.isEmpty
            ? [order.userId]
            : order.participantIds) {
          final person = await _load(uid);
          if (person != null) people.add(person);
        }
        await notifications.sendToAll(
          to: people,
          title: '${order.restaurantName} — ${status.label}',
          body: note.isNotEmpty ? note : status.description,
          kind: status == OrderStatus.onTheWay || status == OrderStatus.delivered
              ? NotificationKind.delivery
              : NotificationKind.order,
          orderId: orderId,
        );
      }
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that order');
    }
  }

  /// Reads a profile so a notification can respect that person's settings.
  Future<AppUser?> _load(String uid) async {
    try {
      final doc = await refs.user(uid).get();
      return doc.exists ? AppUser.fromMap(doc.id, doc.data() ?? {}) : null;
    } on FirebaseException {
      return null;
    }
  }

  /// Reports where the driver is and what they are doing (US11).
  ///
  /// A real driver app would call this on every GPS fix; here the admin order
  /// screen and the tracking screen's debug control stand in for it. The write
  /// is deliberately narrow — a position update must never disturb the order's
  /// status or timeline.
  Future<Result<void>> updateDriverLocation({
    required String orderId,
    required double lat,
    required double lng,
    required DriverStage stage,
    String? driverName,
    String? driverPhone,
  }) async {
    try {
      await refs.order(orderId).update({
        'driverLat': lat,
        'driverLng': lng,
        'driverStage': stage.name,
        'driverUpdatedAt': FieldValue.serverTimestamp(),
        // Omitted when null — sent on the first fix only, so a later update
        // cannot blank out a name the dispatcher already set.
        'driverName': ?driverName,
        'driverPhone': ?driverPhone,
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update the driver location');
    }
  }

  Future<Result<void>> cancelOrder({required String orderId, required String reason}) async {
    try {
      final order = await fetchOrder(orderId);
      if (order == null) return const Err('Order not found');
      if (!order.canCancel) {
        return const Err('This order can no longer be cancelled — it has already left the restaurant');
      }
      await refs.order(orderId).update({
        'status': OrderStatus.cancelled.name,
        'cancelReason': reason,
        'timeline': FieldValue.arrayUnion([
          OrderEvent(status: OrderStatus.cancelled, at: DateTime.now(), note: reason).toMap(),
        ]),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not cancel that order');
    }
  }

  Future<Result<void>> rateOrder({
    required String orderId,
    required int rating,
    String comment = '',
  }) async {
    try {
      await refs.order(orderId).update({'rating': rating, 'reviewComment': comment.trim()});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not save your review');
    }
  }
}
