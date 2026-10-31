import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/payment_method.dart';
import '../models/payment_option.dart';
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

  /// Type names this build still understands.
  ///
  /// Cash on delivery was removed, but a document written before that is
  /// still sitting in whichever accounts had one, and the rules deliberately
  /// stop an administrator reading another person's saved methods — so it
  /// cannot be cleaned up centrally. An unknown type would otherwise parse
  /// back to `card` and draw an empty "  •••• " row, so it is dropped on
  /// read instead and the account simply stops showing it.
  static bool _isKnown(Map<String, dynamic> data) =>
      PaymentMethodType.values.any((t) => t.name == data['type']);

  List<SavedPaymentMethod> _parse(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) =>
      docs
          .where((d) => _isKnown(d.data()))
          .map((d) => SavedPaymentMethod.fromMap(d.id, d.data()))
          .toList();

  Stream<List<SavedPaymentMethod>> watchMethods(String uid) =>
      refs.paymentMethods(uid).snapshots().map((s) => _parse(s.docs));

  Future<List<SavedPaymentMethod>> fetchMethods(String uid) async =>
      _parse((await refs.paymentMethods(uid).get()).docs);

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
      const probe = SavedPaymentMethod(id: '', type: PaymentMethodType.card);
      if (!isUsable(probe, await fetchOptions())) {
        return const Err('Cards are not accepted right now');
      }
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

  /// The enum a configured option maps onto, so a known wallet keeps its own
  /// icon and anything the administrator invents still has somewhere to sit.
  static PaymentMethodType typeForOption(String name) => switch (name.toLowerCase()) {
        'apple pay' => PaymentMethodType.applePay,
        'stc pay' => PaymentMethodType.stcPay,
        'card' || 'credit card' || 'debit card' => PaymentMethodType.card,
        _ => PaymentMethodType.other,
      };

  /// Sets up one of the options the administrator offers — Apple Pay, STC Pay,
  /// PayPal, whatever is on the list.
  Future<Result<SavedPaymentMethod>> addOption({
    required String uid,
    required PaymentOption option,
  }) async {
    if (!option.isEnabled) {
      return const Err('That payment method is currently unavailable. Choose another one.');
    }
    try {
      final existing = await fetchMethods(uid);
      if (existing.any((m) => m.label.toLowerCase() == option.name.toLowerCase())) {
        return Err('${option.name} is already set up');
      }
      final id = _uuid.v4();
      final method = SavedPaymentMethod(
        id: id,
        type: typeForOption(option.name),
        optionName: option.name,
        optionId: option.id,
        isDefault: existing.isEmpty,
      );
      await refs.paymentMethods(uid).doc(id).set(method.toMap());
      return Ok(method);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not add that payment method');
    }
  }

  /// Firebase's own wording for a refused write is "PERMISSION_DENIED:
  /// Missing or insufficient permissions", which means nothing to the person
  /// reading it. Everything else keeps the gateway's message.
  static String _readable(FirebaseException e, String fallback) =>
      e.code == 'permission-denied'
          ? 'You do not have permission to do that'
          : e.message ?? fallback;

  // --------------------------------------------------- payment options ---
  // What the platform offers, as opposed to what one person has saved.

  /// The configured option a saved method belongs to: by id when it was
  /// recorded, then by the option name it was saved under, then — for cards
  /// and wallets saved before options were managed — by type. When several
  /// options share a type, an enabled one wins.
  static PaymentOption? optionFor(SavedPaymentMethod method, List<PaymentOption> catalog) {
    if (method.optionId.isNotEmpty) {
      for (final o in catalog) {
        if (o.id == method.optionId) return o;
      }
    }
    if (method.optionName.isNotEmpty) {
      final name = method.optionName.toLowerCase();
      for (final o in catalog) {
        if (o.name.toLowerCase() == name) return o;
      }
    }
    if (method.type == PaymentMethodType.other) return null;
    final sameType = catalog.where((o) => typeForOption(o.name) == method.type);
    return sameType.where((o) => o.isEnabled).firstOrNull ?? sameType.firstOrNull;
  }

  /// Whether a saved method may be used to pay given the full option list
  /// (enabled and disabled). A method whose option is switched off — or no
  /// longer exists — stays on the account but cannot be charged.
  ///
  /// An empty list means the platform has not configured any options yet,
  /// which is how every account behaved before they were administrator-managed,
  /// so nothing is blocked then.
  static bool isUsable(SavedPaymentMethod method, List<PaymentOption> catalog) {
    if (catalog.isEmpty) return true;
    return optionFor(method, catalog)?.isEnabled ?? false;
  }

  /// The methods from [methods] that [isUsable] allows, in the same order.
  static List<SavedPaymentMethod> usableMethods(
    List<SavedPaymentMethod> methods,
    List<PaymentOption> catalog,
  ) =>
      methods.where((m) => isUsable(m, catalog)).toList();

  /// Which method to pay with when the person has not picked one: their
  /// default if it is still usable, otherwise the first usable card or wallet
  /// that has not expired. Null means there is nothing to pay with.
  static SavedPaymentMethod? defaultMethod(List<SavedPaymentMethod> usable) {
    if (usable.isEmpty) return null;
    for (final m in usable) {
      if (m.isDefault) return m;
    }
    for (final m in usable) {
      if (!m.isExpired) return m;
    }
    return null;
  }

  /// The enabled options in the order a customer should see them: cards
  /// first, because that is what most people reach for, then the rest in the
  /// administrator's order.
  static List<PaymentOption> offeredOptions(List<PaymentOption> enabled) {
    final cards = enabled.where((o) => typeForOption(o.name) == PaymentMethodType.card);
    final rest = enabled.where((o) => typeForOption(o.name) != PaymentMethodType.card);
    return [...cards, ...rest];
  }

  /// Everything the administrator has configured, in display order.
  Stream<List<PaymentOption>> watchOptions() => refs.paymentOptions
      .orderBy('sortOrder')
      .snapshots()
      .map((s) => s.docs.map((d) => PaymentOption.fromMap(d.id, d.data())).toList());

  /// Only the ones a customer may actually choose.
  Stream<List<PaymentOption>> watchEnabledOptions() =>
      watchOptions().map((all) => all.where((o) => o.isEnabled).toList());

  Future<List<PaymentOption>> fetchOptions() async {
    final snapshot = await refs.paymentOptions.orderBy('sortOrder').get();
    return snapshot.docs.map((d) => PaymentOption.fromMap(d.id, d.data())).toList();
  }

  /// Creates or updates an option. The name must be unique, case-insensitively,
  /// so the customer is never offered "PayPal" twice.
  Future<Result<PaymentOption>> upsertOption(PaymentOption option) async {
    final name = option.name.trim();
    if (name.length < 2) return const Err('Enter a name for the payment method');
    try {
      final existing = await fetchOptions();
      final clash = existing.any(
          (o) => o.id != option.id && o.name.toLowerCase() == name.toLowerCase());
      if (clash) return Err('$name is already on the list');

      final isNew = option.id.isEmpty;
      final id = isNew ? _uuid.v4() : option.id;
      final saved = option.copyWith(name: name);
      await refs.paymentOption(id).set({
        ...saved.toMap(),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return Ok(PaymentOption(
        id: id,
        name: name,
        description: saved.description,
        isEnabled: saved.isEnabled,
        sortOrder: saved.sortOrder,
        createdAt: saved.createdAt,
      ));
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not save that payment method'));
    }
  }

  Future<Result<void>> setOptionEnabled(String id, bool enabled) async {
    try {
      await refs.paymentOption(id).update({'isEnabled': enabled});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not change that payment method'));
    }
  }

  Future<Result<void>> deleteOption(String id) async {
    try {
      await refs.paymentOption(id).delete();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not remove that payment method'));
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

  /// Charges [method]. The screens only offer usable methods, but the option
  /// list is checked again here so a method the administrator switched off a
  /// moment ago — while the checkout was already open — is never charged.
  Future<Result<PaymentReceipt>> pay({
    required double amount,
    required SavedPaymentMethod method,
    required String description,
  }) async {
    if (method.isExpired) return const Err('That card has expired. Add a new one.');
    try {
      if (!isUsable(method, await fetchOptions())) {
        return const Err('That payment method is currently unavailable. Choose another one.');
      }
    } on FirebaseException {
      return const Err('Could not check that payment method. Try again.');
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
