import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale.
///
/// League Spartan is the typeface from the reference design system — a
/// geometric sans that stays friendly at display sizes and legible at 14sp.
/// The four sizes called out in that system (28 bold screen title, 24 bold
/// title, 20 medium subtitle, 14 light paragraph) are the anchors; the rest of
/// the ramp is filled in around them.
abstract final class AppType {
  static const family = 'LeagueSpartan';

  static const _base = TextStyle(
    fontFamily: family,
    color: AppColors.ink,
    height: 1.25,
    letterSpacing: 0,
  );

  /// 34/800 — reserved for the launch and onboarding hero lines.
  static final display = _base.copyWith(fontSize: 34, fontWeight: FontWeight.w800, height: 1.15);

  /// 28/700 — the screen title anchor.
  static final screenTitle = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.18);

  /// 24/700 — section and card titles.
  static final title = _base.copyWith(fontSize: 24, fontWeight: FontWeight.w700, height: 1.2);

  /// 20/500 — the subtitle anchor.
  static final subtitle = _base.copyWith(fontSize: 20, fontWeight: FontWeight.w500, height: 1.25);

  static final headline = _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);
  static final bodyLarge = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);
  static final bodyStrong = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);

  /// 14/300 — the paragraph anchor.
  static final body = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w300, height: 1.45);
  static final label = _base.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3);
  static final caption =
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.35, color: AppColors.inkMuted);
  static final overline = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.6,
    color: AppColors.inkMuted,
  );

  /// Button text — pill buttons in this design use a confident bold.
  static final button = _base.copyWith(fontSize: 17, fontWeight: FontWeight.w700, height: 1.1);

  /// Numerals that need to line up in columns (totals, split amounts).
  static final money = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
