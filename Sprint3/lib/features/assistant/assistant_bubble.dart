import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../home/main_shell.dart';

/// Where the floating assistant button sits on a given screen.
enum AssistantBubbleSpot {
  /// A tab page: lifted clear of the floating navigation bar.
  aboveNavBar,

  /// Any other customer page: in the bottom corner.
  corner,
}

/// The five tab pages, which carry the floating navigation bar.
const _tabs = {Routes.home, Routes.search, Routes.group, Routes.orders, Routes.profile};

/// Pages the button never covers. Sign-in and the assistant itself have no
/// use for it; the others keep a primary action along the bottom edge (Add to
/// cart, Checkout, the session and payment bars, Save) or fill the screen, and
/// a button floating over those would hide the very thing the page is for.
const _hiddenExact = {
  Routes.splash,
  Routes.onboarding,
  Routes.login,
  Routes.register,
  Routes.forgotPassword,
  Routes.adminsOnly,
  Routes.assistant,
  Routes.cart,
  Routes.checkout,
  Routes.editProfile,
  Routes.addresses,
  Routes.paymentMethods,
  Routes.contact,
};

const _hiddenPrefixes = [
  Routes.admin, // the administration console
  '/restaurant/', // the cart bar and the dish sheet
  '/group/session/', // lobby, shared cart, spin and payment all have action bars
  '/order/', // order detail and tracking have bottom actions
  Routes.joinSession, // the join-by-code button
  '/stories/view', // full-screen story viewer
  '/spin', // the full-screen spin & win game
];

/// Whether — and where — the assistant button shows for [location] (a go_router
/// matched location such as `/restaurant/abc`). Null means hidden.
///
/// It is for signed-in customers on the phone: the website is the
/// administration console, so it never shows there.
AssistantBubbleSpot? assistantBubbleSpot(
  String location, {
  required bool signedIn,
  bool isWeb = false,
}) {
  if (!signedIn || isWeb || location.isEmpty) return null;
  if (_hiddenExact.contains(location)) return null;
  for (final prefix in _hiddenPrefixes) {
    if (location == prefix || location.startsWith(prefix)) return null;
  }
  return _tabs.contains(location) ? AssistantBubbleSpot.aboveNavBar : AssistantBubbleSpot.corner;
}

/// Tracks dialogs and bottom sheets on the root navigator, so the button can
/// step aside while one is open instead of floating over its buttons. Every
/// sheet in the app opens on the root navigator, and dialogs do by default.
class AssistantBubbleObserver extends NavigatorObserver with ChangeNotifier {
  // The routes themselves rather than a count: a sheet still open when its
  // navigator is torn down never reports closing, and a count would then
  // keep the button hidden for good. A route that is no longer active is
  // ignored instead.
  final _popups = <Route<dynamic>>{};

  bool get popupOpen {
    _popups.removeWhere((r) => !r.isActive);
    return _popups.isNotEmpty;
  }

  void _changed() {
    // Navigator callbacks can arrive mid-build; tell listeners afterwards.
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _opened(Route<dynamic>? route) {
    if (route is PopupRoute && _popups.add(route)) _changed();
  }

  void _closed(Route<dynamic>? route) {
    if (route != null && _popups.remove(route)) _changed();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _opened(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _closed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _closed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _closed(oldRoute);
    _opened(newRoute);
  }
}

/// Handed to the router's root navigator.
final assistantBubbleObserver = AssistantBubbleObserver();

/// The small yellow circle that opens the food assistant from any customer
/// page. It sits over the whole app (see the `builder` in app.dart), so it
/// reads the router's location to decide where to stand.
///
/// It can be dragged up and down and to either side, and snaps to the nearer
/// side when let go. The side is kept as start/end, so a button left on the
/// right in English sits on the left in Arabic; both are remembered on the
/// device.
class AssistantBubble extends ConsumerStatefulWidget {
  const AssistantBubble({super.key, required this.router, this.observer});

  final GoRouter router;

  /// Defaults to [assistantBubbleObserver].
  final AssistantBubbleObserver? observer;

  /// How integration tests find the button.
  static const buttonKey = ValueKey('assistantBubble');

  static const size = 56.0;
  static const _margin = 16.0;
  static const _gap = 12.0;

  static const _sideKey = 'assistant_bubble_at_start';
  static const _liftKey = 'assistant_bubble_lift';

  @override
  ConsumerState<AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends ConsumerState<AssistantBubble>
    with SingleTickerProviderStateMixin {
  /// One gentle pulse the first time it appears in a session, not on every
  /// screen.
  static bool _pulsed = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _atStart = false;
  double _lift = 0;

  /// The button's top-left while a finger is on it.
  Offset? _drag;

  AssistantBubbleObserver get _observer => widget.observer ?? assistantBubbleObserver;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_refresh);
    _observer.addListener(_refresh);
    _restore();
  }

  @override
  void didUpdateWidget(AssistantBubble old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_refresh);
      widget.router.routerDelegate.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_refresh);
    _observer.removeListener(_refresh);
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _atStart = prefs.getBool(AssistantBubble._sideKey) ?? false;
        _lift = prefs.getDouble(AssistantBubble._liftKey) ?? 0;
      });
    } catch (_) {
      // Keep the default corner if preferences are unavailable.
    }
  }

  Future<void> _remember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AssistantBubble._sideKey, _atStart);
      await prefs.setDouble(AssistantBubble._liftKey, _lift);
    } catch (_) {}
  }

  void _refresh() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _refresh());
      return;
    }
    setState(() {});
  }

  String get _location {
    final delegate = widget.router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return '';
    return widget.router.state.matchedLocation;
  }

  void _open() {
    if (_location == Routes.assistant) return;
    widget.router.push(Routes.assistant);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authStateProvider).valueOrNull != null;
    final media = MediaQuery.of(context);
    final location = _location;
    final spot = assistantBubbleSpot(location, signedIn: signedIn);

    // Out of the way while the keyboard is up or a sheet or dialog is open.
    final hidden = spot == null || media.viewInsets.bottom > 0 || _observer.popupOpen;
    if (hidden) return const SizedBox.shrink();

    if (!_pulsed) {
      _pulsed = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pulse.forward();
      });
    }

    const size = AssistantBubble.size;
    final width = media.size.width;
    final height = media.size.height;
    final anchor = spot == AssistantBubbleSpot.aboveNavBar
        ? MainShell.barClearance(media) + AssistantBubble._gap
        : media.padding.bottom + AssistantBubble._margin;
    final maxLift = (height - anchor - size - media.padding.top - 72).clamp(0.0, double.infinity);
    final lift = _lift.clamp(0.0, maxLift);

    final ltr = Directionality.of(context) == TextDirection.ltr;
    final onRight = _atStart != ltr; // end is the right in English
    final left = _drag?.dx ?? (onRight ? width - AssistantBubble._margin - size : AssistantBubble._margin);
    final top = _drag?.dy ?? height - anchor - lift - size;

    return AnimatedPositioned(
      duration: _drag == null ? const Duration(milliseconds: 220) : Duration.zero,
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _drag = Offset(left, top)),
        onPanUpdate: (d) => setState(() {
          final at = _drag! + d.delta;
          _drag = Offset(
            at.dx.clamp(0.0, width - size),
            at.dy.clamp(height - anchor - maxLift - size, height - anchor - size),
          );
        }),
        onPanEnd: (_) => _settle(width, height, anchor, maxLift, ltr),
        onPanCancel: () => _settle(width, height, anchor, maxLift, ltr),
        child: _Bubble(pulse: _pulse, onTap: _open),
      ),
    );
  }

  void _settle(double width, double height, double anchor, double maxLift, bool ltr) {
    final at = _drag;
    if (at == null) return;
    final rightHalf = at.dx + AssistantBubble.size / 2 > width / 2;
    setState(() {
      _atStart = rightHalf != ltr;
      _lift = (height - anchor - AssistantBubble.size - at.dy).clamp(0.0, maxLift);
      _drag = null;
    });
    _remember();
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.pulse, required this.onTap});

  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: context.tr('Food assistant'),
        hint: context.tr('Opens the food assistant. Drag to move it.'),
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: pulse,
          // Two soft beats, then still.
          builder: (context, child) {
            final t = pulse.value;
            final beat = t < 0.5 ? t / 0.5 : (t - 0.5) / 0.5;
            final scale = pulse.isAnimating ? 1 + 0.08 * Curves.easeInOut.transform(1 - (2 * beat - 1).abs()) : 1.0;
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            key: AssistantBubble.buttonKey,
            width: AssistantBubble.size,
            height: AssistantBubble.size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x33184248), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: const Icon(Icons.assistant_rounded, size: 26, color: AppColors.ink),
              ),
            ),
          ),
        ),
      );
}
