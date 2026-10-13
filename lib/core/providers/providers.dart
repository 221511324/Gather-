import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/firestore_refs.dart';
import '../services/seed_service.dart';
import '../services/session_service.dart';

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

final sessionServiceProvider =
    Provider<SessionService>((ref) => SessionService(ref.watch(firestoreRefsProvider)));

final seedServiceProvider =
    Provider<SeedService>((ref) => SeedService(ref.watch(firestoreRefsProvider)));

// -------------------------------------------------------------------- auth --
// US1: registration, login, logout and secure access.

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

// --------------------------------------------------------------- catalogue --
// US3: browse restaurants and menus.

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

// ---------------------------------------------------------------- sessions --
// US4, US5, US6: create a session, invite members, join a session.

/// The session the user is currently looking at.
final activeSessionIdProvider = StateProvider<String?>((ref) => null);

final activeSessionProvider = StreamProvider<GroupSession?>((ref) {
  final id = ref.watch(activeSessionIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(sessionServiceProvider).watch(id);
});

final sessionProvider = StreamProvider.autoDispose.family<GroupSession?, String>(
  (ref, id) => ref.watch(sessionServiceProvider).watch(id),
);

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
