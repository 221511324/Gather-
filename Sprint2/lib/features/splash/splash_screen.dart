import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// Shown while Firebase reports the initial auth state. The router redirects
/// away as soon as that settles.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.band,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.bandGradient),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GatherLogo(size: 150),
                SizedBox(height: Insets.xxxl),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The Gather logo.
///
/// The mark is deep teal with warm figures, so it needs a light surface to sit
/// on. [onLight] renders it directly; otherwise it is lifted onto a rounded
/// white card so it stays legible over the orange brand band.
class GatherLogo extends StatelessWidget {
  const GatherLogo({
    super.key,
    this.size = 120,
    this.onLight = false,
    this.markOnly = false,
  });

  final double size;
  final bool onLight;

  /// Drops the "gather" wordmark and shows only the plate mark.
  final bool markOnly;

  @override
  Widget build(BuildContext context) => Image.asset(
        markOnly ? 'assets/images/logo_mark.png' : 'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        // The card and the mark appear together. Wrapping only the image would
        // flash an empty white box while the asset decodes.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          final content = onLight ? child : _LogoCard(size: size, child: child);
          if (wasSynchronouslyLoaded) return content;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: Motion.normal,
            curve: Motion.curve,
            child: content,
          );
        },
      );
}

/// The white plate the mark sits on when shown over the orange band.
class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(size * 0.16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );
}
