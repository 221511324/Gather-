import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// A labelled prize wheel.
///
/// Shared by Restaurant Spin (FR10) and Spin & Win (FR25). The winner is
/// decided before the animation starts — the spin is presentation, and
/// computing the result up front keeps it honest and testable.
class SpinWheel extends StatelessWidget {
  const SpinWheel({
    super.key,
    required this.labels,
    required this.rotation,
    this.colors,
    this.size = 300,
    this.centerIcon = Icons.restaurant_rounded,
  });

  final List<String> labels;

  /// Current rotation in radians, driven by the caller's animation.
  final double rotation;
  final List<Color>? colors;
  final double size;
  final IconData centerIcon;

  /// The wedge palette. Alternating tints keep neighbouring slices readable.
  static const defaultColors = <Color>[
    AppColors.primary,
    AppColors.accent,
    AppColors.coral,
    AppColors.ink,
    AppColors.band,
    Color(0xFF7C5CD6),
    AppColors.bandDeep,
    Color(0xFF2E86C1),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size + 18,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 18,
              child: Transform.rotate(
                angle: rotation,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _WheelPainter(
                      labels: labels,
                      colors: colors ?? defaultColors,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),
            ),
            // Hub.
            Positioned(
              top: 18 + size / 2 - 26,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(centerIcon, size: 24, color: AppColors.primary),
              ),
            ),
            // The pointer at 12 o'clock — whatever sits under it wins.
            Positioned(
              top: 0,
              child: CustomPaint(size: const Size(28, 30), painter: _PointerPainter()),
            ),
          ],
        ),
      );
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.labels, required this.colors, required this.textDirection});

  final List<String> labels;
  final List<Color> colors;

  /// The labels' own reading direction. The wheel's geometry never mirrors,
  /// but an Arabic label laid out left to right comes out as "%خصم 5".
  final TextDirection textDirection;

  /// The hub drawn over the middle of the wheel, plus a little air.
  static const _hubClearance = 26.0 + 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweep = 2 * math.pi / labels.length;

    for (var i = 0; i < labels.length; i++) {
      // Start at 12 o'clock so wedge 0 is under the pointer at rotation 0.
      final start = -math.pi / 2 - sweep / 2 + i * sweep;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = colors[i % colors.length],
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      _paintLabel(canvas, center, radius, start + sweep / 2, labels[i], sweep);
    }

    // Rim.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
  }

  void _paintLabel(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    String label,
    double sweep,
  ) {
    // Long names are trimmed rather than allowed to overlap the neighbouring
    // wedge — the wheel has to stay readable at six or eight slices.
    final maxChars = (sweep * 14).clamp(6, 18).toInt();
    final text = label.length > maxChars ? '${label.substring(0, maxChars - 1)}…' : label;

    // The label sits between the hub and the rim. The hub is a fixed size, so
    // on a small wheel a share of the radius would slide under it. A label
    // that does not fit shrinks before it is cut.
    final inner = _hubClearance;
    final outer = radius - 8;
    final room = outer - inner;
    TextPainter paintAt(double size) => TextPainter(
          text: TextSpan(
            text: text,
            style: AppType.label.copyWith(color: Colors.white, fontSize: size, letterSpacing: 0),
          ),
          textDirection: textDirection,
          maxLines: 1,
        );
    final natural = paintAt(13)..layout();
    final size = natural.width <= room ? 13.0 : (13 * room / natural.width).clamp(9.0, 13.0);
    natural.dispose();
    final painter = paintAt(size)..layout(maxWidth: room);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    // Push the label out along the radius, then flip it upright on the left
    // half of the wheel so nothing reads upside down.
    final flip = angle > math.pi / 2 && angle < 3 * math.pi / 2;
    canvas.translate((inner + outer) / 2, 0);
    if (flip) canvas.rotate(math.pi);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.labels != labels ||
      oldDelegate.colors != colors ||
      oldDelegate.textDirection != textDirection;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawShadow(path, AppColors.ink.withValues(alpha: 0.4), 3, false);
    canvas.drawPath(path, Paint()..color = AppColors.ink);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Computes the rotation that lands [winnerIndex] under the pointer.
///
/// [turns] full revolutions are added so the wheel visibly spins before
/// settling on the pre-decided winner.
double rotationForWinner({
  required int winnerIndex,
  required int wedgeCount,
  int turns = 5,
}) {
  if (wedgeCount <= 0) return 0;
  final sweep = 2 * math.pi / wedgeCount;
  // Rotating backwards by the winner's angle brings that wedge to 12 o'clock.
  return turns * 2 * math.pi - winnerIndex * sweep;
}
