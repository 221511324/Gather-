import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'app_prefs.dart';
import '../services/admin_service.dart';
import '../services/assistant_service.dart';
import '../services/gemini_brain.dart';
import '../services/notification_service.dart';
import '../services/story_service.dart';
import '../services/voucher_service.dart';
import '../services/spin_service.dart';
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

// The catalogue, and the story, payment and spin feeds further down, are
// readable only when signed in. A listener opened
// before sign-in, or kept across a sign-out, is refused once and never
// recovers, so each one watches the uid: it waits for a session, and starts
// again for whoever signs in next.

final restaurantsProvider = StreamProvider<List<Restaurant>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(catalogServiceProvider).watchRestaurants();
});

final allMenuItemsProvider = StreamProvider<List<MenuItem>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(catalogServiceProvider).watchAllItems();
});

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

/// Every payment option the platform has configured, enabled or not, as the
/// customer sees it. Disabled ones are needed to tell "switched off" apart
/// from "nothing configured yet" — see [PaymentService.isUsable].
final paymentCatalogProvider = StreamProvider<List<PaymentOption>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(paymentServiceProvider).watchOptions();
});

/// The saved methods that may be used to pay right now — those whose option
/// the administrator has not switched off. Both inputs are live Firestore
/// streams, so toggling an option in the console changes this immediately.
///
/// Empty until the option list has loaded, so a disabled method is never
/// briefly offered. If the list cannot be read, everything is offered and
/// [PaymentService.pay] makes the final call.
final usablePaymentMethodsProvider = Provider<List<SavedPaymentMethod>>((ref) {
  final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const <SavedPaymentMethod>[];
  final catalog = ref.watch(paymentCatalogProvider);
  if (catalog.hasError) return methods;
  final options = catalog.valueOrNull;
  if (options == null) return const [];
  return PaymentService.usableMethods(methods, options);
});

/// What to pay with when nothing has been picked: the default if it is still
/// usable, otherwise another usable method, otherwise null (prompt to add).
final defaultPaymentMethodProvider = Provider<SavedPaymentMethod?>((ref) =>
    PaymentService.defaultMethod(ref.watch(usablePaymentMethodsProvider)));

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

/// US19 — food stories.
final storyServiceProvider = Provider<StoryService>(
    (ref) => StoryService(ref.watch(firestoreRefsProvider)));

final storyFeedProvider = StreamProvider<List<FoodStory>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(storyServiceProvider).watchFeed();
});

final myStoriesProvider = StreamProvider<List<FoodStory>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(storyServiceProvider).watchMine(uid);
});

/// One story's picture. Shared by the home rail's thumbnail and the viewer,
/// so opening a story whose circle is on screen does not fetch it twice.
final storyImageProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
    (ref, storyId) => ref.watch(storyServiceProvider).loadImage(storyId));

/// Story ids this device has watched, for the rail's coloured / grey ring.
final seenStoriesProvider = StateNotifierProvider<SeenStories, Set<String>>(
    (ref) => SeenStories(ref.watch(appPrefsProvider)));

class SeenStories extends StateNotifier<Set<String>> {
  SeenStories(this._prefs) : super(_prefs.seenStoryIds.toSet());

  final AppPrefs _prefs;

  /// Stories last a day, so only recent ids are worth keeping; the oldest are
  /// dropped first (the set keeps insertion order).
  static const keep = 500;

  void markSeen(String storyId) {
    if (state.contains(storyId)) return;
    var next = {...state, storyId};
    if (next.length > keep) next = next.skip(next.length - keep).toSet();
    state = next;
    // Best effort: losing a seen marker only means a ring stays coloured.
    _prefs.setSeenStoryIds(next.toList()).ignore();
  }
}

/// US15 — rewards and vouchers.
final voucherServiceProvider = Provider<VoucherService>(
    (ref) => VoucherService(ref.watch(firestoreRefsProvider)));

/// What the signed-in person holds.
final myVouchersProvider = StreamProvider<List<UserVoucher>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(voucherServiceProvider).watchMine(uid);
});

/// FR25 — Spin & Win.
final spinServiceProvider =
    Provider<SpinService>((ref) => SpinService(ref.watch(firestoreRefsProvider)));

/// The prizes on the wheel right now.
final spinWheelProvider = StreamProvider<List<SpinPrize>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(spinServiceProvider).watchWheel();
});

/// When the signed-in person last spun, from their profile; null if never.
final lastSpinAtProvider = Provider<DateTime?>(
    (ref) => ref.watch(currentUserProvider).valueOrNull?.lastSpinAt);

/// The campaigns an administrator manages.
final adminVouchersProvider = StreamProvider<List<Voucher>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(voucherServiceProvider).watchCatalogue();
});

/// US16 — the notification centre.
final notificationServiceProvider = Provider<NotificationService>(
    (ref) => NotificationService(ref.watch(firestoreRefsProvider)));

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationServiceProvider).watch(uid);
});

/// Drives the badge on the profile tab.
final unreadNotificationsProvider = Provider<int>((ref) =>
    (ref.watch(notificationsProvider).valueOrNull ?? const [])
        .where((n) => !n.read)
        .length);

/// US14 — the food assistant.
///
/// Gemini when the build was given a key (`--dart-define-from-file=
/// config/secrets.json`), otherwise the on-device brain alone.
final assistantBrainProvider = Provider<AssistantBrain>((ref) =>
    isUsableGeminiKey(geminiApiKey)
        ? GeminiBrain(apiKey: geminiApiKey)
        : const RetrievalBrain());

final assistantServiceProvider = Provider<AssistantService>((ref) => AssistantService(
    ref.watch(firestoreRefsProvider),
    brain: ref.watch(assistantBrainProvider)));

/// The conversation belonging to the signed-in person.
final assistantConversationProvider =
    StreamProvider<List<AssistantMessage>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(assistantServiceProvider).watchConversation(uid);
});

/// What the assistant is allowed to answer from — the live catalogue, so a
/// dish that has been taken off the menu stops being suggested.
final assistantContextProvider = Provider<AssistantContext>((ref) => AssistantContext(
      restaurants: ref.watch(restaurantsProvider).valueOrNull ?? const [],
      items: ref.watch(allMenuItemsProvider).valueOrNull ?? const [],
    ));

/// Every payment method the platform offers, for the admin console.
final adminPaymentOptionsProvider = StreamProvider<List<PaymentOption>>((ref) {
  if (!ref.watch(isAdminProvider)) return Stream.value(const []);
  return ref.watch(paymentServiceProvider).watchOptions();
});

/// Only the ones a customer may choose, for the app.
final paymentOptionsProvider = StreamProvider<List<PaymentOption>>((ref) {
  if (ref.watch(currentUidProvider) == null) return Stream.value(const []);
  return ref.watch(paymentServiceProvider).watchEnabledOptions();
});

final adminStatsProvider = FutureProvider<AdminStats>((ref) {
  if (!ref.watch(isAdminProvider)) return Future.value(AdminStats.empty);
  return ref.watch(adminServiceProvider).loadStats();
});
