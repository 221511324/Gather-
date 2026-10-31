import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing, radii and elevation tokens.
///
/// The reference design leans on generous rounding — pill buttons, ~20px
/// cards and a ~40px sheet radius where the content overlaps the brand band.
abstract final class Insets {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Horizontal page gutter used by every screen.
  static const gutter = 20.0;
}

abstract final class Radii {
  static const xs = 4.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;

  /// The radius where a content sheet overlaps the brand band.
  static const sheet = 36.0;

  static const pill = 999.0;

  static final brSm = BorderRadius.circular(sm);
  static final brMd = BorderRadius.circular(md);
  static final brLg = BorderRadius.circular(lg);
  static final brXl = BorderRadius.circular(xl);
  static final brPill = BorderRadius.circular(pill);

  static const sheetTop = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}

abstract final class Shadows {
  /// Soft ambient lift for cards sitting on the off-white background.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x14184248), blurRadius: 18, offset: Offset(0, 6)),
  ];

  /// Stronger lift for the floating bottom navigation bar.
  static const floating = <BoxShadow>[
    BoxShadow(color: Color(0x33CC4A12), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const sheet = <BoxShadow>[
    BoxShadow(color: Color(0x16184248), blurRadius: 28, offset: Offset(0, -4)),
  ];

  static List<BoxShadow> glow(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 20, offset: const Offset(0, 8)),
      ];
}

/// Motion durations — kept short so the app feels responsive against the
/// 3-second interaction budget in the requirements.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}

extension ColorShade on Color {
  Color get onColor {
    final luminance = computeLuminance();
    return luminance > 0.55 ? AppColors.ink : Colors.white;
  }
}
