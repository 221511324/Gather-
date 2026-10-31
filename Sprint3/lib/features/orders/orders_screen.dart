import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/ar/qa1.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/state_views.dart';

/// Order history, split into what is happening now and what has finished
/// (FR22 / US10).
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // Created here, not as a `late final` initialiser: a lazily-created
    // controller would be built for the first time inside dispose(), which
    // needs a Ticker from a widget that is already deactivated.
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(myOrdersProvider);
    final active = ref.watch(activeOrdersProvider);
    final past = ref.watch(pastOrdersProvider);

    return BrandScaffold(
      title: 'My orders',
      leading: const SizedBox.shrink(),
      padBody: false,
      bandContent: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: Radii.brPill,
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(color: Colors.white, borderRadius: Radii.brPill),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white,
          labelStyle: AppType.label,
          unselectedLabelStyle: AppType.body.copyWith(fontSize: 14),
          tabs: [
            Tab(text: context.tr('Active ({count})', {'count': active.length})),
            Tab(text: context.tr('History ({count})', {'count': past.length})),
          ],
        ),
      ),
      child: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (_) => TabBarView(
          controller: _tabs,
          children: [
            _OrderList(
              orders: active,
              emptyIcon: Icons.delivery_dining_outlined,
              emptyTitle: 'Nothing on the way',
              emptyMessage: 'Your active orders will appear here so you can track them.',
            ),
            _OrderList(
              orders: past,
              emptyIcon: Icons.history_rounded,
              emptyTitle: 'No past orders',
              emptyMessage: 'Once an order is delivered it moves here.',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<FoodOrder> orders;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyView(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: 'Browse restaurants',
        onAction: () => context.go(Routes.search),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 140),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
      itemBuilder: (context, i) => OrderCard(order: orders[i]),
    );
  }
}

/// One order row, reused by history, the profile summary and the admin list.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onTap});

  final FoodOrder order;
  final VoidCallback? onTap;

  static Color colorFor(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => AppColors.info,
        OrderStatus.preparing => AppColors.accentDeep,
        OrderStatus.onTheWay => AppColors.primary,
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.danger,
      };

  static IconData iconFor(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_rounded,
        OrderStatus.preparing => Icons.soup_kitchen_rounded,
        OrderStatus.onTheWay => Icons.delivery_dining_rounded,
        OrderStatus.delivered => Icons.check_circle_rounded,
        OrderStatus.cancelled => Icons.cancel_rounded,
      };

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap ??
            () => context.push(
                  order.status.isActive ? Routes.trackOrder(order.id) : Routes.order(order.id),
                ),
        child: Column(
          children: [
            Row(
              children: [
                FoodImage(
                  url: order.restaurantImageUrl,
                  width: 54,
                  height: 54,
                  radius: Radii.md,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.isolate(order.restaurantName),
                              style: AppType.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.isGroupOrder)
                            const Padding(
                              padding: EdgeInsetsDirectional.only(start: Insets.sm),
                              child: StatusPill(
                                label: 'Group|order type',
                                color: AppColors.primary,
                                icon: Icons.groups_rounded,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.itemCount == 1 ? context.tr('1 item') : context.tr('{count} items|${countNote(order.itemCount)}', {'count': order.itemCount})} · '
                        '${_when(context, order.placedAt)}',
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.md),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                StatusPill(
                  label: order.status.label,
                  color: colorFor(order.status),
                  icon: iconFor(order.status),
                ),
                const Spacer(),
                Text(
                  Money.format(order.total),
                  style: AppType.money.copyWith(fontSize: 16, color: AppColors.primary),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
              ],
            ),
          ],
        ),
      );

  static String _when(BuildContext context, DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return context.tr('just now');
    if (diff.inMinutes < 60) return context.tr('{n} min ago', {'n': diff.inMinutes});
    if (diff.inHours < 24) return context.tr('{n}h ago', {'n': diff.inHours});
    if (diff.inDays == 1) return context.tr('yesterday');
    if (diff.inDays < 7) return context.tr('{n} days ago|${countNote(diff.inDays)}', {'n': diff.inDays});
    return Dates.dayMonthYear(context, date);
  }
}
