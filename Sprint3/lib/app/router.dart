import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/tr.dart';
import '../core/providers/app_prefs.dart';
import '../core/providers/providers.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admins_only_screen.dart';
import '../features/admin/admin_menu_screen.dart';
import '../features/admin/admin_orders_screen.dart';
import '../features/admin/admin_restaurants_screen.dart';
import '../features/admin/admin_sessions_screen.dart';
import '../features/admin/admin_payments_screen.dart';
import '../features/assistant/assistant_bubble.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/admin/admin_rewards_screen.dart';
import '../features/profile/notifications_screen.dart';
import '../features/profile/rewards_screen.dart';
import '../features/rewards/spin_win_screen.dart';
import '../features/stories/stories_screen.dart';
import '../features/stories/story_viewer_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/admin/admin_tickets_screen.dart';
import '../features/admin/admin_users_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/checkout/checkout_screen.dart';
import '../features/favorites/favorites_screen.dart';
import '../features/group/group_hub_screen.dart';
import '../features/group/join_session_screen.dart';
import '../features/group/session_payment_screen.dart';
import '../features/group/session_screen.dart';
import '../features/group/session_shared_cart_screen.dart';
import '../features/group/restaurant_spin_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/main_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/orders/order_tracking_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/profile/addresses_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/payment_methods_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/restaurant/restaurant_screen.dart';
import '../features/search/search_screen.dart';
import '../features/help/contact_screen.dart';
import '../features/help/faq_screen.dart';
import '../features/help/help_screen.dart';
import '../features/splash/splash_screen.dart';

/// Every named route in Sprint 2, in one place so links are typo-proof.
///
/// Sprint 2 covers US1-US13 and US18. Sprint 3 adds the food assistant
/// (US14) and administrator-managed payment methods; rewards, notifications,
/// settings and food stories are still to come.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const home = '/home';
  static const search = '/search';
  static const group = '/group';
  static const orders = '/orders';
  static const profile = '/profile';

  static const favorites = '/favorites';
  static const cart = '/cart';
  static const checkout = '/checkout';

  static const editProfile = '/profile/edit';
  static const addresses = '/profile/addresses';
  static const paymentMethods = '/profile/payment-methods';

  static const help = '/help';
  static const faq = '/help/faq';
  static const contact = '/help/contact';

  static const joinSession = '/join';

  /// Web only: shown when the signed-in account is not an administrator.
  static const adminsOnly = '/administrators-only';

  static const admin = '/admin';
  static const adminUsers = '/admin/users';
  static const adminOrders = '/admin/orders';
  static const adminSessions = '/admin/sessions';
  static const adminTickets = '/admin/tickets';
  static const adminRestaurants = '/admin/restaurants';
  static const adminPayments = '/admin/payments';
  static const assistant = '/assistant';
  static const settings = '/settings';
  static const notifications = '/notifications';
  static const rewards = '/rewards';
  static const spin = '/spin';
  static const stories = '/stories';

  /// US19 full-screen viewer for one author's stories; [storyId] starts on a
  /// particular one instead of the first unwatched.
  static String storyViewer(String authorId, {String? storyId}) =>
      '/stories/view/${Uri.encodeComponent(authorId)}'
      '${storyId == null ? '' : '?story=${Uri.encodeQueryComponent(storyId)}'}';
  static const adminRewards = '/admin/rewards';

  static String adminMenu(String restaurantId) => '/admin/restaurants/$restaurantId/menu';

  static String restaurant(String id) => '/restaurant/$id';
  static String order(String id) => '/order/$id';
  static String trackOrder(String id) => '/order/$id/track';
  static String session(String id) => '/group/session/$id';
  static String sessionCart(String id) => '/group/session/$id/cart';
  static String sessionSpin(String id) => '/group/session/$id/spin';
  static String sessionPayment(String id) => '/group/session/$id/payment';

  /// The link a host shares to invite someone (FR7).
  static String inviteLink(String code) => 'https://gather.app/join/$code';
}

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

/// Rebuilds the router's redirect whenever auth state settles.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
    _ref.listen(currentUserProvider, (_, _) => notifyListeners());
    _ref.listen(onboardingSeenProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: kIsWeb ? Routes.login : Routes.splash,
    refreshListenable: listenable,
    // Lets the floating assistant button step aside while a sheet or dialog
    // is open.
    observers: [assistantBubbleObserver],
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final path = state.matchedLocation;

      // Hold on the splash until Firebase has reported an auth state.
      if (auth.isLoading) return path == Routes.splash ? null : Routes.splash;

      final signedIn = auth.valueOrNull != null;

      // The website is the administration console: the customer experience is
      // the mobile app, so the web build never leaves the admin area.
      if (kIsWeb) {
        if (!signedIn) {
          return path == Routes.login || path == Routes.forgotPassword
              ? null
              : Routes.login;
        }
        // Wait for the profile before judging the role, or an administrator
        // would be bounced on every refresh while it loads.
        final profile = ref.read(currentUserProvider);
        if (profile.isLoading) return null;
        if (profile.valueOrNull?.isAdmin != true) {
          return path == Routes.adminsOnly ? null : Routes.adminsOnly;
        }
        if (!path.startsWith('/admin')) return Routes.admin;
        return null;
      }

      // First launch on this device goes through onboarding before sign-in.
      if (!signedIn && !ref.read(onboardingSeenProvider)) {
        return path == Routes.onboarding ? null : Routes.onboarding;
      }

      const publicRoutes = {
        Routes.login,
        Routes.register,
        Routes.forgotPassword,
        Routes.onboarding,
        Routes.splash,
      };
      final isPublic = publicRoutes.contains(path) || path.startsWith(Routes.joinSession);

      if (!signedIn) {
        // An invite link still needs an account, but we send them to sign in
        // rather than dropping the link entirely.
        return isPublic && path != Routes.splash ? null : Routes.login;
      }

      if (path == Routes.splash || (isPublic && !path.startsWith(Routes.joinSession))) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),

      // The five tabs live inside a shell so the bottom bar never rebuilds.
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.group, builder: (_, _) => const GroupHubScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.orders, builder: (_, _) => const OrdersScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      GoRoute(
        path: '/restaurant/:id',
        builder: (_, state) => RestaurantScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.favorites, builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen()),
      GoRoute(path: Routes.checkout, builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'track',
            builder: (_, state) => OrderTrackingScreen(orderId: state.pathParameters['id']!),
          ),
        ],
      ),

      GoRoute(
        path: '/group/session/:id',
        builder: (_, state) => SessionScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'cart',
            builder: (_, state) => SessionSharedCartScreen(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'spin',
            builder: (_, state) => RestaurantSpinScreen(sessionId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'payment',
            builder: (_, state) => SessionPaymentScreen(sessionId: state.pathParameters['id']!),
          ),
        ],
      ),

      // Accepts both an in-app tap and a shared invite link.
      GoRoute(
        path: '/join',
        builder: (_, state) => JoinSessionScreen(code: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: '/join/:code',
        builder: (_, state) => JoinSessionScreen(code: state.pathParameters['code']),
      ),

      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: Routes.addresses, builder: (_, _) => const AddressesScreen()),
      GoRoute(path: Routes.paymentMethods, builder: (_, _) => const PaymentMethodsScreen()),

      GoRoute(path: Routes.help, builder: (_, _) => const HelpScreen()),
      GoRoute(path: Routes.faq, builder: (_, _) => const FaqScreen()),
      GoRoute(path: Routes.contact, builder: (_, _) => const ContactScreen()),

      GoRoute(path: Routes.adminsOnly, builder: (_, _) => const AdminsOnlyScreen()),
      GoRoute(path: Routes.admin, builder: (_, _) => const AdminDashboardScreen()),
      GoRoute(path: Routes.adminUsers, builder: (_, _) => const AdminUsersScreen()),
      GoRoute(path: Routes.adminOrders, builder: (_, _) => const AdminOrdersScreen()),
      GoRoute(path: Routes.adminSessions, builder: (_, _) => const AdminSessionsScreen()),
      GoRoute(path: Routes.adminTickets, builder: (_, _) => const AdminTicketsScreen()),
      GoRoute(path: Routes.adminPayments, builder: (_, _) => const AdminPaymentsScreen()),
      GoRoute(path: Routes.assistant, builder: (_, _) => const AssistantScreen()),
      GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: Routes.rewards, builder: (_, _) => const RewardsScreen()),
      GoRoute(
        path: Routes.spin,
        builder: (_, state) =>
            SpinWinScreen(fromRewards: state.uri.queryParameters['from'] == 'rewards'),
      ),
      GoRoute(path: Routes.stories, builder: (_, _) => const StoriesScreen()),
      GoRoute(
        path: '/stories/view/:authorId',
        builder: (_, state) => StoryViewerScreen(
          authorId: state.pathParameters['authorId']!,
          storyId: state.uri.queryParameters['story'],
        ),
      ),
      GoRoute(path: Routes.adminRewards, builder: (_, _) => const AdminRewardsScreen()),
      GoRoute(
        path: Routes.adminRestaurants,
        builder: (_, _) => const AdminRestaurantsScreen(),
        routes: [
          GoRoute(
            path: ':id/menu',
            builder: (_, state) => AdminMenuScreen(restaurantId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.toString()),
  );
});

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_off_rounded, size: 56),
                const SizedBox(height: 16),
                Text(
                  context.tr('We could not find {location}', {'location': location}),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(Routes.home),
                  child: Text(context.tr('Go home')),
                ),
              ],
            ),
          ),
        ),
      );
}
