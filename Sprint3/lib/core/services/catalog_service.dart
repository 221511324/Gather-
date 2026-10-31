import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/restaurant.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// Restaurant and menu reads (FR3), favourites (FR23) and the admin writes
/// behind the catalogue manager (FR31).
class CatalogService {
  CatalogService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();

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

  // ------------------------------------------------------------ favourites --

  Future<void> toggleFavoriteRestaurant(String uid, String restaurantId, bool isFavorite) =>
      refs.user(uid).update({
        'favoriteRestaurantIds':
            isFavorite ? FieldValue.arrayUnion([restaurantId]) : FieldValue.arrayRemove([restaurantId]),
      });

  Future<void> toggleFavoriteItem(String uid, String itemId, bool isFavorite) =>
      refs.user(uid).update({
        'favoriteItemIds':
            isFavorite ? FieldValue.arrayUnion([itemId]) : FieldValue.arrayRemove([itemId]),
      });

  // ------------------------------------------------------- admin (FR31) ---

  Future<Result<Restaurant>> upsertRestaurant(Restaurant restaurant) async {
    final name = restaurant.name.trim();
    final cuisine = restaurant.cuisine.trim();
    if (name.isEmpty) return const Err('Give the restaurant a name');
    if (cuisine.isEmpty) return const Err('Say what kind of food it serves');
    if (restaurant.rating < 0 || restaurant.rating > 5) {
      return const Err('A rating must be between 0 and 5');
    }
    if (restaurant.ratingCount < 0) return const Err('The rating count cannot be negative');
    if (restaurant.deliveryFee < 0) return const Err('The delivery fee cannot be negative');
    if (restaurant.deliveryMinutes <= 0) {
      return const Err('Delivery time must be at least one minute');
    }
    if (restaurant.minimumOrder < 0) return const Err('The minimum order cannot be negative');
    if (restaurant.priceLevel < 1 || restaurant.priceLevel > 3) {
      return const Err('Price level runs from 1 to 3');
    }

    try {
      // New restaurants get a slug rather than a UUID so the document id that
      // ends up in shared links (/restaurant/burger-barn) stays readable.
      final id = restaurant.id.isEmpty ? await _freeSlug(slugify(name)) : restaurant.id;
      final saved = Restaurant(
        id: id,
        name: name,
        cuisine: cuisine,
        imageUrl: restaurant.imageUrl.trim(),
        description: restaurant.description.trim(),
        rating: restaurant.rating,
        ratingCount: restaurant.ratingCount,
        deliveryFee: restaurant.deliveryFee,
        deliveryMinutes: restaurant.deliveryMinutes,
        minimumOrder: restaurant.minimumOrder,
        tags: restaurant.tags,
        isOpen: restaurant.isOpen,
        priceLevel: restaurant.priceLevel,
      );
      await refs.restaurant(id).set(saved.toMap());
      return Ok(saved);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not save that restaurant');
    }
  }

  Future<Result<void>> deleteRestaurant(String id) async {
    try {
      // Firestore does not cascade. Deleting only the parent would leave the
      // menu documents behind, and they would still answer the collection
      // group query the home feed and search run — so the items and their
      // restaurant go in one batch, which also keeps it all-or-nothing.
      // A menu is far below the 500-write batch limit in practice.
      final items = await refs.menu(id).get();
      final batch = refs.db.batch();
      for (final doc in items.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(refs.restaurant(id));
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not delete that restaurant');
    }
  }

  Future<Result<void>> setRestaurantOpen(String id, bool isOpen) async {
    try {
      await refs.restaurant(id).update({'isOpen': isOpen});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that restaurant');
    }
  }

  Future<Result<MenuItem>> upsertMenuItem(MenuItem item) async {
    final name = item.name.trim();
    if (name.isEmpty) return const Err('Give the item a name');
    if (item.price <= 0) return const Err('Enter a price greater than zero');
    if (item.restaurantId.isEmpty) return const Err('This item has no restaurant');

    try {
      final id = item.id.isEmpty ? _uuid.v4() : item.id;
      final saved = MenuItem(
        id: id,
        restaurantId: item.restaurantId,
        name: name,
        price: item.price,
        imageUrl: item.imageUrl.trim(),
        category: item.category,
        description: item.description.trim(),
        optionGroups: item.optionGroups,
        rating: item.rating,
        isAvailable: item.isAvailable,
        isBestSeller: item.isBestSeller,
        calories: item.calories,
      );
      // A full overwrite, not a merge: `toMap` omits calories when it is null,
      // so merging would silently keep a figure the admin just cleared.
      await refs.menu(item.restaurantId).doc(id).set(saved.toMap());
      return Ok(saved);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not save that menu item');
    }
  }

  Future<Result<void>> deleteMenuItem(String restaurantId, String itemId) async {
    try {
      await refs.menu(restaurantId).doc(itemId).delete();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not delete that menu item');
    }
  }

  Future<Result<void>> setItemAvailable(
    String restaurantId,
    String itemId,
    bool isAvailable,
  ) async {
    try {
      await refs.menu(restaurantId).doc(itemId).update({'isAvailable': isAvailable});
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not update that menu item');
    }
  }

  /// `Burger Barn & Co.` becomes `burger-barn-co`.
  static String slugify(String name) => name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Two restaurants with the same name would otherwise share a slug and
  /// overwrite each other, so a taken one is suffixed `-2`, `-3` and so on.
  Future<String> _freeSlug(String base) async {
    final root = base.isEmpty ? _uuid.v4() : base;
    var candidate = root;
    var suffix = 1;
    while ((await refs.restaurant(candidate).get()).exists) {
      suffix++;
      candidate = '$root-$suffix';
    }
    return candidate;
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
