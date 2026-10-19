import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../services/firestore_refs.dart';
import '../services/order_service.dart';
import '../services/payment_service.dart';
import '../services/seed_service.dart';
import '../services/session_service.dart';
import '../services/support_service.dart';

// ---------------------------------------------------------------- platform --

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final firestoreRefsProvider =
    Provider<FirestoreRefs>((ref) => FirestoreRefs(ref.watch(firestoreProvider)));

// ---------------------------------------------------------------- services --

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(auth: ref.watch(firebaseAuthProvider), refs: ref.watch(firestoreRefsProvider)),
);

final catalogServiceProvider =
    Provider<CatalogService>((ref) => CatalogService(ref.watch(firestoreRefsProvider)));

final cartServiceProvider =
    Provider<CartService>((ref) => CartService(ref.watch(firestoreRefsProvider)));

final sessionServiceProvider =
    Provider<SessionService>((ref) => SessionService(ref.watch(firestoreRefsProvider)));

final orderServiceProvider =
    Provider<OrderService>((ref) => OrderService(ref.watch(firestoreRefsProvider)));

final paymentGatewayProvider = Provider<PaymentGateway>((ref) => SimulatedPaymentGateway());

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(
    refs: ref.watch(firestoreRefsProvider),
    gateway: ref.watch(paymentGatewayProvider),
  ),
);

final supportServiceProvider =
    Provider<SupportService>((ref) => SupportService(ref.watch(firestoreRefsProvider)));

final adminServiceProvider =
    Provider<AdminService>((ref) => AdminService(ref.watch(firestoreRefsProvider)));

final seedServiceProvider =
    Provider<SeedService>((ref) => SeedService(ref.watch(firestoreRefsProvider)));

// -------------------------------------------------------------------- auth --

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// The signed-in user's profile, or null when signed out.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return ref.watch(authServiceProvider).watchProfile(auth.uid);
});

/// Convenience accessor for code paths that already know a user is present.
final currentUserOrNullProvider = Provider<AppUser?>(
  (ref) => ref.watch(currentUserProvider).valueOrNull,
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

final isAdminProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false,
);

// --------------------------------------------------------------- catalogue --

final restaurantsProvider = StreamProvider<List<Restaurant>>(
  (ref) => ref.watch(catalogServiceProvider).watchRestaurants(),
);

final allMenuItemsProvider = StreamProvider<List<MenuItem>>(
  (ref) => ref.watch(catalogServiceProvider).watchAllItems(),
);

final restaurantProvider = StreamProvider.autoDispose.family<Restaurant?, String>(
  (ref, id) => ref.watch(catalogServiceProvider).watchRestaurant(id),
);

final menuProvider = StreamProvider.autoDispose.family<List<MenuItem>, String>(
  (ref, restaurantId) => ref.watch(catalogServiceProvider).watchMenu(restaurantId),
);

/// Best sellers across the whole catalogue, for the home feed.
final bestSellersProvider = Provider<List<MenuItem>>((ref) {
  final items = ref.watch(allMenuItemsProvider).valueOrNull ?? const [];
  return items.where((i) => i.isBestSeller).toList()
    ..sort((a, b) => b.rating.compareTo(a.rating));
});

/// Highly-rated items that are not already surfaced as best sellers.
final recommendedProvider = Provider<List<MenuItem>>((ref) {
  final items = ref.watch(allMenuItemsProvider).valueOrNull ?? const [];
  final rest = items.where((i) => !i.isBestSeller).toList()
    ..sort((a, b) => b.rating.compareTo(a.rating));
  return rest.take(8).toList();
});

// -------------------------------------------------------------------- cart --

final cartProvider = StreamProvider<List<CartLine>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(cartServiceProvider).watch(uid);
});

/// The restaurant the personal cart belongs to. A cart only ever holds one.
final cartRestaurantProvider = Provider<AsyncValue<Restaurant?>>((ref) {
  final lines = ref.watch(cartProvider).valueOrNull ?? const [];
  if (lines.isEmpty) return const AsyncValue.data(null);
  return ref.watch(restaurantProvider(lines.first.restaurantId));
});

final cartTotalsProvider = Provider<CartTotals>((ref) {
  final lines = ref.watch(cartProvider).valueOrNull ?? const [];
  final restaurant = ref.watch(cartRestaurantProvider).valueOrNull;
  return OrderService.totalsFor(lines: lines, restaurant: restaurant, discount: 0);
});

final cartCountProvider = Provider<int>((ref) {
  final lines = ref.watch(cartProvider).valueOrNull ?? const [];
  return lines.fold<int>(0, (acc, l) => acc + l.quantity);
});

// ---------------------------------------------------------------- sessions --

/// The session the user is currently looking at.
///
/// Every screen that takes the user out of a session clears this. A stale id
/// is not harmless: the shared cart under it is readable only by members, so
/// it would leave the app offering to add food to a session every write to
/// which the rules refuse.
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

final activeSessionProvider = StreamProvider<GroupSession?>((ref) {
  final id = ref.watch(activeSessionIdProvider);
  final uid = ref.watch(currentUidProvider);
  if (id == null || uid == null) return Stream.value(null);
  // Only a session the user is still in counts as active, so being removed by
  // the host — or leaving from another device — stops the rest of the app
  // treating it as the place food goes, even before the id is cleared.
  return ref
      .watch(sessionServiceProvider)
      .watch(id)
      .map((session) => session != null && session.hasMember(uid) ? session : null);
});

final sessionProvider = StreamProvider.autoDispose.family<GroupSession?, String>(
  (ref, id) => ref.watch(sessionServiceProvider).watch(id),
);

final sessionLinesProvider = StreamProvider.autoDispose.family<List<CartLine>, String>(
  (ref, sessionId) => ref.watch(sessionServiceProvider).watchLines(sessionId),
);

final activeSessionLinesProvider = Provider<List<CartLine>>((ref) {
  final session = ref.watch(activeSessionProvider).valueOrNull;
  if (session == null) return const [];
  return ref.watch(sessionLinesProvider(session.id)).valueOrNull ?? const [];
});

final mySessionsProvider = StreamProvider<List<GroupSession>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(sessionServiceProvider).watchMySessions(uid);
});

/// Live sessions only — what the home screen surfaces as "continue where you
/// left off".
final liveSessionsProvider = Provider<List<GroupSession>>((ref) {
  final all = ref.watch(mySessionsProvider).valueOrNull ?? const [];
  return all.where((s) => s.stage.isLive).toList();
});

final myInvitesProvider = StreamProvider<List<GroupSession>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(sessionServiceProvider).watchMyInvites(uid);
});

final savedSessionsProvider = StreamProvider<List<SavedSession>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(sessionServiceProvider).watchSavedSessions(uid);
});

/// Totals for a group session, priced the same way as an individual cart.
final sessionTotalsProvider = Provider.autoDispose.family<CartTotals, String>((ref, sessionId) {
  final lines = ref.watch(sessionLinesProvider(sessionId)).valueOrNull ?? const [];
  final session = ref.watch(sessionProvider(sessionId)).valueOrNull;
  final restaurantId = session?.restaurantId;
  final restaurant =
      restaurantId == null ? null : ref.watch(restaurantProvider(restaurantId)).valueOrNull;
  return OrderService.totalsFor(
    lines: lines,
    restaurant: restaurant,
    discount: session?.voucherDiscount ?? 0,
  );
});

// ------------------------------------------------------------------ orders --

final myOrdersProvider = StreamProvider<List<FoodOrder>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(orderServiceProvider).watchMyOrders(uid);
});

final orderProvider = StreamProvider.autoDispose.family<FoodOrder?, String>(
  (ref, id) => ref.watch(orderServiceProvider).watchOrder(id),
);

final activeOrdersProvider = Provider<List<FoodOrder>>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  return orders.where((o) => o.status.isActive).toList();
});

final pastOrdersProvider = Provider<List<FoodOrder>>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  return orders.where((o) => o.status.isTerminal).toList();
});

// --------------------------------------------------------------- payments ---

final paymentMethodsProvider = StreamProvider<List<SavedPaymentMethod>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(paymentServiceProvider).watchMethods(uid);
});

final defaultPaymentMethodProvider = Provider<SavedPaymentMethod?>((ref) {
  final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const [];
  if (methods.isEmpty) return null;
  for (final m in methods) {
    if (m.isDefault) return m;
  }
  return methods.first;
});

// --------------------------------------------------------------- favourites --

final favoriteRestaurantsProvider = Provider<List<Restaurant>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final all = ref.watch(restaurantsProvider).valueOrNull ?? const [];
  if (user == null) return const [];
  return all.where((r) => user.favoriteRestaurantIds.contains(r.id)).toList();
});

final favoriteItemsProvider = Provider<List<MenuItem>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final all = ref.watch(allMenuItemsProvider).valueOrNull ?? const [];
  if (user == null) return const [];
  return all.where((i) => user.favoriteItemIds.contains(i.id)).toList();
});

// --------------------------------------------------------------- support ----

final myTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(supportServiceProvider).watchMyTickets(uid);
});

// ----------------------------------------------------------------- admin ----

final adminUsersProvider = StreamProvider<List<AppUser>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(adminServiceProvider).watchUsers();
});

final adminRestaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(catalogServiceProvider).watchRestaurants();
});

final adminOrdersProvider = StreamProvider<List<FoodOrder>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(orderServiceProvider).watchAllOrders();
});

final adminSessionsProvider = StreamProvider<List<GroupSession>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(adminServiceProvider).watchSessions();
});

final adminTicketsProvider = StreamProvider<List<SupportTicket>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(supportServiceProvider).watchAllTickets();
});

final adminStatsProvider = FutureProvider<AdminStats>((ref) {
  if (!ref.watch(isAdminProvider)) return Future.value(AdminStats.empty);
  return ref.watch(adminServiceProvider).loadStats();
});
