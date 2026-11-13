import '../utils/parse.dart';

/// How a voucher reduces a bill.
enum DiscountType { percentage, fixedAmount, freeDelivery }

extension DiscountTypeX on DiscountType {
  String get label => switch (this) {
        DiscountType.percentage => 'Percentage off',
        DiscountType.fixedAmount => 'Amount off',
        DiscountType.freeDelivery => 'Free delivery',
      };
}

/// Whether a reward can still be used.
enum VoucherStatus { available, used, expired }

/// US15 — a reward in the catalogue, created by an administrator.
class Voucher {
  const Voucher({
    required this.id,
    required this.code,
    required this.title,
    this.description = '',
    this.discountType = DiscountType.percentage,
    this.discountValue = 0,
    this.minimumOrder = 0,
    this.maxRedemptions = 0,
    this.redeemedCount = 0,
    this.validUntil,
    this.isActive = true,
    this.onSpinWheel = false,
    this.createdAt,
  });

  final String id;

  /// What the customer types or taps. Unique, and always stored upper-case so
  /// "save10" and "SAVE10" cannot be two different rewards.
  final String code;

  final String title;
  final String description;
  final DiscountType discountType;

  /// Per cent for [DiscountType.percentage], riyals for
  /// [DiscountType.fixedAmount], ignored for free delivery.
  final double discountValue;

  /// The smallest order this may be used on.
  final double minimumOrder;

  /// Zero means unlimited.
  final int maxRedemptions;
  final int redeemedCount;

  final DateTime? validUntil;
  final bool isActive;

  /// Offered as a prize on Spin & Win (FR25), as well as by code.
  final bool onSpinWheel;
  final DateTime? createdAt;

  bool get isExhausted => maxRedemptions > 0 && redeemedCount >= maxRedemptions;

  bool get hasExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  /// Whether it can be handed out at all right now.
  bool get isOffered => isActive && !isExhausted && !hasExpired;

  /// What this takes off a bill, given what the order is worth.
  ///
  /// Never more than the order itself — a 50 SAR voucher on a 30 SAR order
  /// takes off 30, not 50, so a bill can reach zero but never go below it.
  double discountOn({required double subtotal, required double deliveryFee}) {
    if (subtotal < minimumOrder) return 0;
    final raw = switch (discountType) {
      DiscountType.percentage => subtotal * (discountValue / 100),
      DiscountType.fixedAmount => discountValue,
      DiscountType.freeDelivery => deliveryFee,
    };
    final ceiling = discountType == DiscountType.freeDelivery
        ? deliveryFee
        : subtotal;
    return raw.clamp(0, ceiling).toDouble();
  }

  String get summary => switch (discountType) {
        DiscountType.percentage => '${discountValue.toStringAsFixed(0)}% off',
        DiscountType.fixedAmount => '${discountValue.toStringAsFixed(0)} SAR off',
        DiscountType.freeDelivery => 'Free delivery',
      };

  Voucher copyWith({
    String? code,
    String? title,
    String? description,
    DiscountType? discountType,
    double? discountValue,
    double? minimumOrder,
    int? maxRedemptions,
    DateTime? validUntil,
    bool? isActive,
    bool? onSpinWheel,
  }) =>
      Voucher(
        id: id,
        code: code ?? this.code,
        title: title ?? this.title,
        description: description ?? this.description,
        discountType: discountType ?? this.discountType,
        discountValue: discountValue ?? this.discountValue,
        minimumOrder: minimumOrder ?? this.minimumOrder,
        maxRedemptions: maxRedemptions ?? this.maxRedemptions,
        redeemedCount: redeemedCount,
        validUntil: validUntil ?? this.validUntil,
        isActive: isActive ?? this.isActive,
        onSpinWheel: onSpinWheel ?? this.onSpinWheel,
        createdAt: createdAt,
      );

  factory Voucher.fromMap(String id, Map<String, dynamic> m) => Voucher(
        id: id,
        code: Parse.str(m['code']).toUpperCase(),
        title: Parse.str(m['title']),
        description: Parse.str(m['description']),
        discountType:
            Parse.enumOf(DiscountType.values, m['discountType'], DiscountType.percentage),
        discountValue: Parse.number(m['discountValue']),
        minimumOrder: Parse.number(m['minimumOrder']),
        maxRedemptions: Parse.integer(m['maxRedemptions']),
        redeemedCount: Parse.integer(m['redeemedCount']),
        validUntil: Parse.dateOrNull(m['validUntil']),
        isActive: Parse.boolean(m['isActive'], true),
        onSpinWheel: Parse.boolean(m['onSpinWheel']),
        createdAt: Parse.dateOrNull(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'code': code.toUpperCase(),
        'title': title,
        'description': description,
        'discountType': discountType.name,
        'discountValue': discountValue,
        'minimumOrder': minimumOrder,
        'maxRedemptions': maxRedemptions,
        'redeemedCount': redeemedCount,
        'validUntil': validUntil,
        'isActive': isActive,
        'onSpinWheel': onSpinWheel,
      };
}

/// US15 — a reward held by one person.
///
/// The terms are copied from the catalogue when it is granted, so changing a
/// campaign later cannot silently change what somebody was already promised.
class UserVoucher {
  const UserVoucher({
    required this.id,
    required this.voucherId,
    required this.code,
    required this.title,
    this.description = '',
    this.discountType = DiscountType.percentage,
    this.discountValue = 0,
    this.minimumOrder = 0,
    this.status = VoucherStatus.available,
    this.grantedAt,
    this.expiresAt,
    this.redeemedAt,
    this.orderId,
  });

  final String id;
  final String voucherId;
  final String code;
  final String title;
  final String description;
  final DiscountType discountType;
  final double discountValue;
  final double minimumOrder;
  final VoucherStatus status;
  final DateTime? grantedAt;
  final DateTime? expiresAt;
  final DateTime? redeemedAt;
  final String? orderId;

  bool get hasExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// Usable only if it has not been spent and has not run out of time.
  bool get isUsable => status == VoucherStatus.available && !hasExpired;

  String get summary => switch (discountType) {
        DiscountType.percentage => '${discountValue.toStringAsFixed(0)}% off',
        DiscountType.fixedAmount => '${discountValue.toStringAsFixed(0)} SAR off',
        DiscountType.freeDelivery => 'Free delivery',
      };

  double discountOn({required double subtotal, required double deliveryFee}) {
    if (!isUsable || subtotal < minimumOrder) return 0;
    final raw = switch (discountType) {
      DiscountType.percentage => subtotal * (discountValue / 100),
      DiscountType.fixedAmount => discountValue,
      DiscountType.freeDelivery => deliveryFee,
    };
    final ceiling =
        discountType == DiscountType.freeDelivery ? deliveryFee : subtotal;
    return raw.clamp(0, ceiling).toDouble();
  }

  factory UserVoucher.fromVoucher(Voucher v, {required String id}) => UserVoucher(
        id: id,
        voucherId: v.id,
        code: v.code,
        title: v.title,
        description: v.description,
        discountType: v.discountType,
        discountValue: v.discountValue,
        minimumOrder: v.minimumOrder,
        expiresAt: v.validUntil,
      );

  factory UserVoucher.fromMap(String id, Map<String, dynamic> m) => UserVoucher(
        id: id,
        voucherId: Parse.str(m['voucherId']),
        code: Parse.str(m['code']).toUpperCase(),
        title: Parse.str(m['title']),
        description: Parse.str(m['description']),
        discountType:
            Parse.enumOf(DiscountType.values, m['discountType'], DiscountType.percentage),
        discountValue: Parse.number(m['discountValue']),
        minimumOrder: Parse.number(m['minimumOrder']),
        status: Parse.enumOf(VoucherStatus.values, m['status'], VoucherStatus.available),
        grantedAt: Parse.dateOrNull(m['grantedAt']),
        expiresAt: Parse.dateOrNull(m['expiresAt']),
        redeemedAt: Parse.dateOrNull(m['redeemedAt']),
        orderId: Parse.strOrNull(m['orderId']),
      );

  Map<String, dynamic> toMap() => {
        'voucherId': voucherId,
        'code': code.toUpperCase(),
        'title': title,
        'description': description,
        'discountType': discountType.name,
        'discountValue': discountValue,
        'minimumOrder': minimumOrder,
        'status': status.name,
        'expiresAt': expiresAt,
        'redeemedAt': redeemedAt,
        'orderId': orderId,
      };
}
