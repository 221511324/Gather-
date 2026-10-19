import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';

/// Profile home (FR2) and the hub for settings, help and admin.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
    final saved = ref.watch(savedSessionsProvider).valueOrNull ?? const [];
    final isAdmin = ref.watch(isAdminProvider);

    if (user == null) {
      return const BrandScaffold(title: 'Profile', child: LoadingView());
    }

    return BrandScaffold(
      title: 'Profile',
      leading: const SizedBox.shrink(),
      padBody: false,
      bandContent: Row(
        children: [
          MemberAvatar(
            uid: user.uid,
            initials: user.initials,
            photoUrl: user.photoUrl,
            size: 62,
            borderColor: Colors.white,
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.fullName.isEmpty ? user.username : user.fullName,
                  style: AppType.headline.copyWith(color: Colors.white, fontSize: 19),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${user.username}',
                  style: AppType.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(Routes.editProfile),
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
            tooltip: 'Edit profile',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 140),
        children: [
          Row(
            children: [
              _Stat(label: 'Orders', value: '${orders.length}', icon: Icons.receipt_long_rounded),
              const SizedBox(width: Insets.md),
              _Stat(
                label: 'Groups',
                value: '${saved.length}',
                icon: Icons.groups_rounded,
                onTap: () => context.go(Routes.group),
              ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
          const SectionHeader(title: 'Account'),
          _Group(
            children: [
              _Row(
                icon: Icons.person_outline_rounded,
                label: 'My profile',
                onTap: () => context.push(Routes.editProfile),
              ),
              _Row(
                icon: Icons.location_on_outlined,
                label: 'Delivery addresses',
                trailing: '${user.addresses.length}',
                onTap: () => context.push(Routes.addresses),
              ),
              _Row(
                icon: Icons.credit_card_rounded,
                label: 'Payment methods',
                onTap: () => context.push(Routes.paymentMethods),
              ),
              _Row(
                icon: Icons.favorite_border_rounded,
                label: 'Favourites',
                trailing: '${user.favoriteRestaurantIds.length + user.favoriteItemIds.length}',
                onTap: () => context.push(Routes.favorites),
              ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
          const SectionHeader(title: 'Activity'),
          _Group(
            children: [
              _Row(
                icon: Icons.receipt_long_outlined,
                label: 'My orders',
                onTap: () => context.go(Routes.orders),
              ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
          const SectionHeader(title: 'App'),
          _Group(
            children: [
              _Row(
                icon: Icons.help_outline_rounded,
                label: 'Help & support',
                onTap: () => context.push(Routes.help),
              ),
              if (isAdmin)
                _Row(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin dashboard',
                  color: AppColors.accentDeep,
                  onTap: () => context.push(Routes.admin),
                ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
          _Group(
            children: [
              _Row(
                icon: Icons.logout_rounded,
                label: 'Log out',
                color: AppColors.danger,
                showChevron: false,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text('You will need to sign in again to order.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Stay'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  ref.read(activeSessionIdProvider.notifier).state = null;
                  await ref.read(authServiceProvider).signOut();
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          Center(
            child: Text(
              'Gather · Senior Project · Prince Sultan University',
              style: AppType.overline.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon, this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GatherCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: Insets.lg),
          child: Column(
            children: [
              Icon(icon, size: 21, color: AppColors.primary),
              const SizedBox(height: Insets.sm),
              Text(value, style: AppType.title.copyWith(fontSize: 20)),
              Text(label, style: AppType.overline.copyWith(fontSize: 10)),
            ],
          ),
        ),
      );
}

/// A rounded group of rows, the way iOS settings lists read.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GatherCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 56),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailing;
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.lg),
          child: Row(
            children: [
              Icon(icon, size: 21, color: color ?? AppColors.inkMuted),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Text(
                  label,
                  style: AppType.bodyLarge.copyWith(
                    fontSize: 15,
                    color: color ?? AppColors.ink,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: AppType.caption.copyWith(fontSize: 13)),
              if (showChevron) ...[
                const SizedBox(width: Insets.xs),
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkFaint),
              ],
            ],
          ),
        ),
      );
}

/// Shared by the settings and help screens so every list looks the same.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => _Group(children: children);
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.color,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? trailing;
  final Color? color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => _Row(
        icon: icon,
        label: label,
        onTap: onTap,
        trailing: trailing,
        color: color,
        showChevron: showChevron,
      );
}
