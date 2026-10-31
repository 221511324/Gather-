import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/firebase_options.dart';

/// Creates one structure document in each collection that is reserved for
/// Sprint 3, so the collection is visible in the Firebase console and the
/// schema can be shown before the feature exists.
///
/// Firestore has no empty collections — a collection appears only while it
/// holds at least one document — so showing the shape requires writing one.
/// Each is given the id `_schema` and carries `_reserved: true`, so it sorts
/// to the top, reads as structure rather than data, and cannot be mistaken
/// for a real voucher or notification. Nothing in the app reads these
/// documents, so nothing is displayed anywhere.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reserve', (t) async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'admin@gather.app', password: 'GatherAdmin2026!');
    final uid = cred.user!.uid;
    final db = FirebaseFirestore.instance;

    Map<String, dynamic> marker(String what) => {
          '_reserved': true,
          '_sprint': 3,
          '_note': 'Structure only. $what is not implemented in Sprint 2 — no '
              'code reads or writes this collection yet, so nothing is shown '
              'in the app. The fields below are the shape it will hold.',
          '_createdAt': FieldValue.serverTimestamp(),
        };

    // 1 — the reward catalogue an administrator will manage.
    await db.collection('vouchers').doc('_schema').set({
      ...marker('The reward catalogue'),
      'code': '',
      'title': '',
      'description': '',
      'discountType': '',       // percentage | fixedAmount | freeDelivery
      'discountValue': 0,
      'minimumOrder': 0,
      'maxRedemptions': 0,
      'redeemedCount': 0,
      'validFrom': null,
      'validUntil': null,
      'isActive': false,
    });
    debugPrint('RESERVE vouchers/_schema');

    // 2 — a reward held by one person.
    await db.collection('users').doc(uid).collection('vouchers').doc('_schema').set({
      ...marker('Rewards a user holds'),
      'voucherId': '',
      'code': '',
      'title': '',
      'discountType': '',
      'discountValue': 0,
      'status': '',             // available | used | expired
      'grantedAt': null,
      'expiresAt': null,
      'redeemedAt': null,
      'orderId': null,
    });
    debugPrint('RESERVE users/$uid/vouchers/_schema');

    // 3 — the notification centre.
    await db.collection('users').doc(uid).collection('notifications').doc('_schema').set({
      ...marker('The notification centre'),
      'title': '',
      'body': '',
      'type': '',               // orderUpdate | groupInvite | promotion
      'orderId': null,
      'sessionId': null,
      'read': false,
      'createdAt': null,
    });
    debugPrint('RESERVE users/$uid/notifications/_schema');

    // 4 — the assistant transcript.
    await db.collection('users').doc(uid).collection('aiChat').doc('_schema').set({
      ...marker('The assistant'),
      'role': '',               // user | assistant
      'text': '',
      'createdAt': null,
    });
    debugPrint('RESERVE users/$uid/aiChat/_schema');

    // Confirm each is readable back, so the console will show them.
    for (final p in ['vouchers/_schema', 'users/$uid/vouchers/_schema',
                     'users/$uid/notifications/_schema', 'users/$uid/aiChat/_schema']) {
      final d = await db.doc(p).get();
      expect(d.exists, isTrue, reason: p);
      expect(d.data()!['_reserved'], isTrue, reason: p);
    }
    debugPrint('RESERVE-COMPLETE adminUid=$uid');
  });
}
