import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local preferences that have to be known before the first frame —
/// whether onboarding has been shown — and which food stories this device has
/// already watched (US19), which is per device by design, like a read marker.
class AppPrefs {
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingKey = 'onboarding_seen';

  bool get hasSeenOnboarding => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> markOnboardingSeen() => _prefs.setBool(_onboardingKey, true);

  static const _seenStoriesKey = 'seen_story_ids';

  List<String> get seenStoryIds => _prefs.getStringList(_seenStoriesKey) ?? const [];

  Future<void> setSeenStoryIds(List<String> ids) =>
      _prefs.setStringList(_seenStoriesKey, ids);

  static Future<AppPrefs> load() async => AppPrefs(await SharedPreferences.getInstance());
}

/// Overridden in `main()` once the real instance has loaded.
final appPrefsProvider = Provider<AppPrefs>(
  (ref) => throw UnimplementedError('appPrefsProvider must be overridden'),
);

/// Mirrors [AppPrefs.hasSeenOnboarding] so the router can react when it flips.
final onboardingSeenProvider = StateProvider<bool>(
  (ref) => ref.watch(appPrefsProvider).hasSeenOnboarding,
);
