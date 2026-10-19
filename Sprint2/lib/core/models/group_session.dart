import '../utils/parse.dart';

/// How the bill is settled for a group order (FR14).
enum PaymentMode {
  /// Every member pays for exactly what they added.
  individual,

  /// The bill is divided evenly across all members, whatever they ordered.
  equalSplit,

  /// The host covers the whole order; nobody else is asked to pay.
  hostPays,
}

extension PaymentModeX on PaymentMode {
  String get label => switch (this) {
        PaymentMode.individual => 'Everyone pays their own',
        PaymentMode.equalSplit => 'Split equally',
        PaymentMode.hostPays => 'Host pays for everyone',
      };

  String get shortLabel => switch (this) {
        PaymentMode.individual => 'Individual',
        PaymentMode.equalSplit => 'Equal split',
        PaymentMode.hostPays => 'Host pays',
      };

  String get description => switch (this) {
        PaymentMode.individual => 'Each member is charged for the items they added to the shared cart.',
        PaymentMode.equalSplit => 'The total is divided evenly between every member in the session.',
        PaymentMode.hostPays => 'You pay the full amount. No one else is asked for payment.',
      };
}

/// Lifecycle of a group session. The host drives it forward; members see the
/// stage change in real time.
/// How the group settles on a restaurant. The host picks this once, at the
/// start, and it decides what everyone else is offered.
enum RestaurantDecisionMode {
  /// Members each put one restaurant forward and the wheel decides.
  spin,

  /// The host chooses, and members are not asked to suggest.
  hostChoice,
}

extension RestaurantDecisionModeX on RestaurantDecisionMode {
  String get label => switch (this) {
        RestaurantDecisionMode.spin => 'Spin the wheel',
        RestaurantDecisionMode.hostChoice => 'Host chooses',
      };
}

enum SessionStage {
  /// Members are still joining.
  lobby,

  /// Members are suggesting restaurants / the host is spinning.
  choosingRestaurant,

  /// Restaurant is locked; everyone is adding their items.
  ordering,

  /// Host has locked the cart and chosen how the bill is settled.
  payment,

  /// Order placed.
  placed,

  cancelled,
}

extension SessionStageX on SessionStage {
  String get label => switch (this) {
        SessionStage.lobby => 'Waiting for members',
        SessionStage.choosingRestaurant => 'Choosing a restaurant',
        SessionStage.ordering => 'Adding items',
        SessionStage.payment => 'Payment',
        SessionStage.placed => 'Order placed',
        SessionStage.cancelled => 'Cancelled',
      };

  bool get isLive => this != SessionStage.placed && this != SessionStage.cancelled;
}

enum MemberPaymentStatus {
  /// Owes money and has not paid yet.
  pending,
  paid,

  /// Nothing to pay under the selected mode (e.g. host-pays).
  notRequired,
}

extension MemberPaymentStatusX on MemberPaymentStatus {
  String get label => switch (this) {
        MemberPaymentStatus.pending => 'Pending',
        MemberPaymentStatus.paid => 'Paid',
        MemberPaymentStatus.notRequired => 'Covered',
      };
}

class SessionMember {
  const SessionMember({
    required this.uid,
    required this.name,
    required this.username,
    this.photoUrl,
    this.isHost = false,
    this.joinedAt,
    this.paymentStatus = MemberPaymentStatus.pending,
    this.amountDue = 0,
    this.hasConfirmedItems = false,
  });

  final String uid;
  final String name;
  final String username;
  final String? photoUrl;
  final bool isHost;
  final DateTime? joinedAt;
  final MemberPaymentStatus paymentStatus;

  /// What this member owes under the session's current payment mode.
  final double amountDue;

  /// The member pressed "I'm done" on their own items (FR13).
  final bool hasConfirmedItems;

  String get initials {
    final source = name.trim().isEmpty ? username : name.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  factory SessionMember.fromMap(Map<String, dynamic> m) => SessionMember(
        uid: Parse.str(m['uid']),
        name: Parse.str(m['name']),
        username: Parse.str(m['username']),
        photoUrl: Parse.strOrNull(m['photoUrl']),
        isHost: Parse.boolean(m['isHost']),
        joinedAt: Parse.dateOrNull(m['joinedAt']),
        paymentStatus:
            Parse.enumOf(MemberPaymentStatus.values, m['paymentStatus'], MemberPaymentStatus.pending),
        amountDue: Parse.number(m['amountDue']),
        hasConfirmedItems: Parse.boolean(m['hasConfirmedItems']),
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'username': username,
        'photoUrl': photoUrl,
        'isHost': isHost,
        'joinedAt': joinedAt,
        'paymentStatus': paymentStatus.name,
        'amountDue': amountDue,
        'hasConfirmedItems': hasConfirmedItems,
      };

  SessionMember copyWith({
    MemberPaymentStatus? paymentStatus,
    double? amountDue,
    bool? hasConfirmedItems,
    String? name,
  }) =>
      SessionMember(
        uid: uid,
        name: name ?? this.name,
        username: username,
        photoUrl: photoUrl,
        isHost: isHost,
        joinedAt: joinedAt,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        amountDue: amountDue ?? this.amountDue,
        hasConfirmedItems: hasConfirmedItems ?? this.hasConfirmedItems,
      );
}

/// A restaurant a member put forward for the group to consider (FR10 / US7).
class RestaurantSuggestion {
  const RestaurantSuggestion({
    required this.restaurantId,
    required this.restaurantName,
    required this.imageUrl,
    required this.suggestedBy,
    required this.suggestedByName,
    this.votes = const [],
    this.suggestedAt,
  });

  final String restaurantId;
  final String restaurantName;
  final String imageUrl;
  final String suggestedBy;
  final String suggestedByName;

  /// Uids that backed this suggestion. Votes are advisory — the wheel is what
  /// actually decides — but they let a clear favourite surface without a spin.
  final List<String> votes;
  final DateTime? suggestedAt;

  factory RestaurantSuggestion.fromMap(Map<String, dynamic> m) => RestaurantSuggestion(
        restaurantId: Parse.str(m['restaurantId']),
        restaurantName: Parse.str(m['restaurantName']),
        imageUrl: Parse.str(m['imageUrl']),
        suggestedBy: Parse.str(m['suggestedBy']),
        suggestedByName: Parse.str(m['suggestedByName']),
        votes: Parse.strList(m['votes']),
        suggestedAt: Parse.dateOrNull(m['suggestedAt']),
      );

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'imageUrl': imageUrl,
        'suggestedBy': suggestedBy,
        'suggestedByName': suggestedByName,
        'votes': votes,
        'suggestedAt': suggestedAt,
      };
}

class GroupSession {
  const GroupSession({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    required this.hostName,
    this.stage = SessionStage.lobby,
    this.members = const [],
    this.memberIds = const [],
    this.suggestions = const [],
    this.restaurantId,
    this.restaurantName,
    this.restaurantImageUrl,
    this.decidedBySpin = false,
    this.decisionMode,
    this.paymentMode,
    this.deliveryAddress,
    this.orderId,
    this.voucherCode,
    this.voucherDiscount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// The 4-digit join code shown in the invite sheet (FR7).
  final String code;
  final String name;
  final String hostId;
  final String hostName;
  final SessionStage stage;
  final List<SessionMember> members;

  /// Denormalised uid list so members can query "sessions I'm in" with a
  /// single `arrayContains` — Firestore cannot index into [members].
  final List<String> memberIds;
  final List<RestaurantSuggestion> suggestions;
  final String? restaurantId;
  final String? restaurantName;
  final String? restaurantImageUrl;

  /// True when Restaurant Spin picked the restaurant rather than the host.
  final bool decidedBySpin;

  /// Null until the host decides how the restaurant will be chosen.
  final RestaurantDecisionMode? decisionMode;
  final PaymentMode? paymentMode;
  final String? deliveryAddress;

  /// Set once the host places the order.
  final String? orderId;
  final String? voucherCode;

  /// The discount the host's voucher yields, resolved once when it is applied
  /// so the whole group sees the same total.
  final double voucherDiscount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SessionMember? get host {
    for (final m in members) {
      if (m.uid == hostId) return m;
    }
    return null;
  }

  SessionMember? memberOf(String uid) {
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  /// The one suggestion this member put forward, if any. Each member gets a
  /// single pick, so this is a lookup rather than a list.
  RestaurantSuggestion? suggestionBy(String uid) {
    for (final s in suggestions) {
      if (s.suggestedBy == uid) return s;
    }
    return null;
  }

  bool isHostOf(String uid) => hostId == uid;
  bool hasMember(String uid) => memberIds.contains(uid);
  bool get hasRestaurant => (restaurantId ?? '').isNotEmpty;
  int get memberCount => members.length;

  bool get everyonePaid => members.every((m) => m.paymentStatus != MemberPaymentStatus.pending);
  int get paidCount => members.where((m) => m.paymentStatus != MemberPaymentStatus.pending).length;

  factory GroupSession.fromMap(String id, Map<String, dynamic> m) => GroupSession(
        id: id,
        code: Parse.str(m['code']),
        name: Parse.str(m['name'], 'Group order'),
        hostId: Parse.str(m['hostId']),
        hostName: Parse.str(m['hostName']),
        stage: Parse.enumOf(SessionStage.values, m['stage'], SessionStage.lobby),
        members: Parse.mapList(m['members']).map(SessionMember.fromMap).toList(),
        memberIds: Parse.strList(m['memberIds']),
        suggestions: Parse.mapList(m['suggestions']).map(RestaurantSuggestion.fromMap).toList(),
        restaurantId: Parse.strOrNull(m['restaurantId']),
        restaurantName: Parse.strOrNull(m['restaurantName']),
        restaurantImageUrl: Parse.strOrNull(m['restaurantImageUrl']),
        decidedBySpin: Parse.boolean(m['decidedBySpin']),
        decisionMode: m['decisionMode'] == null
            ? null
            : Parse.enumOf(RestaurantDecisionMode.values, m['decisionMode'],
                RestaurantDecisionMode.spin),
        paymentMode: m['paymentMode'] == null
            ? null
            : Parse.enumOf(PaymentMode.values, m['paymentMode'], PaymentMode.individual),
        deliveryAddress: Parse.strOrNull(m['deliveryAddress']),
        orderId: Parse.strOrNull(m['orderId']),
        voucherCode: Parse.strOrNull(m['voucherCode']),
        voucherDiscount: Parse.number(m['voucherDiscount']),
        createdAt: Parse.dateOrNull(m['createdAt']),
        updatedAt: Parse.dateOrNull(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'hostId': hostId,
        'hostName': hostName,
        'stage': stage.name,
        'members': members.map((m) => m.toMap()).toList(),
        'memberIds': memberIds,
        'suggestions': suggestions.map((s) => s.toMap()).toList(),
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'restaurantImageUrl': restaurantImageUrl,
        'decidedBySpin': decidedBySpin,
        'decisionMode': decisionMode?.name,
        'paymentMode': paymentMode?.name,
        'deliveryAddress': deliveryAddress,
        'orderId': orderId,
        'voucherCode': voucherCode,
        'voucherDiscount': voucherDiscount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

/// A reusable group (FR20 / FR21). Saving a session keeps the roster, not the
/// items, so the same people can be pulled into a fresh order in one tap.
class SavedSession {
  const SavedSession({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.members,
    this.lastRestaurantName,
    this.timesUsed = 0,
    this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final List<SessionMember> members;
  final String? lastRestaurantName;
  final int timesUsed;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  factory SavedSession.fromMap(String id, Map<String, dynamic> m) => SavedSession(
        id: id,
        name: Parse.str(m['name'], 'Saved group'),
        ownerId: Parse.str(m['ownerId']),
        members: Parse.mapList(m['members']).map(SessionMember.fromMap).toList(),
        lastRestaurantName: Parse.strOrNull(m['lastRestaurantName']),
        timesUsed: Parse.integer(m['timesUsed']),
        createdAt: Parse.dateOrNull(m['createdAt']),
        lastUsedAt: Parse.dateOrNull(m['lastUsedAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerId': ownerId,
        'members': members.map((m) => m.toMap()).toList(),
        'lastRestaurantName': lastRestaurantName,
        'timesUsed': timesUsed,
        'createdAt': createdAt,
        'lastUsedAt': lastUsedAt,
      };
}
