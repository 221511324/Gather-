import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers/app_prefs.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Loaded before the first frame so the router can decide, without a flash,
  // whether to open onboarding or sign-in.
  final prefs = await AppPrefs.load();

  // The splash shows the logo immediately; decoding it lazily leaves an empty
  // card on screen for the first few frames.
  await Future.wait([
    _warmAsset('assets/images/logo.png'),
    _warmAsset('assets/images/logo_mark.png'),
  ]);

  runApp(
    ProviderScope(
      overrides: [appPrefsProvider.overrideWithValue(prefs)],
      child: const GatherApp(),
    ),
  );
}

/// Decodes an asset image into the cache before the first frame is drawn.
Future<void> _warmAsset(String asset) {
  final completer = Completer<void>();
  final stream = AssetImage(asset).resolve(ImageConfiguration.empty);

  late final ImageStreamListener listener;
  void finish() {
    if (!completer.isCompleted) completer.complete();
    stream.removeListener(listener);
  }

  listener = ImageStreamListener(
    (_, _) => finish(),
    // A missing or broken asset must not stop the app from starting.
    onError: (_, _) => finish(),
  );
  stream.addListener(listener);
  return completer.future;
}
