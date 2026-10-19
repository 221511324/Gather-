import '../utils/parse.dart';

enum PaymentMethodType { card, applePay, stcPay, cash }

extension PaymentMethodTypeX on PaymentMethodType {
  String get label => switch (this) {
        PaymentMethodType.card => 'Card',
        PaymentMethodType.applePay => 'Apple Pay',
        PaymentMethodType.stcPay => 'STC Pay',
        PaymentMethodType.cash => 'Cash on delivery',
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
  });

  final String id;
  final PaymentMethodType type;
  final String brand;
  final String last4;
  final String holderName;
  final int expiryMonth;
  final int expiryYear;
  final bool isDefault;

  String get label => switch (type) {
        PaymentMethodType.card => '$brand •••• $last4',
        _ => type.label,
      };

  String get expiryLabel =>
      '${expiryMonth.toString().padLeft(2, '0')}/${expiryYear.toString().padLeft(2, '0')}';

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
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'brand': brand,
        'last4': last4,
        'holderName': holderName,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'isDefault': isDefault,
      };
}
