import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/firebase_options.dart';

/// Counts what is actually in the live database, collection by collection.
///
/// Not a test of behaviour — a census, so the database documentation reports
/// what is really there rather than what the code implies should be there.
///
/// Subcollections are read with a plain get() rather than an aggregate
/// count(): hundreds of count() calls in a row start failing part way through,
/// and a failed aggregate is indistinguishable from an empty collection, which
/// silently reported real data as zero.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('census', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: 'admin@gather.app', password: 'GatherAdmin2026!');
    final db = FirebaseFirestore.instance;
    var failures = 0;

    for (final name in [
      'users', 'usernames', 'sessionCodes', 'restaurants',
      'sessions', 'orders', 'vouchers', 'tickets', 'meta',
    ]) {
      final n = (await db.collection(name).get()).size;
      debugPrint('CENSUS $name=$n');
    }

    Future<void> sub(String parent, List<String> names, {int? cap}) async {
      final q = cap == null
          ? await db.collection(parent).get()
          : await db.collection(parent).limit(cap).get();
      final totals = {for (final n in names) n: 0};
      final holders = {for (final n in names) n: 0};
      for (final p in q.docs) {
        for (final n in names) {
          try {
            final s = await p.reference.collection(n).get();
            if (s.size > 0) { totals[n] = totals[n]! + s.size; holders[n] = holders[n]! + 1; }
          } catch (e) {
            failures++;
          }
        }
      }
      for (final n in names) {
        debugPrint('CENSUS $parent/*/$n=${totals[n]} across ${holders[n]} of ${q.docs.length}');
      }
    }

    await sub('users', ['cart', 'vouchers', 'savedSessions', 'paymentMethods',
                        'notifications', 'aiChat']);
    await sub('restaurants', ['menu']);
    await sub('sessions', ['lines'], cap: 110);

    debugPrint('CENSUS-FAILED-READS $failures');
    debugPrint('CENSUS-COMPLETE');
  });
}
