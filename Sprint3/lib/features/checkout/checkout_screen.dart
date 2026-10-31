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
import '../../core/models/reward_rules.dart';
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
  UserVoucher? _reward;
  bool _placing = false;

  /// US15 — the rewards on offer, the one in use, and the bill with it off.
  /// A reward already applied to an unplaced group order is not offered, and
  /// one the order no longer qualifies for stays picked but takes nothing off
  /// (its row says why) rather than vanishing.
  ({List<UserVoucher> rewards, UserVoucher? reward, RewardQuote? quote, CartTotals totals})
      _priced(T Function<T>(ProviderListenable<T>) read) {
    final base = read(cartTotalsProvider);
    final uid = read(currentUidProvider) ?? '';
    final rewards = RewardRules.spendable(
      read(myVouchersProvider).valueOrNull ?? const <UserVoucher>[],
      heldElsewhere: RewardRules.heldInSessions(
          read(mySessionsProvider).valueOrNull ?? const <GroupSession>[],
          holderUid: uid),
    );
    final reward = RewardRules.resolve(_reward, rewards);
    final quote = reward == null
        ? null
        : RewardRules.quote(reward, subtotal: base.subtotal, deliveryFee: base.deliveryFee);
    final totals =
        quote != null && quote.isOk ? RewardRules.withDiscount(base, quote.discount) : base;
    return (rewards: rewards, reward: reward, quote: quote, totals: totals);
  }

  Future<void> _placeOrder() async {
    final user = ref.read(currentUserOrNullProvider);
    final lines = ref.read(cartProvider).valueOrNull ?? const <CartLine>[];
    final restaurant = ref.read(cartRestaurantProvider).valueOrNull;
    final priced = _priced(ref.read);
    final totals = priced.totals;
    final address = _address ?? user?.defaultAddress;
    final method = resolvePaymentMethod(_method, ref.read(usablePaymentMethodsProvider),
        ref.read(defaultPaymentMethodProvider));

    if (user == null || restaurant == null || lines.isEmpty) return;
    if (address == null) {
      AppSnack.error(context, 'Choose a delivery address first');
      return;
    }
    if (method == null) {
      AppSnack.error(context, 'Choose a payment method first');
      return;
    }
    // Never charge the full price for an order the person thinks is reduced.
    if (priced.quote case RewardQuote(isOk: false, :final problem?)) {
      AppSnack.error(context, problem);
      return;
    }
    final reward = priced.reward;

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
            voucherCode: reward?.code,
          );

      switch (placed) {
        case Err(:final message):
          if (mounted) AppSnack.error(context, message);
        case Ok(:final value):
          // The order is written first; the reward is spent after it, and a
          // failure there is reported without undoing the order.
          final spent = reward == null
              ? null
              : await ref
                  .read(voucherServiceProvider)
                  .redeem(uid: user.uid, held: reward, orderId: value.id);
          await ref.read(cartServiceProvider).clear(user.uid);
          if (!mounted) return;
          if (spent case Err(:final message)) {
            AppSnack.error(
                context, 'Order placed, but the reward was not marked as used: $message');
          }
          context.pushReplacement(Routes.trackOrder(value.id));
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
    final priced = _priced(ref.watch);
    final totals = priced.totals;
    final reward = priced.reward;
    final quote = priced.quote;
    // Only methods whose option is still enabled; a pick that has since been
    // switched off falls back to the usable default.
    final methods = ref.watch(usablePaymentMethodsProvider);

    final address = _address ?? user?.defaultAddress;
    final method = resolvePaymentMethod(_method, methods, ref.watch(defaultPaymentMethodProvider));

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
                  value: address == null
                      ? context.tr('Add a delivery address')
                      : context.isolate(address.oneLine),
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
                  value: method == null
                      ? context.tr('Add a payment method')
                      : context.isolate(method.label),
                  warning: method == null,
                  actionLabel: method == null ? 'Add' : 'Change',
                  onTap: () async {
                    final picked = await pickPaymentMethod(context, methods);
                    if (picked != null && mounted) setState(() => _method = picked);
                  },
                ),
                const SizedBox(height: Insets.md),
                if (priced.rewards.isNotEmpty) ...[
                  CheckoutRow(
                    icon: Icons.local_offer_outlined,
                    label: 'REWARD',
                    value: reward == null
                        ? context.tr(
                            priced.rewards.length == 1
                                ? '{count} reward available'
                                : '{count} rewards available|${countNote(priced.rewards.length)}',
                            {'count': priced.rewards.length})
                        : quote!.isOk
                            ? context.tr('{code} · −{amount}', {
                                'code': context.isolate(reward.code),
                                'amount': Money.format(quote.discount),
                              })
                            : context.tr(quote.problem!),
                    warning: quote != null && !quote.isOk,
                    actionLabel: reward == null ? 'Use' : 'Change',
                    onTap: () async {
                      final picked = await pickReward(
                        context,
                        rewards: priced.rewards,
                        current: reward,
                        subtotal: totals.subtotal,
                        deliveryFee: totals.deliveryFee,
                      );
                      if (picked != null && mounted) setState(() => _reward = picked.reward);
                    },
                  ),
                  const SizedBox(height: Insets.md),
                ],
                const SizedBox(height: Insets.xxl),
                SectionHeader(title: context.tr('Your order ({count})', {'count': lines.length})),
                if (restaurant != null) ...[
                  Text(
                    context.tr('From {restaurant} · arrives in about {minutes} min|${countNote(restaurant.deliveryMinutes)}',
                        {'restaurant': context.isolate(restaurant.name), 'minutes': restaurant.deliveryMinutes}),
                    style: AppType.caption,
                  ),
                  const SizedBox(height: Insets.md),
                ],
                for (final line in lines) ...[
                  CartLineTile(line: line, readOnly: true),
                  const SizedBox(height: Insets.sm),
                ],
                const SizedBox(height: Insets.lg),
                GatherCard(
                  child: TotalsPanel(
                    totals: totals,
                    voucherCode: totals.discount > 0 ? reward?.code : null,
                  ),
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.inkFaint),
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: Text(
                        context.tr('Card details are never stored on your device or in our database.'),
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
              label: context.tr('Place order · {total}', {'total': Money.format(totals.total)}),
              busy: _placing,
              onPressed: _placeOrder,
            ),
          ),
        ],
      ),
    );
  }
}
