import 'package:flutter/material.dart';

/// Gather's colour identity, taken straight from the logo.
///
/// The mark is a plate formed by a "G", with three people around it in orange,
/// red and yellow, and a deep teal wordmark. Those four colours are the whole
/// palette: warm orange carries the brand, the yellow marks rewards and
/// prices, and the wordmark's teal is the ink everything is written in. The
/// app sits on a very light beige rather than white so the warm colours read
/// as intentional rather than loud.
abstract final class AppColors {
  // ---------------------------------------------------------------- brand ---
  /// Header band / hero surfaces. The gradient runs from the logo's orange
  /// figure toward its red one.
  static const band = Color(0xFFF5901F);
  static const bandDeep = Color(0xFFDE4E16);
  static const bandSoft = Color(0xFFFFDCB0);

  /// Primary actions: buttons, bottom nav, active states. Deeper than the band
  /// so white label text clears the 4.5:1 contrast bar.
  static const primary = Color(0xFFCC4A12);
  static const primaryDark = Color(0xFFA63A0C);
  static const primarySoft = Color(0xFFFCE6D2);
  static const primaryTint = Color(0xFFFEF4EA);

  /// The logo's yellow. Rewards, prices, spin wheels — anything celebratory.
  static const accent = Color(0xFFF8C61C);
  static const accentDeep = Color(0xFFB07C00);
  static const accentSoft = Color(0xFFFEF2CC);

  /// The logo's red figure, for food-forward highlights.
  static const coral = Color(0xFFF84830);
  static const coralSoft = Color(0xFFFFE0D9);

  // ------------------------------------------------------------- neutrals ---
  /// The wordmark's deep teal. Warm oranges need a cool, dark ink to sit
  /// against, and using the logo's own colour keeps the whole app on-brand.
  static const ink = Color(0xFF184248);
  static const inkMuted = Color(0xFF5A7178);
  static const inkFaint = Color(0xFF97A9AE);
  static const line = Color(0xFFEBDCC4);

  /// Cards are a warm off-white rather than pure white, so they lift off the
  /// beige page without introducing a cold surface.
  static const surface = Color(0xFFFFFCF6);
  static const surfaceAlt = Color(0xFFF4E6D0);

  /// The light beige everything sits on. Warm enough to actually read as
  /// beige — an almost-white tint just looks like white on a phone.
  static const background = Color(0xFFF9EFDF);

  // ------------------------------------------------------------- semantic ---
  // Deliberately not brand colours: a success or an error has to read as
  // itself, not as part of the palette.
  static const success = Color(0xFF1B8A55);
  static const successSoft = Color(0xFFE3F4EB);
  static const warning = Color(0xFFCC7A00);
  static const warningSoft = Color(0xFFFDF0DA);
  static const danger = Color(0xFFC62828);
  static const dangerSoft = Color(0xFFFBE6E6);
  static const info = Color(0xFF2563EB);
  static const infoSoft = Color(0xFFE8F0FE);

  // --------------------------------------------------------------- extras ---
  static const bandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [band, bandDeep],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD84D), accent],
  );

  /// Stable, pleasant colours for member avatars in a group session. Led by
  /// the logo's three figures, then widened so a large group stays legible.
  static const memberPalette = <Color>[
    Color(0xFFCC4A12),
    Color(0xFFF84830),
    Color(0xFF184248),
    Color(0xFFD99400),
    Color(0xFF7C5CD6),
    Color(0xFF2E86C1),
    Color(0xFF1B8A55),
    Color(0xFFB5567F),
  ];

  /// Deterministic avatar colour for a user id, so a member keeps the same
  /// colour everywhere in the app (shared cart, lobby, payment status).
  static Color memberColor(String seed) {
    if (seed.isEmpty) return memberPalette.first;
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return memberPalette[hash % memberPalette.length];
  }
}
