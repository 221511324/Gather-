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
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/state_views.dart';
import '../cart/cart_line_tile.dart';
import 'checkout_widgets.dart';

/// Checkout for an individual order (FR11, FR15, FR18).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Address? _address;
  SavedPaymentMethod? _method;
  bool _placing = false;

  Future<void> _placeOrder() async {
    final user = ref.read(currentUserOrNullProvider);
    final lines = ref.read(cartProvider).valueOrNull ?? const <CartLine>[];
    final restaurant = ref.read(cartRestaurantProvider).valueOrNull;
    final totals = ref.read(cartTotalsProvider);
    final address = _address ?? user?.defaultAddress;
    final method = _method ?? ref.read(defaultPaymentMethodProvider);

    if (user == null || restaurant == null || lines.isEmpty) return;
    if (address == null) {
      AppSnack.error(context, 'Choose a delivery address first');
      return;
    }
    if (method == null) {
      AppSnack.error(context, 'Choose a payment method first');
      return;
    }

    setState(() => _placing = true);
    try {
      // Take the payment first: an order should never exist without one.
      final receipt = await ref.read(paymentServiceProvider).pay(
            amount: totals.total,
            method: method,
            description: 'Gather order from ${restaurant.name}',
          );

      if (receipt case Err(:final message)) {
        if (mounted) AppSnack.error(context, message);
        return;
      }

      final placed = await ref.read(orderServiceProvider).placeIndividualOrder(
            user: user,
            restaurant: restaurant,
            lines: lines,
            totals: totals,
            paymentMethodLabel: method.label,
            deliveryAddress: address.oneLine,
          );

      switch (placed) {
        case Err(:final message):
          if (mounted) AppSnack.error(context, message);
        case Ok(:final value):
          await ref.read(cartServiceProvider).clear(user.uid);
          if (mounted) context.pushReplacement(Routes.trackOrder(value.id));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final lines = ref.watch(cartProvider).valueOrNull ?? const <CartLine>[];
    final restaurant = ref.watch(cartRestaurantProvider).valueOrNull;
    final totals = ref.watch(cartTotalsProvider);
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const <SavedPaymentMethod>[];

    final address = _address ?? user?.defaultAddress;
    final method = _method ?? ref.watch(defaultPaymentMethodProvider);

    if (lines.isEmpty) {
      return BrandScaffold(
        title: 'Checkout',
        showBack: true,
        child: EmptyView(
          icon: Icons.shopping_bag_outlined,
          title: 'Nothing to check out',
          message: 'Your cart is empty.',
          actionLabel: 'Browse restaurants',
          onAction: () => context.go(Routes.search),
        ),
      );
    }

    return BrandScaffold(
      title: 'Checkout',
      showBack: true,
      padBody: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
              children: [
                CheckoutRow(
                  icon: Icons.location_on_outlined,
                  label: 'DELIVER TO',
                  value: address?.oneLine ?? 'Add a delivery address',
                  warning: address == null,
                  actionLabel: address == null ? 'Add' : 'Change',
                  onTap: () async {
                    final picked = await pickAddress(context, user?.addresses ?? const []);
                    if (picked != null && mounted) setState(() => _address = picked);
                  },
                ),
                const SizedBox(height: Insets.md),
                CheckoutRow(
                  icon: method == null ? Icons.credit_card_off_outlined : paymentIcon(method.type),
                  label: 'PAY WITH',
                  value: method?.label ?? 'Add a payment method',
                  warning: method == null,
                  actionLabel: method == null ? 'Add' : 'Change',
                  onTap: () async {
                    final picked = await pickPaymentMethod(context, methods);
                    if (picked != null && mounted) setState(() => _method = picked);
                  },
                ),
                const SizedBox(height: Insets.md),
                const SizedBox(height: Insets.xxl),
                SectionHeader(title: 'Your order (${lines.length})'),
                if (restaurant != null) ...[
                  Text(
                    'From ${restaurant.name} · arrives in about ${restaurant.deliveryMinutes} min',
                    style: AppType.caption,
                  ),
                  const SizedBox(height: Insets.md),
                ],
                for (final line in lines) ...[
                  CartLineTile(line: line, readOnly: true),
                  const SizedBox(height: Insets.sm),
                ],
                const SizedBox(height: Insets.lg),
                GatherCard(child: TotalsPanel(totals: totals)),
                const SizedBox(height: Insets.lg),
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.inkFaint),
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: Text(
                        'Card details are never stored on your device or in our database.',
                        style: AppType.caption.copyWith(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
            child: GatherButton(
              label: 'Place order · ${Money.format(totals.total)}',
              busy: _placing,
              onPressed: _placeOrder,
            ),
          ),
        ],
      ),
    );
  }
}
