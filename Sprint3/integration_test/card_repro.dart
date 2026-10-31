import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/payment_service.dart';
import 'package:gather/firebase_options.dart';

/// Reproduces "adding a payment card does not work" against the real service,
/// with the inputs the screen actually sends it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('card inputs', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    final uid = cred.user!.uid;
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final pay = c.read(paymentServiceProvider);

    // Pure validation first — no network, so a failure here is a logic bug.
    for (final (label, num_) in [
      ('visa 16',        '4242 4242 4242 4242'),
      ('mastercard',     '5555 5555 5555 4444'),
      ('amex 15',        '3782 822463 10005'),
      ('made-up number', '1234 5678 9012 3456'),
      ('visa no spaces', '4242424242424242'),
    ]) {
      final digits = num_.replaceAll(RegExp(r'\s'), '');
      debugPrint('NUM $label -> ${PaymentService.validateCardNumber(digits) ?? "OK"} '
          '(brand ${PaymentService.brandOf(digits)})');
    }
    for (final (label, m, y) in [
      ('MM/YY 12/29', 12, 29), ('MM/YYYY 12/2029', 12, 2029),
      ('past 01/20', 1, 20),   ('month 0', 0, 29),
    ]) {
      debugPrint('EXP $label -> ${PaymentService.validateExpiry(m, y) ?? "OK"}');
    }

    // Then the real write, exactly as the screen calls it.
    final before = (await pay.fetchMethods(uid)).length;
    final r = await pay.addCard(
      uid: uid, number: '4242 4242 4242 4242', holderName: 'GATHER ADMIN',
      expiryMonth: 12, expiryYear: 29, cvv: '123');
    debugPrint('ADDCARD ${r.isSuccess ? "OK" : "ERR: ${r.errorOrNull}"}');
    final after = await pay.fetchMethods(uid);
    debugPrint('COUNT before=$before after=${after.length}');
    for (final m in after) {
      debugPrint('  METHOD ${m.type.name} "${m.label}" expiry="${m.expiryLabel}" '
          'expired=${m.isExpired} default=${m.isDefault}');
    }
    debugPrint('CARD-REPRO-COMPLETE');
  });
}
