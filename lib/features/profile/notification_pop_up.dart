import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/local_alerts.dart';
import 'notifications_screen.dart';

/// Which notifications are new enough to pop up. Kept apart from the widget
/// so it can be unit-tested.
abstract final class AlertRules {
  /// An unread notification older than this is not news any more — it was
  /// missed, and the list in Notifications is where it belongs.
  static const freshFor = Duration(minutes: 10);

  /// The notifications in [current] that were not there before ([seen]),
  /// are unread, and are recent. A pending write has no time yet and counts
  /// as recent.
  static List<AppNotification> fresh(
    Set<String> seen,
    List<AppNotification> current,
    DateTime now,
  ) =>
      current
          .where((n) =>
              !seen.contains(n.id) &&
              !n.read &&
              (n.createdAt == null || now.difference(n.createdAt!) < freshFor))
          .toList();

  /// Where tapping one goes: an order to its live tracking, a session to the
  /// session, anything else to the notifications list.
  static String routeFor(AppNotification n) {
    if (n.orderId != null) return Routes.trackOrder(n.orderId!);
    if (n.sessionId != null) return Routes.session(n.sessionId!);
    return Routes.notifications;
  }
}

/// US16 — tells the person the moment something happens, the way a delivery
/// app does: "Your order is ready", "Your order is on its way".
///
/// It watches the person's notifications. When a new one arrives while the app
/// is on screen, a banner slides down from the top; while the app is in the
/// background, the phone shows it in the status bar instead
/// ([LocalAlerts]). Either one, tapped, opens the order or the session.
///
/// Stays silent until [LocalAlerts.init] has run (it does in `main`), so the
/// widget and integration tests are not interrupted by banners.
class NotificationPopUp extends ConsumerStatefulWidget {
  const NotificationPopUp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<NotificationPopUp> createState() => _NotificationPopUpState();
}

class _NotificationPopUpState extends ConsumerState<NotificationPopUp>
    with SingleTickerProviderStateMixin {
  static const _onScreenFor = Duration(seconds: 5);

  final _seen = <String>{};
  String? _primedFor;
  AppNotification? _showing;
  Timer? _hide;

  // Preserve: the banner must still slide on phones with animations off.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    animationBehavior: AnimationBehavior.preserve,
  );
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    LocalAlerts.instance.onOpen = _open;
    ref.listenManual(notificationsProvider, (_, next) {
      if (next is AsyncData<List<AppNotification>>) _arrived(next.value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _slide.dispose();
    if (LocalAlerts.instance.onOpen == _open) LocalAlerts.instance.onOpen = null;
    super.dispose();
  }

  void _arrived(List<AppNotification> all) {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      _primedFor = null;
      _seen.clear();
      return;
    }
    // The first list after signing in is history, not news.
    if (_primedFor != uid) {
      _primedFor = uid;
      _seen
        ..clear()
        ..addAll(all.map((n) => n.id));
      _signedIn();
      return;
    }
    final fresh = AlertRules.fresh(_seen, all, DateTime.now());
    _seen.addAll(all.map((n) => n.id));
    if (fresh.isEmpty || !LocalAlerts.instance.isReady) return;

    // Not yet known (the first frames) counts as on screen: the app is
    // drawing. Paused, hidden or inactive goes to the phone instead.
    final state = WidgetsBinding.instance.lifecycleState;
    final onScreen = state == null || state == AppLifecycleState.resumed;
    if (onScreen) {
      _present(fresh.first); // newest first
    } else {
      for (final n in fresh) {
        LocalAlerts.instance.show(
          id: n.id,
          title: NotificationsScreen.say(context, n.title),
          body: NotificationsScreen.say(context, n.body),
          route: AlertRules.routeFor(n),
        );
      }
    }
  }

  void _signedIn() {
    if (!LocalAlerts.instance.isReady) return;
    LocalAlerts.instance.requestPermission();
    final route = LocalAlerts.instance.takeLaunchRoute();
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(route));
    }
  }

  void _present(AppNotification n) {
    _hide?.cancel();
    setState(() => _showing = n);
    _slide.forward(from: 0);
    _hide = Timer(_onScreenFor, _dismiss);
  }

  Future<void> _dismiss() async {
    _hide?.cancel();
    if (!mounted || _showing == null) return;
    await _slide.reverse();
    if (mounted) setState(() => _showing = null);
  }

  void _open(String route) {
    if (!mounted) return;
    widget.router.push(route);
  }

  void _tapped(AppNotification n) {
    final uid = ref.read(currentUidProvider);
    if (uid != null) ref.read(notificationServiceProvider).markRead(uid, n.id);
    _dismiss();
    _open(AlertRules.routeFor(n));
  }

  @override
  Widget build(BuildContext context) {
    final n = _showing;
    if (n == null) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.sm, Insets.md, 0),
          child: SlideTransition(
            position: _offset,
            child: Dismissible(
              key: ValueKey('pop-${n.id}'),
              direction: DismissDirection.up,
              onDismissed: (_) {
                _hide?.cancel();
                setState(() => _showing = null);
              },
              child: _Banner(notification: n, onTap: () => _tapped(n)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return Material(
      key: const ValueKey('notification-pop-up'),
      color: AppColors.surface,
      elevation: 10,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(NotificationsScreen.iconFor(n.kind),
                    size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            NotificationsScreen.say(context, n.title),
                            style: AppType.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(context.tr('now'), style: AppType.caption),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      NotificationsScreen.say(context, n.body),
                      style: AppType.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
