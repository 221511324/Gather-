import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/payment_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 3 — payment management, TC_P_001 to TC_P_010.
///
/// US20  As an administrator, I want to manage the payment methods the
///       platform accepts, so that a new one can be offered without the app
///       being rebuilt.
///
/// TC_P_001 to TC_P_008 cover US20 itself. TC_P_009 and TC_P_010 cover the
/// customer entering a card, which belongs to US10 (group payment) and is
/// re-checked here because the payment work touched it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  const password = 'TestPass123!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final customerEmail = 's3cust$stamp@gather-test.local';

  late ProviderContainer c;
  late PaymentService pay;
  late String customerUid;
  final created = <String>[];

  Future<String> signIn(String email, String pw) async {
    await FirebaseAuth.instance.signOut();
    final cred = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: pw);
    return cred.user!.uid;
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    c = ProviderContainer();
    pay = c.read(paymentServiceProvider);

    await signIn(adminEmail, adminPassword);
    final reg = await c.read(authServiceProvider).signUp(
        fullName: 'Test Customer', username: 'cust$stamp', email: customerEmail,
        phone: '+96657${stamp % 100000}', password: password);
    expect(reg.isSuccess, isTrue, reason: reg.errorOrNull ?? '');
    customerUid = reg.valueOrNull!.uid;
  });

  tearDownAll(() async {
    await signIn(adminEmail, adminPassword);
    for (final id in created) {
      await pay.deleteOption(id);
    }
    c.dispose();
  });

  // ---------------------------------------------- US20, the administrator ---

  testWidgets('TC_P_001 An administrator can add a new payment method', (t) async {
    await signIn(adminEmail, adminPassword);
    final r = await pay.upsertOption(
        const PaymentOption(id: '', name: 'PayPal', description: 'Pay with PayPal'));
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    created.add(r.valueOrNull!.id);

    final all = await pay.fetchOptions();
    expect(all.map((o) => o.name), contains('PayPal'));
    debugPrint('TC_P_001 PASS added PayPal, ${all.length} methods now');
  });

  testWidgets('TC_P_002 The same method cannot be added twice', (t) async {
    final r = await pay.upsertOption(const PaymentOption(id: '', name: 'paypal'));
    expect(r.isSuccess, isFalse, reason: 'a duplicate name must be refused');
    expect(r.errorOrNull, contains('already'));
    debugPrint('TC_P_002 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_P_003 A method must have a name', (t) async {
    final r = await pay.upsertOption(const PaymentOption(id: '', name: ' '));
    expect(r.isSuccess, isFalse);
    debugPrint('TC_P_003 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_P_004 An administrator can rename a payment method', (t) async {
    final id = created.first;
    final r = await pay.upsertOption(PaymentOption(id: id, name: 'PayPal Checkout'));
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    final all = await pay.fetchOptions();
    expect(all.firstWhere((o) => o.id == id).name, 'PayPal Checkout');
    await pay.upsertOption(PaymentOption(id: id, name: 'PayPal'));
    debugPrint('TC_P_004 PASS renamed and restored');
  });

  testWidgets('TC_P_005 Hiding a method removes it from the customer list', (t) async {
    final id = created.first;
    expect((await pay.setOptionEnabled(id, false)).isSuccess, isTrue);

    final visible = await pay.watchEnabledOptions().first;
    expect(visible.map((o) => o.name), isNot(contains('PayPal')),
        reason: 'a hidden method must not be offered');
    final adminSees = await pay.fetchOptions();
    expect(adminSees.map((o) => o.name), contains('PayPal'),
        reason: 'but the administrator must still see it');

    expect((await pay.setOptionEnabled(id, true)).isSuccess, isTrue);
    debugPrint('TC_P_005 PASS hidden from customers, still listed for admin');
  });

  // ------------------------- US20, what the customer is offered as a result ---

  testWidgets('TC_P_006 A customer can set up a method the admin added', (t) async {
    customerUid = await signIn(customerEmail, password);
    final options = await pay.watchEnabledOptions().first;
    final paypal = options.firstWhere((o) => o.name == 'PayPal');

    final r = await pay.addOption(uid: customerUid, option: paypal);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    expect(r.valueOrNull!.label, 'PayPal');

    final saved = await pay.fetchMethods(customerUid);
    expect(saved.map((m) => m.label), contains('PayPal'));
    debugPrint('TC_P_006 PASS customer saved PayPal');
  });

  testWidgets('TC_P_007 The same method cannot be set up twice', (t) async {
    final options = await pay.watchEnabledOptions().first;
    final paypal = options.firstWhere((o) => o.name == 'PayPal');
    final r = await pay.addOption(uid: customerUid, option: paypal);
    expect(r.isSuccess, isFalse);
    expect(r.errorOrNull, contains('already'));
    debugPrint('TC_P_007 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_P_008 A customer cannot change what the platform offers', (t) async {
    customerUid = await signIn(customerEmail, password);
    final r = await pay.upsertOption(
        const PaymentOption(id: '', name: 'Free money'));
    expect(r.isSuccess, isFalse,
        reason: 'only an administrator may add a payment method');

    final all = await pay.fetchOptions();
    expect(all.map((o) => o.name), isNot(contains('Free money')));
    debugPrint('TC_P_008 PASS refused="${r.errorOrNull}"');
  });

  // ------------------------------------------ US10, entering a card to pay ---

  testWidgets('TC_P_009 A valid card is accepted and stored safely', (t) async {
    customerUid = await signIn(customerEmail, password);
    final r = await pay.addCard(
        uid: customerUid, number: '4242 4242 4242 4242',
        holderName: 'TEST CUSTOMER', expiryMonth: 12, expiryYear: 29, cvv: '123');
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final card = r.valueOrNull!;
    expect(card.last4, '4242');
    expect(card.brand, 'Visa');
    expect(card.expiryLabel, '12/29');

    // The full number must never reach the database.
    final raw = await c.read(firestoreRefsProvider)
        .paymentMethods(customerUid).doc(card.id).get();
    expect(raw.data().toString(), isNot(contains('4242424242424242')));
    debugPrint('TC_P_009 PASS stored "${card.label}" expiry ${card.expiryLabel}');
  });

  testWidgets('TC_P_010 A bad card is refused with a clear reason', (t) async {
    for (final (what, number, month, year, cvv) in [
      ('fails the checksum', '1234 5678 9012 3456', 12, 29, '123'),
      ('already expired',    '4242 4242 4242 4242',  1, 20, '123'),
      ('impossible month',   '4242 4242 4242 4242', 13, 29, '123'),
      ('short security code','4242 4242 4242 4242', 12, 29, '1'),
    ]) {
      final r = await pay.addCard(
          uid: customerUid, number: number, holderName: 'TEST CUSTOMER',
          expiryMonth: month, expiryYear: year, cvv: cvv);
      expect(r.isSuccess, isFalse, reason: 'must refuse a card that $what');
      debugPrint('TC_P_010   $what -> "${r.errorOrNull}"');
    }
    debugPrint('TC_P_010 PASS all four refused');
  });
}
