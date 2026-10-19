import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/providers.dart';
import 'router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class GatherApp extends ConsumerStatefulWidget {
  const GatherApp({super.key});

  @override
  ConsumerState<GatherApp> createState() => _GatherAppState();
}

class _GatherAppState extends ConsumerState<GatherApp> {
  bool _seedAttempted = false;

  /// Writes the starter catalogue the first time anyone signs in to an empty
  /// project. The security rules only open the catalogue for writing while
  /// `meta/seed` is absent, so this is a one-shot bootstrap rather than a
  /// standing permission.
  void _seedOnce() {
    if (_seedAttempted) return;
    _seedAttempted = true;
    ref.read(seedServiceProvider).seedIfNeeded().catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      if (next.valueOrNull != null) _seedOnce();
    });
    if (ref.read(authStateProvider).valueOrNull != null) _seedOnce();

    final router = ref.watch(routerProvider);

    // The language chosen in settings drives Material's own strings and the
    // layout direction. Gather's own copy is English only for now.
    final language = ref.watch(currentUserProvider).valueOrNull?.settings.language ?? 'en';

    return MaterialApp.router(
      title: 'Gather',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: Locale(language),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep the layout predictable if the device is set to a very large
        // font scale — the design relies on fixed-height bands and pills.
        final media = MediaQuery.of(context);
        final scaled = MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
          ),
          child: child ?? const SizedBox.shrink(),
        );

        // On a monitor the screens would otherwise stretch to the full width
        // and a text field would run for 2000 pixels. Hold the console to a
        // page width and centre it.
        if (!kIsWeb) return scaled;
        return ColoredBox(
          color: AppColors.line,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Material(color: AppColors.background, child: scaled),
            ),
          ),
        );
      },
    );
  }
}
