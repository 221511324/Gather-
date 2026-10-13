import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_prefs.dart';
import '../core/providers/providers.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/group/group_hub_screen.dart';
import '../features/group/join_session_screen.dart';
import '../features/group/session_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/main_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/restaurant/restaurant_screen.dart';
import '../features/search/search_screen.dart';
import '../features/splash/splash_screen.dart';

/// Every named route in Phase 1, in one place so links are typo-proof.
///
/// Phase 1 covers US1–US6: authentication, profile management, restaurant and
/// menu browsing, group session creation, invitation and joining. Routes for
/// the shared cart, payment, orders, rewards, notifications, the AI assistant
/// and the admin dashboard arrive in Phase 2 and Phase 3.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  static const home = '/home';
  static const search = '/search';
  static const group = '/group';
  static const profile = '/profile';

  static const editProfile = '/profile/edit';

  static const joinSession = '/join';

  static String restaurant(String id) => '/restaurant/$id';
  static String session(String id) => '/group/session/$id';

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
    initialLocation: Routes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final path = state.matchedLocation;

      // Hold on the splash until Firebase has reported an auth state.
      if (auth.isLoading) return path == Routes.splash ? null : Routes.splash;

      final signedIn = auth.valueOrNull != null;

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

      // The four tabs live inside a shell so the bottom bar never rebuilds.
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
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),

      GoRoute(
        path: '/restaurant/:id',
        builder: (_, state) => RestaurantScreen(restaurantId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: '/group/session/:id',
        builder: (_, state) => SessionScreen(sessionId: state.pathParameters['id']!),
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
                Text('We could not find $location', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(Routes.home),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      );
}
