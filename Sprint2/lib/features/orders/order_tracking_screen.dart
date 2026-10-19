import 'package:flutter/foundation.dart';
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
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import 'driver_map_card.dart';

/// Live order tracking (FR19 / US10).
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));

    return orderAsync.when(
      loading: () => const BrandScaffold(title: 'Tracking', showBack: true, child: LoadingView()),
      error: (e, _) =>
          BrandScaffold(title: 'Tracking', showBack: true, child: ErrorView(message: '$e')),
      data: (order) {
        if (order == null) {
          return const BrandScaffold(
            title: 'Tracking',
            showBack: true,
            child: EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'It may have been removed.',
            ),
          );
        }

        return BrandScaffold(
          title: 'Order tracking',
          showBack: true,
          padBody: false,
          bandContent: _BandStatus(order: order),
          bottomBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
            child: Row(
              children: [
                Expanded(
                  child: GatherOutlineButton(
                    label: 'Order details',
                    icon: Icons.receipt_long_rounded,
                    onPressed: () => context.pushReplacement(Routes.order(order.id)),
                  ),
                ),
                if (order.canCancel) ...[
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: GatherOutlineButton(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      color: AppColors.danger,
                      onPressed: () => _cancel(context, ref, order),
                    ),
                  ),
                ],
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
            children: [
              // Shown only once a driver has actually reported a position —
              // without one there is nothing to plot, and the timeline below
              // already tells the whole story.
              if (order.status != OrderStatus.cancelled && order.hasDriverPosition) ...[
                DriverMapCard(order: order),
                const SizedBox(height: Insets.xxl),
              ],
              _Timeline(order: order),
              const SizedBox(height: Insets.xxl),
              GatherCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Detail(
                      icon: Icons.storefront_rounded,
                      label: 'RESTAURANT',
                      value: order.restaurantName,
                    ),
                    const SizedBox(height: Insets.lg),
                    _Detail(
                      icon: Icons.location_on_outlined,
                      label: 'DELIVERING TO',
                      value: order.deliveryAddress.isEmpty
                          ? 'No address on file'
                          : order.deliveryAddress,
                    ),
                    const SizedBox(height: Insets.lg),
                    _Detail(
                      icon: Icons.payments_outlined,
                      label: 'PAID WITH',
                      value: order.paymentMethodLabel.isEmpty
                          ? 'Not recorded'
                          : order.paymentMethodLabel,
                    ),
                    if (order.isGroupOrder) ...[
                      const SizedBox(height: Insets.lg),
                      _Detail(
                        icon: Icons.groups_rounded,
                        label: 'GROUP',
                        value: '${order.sessionName ?? 'Group order'} · '
                            '${order.participants.length} people · '
                            '${order.paymentMode?.shortLabel ?? ''}',
                      ),
                    ],
                  ],
                ),
              ),
              if (order.isGroupOrder && order.participants.isNotEmpty) ...[
                const SizedBox(height: Insets.xxl),
                const SectionHeader(title: 'Who paid what'),
                for (final p in order.participants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: GatherCard(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        children: [
                          MemberAvatar(uid: p.uid, initials: _initials(p.name), size: 32),
                          const SizedBox(width: Insets.md),
                          Expanded(child: Text(p.name, style: AppType.bodyLarge.copyWith(fontSize: 15))),
                          Text(Money.format(p.amount), style: AppType.money.copyWith(fontSize: 14)),
                          const SizedBox(width: Insets.sm),
                          Icon(
                            p.paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            size: 18,
                            color: p.paid ? AppColors.success : AppColors.inkFaint,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              // Stepping an order forward is the restaurant's job; the admin
              // dashboard does it for real. This shortcut exists only in debug
              // builds so the flow can be demonstrated end to end.
              if (kDebugMode && order.status.isActive) ...[
                const SizedBox(height: Insets.xxl),
                GatherOutlineButton(
                  label: 'Simulate next step (debug)',
                  icon: Icons.fast_forward_rounded,
                  color: AppColors.inkMuted,
                  onPressed: () => _advance(ref, order),
                ),
                const SizedBox(height: Insets.sm),
                // The driver side of the same shortcut: there is no driver app,
                // so this is what makes the map move during a demo. The admin
                // order screen has the same control for release builds.
                GatherOutlineButton(
                  label: order.driverStage == null
                      ? 'Assign a driver (debug)'
                      : 'Move driver (debug)',
                  icon: Icons.delivery_dining_rounded,
                  color: AppColors.inkMuted,
                  onPressed: () => _stepDriver(context, ref, order),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  Future<void> _advance(WidgetRef ref, FoodOrder order) async {
    final next = switch (order.status) {
      OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.onTheWay,
      OrderStatus.onTheWay => OrderStatus.delivered,
      _ => null,
    };
    if (next == null) return;
    await ref.read(orderServiceProvider).advanceStatus(orderId: order.id, status: next);
  }

  Future<void> _stepDriver(BuildContext context, WidgetRef ref, FoodOrder order) async {
    final result = await DriverSimulator.step(
      service: ref.read(orderServiceProvider),
      order: order,
    );
    if (!context.mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok(:final value):
        AppSnack.show(context, value.label);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, FoodOrder order) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancelDialog(),
    );
    if (reason == null) return;

    final result =
        await ref.read(orderServiceProvider).cancelOrder(orderId: order.id, reason: reason);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        if (context.mounted) AppSnack.show(context, 'Order cancelled');
    }
  }
}

class _BandStatus extends StatelessWidget {
  const _BandStatus({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final eta = order.estimatedArrival;
    final etaText = eta == null || !order.status.isActive
        ? order.status.label
        : 'Arriving around ${eta.hour.toString().padLeft(2, '0')}:'
            '${eta.minute.toString().padLeft(2, '0')}';

    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Icon(
            OrderCardIcons.iconFor(order.status),
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.status.label,
                style: AppType.headline.copyWith(color: Colors.white, fontSize: 19),
              ),
              const SizedBox(height: 2),
              Text(
                etaText,
                style: AppType.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small indirection so the tracking screen does not import the orders list
/// just for two switch statements.
abstract final class OrderCardIcons {
  static IconData iconFor(OrderStatus status) => switch (status) {
        OrderStatus.confirmed => Icons.receipt_long_rounded,
        OrderStatus.preparing => Icons.soup_kitchen_rounded,
        OrderStatus.onTheWay => Icons.delivery_dining_rounded,
        OrderStatus.delivered => Icons.check_circle_rounded,
        OrderStatus.cancelled => Icons.cancel_rounded,
      };
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return GatherCard(
        color: AppColors.dangerSoft,
        shadows: const [],
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 24),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Order cancelled', style: AppType.bodyStrong),
                  if (order.cancelReason != null)
                    Text(order.cancelReason!, style: AppType.caption),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final steps = OrderStatusX.timeline;
    final currentIndex = steps.indexOf(order.status);

    return GatherCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _Step(
              status: steps[i],
              done: i <= currentIndex,
              active: i == currentIndex,
              isLast: i == steps.length - 1,
              at: _timeFor(steps[i]),
            ),
        ],
      ),
    );
  }

  DateTime? _timeFor(OrderStatus status) {
    for (final event in order.timeline) {
      if (event.status == status) return event.at;
    }
    return null;
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.status,
    required this.done,
    required this.active,
    required this.isLast,
    this.at,
  });

  final OrderStatus status;
  final bool done;
  final bool active;
  final bool isLast;
  final DateTime? at;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: Motion.normal,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? AppColors.primary : AppColors.line,
                    shape: BoxShape.circle,
                    boxShadow: active ? Shadows.glow(AppColors.primary) : null,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.circle,
                    size: done ? 16 : 8,
                    color: done ? Colors.white : AppColors.inkFaint,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: done ? AppColors.primary : AppColors.line,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : Insets.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            status.label,
                            style: active
                                ? AppType.bodyStrong.copyWith(color: AppColors.primary)
                                : AppType.bodyStrong.copyWith(
                                    color: done ? AppColors.ink : AppColors.inkFaint,
                                  ),
                          ),
                        ),
                        if (at != null)
                          Text(
                            '${at!.hour.toString().padLeft(2, '0')}:'
                            '${at!.minute.toString().padLeft(2, '0')}',
                            style: AppType.caption,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.description,
                      style: AppType.caption.copyWith(
                        color: done ? AppColors.inkMuted : AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppType.overline),
                const SizedBox(height: 2),
                Text(value, style: AppType.bodyLarge.copyWith(fontSize: 14.5)),
              ],
            ),
          ),
        ],
      );
}

class _CancelDialog extends StatefulWidget {
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  static const _reasons = [
    'Ordered by mistake',
    'Taking too long',
    'Changed my mind',
    'Wrong items selected',
    'Other',
  ];

  String _selected = _reasons.first;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let us know why so we can improve.',
              style: AppType.body.copyWith(color: AppColors.inkMuted, fontSize: 14),
            ),
            const SizedBox(height: Insets.md),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v ?? _reasons.first),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final reason in _reasons)
                    RadioListTile<String>(
                      value: reason,
                      title: Text(reason, style: AppType.body.copyWith(fontSize: 14)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep order')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Cancel order'),
          ),
        ],
      );
}
