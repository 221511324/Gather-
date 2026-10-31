import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/firebase_options.dart';

/// Fills the collections the demo account leaves empty, through the real
/// services, so every implemented collection has data to show.
///
/// Only touches collections the app itself writes. It does not invent a
/// `vouchers` document: nothing in Sprint 2 reads or writes one, and seeding
/// a collection no code uses would put a feature in the database that does
/// not exist in the build.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fill', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    final uid = cred.user!.uid;
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // 1 — saved payment methods.
    final pay = c.read(paymentServiceProvider);
    final hasMethods = await pay.fetchMethods(uid);
    if (hasMethods.isEmpty) {
      final card = await pay.addCard(
        uid: uid, number: '4242 4242 4242 4242', holderName: 'Gather Admin',
        expiryMonth: 11, expiryYear: 2029, cvv: '123', makeDefault: true);
      debugPrint('FILL card ${card.isSuccess ? 'ok' : card.errorOrNull}');
      for (final name in ['Apple Pay', 'STC Pay']) {
        final r = await pay.addOption(
            uid: uid, option: PaymentOption(id: '', name: name));
        debugPrint('FILL $name ${r.isSuccess ? 'ok' : r.errorOrNull}');
      }
    } else {
      debugPrint('FILL paymentMethods already ${hasMethods.length}');
    }

    // 2 — a personal cart.
    final cart = c.read(cartServiceProvider);
    final catalog = c.read(catalogServiceProvider);
    if ((await cart.fetch(uid)).isEmpty) {
      final rests = await catalog.fetchRestaurants();
      final menu = await catalog.fetchMenu(rests.first.id);
      for (final item in menu.take(2)) {
        await cart.add(uid, item, quantity: 1);
        debugPrint('FILL cart + ${item.name}');
      }
    } else {
      debugPrint('FILL cart already has lines');
    }

    // 3 — a saved group, built from a real session.
    final sessions = c.read(sessionServiceProvider);
    final saved = await sessions.watchSavedSessions(uid).first;
    if (saved.isEmpty) {
      final me = await c.read(authServiceProvider).loadProfile(uid);
      final made = await sessions.createSession(host: me!, name: 'Team lunch');
      if (made.isSuccess) {
        final r = await sessions.saveAsGroup(
            session: made.valueOrNull!, ownerId: uid, name: 'Team lunch');
        debugPrint('FILL savedSession ${r.isSuccess ? 'ok' : r.errorOrNull}');
        await sessions.cancel(made.valueOrNull!.id);
      }
    } else {
      debugPrint('FILL savedSessions already ${saved.length}');
    }

    debugPrint('FILL-COMPLETE');
  });
}
