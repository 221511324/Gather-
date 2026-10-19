import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/driver_simulator.dart';
import '../../core/services/result.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/state_views.dart';
import 'admin_shell.dart';

/// Order monitoring (FR31 / US17-AC2).
///
/// Advancing an order's status is normally the restaurant's job; here it is
/// the admin's, which is what makes the delivery lifecycle demonstrable.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(adminOrdersProvider);

    return AdminShell(
      title: 'Order monitoring',
      child: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (orders) {
          final filtered =
              _filter == null ? orders : orders.where((o) => o.status == _filter).toList();

          return Column(
            children: [
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.md, Insets.gutter, 0),
                  children: [
                    _Chip(
                      label: 'All (${orders.length})',
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final status in OrderStatus.values)
                      _Chip(
                        label: '${status.label} '
                            '(${orders.where((o) => o.status == status).length})',
                        selected: _filter == status,
                        onTap: () => setState(() => _filter = _filter == status ? null : status),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyView(
                        icon: Icons.receipt_long_outlined,
                        title: 'No orders here',
                        message: 'Nothing matches this filter yet.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.gutter, Insets.md, Insets.gutter, Insets.xxl),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
                        itemBuilder: (context, i) => _AdminOrderCard(order: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          backgroundColor: AppColors.surface,
          labelStyle: AppType.label.copyWith(
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      );
}

class _AdminOrderCard extends ConsumerWidget {
  const _AdminOrderCard({required this.order});

  final FoodOrder order;

  static Color colorFor(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => AppColors.info,
        OrderStatus.preparing => AppColors.accentDeep,
        OrderStatus.onTheWay => AppColors.primary,
        OrderStatus.delivered => AppColors.success,
        OrderStatus.cancelled => AppColors.danger,
      };

  OrderStatus? get _next => switch (order.status) {
        OrderStatus.confirmed => OrderStatus.preparing,
        OrderStatus.preparing => OrderStatus.onTheWay,
        OrderStatus.onTheWay => OrderStatus.delivered,
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        onTap: () => context.push(Routes.order(order.id)),
        child: Column(
          children: [
            Row(
              children: [
                FoodImage(
                  url: order.restaurantImageUrl,
                  width: 46,
                  height: 46,
                  radius: Radii.sm,
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
                              order.restaurantName,
                              style: AppType.bodyStrong,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.isGroupOrder)
                            const StatusPill(
                              label: 'Group',
                              color: AppColors.primary,
                              compact: true,
                            ),
                        ],
                      ),
                      Text(
                        '#${order.id.substring(0, 8).toUpperCase()} · '
                        '${order.itemCount} items · ${order.participants.length} '
                        '${order.participants.length == 1 ? 'person' : 'people'}',
                        style: AppType.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  compact: true,
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  Money.format(order.total),
                  style: AppType.money.copyWith(fontSize: 14, color: AppColors.primary),
                ),
                const Spacer(),
                // Driver tracking (US11) has no driver app behind it, so the
                // admin walks the simulated driver along the route from here —
                // that is what the customer's tracking map reacts to.
                if (order.status.isActive)
                  IconButton(
                    onPressed: () async {
                      final result = await DriverSimulator.step(
                        service: ref.read(orderServiceProvider),
                        order: order,
                      );
                      if (!context.mounted) return;
                      switch (result) {
                        case Err(:final message):
                          AppSnack.error(context, message);
                        case Ok(:final value):
                          AppSnack.show(context, 'Driver: ${value.label}');
                      }
                    },
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                    icon: const Icon(Icons.delivery_dining_rounded),
                    color: order.driverStage == null ? AppColors.inkFaint : AppColors.primary,
                    tooltip: order.driverStage == null
                        ? 'Assign a simulated driver'
                        : 'Move driver · ${order.driverStage!.label}',
                  ),
                if (_next != null)
                  TextButton.icon(
                    onPressed: () async {
                      final next = _next!;
                      final result = await ref
                          .read(orderServiceProvider)
                          .advanceStatus(orderId: order.id, status: next);
                      if (!context.mounted) return;
                      switch (result) {
                        case Err(:final message):
                          AppSnack.error(context, message);
                        case Ok():
                          if (context.mounted) {
                            AppSnack.show(context, 'Moved to ${next.label}');
                          }
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      _next!.label,
                      style: AppType.label.copyWith(fontSize: 12.5),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
