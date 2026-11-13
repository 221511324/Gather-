import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/theme/app_colors.dart';

/// US16 — the phone's own notifications: a heads-up in the status bar, with
/// sound, when an order or group update arrives while Gather is in the
/// background.
///
/// Free of any server. The app already listens to the person's notifications
/// in Firestore; when a new one lands this posts it on the phone. That works
/// while the app is open or in the background. Reaching a phone whose app has
/// been closed needs Firebase Cloud Messaging sent from a server (Cloud
/// Functions, on the paid Blaze plan), which this project does not use.
///
/// Nothing here runs until [init] is called from `main`, so widget and
/// integration tests, which never call it, are not shown system dialogs.
class LocalAlerts {
  LocalAlerts._();
  static final instance = LocalAlerts._();

  static const channelId = 'gather_updates';
  static const _channel = AndroidNotificationChannel(
    channelId,
    'Order and group updates',
    description: 'Your order being prepared, ready, on its way and delivered, '
        'and invitations to group orders.',
    importance: Importance.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  String? _launchRoute;

  /// Called with a notification's route when the person taps it.
  void Function(String route)? onOpen;

  /// Whether [init] succeeded. False on the web and in tests.
  bool get isReady => _ready;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_ready || !_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_gather'),
          // Asked for after sign-in instead, by [requestPermission].
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          final route = r.payload;
          if (route != null && route.isNotEmpty) onOpen?.call(route);
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      // Tapping a notification while the app was closed starts the app; the
      // route is kept until there is a signed-in screen to open it on.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchRoute = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// The route of the notification that started the app, once.
  String? takeLaunchRoute() {
    final route = _launchRoute;
    _launchRoute = null;
    return route;
  }

  /// Android 13 and later, and iOS, ask the person once.
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Notification permission not requested: $e');
    }
  }

  /// The titles now in the phone's notification shade from this app.
  /// Android only; used by the integration tests to see what was posted.
  Future<List<String>> activeTitles() async {
    if (!_ready) return const [];
    final active = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.getActiveNotifications();
    return [for (final n in active ?? const <ActiveNotification>[]) n.title ?? ''];
  }

  Future<void> show({
    required String id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id.hashCode & 0x7fffffff,
        title: title,
        body: body,
        payload: route,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            color: AppColors.primary,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Could not post a notification: $e');
    }
  }
}
