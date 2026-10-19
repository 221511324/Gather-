import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/state_views.dart';

/// Wraps every admin screen with the authorisation check (FR29, US17-AC6).
///
/// Access is decided by the `role` field on the user's own profile document,
/// which only another admin can change. The Firestore rules enforce the same
/// thing server-side — this widget is the UI half of that.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.bandContent,
    this.padBody = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bandContent;
  final bool padBody;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return BrandScaffold(
      title: title,
      subtitle: subtitle,
      showBack: true,
      padBody: padBody,
      actions: actions,
      bandContent: bandContent,
      child: userAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (user) {
          if (user == null || !user.isAdmin) {
            return const EmptyView(
              icon: Icons.lock_outline_rounded,
              title: 'Admins only',
              message: 'This area is restricted to authorised administrators.',
            );
          }
          return child;
        },
      ),
    );
  }
}

/// A labelled metric tile for the dashboard.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.footnote,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? footnote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;

    return GatherCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: Radii.brSm,
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkFaint),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(value, style: AppType.title.copyWith(fontSize: 24)),
          Text(label, style: AppType.overline.copyWith(fontSize: 10)),
          if (footnote != null) ...[
            const SizedBox(height: 2),
            Text(footnote!, style: AppType.caption.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
