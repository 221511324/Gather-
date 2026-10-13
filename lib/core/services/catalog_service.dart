import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/restaurant.dart';
import 'firestore_refs.dart';

/// Restaurant and menu reads (FR3), favourites (FR23) and the admin writes
/// behind the catalogue manager (FR31).
class CatalogService {
  CatalogService(this.refs);

  final FirestoreRefs refs;

  Stream<List<Restaurant>> watchRestaurants() => refs.restaurants
      .orderBy('rating', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Restaurant.fromMap(d.id, d.data())).toList());

  Future<List<Restaurant>> fetchRestaurants() async {
    final snapshot = await refs.restaurants.orderBy('rating', descending: true).get();
    return snapshot.docs.map((d) => Restaurant.fromMap(d.id, d.data())).toList();
  }

  Stream<Restaurant?> watchRestaurant(String id) => refs
      .restaurant(id)
      .snapshots()
      .map((d) => d.exists ? Restaurant.fromMap(d.id, d.data() ?? {}) : null);

  Future<Restaurant?> fetchRestaurant(String id) async {
    final doc = await refs.restaurant(id).get();
    return doc.exists ? Restaurant.fromMap(doc.id, doc.data() ?? {}) : null;
  }

  Future<List<Restaurant>> fetchRestaurantsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    // whereIn takes at most 30 values, so long favourite lists are chunked.
    final results = <Restaurant>[];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snapshot = await refs.restaurants.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snapshot.docs.map((d) => Restaurant.fromMap(d.id, d.data())));
    }
    return results;
  }

  Stream<List<MenuItem>> watchMenu(String restaurantId) => refs
      .menu(restaurantId)
      .snapshots()
      .map((s) => s.docs.map((d) => MenuItem.fromMap(d.id, d.data())).toList());

  Future<List<MenuItem>> fetchMenu(String restaurantId) async {
    final snapshot = await refs.menu(restaurantId).get();
    return snapshot.docs.map((d) => MenuItem.fromMap(d.id, d.data())).toList();
  }

  Future<MenuItem?> fetchMenuItem(String restaurantId, String itemId) async {
    final doc = await refs.menu(restaurantId).doc(itemId).get();
    return doc.exists ? MenuItem.fromMap(doc.id, doc.data() ?? {}) : null;
  }

  /// Menu items across every restaurant, used by search, the home feed and
  /// the favourites screen. A collection-group query keeps this to one read
  /// instead of one per restaurant.
  Stream<List<MenuItem>> watchAllItems() => refs.db
      .collectionGroup('menu')
      .snapshots()
      .map((s) => s.docs.map((d) => MenuItem.fromMap(d.id, d.data())).toList());

  Future<List<MenuItem>> fetchAllItems() async {
    final snapshot = await refs.db.collectionGroup('menu').get();
    return snapshot.docs.map((d) => MenuItem.fromMap(d.id, d.data())).toList();
  }

}

/// In-memory search over the catalogue.
///
/// Firestore has no substring matching, and the catalogue is small enough to
/// hold client-side, so search filters the already-streamed lists. That also
/// keeps search instant as the user types.
abstract final class CatalogSearch {
  static List<Restaurant> restaurants(List<Restaurant> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((r) {
      return r.name.toLowerCase().contains(q) ||
          r.cuisine.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  static List<MenuItem> items(List<MenuItem> source, String query, {FoodCategory? category}) {
    final q = query.trim().toLowerCase();
    return source.where((i) {
      if (category != null && i.category != category) return false;
      if (q.isEmpty) return true;
      return i.name.toLowerCase().contains(q) || i.description.toLowerCase().contains(q);
    }).toList();
  }
}
