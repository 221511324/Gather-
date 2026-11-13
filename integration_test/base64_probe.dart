import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/firebase_options.dart';

/// Measures whether photographs can live in Firestore as base64 instead of
/// Firebase Storage, which needs a paid plan.
///
/// Not a test of the product — a measurement, so the decision is made on real
/// numbers from the real project rather than on remembered limits.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('probe', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    final db = FirebaseFirestore.instance;
    final probe = db.collection('users').doc(cred.user!.uid).collection('aiChat');

    // 1 — a real image, round-tripped.
    for (final asset in ['assets/images/logo.jpeg', 'assets/images/logo.png']) {
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      final encoded = base64Encode(bytes);
      final doc = probe.doc('_probe_${asset.hashCode}');
      final started = DateTime.now();
      try {
        await doc.set({'_reserved': true, 'b64': encoded});
        final back = await doc.get(const GetOptions(source: Source.server));
        final ok = back.data()!['b64'] == encoded;
        final ms = DateTime.now().difference(started).inMilliseconds;
        debugPrint('PROBE $asset raw=${bytes.length}B '
            'base64=${encoded.length}B overhead='
            '${((encoded.length / bytes.length - 1) * 100).toStringAsFixed(1)}% '
            'roundTrip=${ok ? 'identical' : 'CORRUPT'} ${ms}ms');
        await doc.delete();
      } catch (e) {
        debugPrint('PROBE $asset FAILED ${e.toString().split('\n').first}');
      }
    }

    // 2 — where does Firestore actually refuse? Walk the payload up.
    final rnd = Random(7);
    for (final rawKb in [100, 250, 500, 700, 780, 800, 1000]) {
      final raw = Uint8List.fromList(
          List.generate(rawKb * 1024, (_) => rnd.nextInt(256)));
      final encoded = base64Encode(raw);
      final doc = probe.doc('_probe_size');
      try {
        await doc.set({'_reserved': true, 'b64': encoded});
        debugPrint('SIZE raw=${rawKb}KB base64=${(encoded.length / 1024).round()}KB  ACCEPTED');
        await doc.delete();
      } catch (e) {
        final msg = e.toString().split('\n').first;
        debugPrint('SIZE raw=${rawKb}KB base64=${(encoded.length / 1024).round()}KB  '
            'REFUSED: ${msg.length > 90 ? msg.substring(0, 90) : msg}');
      }
    }
    debugPrint('PROBE-COMPLETE');
  });
}
