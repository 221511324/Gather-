import 'package:flutter/foundation.dart' show kIsWeb;
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

    final user = userAsync.valueOrNull;

    return BrandScaffold(
      title: title,
      subtitle: subtitle,
      // On the web console there is nowhere to go back to — the browser only
      // ever shows the admin area — so the arrow would be a dead control.
      showBack: !kIsWeb,
      padBody: padBody,
      actions: [
        ...?actions,
        // Without this the console is a one-way door: you can sign in and
        // never sign out, and there is no customer app to leave through.
        if (user != null && user.isAdmin)
          _SignOutButton(email: user.email, ref: ref),
      ],
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

/// Signs the administrator out, with a confirmation so a stray tap during a
/// demonstration does not end the session.
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.email, required this.ref});

  final String email;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Account',
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_circle_outlined,
              size: 21, color: Colors.white),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: Text('Signed in as $email', style: AppType.caption),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'out',
            child: Text('Sign out', style: TextStyle(color: AppColors.danger)),
          ),
        ],
        onSelected: (v) async {
          if (v != 'out') return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign out?'),
              content: const Text('You will need the administrator '
                  'credentials to get back in.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Stay'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          await ref.read(authServiceProvider).signOut();
        },
      );
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
