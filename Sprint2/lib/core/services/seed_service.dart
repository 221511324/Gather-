import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_refs.dart';
import 'seed_data.dart';

/// Writes the starter catalogue into Firestore the first time the app runs
/// against an empty project.
///
/// A version marker in `meta/seed` makes this idempotent, so restarting the
/// app does not duplicate data and bumping [version] re-seeds after the
/// catalogue changes.
class SeedService {
  SeedService(this.refs);

  final FirestoreRefs refs;

  static const version = 3;

  Future<bool> seedIfNeeded() async {
    try {
      final marker = await refs.meta('seed').get();
      final current = marker.exists ? (marker.data() ?? {})['version'] : null;
      if (current is int && current >= version) return false;

      // Firestore batches cap at 500 writes; the catalogue is well inside that
      // but the counter keeps it honest if the seed data grows.
      var batch = refs.db.batch();
      var writes = 0;

      Future<void> flushIfFull() async {
        if (writes >= 400) {
          await batch.commit();
          batch = refs.db.batch();
          writes = 0;
        }
      }

      for (final restaurant in SeedCatalogue.restaurants()) {
        batch.set(refs.restaurant(restaurant.id), restaurant.toMap(), SetOptions(merge: true));
        writes++;
        await flushIfFull();
      }

      for (final item in SeedCatalogue.menu()) {
        batch.set(
          refs.menu(item.restaurantId).doc(item.id),
          item.toMap(),
          SetOptions(merge: true),
        );
        writes++;
        await flushIfFull();
      }

      batch.set(refs.meta('seed'), {
        'version': version,
        'seededAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return true;
    } on FirebaseException {
      // Seeding is best-effort: a locked-down rule set or an offline start
      // should never stop the app from launching.
      return false;
    }
  }
}
