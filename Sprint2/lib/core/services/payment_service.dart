import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/payment_method.dart';
import 'firestore_refs.dart';
import 'result.dart';

class PaymentReceipt {
  const PaymentReceipt({
    required this.reference,
    required this.amount,
    required this.methodLabel,
    required this.paidAt,
  });

  final String reference;
  final double amount;
  final String methodLabel;
  final DateTime paidAt;
}

/// Digital payments (FR15, NFR10).
///
/// Building a real payment rail is explicitly out of scope for this project,
/// so this is a simulated gateway: it validates the card properly, takes a
/// realistic amount of time, and can fail — but it never contacts a bank and
/// never stores a full card number. [PaymentGateway] is the seam where a real
/// provider would be dropped in without touching any calling code.
abstract interface class PaymentGateway {
  Future<Result<PaymentReceipt>> charge({
    required double amount,
    required String methodLabel,
    required String description,
  });
}

class SimulatedPaymentGateway implements PaymentGateway {
  SimulatedPaymentGateway({this.failureRate = 0.0});

  /// Probability a charge is declined. Kept at zero for demos; raise it to
  /// exercise the failure path.
  final double failureRate;
  static final _random = Random();
  static const _uuid = Uuid();

  @override
  Future<Result<PaymentReceipt>> charge({
    required double amount,
    required String methodLabel,
    required String description,
  }) async {
    if (amount <= 0) return const Err('There is nothing to pay');

    await Future<void>.delayed(Duration(milliseconds: 900 + _random.nextInt(700)));

    if (failureRate > 0 && _random.nextDouble() < failureRate) {
      return const Err('Your payment was declined. Try a different method.');
    }

    return Ok(PaymentReceipt(
      reference: 'GTHR-${_uuid.v4().substring(0, 8).toUpperCase()}',
      amount: amount,
      methodLabel: methodLabel,
      paidAt: DateTime.now(),
    ));
  }
}

/// Saved payment methods (FR28 settings, FR15 checkout).
class PaymentService {
  PaymentService({required this.refs, required this.gateway});

  final FirestoreRefs refs;
  final PaymentGateway gateway;
  static const _uuid = Uuid();

  Stream<List<SavedPaymentMethod>> watchMethods(String uid) => refs
      .paymentMethods(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => SavedPaymentMethod.fromMap(d.id, d.data())).toList());

  Future<List<SavedPaymentMethod>> fetchMethods(String uid) async {
    final snapshot = await refs.paymentMethods(uid).get();
    return snapshot.docs.map((d) => SavedPaymentMethod.fromMap(d.id, d.data())).toList();
  }

  /// Stores a card as brand + last four only. The number entered by the user
  /// is validated, used to derive those two fields, and then dropped.
  Future<Result<SavedPaymentMethod>> addCard({
    required String uid,
    required String number,
    required String holderName,
    required int expiryMonth,
    required int expiryYear,
    required String cvv,
    bool makeDefault = false,
  }) async {
    final digits = number.replaceAll(RegExp(r'\s'), '');

    final numberError = validateCardNumber(digits);
    if (numberError != null) return Err(numberError);
    final expiryError = validateExpiry(expiryMonth, expiryYear);
    if (expiryError != null) return Err(expiryError);
    if (cvv.length < 3 || cvv.length > 4 || int.tryParse(cvv) == null) {
      return const Err('Enter the 3 or 4 digit security code');
    }
    if (holderName.trim().length < 2) return const Err('Enter the name on the card');

    try {
      final existing = await fetchMethods(uid);
      final id = _uuid.v4();
      final method = SavedPaymentMethod(
        id: id,
        type: PaymentMethodType.card,
        brand: brandOf(digits),
        last4: digits.substring(digits.length - 4),
        holderName: holderName.trim(),
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        isDefault: makeDefault || existing.isEmpty,
      );

      final batch = refs.db.batch();
      if (method.isDefault) {
        for (final other in existing.where((m) => m.isDefault)) {
          batch.update(refs.paymentMethods(uid).doc(other.id), {'isDefault': false});
        }
      }
      batch.set(refs.paymentMethods(uid).doc(id), method.toMap());
      await batch.commit();
      return Ok(method);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not save that card');
    }
  }

  /// Adds a non-card method (Apple Pay, STC Pay, cash on delivery).
  Future<Result<SavedPaymentMethod>> addWallet({
    required String uid,
    required PaymentMethodType type,
  }) async {
    try {
      final existing = await fetchMethods(uid);
      if (existing.any((m) => m.type == type)) {
        return Err('${type.label} is already set up');
      }
      final id = _uuid.v4();
      final method = SavedPaymentMethod(id: id, type: type, isDefault: existing.isEmpty);
      await refs.paymentMethods(uid).doc(id).set(method.toMap());
      return Ok(method);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not add that payment method');
    }
  }

  Future<void> setDefault(String uid, String methodId) async {
    final existing = await fetchMethods(uid);
    final batch = refs.db.batch();
    for (final m in existing) {
      batch.update(refs.paymentMethods(uid).doc(m.id), {'isDefault': m.id == methodId});
    }
    await batch.commit();
  }

  Future<void> removeMethod(String uid, String methodId) =>
      refs.paymentMethods(uid).doc(methodId).delete();

  Future<Result<PaymentReceipt>> pay({
    required double amount,
    required SavedPaymentMethod method,
    required String description,
  }) {
    if (method.isExpired) {
      return Future.value(const Err('That card has expired. Add a new one.'));
    }
    return gateway.charge(amount: amount, methodLabel: method.label, description: description);
  }

  // ------------------------------------------------------------ validation --

  static String? validateCardNumber(String digits) {
    if (digits.isEmpty) return 'Enter your card number';
    if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return 'Card numbers contain digits only';
    if (digits.length < 13 || digits.length > 19) return 'That card number looks incomplete';
    if (!passesLuhn(digits)) return 'That card number is not valid';
    return null;
  }

  static String? validateExpiry(int month, int year) {
    if (month < 1 || month > 12) return 'Enter a month between 01 and 12';
    final fullYear = year < 100 ? 2000 + year : year;
    final now = DateTime.now();
    final endOfMonth = DateTime(fullYear, month + 1, 0, 23, 59);
    if (endOfMonth.isBefore(now)) return 'That card has already expired';
    if (fullYear > now.year + 20) return 'Check the expiry year';
    return null;
  }

  /// The Luhn checksum every real card number satisfies.
  static bool passesLuhn(String digits) {
    var sum = 0;
    var shouldDouble = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var digit = digits.codeUnitAt(i) - 48;
      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      shouldDouble = !shouldDouble;
    }
    return sum % 10 == 0;
  }

  static String brandOf(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (RegExp(r'^5[1-5]').hasMatch(digits)) return 'Mastercard';
    if (RegExp(r'^2(2[2-9]|[3-6]|7[01]|720)').hasMatch(digits)) return 'Mastercard';
    if (RegExp(r'^3[47]').hasMatch(digits)) return 'Amex';
    if (RegExp(r'^9682').hasMatch(digits)) return 'Mada';
    if (RegExp(r'^6(011|5)').hasMatch(digits)) return 'Discover';
    return 'Card';
  }

  /// "4242 4242 4242 4242" — grouping for the card input field.
  static String formatCardNumber(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
