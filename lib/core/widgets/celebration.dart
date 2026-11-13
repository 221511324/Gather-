import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A burst of confetti, drawn on a canvas we own.
///
/// This replaces the `confetti` package, whose widget schedules a post-frame
/// callback on every build without a `mounted` guard — popping the route while
/// it is on screen throws "Looking up a deactivated widget's ancestor". Owning
/// the animation means the lifecycle is ours and that class of bug cannot
/// happen.
///
/// Increment [trigger] to fire a burst.
class Celebration extends StatefulWidget {
  const Celebration({
    super.key,
    required this.trigger,
    required this.colors,
    this.particleCount = 90,
    this.duration = const Duration(milliseconds: 2600),
  });

  /// Any change to this value starts a new burst.
  final int trigger;
  final List<Color> colors;
  final int particleCount;
  final Duration duration;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _random = math.Random();
  List<_Particle> _particles = const [];

  @override
  void initState() {
    super.initState();
    // Created here, not as a `late final` initialiser: a lazily-created
    // controller would be built for the first time inside dispose(), which
    // needs a Ticker from a widget that is already deactivated.
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(Celebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _burst();
  }

  void _burst() {
    setState(() {
      _particles = List.generate(widget.particleCount, (_) {
        // Fired upward and outward from the centre, then pulled down by
        // gravity in the painter.
        final angle = -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 1.1;
        final speed = 0.35 + _random.nextDouble() * 0.65;
        return _Particle(
          angle: angle,
          speed: speed,
          color: widget.colors[_random.nextInt(widget.colors.length)],
          size: 5 + _random.nextDouble() * 7,
          spin: (_random.nextDouble() - 0.5) * 10,
          drift: (_random.nextDouble() - 0.5) * 0.4,
          isCircle: _random.nextBool(),
          delay: _random.nextDouble() * 0.15,
        );
      });
    });
    _controller
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(progress: _controller.value, particles: _particles),
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
    required this.spin,
    required this.drift,
    required this.isCircle,
    required this.delay,
  });

  final double angle;
  final double speed;
  final Color color;
  final double size;
  final double spin;
  final double drift;
  final bool isCircle;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.34);
    final paint = Paint();

    for (final p in particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final reach = size.height * 0.85;
      final dx = math.cos(p.angle) * p.speed * reach * t + p.drift * reach * t * t;
      // Upward launch, then gravity takes over.
      final dy = math.sin(p.angle) * p.speed * reach * t + 1.7 * reach * t * t;

      // Fade out over the last third of the flight.
      final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(origin.dx + dx, origin.dy + dy);
      canvas.rotate(p.spin * t);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}
