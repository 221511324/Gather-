import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../cart/cart_line_tile.dart';
import 'orders_screen.dart';

/// A placed order in full (FR18, FR22) with reordering and reviewing.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderProvider(orderId));
    final uid = ref.watch(currentUidProvider);

    return orderAsync.when(
      loading: () => const BrandScaffold(title: 'Order', showBack: true, child: LoadingView()),
      error: (e, _) =>
          BrandScaffold(title: 'Order', showBack: true, child: ErrorView(message: '$e')),
      data: (order) {
        if (order == null) {
          return const BrandScaffold(
            title: 'Order',
            showBack: true,
            child: EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'Order not found',
              message: 'It may have been removed.',
            ),
          );
        }

        final myLines = order.isGroupOrder && uid != null ? order.linesFor(uid) : order.lines;

        return BrandScaffold(
          title: 'Order details',
          subtitle: '#${order.id.substring(0, 8).toUpperCase()}',
          showBack: true,
          padBody: false,
          bottomBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
            child: Row(
              children: [
                if (order.status.isActive)
                  Expanded(
                    child: GatherButton(
                      label: 'Track order',
                      icon: Icons.delivery_dining_rounded,
                      onPressed: () {
                        context.pushReplacement(Routes.trackOrder(order.id));
                      },
                    ),
                  )
                else
                  Expanded(
                    child: GatherButton(
                      label: 'Order again',
                      icon: Icons.refresh_rounded,
                      onPressed: () => _reorder(context, ref, order),
                    ),
                  ),
                if (order.canReview) ...[
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: GatherOutlineButton(
                      label: 'Leave a review',
                      icon: Icons.star_outline_rounded,
                      onPressed: () => _review(context, ref, order),
                    ),
                  ),
                ],
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
            children: [
              GatherCard(
                onTap: () => context.push(Routes.restaurant(order.restaurantId)),
                child: Row(
                  children: [
                    FoodImage(
                      url: order.restaurantImageUrl,
                      width: 52,
                      height: 52,
                      radius: Radii.md,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(order.restaurantName, style: AppType.headline.copyWith(fontSize: 17)),
                          Text(_placedAt(order.placedAt), style: AppType.caption),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: order.status.label,
                      color: OrderCard.colorFor(order.status),
                      compact: true,
                    ),
                  ],
                ),
              ),
              if (order.rating != null) ...[
                const SizedBox(height: Insets.md),
                GatherCard(
                  color: AppColors.accentSoft,
                  shadows: const [],
                  child: Row(
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= order.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 20,
                          color: AppColors.accentDeep,
                        ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Text(
                          (order.reviewComment ?? '').isEmpty
                              ? 'You rated this order'
                              : order.reviewComment!,
                          style: AppType.caption.copyWith(color: AppColors.accentDeep),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Insets.xxl),

              if (order.isGroupOrder) ...[
                _GroupBlock(order: order, uid: uid),
                const SizedBox(height: Insets.xxl),
                SectionHeader(title: 'Everything ordered (${order.lines.length})'),
                for (final line in order.lines) ...[
                  CartLineTile(line: line, readOnly: true, showOwner: true),
                  const SizedBox(height: Insets.sm),
                ],
                if (myLines.isNotEmpty) ...[
                  const SizedBox(height: Insets.lg),
                  SectionHeader(title: 'Your items (${myLines.length})'),
                  for (final line in myLines) ...[
                    CartLineTile(line: line, readOnly: true),
                    const SizedBox(height: Insets.sm),
                  ],
                ],
              ] else ...[
                SectionHeader(title: 'Items (${order.lines.length})'),
                for (final line in order.lines) ...[
                  CartLineTile(line: line, readOnly: true),
                  const SizedBox(height: Insets.sm),
                ],
              ],

              const SizedBox(height: Insets.lg),
              GatherCard(
                child: TotalsPanel(
                  totals: CartTotals(
                    subtotal: order.subtotal,
                    deliveryFee: order.deliveryFee,
                    serviceFee: order.serviceFee,
                    discount: order.discount,
                  ),
                  voucherCode: order.voucherCode,
                ),
              ),
              const SizedBox(height: Insets.md),
              GatherCard(
                child: Column(
                  children: [
                    _Line(
                      label: 'Delivered to',
                      value: order.deliveryAddress.isEmpty ? '—' : order.deliveryAddress,
                    ),
                    const SizedBox(height: Insets.md),
                    _Line(
                      label: 'Paid with',
                      value: order.paymentMethodLabel.isEmpty ? '—' : order.paymentMethodLabel,
                    ),
                    const SizedBox(height: Insets.md),
                    _Line(label: 'Order ID', value: order.id.substring(0, 13).toUpperCase()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _placedAt(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} at '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref, FoodOrder order) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final cart = ref.read(cartProvider).valueOrNull ?? const <CartLine>[];
    if (cart.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace your cart?'),
          content: const Text('Reordering clears whatever is in your cart right now.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }

    final service = ref.read(cartServiceProvider);
    await service.clear(uid);

    // Only the current user's items come back — reordering a group order
    // should not silently buy everyone else's food.
    final source = order.isGroupOrder ? order.linesFor(uid) : order.lines;
    final refs = ref.read(firestoreRefsProvider);
    for (final line in source) {
      await refs.cart(uid).doc(line.id).set({
        ...line.toMap(),
        'ownerId': uid,
        'ownerName': '',
        'addedAt': DateTime.now(),
      });
    }

    if (!context.mounted) return;
    if (source.isEmpty) {
      AppSnack.error(context, 'There was nothing of yours in that order');
      return;
    }
    context.push(Routes.cart);
    AppSnack.show(context, 'Added ${source.length} items back to your cart');
  }

  Future<void> _review(BuildContext context, WidgetRef ref, FoodOrder order) async {
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (context) => _ReviewDialog(restaurantName: order.restaurantName),
    );
    if (result == null) return;

    final saved = await ref.read(orderServiceProvider).rateOrder(
          orderId: order.id,
          rating: result.$1,
          comment: result.$2,
        );
    if (!context.mounted) return;
    switch (saved) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        AppSnack.show(context, 'Thanks for the review!');
    }
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({required this.order, this.uid});

  final FoodOrder order;
  final String? uid;

  @override
  Widget build(BuildContext context) => GatherCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    order.sessionName ?? 'Group order',
                    style: AppType.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (order.paymentMode != null)
                  StatusPill(
                    label: order.paymentMode!.shortLabel,
                    color: AppColors.primary,
                    compact: true,
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.md),
              child: Divider(height: 1),
            ),
            for (final p in order.participants)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Row(
                  children: [
                    MemberAvatar(uid: p.uid, initials: _initials(p.name), size: 28),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        p.uid == uid ? '${p.name} (you)' : p.name,
                        style: AppType.bodyLarge.copyWith(fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(Money.format(p.amount), style: AppType.money.copyWith(fontSize: 13.5)),
                    const SizedBox(width: Insets.sm),
                    Icon(
                      p.paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 17,
                      color: p.paid ? AppColors.success : AppColors.inkFaint,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: AppType.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.body.copyWith(fontSize: 14, color: AppColors.ink),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.restaurantName});

  final String restaurantName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('How was ${widget.restaurantName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _rating = i),
                    iconSize: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    icon: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Anything you want to add? (optional)',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
          FilledButton(
            onPressed: () => Navigator.pop(context, (_rating, _comment.text)),
            child: const Text('Submit'),
          ),
        ],
      );
}
