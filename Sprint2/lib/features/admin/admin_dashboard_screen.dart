import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/state_views.dart';
import '../profile/profile_screen.dart';
import 'admin_shell.dart';

/// Admin overview (FR29–FR31).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);

    return AdminShell(
      title: 'Admin dashboard',
      subtitle: 'Platform overview',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(adminStatsProvider),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminStatsProvider),
        child: statsAsync.when(
          loading: () => const LoadingView(message: 'Loading platform figures…'),
          error: (e, _) => ErrorView(
            message: '$e',
            onRetry: () => ref.invalidate(adminStatsProvider),
          ),
          data: (stats) => ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.xl, Insets.gutter, Insets.xxxl),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: Insets.md,
                mainAxisSpacing: Insets.md,
                childAspectRatio: 1.32,
                children: [
                  StatTile(
                    label: 'TOTAL USERS',
                    value: '${stats.totalUsers}',
                    icon: Icons.people_alt_rounded,
                    footnote: stats.suspendedUsers > 0
                        ? '${stats.suspendedUsers} suspended'
                        : 'All active',
                    onTap: () => context.push(Routes.adminUsers),
                  ),
                  StatTile(
                    label: 'TOTAL ORDERS',
                    value: '${stats.totalOrders}',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.info,
                    footnote: '${stats.activeOrders} in progress',
                    onTap: () => context.push(Routes.adminOrders),
                  ),
                  StatTile(
                    label: 'GROUP ORDERS',
                    value: '${stats.groupOrders}',
                    icon: Icons.groups_rounded,
                    color: AppColors.coral,
                    footnote: '${(stats.groupShare * 100).toStringAsFixed(0)}% of all orders',
                  ),
                  StatTile(
                    label: 'REVENUE',
                    value: Money.whole(stats.revenue),
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                    footnote: 'Excluding cancelled',
                  ),
                  StatTile(
                    label: 'LIVE SESSIONS',
                    value: '${stats.liveSessions}',
                    icon: Icons.sensors_rounded,
                    color: AppColors.accentDeep,
                    onTap: () => context.push(Routes.adminSessions),
                  ),
                  StatTile(
                    label: 'OPEN TICKETS',
                    value: '${stats.openTickets}',
                    icon: Icons.support_agent_rounded,
                    color: stats.openTickets > 0 ? AppColors.danger : AppColors.inkMuted,
                    onTap: () => context.push(Routes.adminTickets),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xxl),
              const SectionHeader(title: 'Manage'),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.storefront_outlined,
                    label: 'Restaurants & menus',
                    onTap: () => context.push(Routes.adminRestaurants),
                  ),
                  SettingsRow(
                    icon: Icons.people_alt_outlined,
                    label: 'User accounts',
                    onTap: () => context.push(Routes.adminUsers),
                  ),
                  SettingsRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Order monitoring',
                    onTap: () => context.push(Routes.adminOrders),
                  ),
                  SettingsRow(
                    icon: Icons.groups_outlined,
                    label: 'Group sessions',
                    onTap: () => context.push(Routes.adminSessions),
                  ),
                  SettingsRow(
                    icon: Icons.support_agent_outlined,
                    label: 'Support tickets',
                    trailing: stats.openTickets > 0 ? '${stats.openTickets} open' : null,
                    onTap: () => context.push(Routes.adminTickets),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xxl),
              GatherCard(
                color: AppColors.primaryTint,
                shadows: const [],
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 19, color: AppColors.primary),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        'These figures are read directly from the live database each '
                        'time you open or refresh this screen.',
                        style: AppType.caption.copyWith(
                          color: AppColors.primaryDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
