import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import 'spin_clock.dart';

/// FR25 — the way into Spin & Win, for the home page and the rewards screen.
///
/// Says "your free spin is ready" when it is, and counts down to the next
/// one when it is not. Tapping it opens the wheel either way.
class SpinWinBanner extends ConsumerWidget {
  const SpinWinBanner({super.key, this.margin = EdgeInsetsDirectional.zero, this.onTap});

  final EdgeInsetsGeometry margin;

  /// Defaults to opening the wheel.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentUidProvider) == null) return const SizedBox.shrink();

    return Padding(
      padding: margin,
      child: SpinClock(
        builder: (context, remaining) {
          final ready = remaining == Duration.zero;
          return Material(
            color: Colors.transparent,
            borderRadius: Radii.brLg,
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: ready ? AppColors.bandGradient : null,
                color: ready ? null : AppColors.surface,
                borderRadius: Radii.brLg,
                boxShadow: Shadows.card,
              ),
              child: InkWell(
                key: const ValueKey('spin-win-banner'),
                onTap: onTap ?? () => context.push(Routes.spin),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: ready ? Colors.white.withValues(alpha: 0.22) : AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.casino_rounded,
                          color: ready ? Colors.white : AppColors.accentDeep,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr('Spin & Win'),
                              style: AppType.headline.copyWith(
                                color: ready ? Colors.white : AppColors.ink,
                              ),
                            ),
                            Text(
                              ready
                                  ? context.tr('Your free spin is ready')
                                  : context.tr('Next spin in {time}',
                                      {'time': spinCountdownText(context, remaining)}),
                              style: AppType.caption.copyWith(
                                color: ready ? Colors.white : AppColors.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: ready ? Colors.white : AppColors.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
