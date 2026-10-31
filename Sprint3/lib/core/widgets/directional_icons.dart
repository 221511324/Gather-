import 'package:flutter/widgets.dart';

/// Material icons that point one way but which Flutter's [Icons] does not
/// mark to mirror. These copies are drawn the other way round when the
/// screen reads right to left, as [Icons.arrow_forward_rounded] and
/// [Icons.chevron_right_rounded] already are.
///
/// Each is the same glyph as its [Icons] original (a test checks the code
/// points), and is const so icon tree shaking still finds it.
abstract final class DirectionalIcons {
  /// [Icons.logout_rounded]: the arrow leaves through the door at the end of
  /// the line.
  static const IconData logout =
      IconData(0xf88b, fontFamily: 'MaterialIcons', matchTextDirection: true);
}
