import '../utils/parse.dart';

enum PaymentMethodType { card, applePay, stcPay, other }

extension PaymentMethodTypeX on PaymentMethodType {
  String get label => switch (this) {
        PaymentMethodType.card => 'Card',
        PaymentMethodType.applePay => 'Apple Pay',
        PaymentMethodType.stcPay => 'STC Pay',
        PaymentMethodType.other => 'Payment method',
      };
}

/// A saved payment method.
///
/// Only the last four digits and the brand are persisted — the full card
/// number is never written to Firestore, which is what NFR4/NFR5 require of
/// payment data. A production build would swap this for a gateway token.
class SavedPaymentMethod {
  const SavedPaymentMethod({
    required this.id,
    required this.type,
    this.brand = '',
    this.last4 = '',
    this.holderName = '',
    this.expiryMonth = 0,
    this.expiryYear = 0,
    this.isDefault = false,
    this.optionName = '',
    this.optionId = '',
  });

  final String id;
  final PaymentMethodType type;
  final String brand;
  final String last4;
  final String holderName;
  final int expiryMonth;
  final int expiryYear;
  final bool isDefault;

  /// The administrator-configured option this came from, e.g. "PayPal".
  /// Empty for a card, and for wallets saved before options were managed.
  final String optionName;

  /// The id of that option, so renaming it in the console keeps the link.
  /// Empty for cards and for anything saved before the id was recorded —
  /// those are matched by name or type instead.
  final String optionId;

  String get label => switch (type) {
        PaymentMethodType.card => '$brand •••• $last4',
        _ => optionName.isNotEmpty ? optionName : type.label,
      };

  /// Always MM/YY, whether the year was stored as 29 or 2029.
  String get expiryLabel =>
      '${expiryMonth.toString().padLeft(2, '0')}/'
      '${(expiryYear % 100).toString().padLeft(2, '0')}';

  bool get isExpired {
    if (type != PaymentMethodType.card || expiryYear == 0) return false;
    final now = DateTime.now();
    final fullYear = expiryYear < 100 ? 2000 + expiryYear : expiryYear;
    final endOfMonth = DateTime(fullYear, expiryMonth + 1, 0, 23, 59);
    return endOfMonth.isBefore(now);
  }

  factory SavedPaymentMethod.fromMap(String id, Map<String, dynamic> m) => SavedPaymentMethod(
        id: id,
        type: Parse.enumOf(PaymentMethodType.values, m['type'], PaymentMethodType.card),
        brand: Parse.str(m['brand']),
        last4: Parse.str(m['last4']),
        holderName: Parse.str(m['holderName']),
        expiryMonth: Parse.integer(m['expiryMonth']),
        expiryYear: Parse.integer(m['expiryYear']),
        isDefault: Parse.boolean(m['isDefault']),
        optionName: Parse.str(m['optionName']),
        optionId: Parse.str(m['optionId']),
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'brand': brand,
        'last4': last4,
        'holderName': holderName,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'isDefault': isDefault,
        'optionName': optionName,
        if (optionId.isNotEmpty) 'optionId': optionId,
      };
}
