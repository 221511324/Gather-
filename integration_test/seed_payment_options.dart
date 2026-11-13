import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// Seeds the payment methods the platform offered before they were
/// administrator-managed, so nothing a customer already had disappears.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('seed options', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final pay = c.read(paymentServiceProvider);

    const defaults = [
      ('Card', 'Visa, Mastercard or Mada', 10),
      ('Apple Pay', 'Pay with the card in your Apple Wallet', 20),
      ('STC Pay', 'Pay from your STC Pay balance', 30),
    ];
    for (final (name, description, order) in defaults) {
      final r = await pay.upsertOption(PaymentOption(
          id: '', name: name, description: description, sortOrder: order));
      debugPrint('SEEDOPT $name ${r.isSuccess ? 'ok' : r.errorOrNull}');
    }

    final all = await pay.fetchOptions();
    for (final o in all) {
      debugPrint('  OPTION ${o.name} enabled=${o.isEnabled} order=${o.sortOrder}');
    }
    expect(all.length, greaterThanOrEqualTo(3));
    debugPrint('SEEDOPT-COMPLETE ${all.length}');
  });
}
