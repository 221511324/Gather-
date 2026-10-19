import '../utils/parse.dart';
import 'cart_line.dart';
import 'group_session.dart';

/// Order lifecycle used for tracking (FR19). The order of the enum is the
/// order of the tracking timeline, so `index` doubles as progress.
enum OrderStatus { confirmed, preparing, onTheWay, delivered, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.onTheWay => 'On the way',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  String get description => switch (this) {
        OrderStatus.confirmed => 'The restaurant has received your order.',
        OrderStatus.preparing => 'Your food is being prepared.',
        OrderStatus.onTheWay => 'Your driver is on the way to you.',
        OrderStatus.delivered => 'Delivered. Enjoy your meal!',
        OrderStatus.cancelled => 'This order was cancelled.',
      };

  bool get isActive => this == OrderStatus.confirmed || this == OrderStatus.preparing || this == OrderStatus.onTheWay;
  bool get isTerminal => this == OrderStatus.delivered || this == OrderStatus.cancelled;

  /// The steps shown on the tracking timeline (cancelled is handled apart).
  static const timeline = [
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];
}

/// Where the assigned driver is in the delivery run (US11).
///
/// The order of the enum is the order of the run, so `index` can be compared
/// to tell "still waiting at the restaurant" apart from "already carrying the
/// food" — which is exactly the question the tracking screen has to answer.
enum DriverStage { assigned, headingToRestaurant, atRestaurant, pickedUp, onTheWay, arrived }

extension DriverStageX on DriverStage {
  String get label => switch (this) {
        DriverStage.assigned => 'Driver assigned',
        DriverStage.headingToRestaurant => 'Heading to the restaurant',
        DriverStage.atRestaurant => 'At the restaurant',
        DriverStage.pickedUp => 'Picked up your order',
        DriverStage.onTheWay => 'On the way to you',
        DriverStage.arrived => 'Arrived at your address',
      };

  String get description => switch (this) {
        DriverStage.assigned => 'A driver has taken this delivery.',
        DriverStage.headingToRestaurant => 'Driving to the restaurant to collect the order.',
        DriverStage.atRestaurant => 'Waiting at the restaurant for the order to be handed over.',
        DriverStage.pickedUp => 'The order is with the driver and about to leave.',
        DriverStage.onTheWay => 'Driving to your address.',
        DriverStage.arrived => 'The driver is at your address.',
      };

  /// True once the food is in the driver's hands. Used to colour the map and
  /// to word the stage line, because "at the restaurant" and "left with your
  /// order" look the same on a map otherwise.
  bool get hasOrder => index >= DriverStage.pickedUp.index;

  /// The run in order, so a caller can step a driver forward one stage.
  static const route = DriverStage.values;
}

/// One entry in an order's audit trail. Drives the tracking screen and gives
/// admins something concrete to look at when investigating an order.
class OrderEvent {
  const OrderEvent({required this.status, required this.at, this.note = ''});

  final OrderStatus status;
  final DateTime at;
  final String note;

  factory OrderEvent.fromMap(Map<String, dynamic> m) => OrderEvent(
        status: Parse.enumOf(OrderStatus.values, m['status'], OrderStatus.confirmed),
        at: Parse.date(m['at']),
        note: Parse.str(m['note']),
      );

  Map<String, dynamic> toMap() => {'status': status.name, 'at': at, 'note': note};
}

/// What a single participant owes and whether they have settled it. Mirrors
/// the session's payment state onto the placed order so history stays truthful
/// even after the session is cleaned up.
class OrderParticipant {
  const OrderParticipant({
    required this.uid,
    required this.name,
    required this.amount,
    this.paid = false,
  });

  final String uid;
  final String name;
  final double amount;
  final bool paid;

  factory OrderParticipant.fromMap(Map<String, dynamic> m) => OrderParticipant(
        uid: Parse.str(m['uid']),
        name: Parse.str(m['name']),
        amount: Parse.number(m['amount']),
        paid: Parse.boolean(m['paid']),
      );

  Map<String, dynamic> toMap() => {'uid': uid, 'name': name, 'amount': amount, 'paid': paid};
}

class FoodOrder {
  const FoodOrder({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.lines,
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.discount,
    required this.total,
    required this.status,
    this.restaurantImageUrl = '',
    this.isGroupOrder = false,
    this.sessionId,
    this.sessionName,
    this.paymentMode,
    this.participants = const [],
    this.participantIds = const [],
    this.paymentMethodLabel = '',
    this.deliveryAddress = '',
    this.voucherCode,
    this.timeline = const [],
    this.placedAt,
    this.estimatedArrival,
    this.cancelReason,
    this.rating,
    this.reviewComment,
    this.driverName,
    this.driverPhone,
    this.driverLat,
    this.driverLng,
    this.driverStage,
    this.driverUpdatedAt,
  });

  final String id;

  /// Who placed the order. For a group order this is the host.
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImageUrl;
  final List<CartLine> lines;
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double discount;
  final double total;
  final OrderStatus status;
  final bool isGroupOrder;
  final String? sessionId;
  final String? sessionName;
  final PaymentMode? paymentMode;
  final List<OrderParticipant> participants;

  /// Every uid that should see this order in their history — the host plus all
  /// members of the session.
  final List<String> participantIds;
  final String paymentMethodLabel;
  final String deliveryAddress;
  final String? voucherCode;
  final List<OrderEvent> timeline;
  final DateTime? placedAt;
  final DateTime? estimatedArrival;
  final String? cancelReason;
  final int? rating;
  final String? reviewComment;

  // -- live driver tracking (US11) ------------------------------------------
  // All optional: orders placed before tracking existed, and orders no driver
  // has picked up yet, carry none of these and must still parse.
  final String? driverName;
  final String? driverPhone;
  final double? driverLat;
  final double? driverLng;
  final DriverStage? driverStage;

  /// When the driver's position was last reported, so the UI can say how
  /// fresh the dot on the map is instead of implying it is live.
  final DateTime? driverUpdatedAt;

  /// Only a driver with a reported position can be put on a map; everything
  /// else falls back to the plain timeline.
  bool get hasDriverPosition => driverLat != null && driverLng != null;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  /// Lines belonging to one member — used by "my items" in a group order.
  List<CartLine> linesFor(String uid) => lines.where((l) => l.ownerId == uid).toList();

  double amountFor(String uid) {
    for (final p in participants) {
      if (p.uid == uid) return p.amount;
    }
    return total;
  }

  /// An order can still be cancelled while the restaurant has not started
  /// preparing it.
  bool get canCancel => status == OrderStatus.confirmed || status == OrderStatus.preparing;
  bool get canReview => status == OrderStatus.delivered && rating == null;

  factory FoodOrder.fromMap(String id, Map<String, dynamic> m) => FoodOrder(
        id: id,
        userId: Parse.str(m['userId']),
        restaurantId: Parse.str(m['restaurantId']),
        restaurantName: Parse.str(m['restaurantName']),
        restaurantImageUrl: Parse.str(m['restaurantImageUrl']),
        lines: Parse.mapList(m['lines'])
            .map((l) => CartLine.fromMap(Parse.str(l['id']), l))
            .toList(),
        subtotal: Parse.number(m['subtotal']),
        deliveryFee: Parse.number(m['deliveryFee']),
        serviceFee: Parse.number(m['serviceFee']),
        discount: Parse.number(m['discount']),
        total: Parse.number(m['total']),
        status: Parse.enumOf(OrderStatus.values, m['status'], OrderStatus.confirmed),
        isGroupOrder: Parse.boolean(m['isGroupOrder']),
        sessionId: Parse.strOrNull(m['sessionId']),
        sessionName: Parse.strOrNull(m['sessionName']),
        paymentMode: m['paymentMode'] == null
            ? null
            : Parse.enumOf(PaymentMode.values, m['paymentMode'], PaymentMode.individual),
        participants: Parse.mapList(m['participants']).map(OrderParticipant.fromMap).toList(),
        participantIds: Parse.strList(m['participantIds']),
        paymentMethodLabel: Parse.str(m['paymentMethodLabel']),
        deliveryAddress: Parse.str(m['deliveryAddress']),
        voucherCode: Parse.strOrNull(m['voucherCode']),
        timeline: Parse.mapList(m['timeline']).map(OrderEvent.fromMap).toList(),
        placedAt: Parse.dateOrNull(m['placedAt']),
        estimatedArrival: Parse.dateOrNull(m['estimatedArrival']),
        cancelReason: Parse.strOrNull(m['cancelReason']),
        rating: m['rating'] == null ? null : Parse.integer(m['rating']),
        reviewComment: Parse.strOrNull(m['reviewComment']),
        driverName: Parse.strOrNull(m['driverName']),
        driverPhone: Parse.strOrNull(m['driverPhone']),
        driverLat: m['driverLat'] == null ? null : Parse.number(m['driverLat']),
        driverLng: m['driverLng'] == null ? null : Parse.number(m['driverLng']),
        driverStage: m['driverStage'] == null
            ? null
            : Parse.enumOf(DriverStage.values, m['driverStage'], DriverStage.assigned),
        driverUpdatedAt: Parse.dateOrNull(m['driverUpdatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantImageUrl': restaurantImageUrl,
        'lines': lines.map((l) => {'id': l.id, ...l.toMap()}).toList(),
        'subtotal': subtotal,
        'deliveryFee': deliveryFee,
        'serviceFee': serviceFee,
        'discount': discount,
        'total': total,
        'status': status.name,
        'isGroupOrder': isGroupOrder,
        'sessionId': sessionId,
        'sessionName': sessionName,
        'paymentMode': paymentMode?.name,
        'participants': participants.map((p) => p.toMap()).toList(),
        'participantIds': participantIds,
        'paymentMethodLabel': paymentMethodLabel,
        'deliveryAddress': deliveryAddress,
        'voucherCode': voucherCode,
        'timeline': timeline.map((e) => e.toMap()).toList(),
        'placedAt': placedAt,
        'estimatedArrival': estimatedArrival,
        'cancelReason': cancelReason,
        'rating': rating,
        'reviewComment': reviewComment,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverLat': driverLat,
        'driverLng': driverLng,
        'driverStage': driverStage?.name,
        'driverUpdatedAt': driverUpdatedAt,
      };

  /// Only the fields any caller actually replaces are parameters here; the
  /// rest are carried over. Nulls mean "leave as is", so clearing a driver is
  /// done by writing the document rather than through [copyWith].
  FoodOrder copyWith({
    OrderStatus? status,
    List<OrderEvent>? timeline,
    DateTime? estimatedArrival,
    String? cancelReason,
    int? rating,
    String? reviewComment,
    String? driverName,
    String? driverPhone,
    double? driverLat,
    double? driverLng,
    DriverStage? driverStage,
    DateTime? driverUpdatedAt,
  }) =>
      FoodOrder(
        id: id,
        userId: userId,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        restaurantImageUrl: restaurantImageUrl,
        lines: lines,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        serviceFee: serviceFee,
        discount: discount,
        total: total,
        status: status ?? this.status,
        isGroupOrder: isGroupOrder,
        sessionId: sessionId,
        sessionName: sessionName,
        paymentMode: paymentMode,
        participants: participants,
        participantIds: participantIds,
        paymentMethodLabel: paymentMethodLabel,
        deliveryAddress: deliveryAddress,
        voucherCode: voucherCode,
        timeline: timeline ?? this.timeline,
        placedAt: placedAt,
        estimatedArrival: estimatedArrival ?? this.estimatedArrival,
        cancelReason: cancelReason ?? this.cancelReason,
        rating: rating ?? this.rating,
        reviewComment: reviewComment ?? this.reviewComment,
        driverName: driverName ?? this.driverName,
        driverPhone: driverPhone ?? this.driverPhone,
        driverLat: driverLat ?? this.driverLat,
        driverLng: driverLng ?? this.driverLng,
        driverStage: driverStage ?? this.driverStage,
        driverUpdatedAt: driverUpdatedAt ?? this.driverUpdatedAt,
      );
}
