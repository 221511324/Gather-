import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_line.dart';
import '../models/restaurant.dart';
import 'firestore_refs.dart';

/// The personal cart used for individual orders (FR4, FR5, FR11).
///
/// Lines live under `users/{uid}/cart` so they survive app restarts and follow
/// the user across devices.
class CartService {
  CartService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();

  Stream<List<CartLine>> watch(String uid) =>
      refs.cart(uid).orderBy('addedAt').snapshots().map(_mapLines);

  Future<List<CartLine>> fetch(String uid) async {
    final snapshot = await refs.cart(uid).orderBy('addedAt').get();
    return _mapLines(snapshot);
  }

  static List<CartLine> _mapLines(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => CartLine.fromMap(d.id, d.data())).toList();

  /// Adds an item, merging into an existing line when the item, its
  /// customizations and its note all match — otherwise the cart fills up with
  /// near-duplicate rows.
  Future<void> add(
    String uid,
    MenuItem item, {
    required int quantity,
    List<SelectedOption> options = const [],
    String note = '',
  }) async {
    final candidate = CartLine.fromMenuItem(
      item,
      id: _uuid.v4(),
      quantity: quantity,
      options: options,
      note: note,
      ownerId: uid,
    );

    final existing = await fetch(uid);
    for (final line in existing) {
      if (line.signature == candidate.signature) {
        await refs.cart(uid).doc(line.id).update({'quantity': line.quantity + quantity});
        return;
      }
    }
    await refs.cart(uid).doc(candidate.id).set({
      ...candidate.toMap(),
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setQuantity(String uid, String lineId, int quantity) {
    if (quantity <= 0) return remove(uid, lineId);
    return refs.cart(uid).doc(lineId).update({'quantity': quantity});
  }

  Future<void> updateLine(String uid, CartLine line) =>
      refs.cart(uid).doc(line.id).update(line.toMap());

  Future<void> remove(String uid, String lineId) => refs.cart(uid).doc(lineId).delete();

  Future<void> clear(String uid) async {
    final snapshot = await refs.cart(uid).get();
    if (snapshot.docs.isEmpty) return;
    final batch = refs.db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
