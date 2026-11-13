import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/models/reward_rules.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/state_views.dart';
import '../profile/addresses_screen.dart';

/// A labelled row that opens a picker — the repeated building block of the
/// checkout and group payment screens.
class CheckoutRow extends StatelessWidget {
  const CheckoutRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.actionLabel = 'Change',
    this.onTap,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback? onTap;
  final bool warning;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: warning ? AppColors.warningSoft : AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: warning ? AppColors.warning : AppColors.primary,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(label), style: AppType.overline),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppType.bodyStrong.copyWith(
                      color: warning ? AppColors.accentDeep : AppColors.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Text(
                context.tr(actionLabel),
                style: AppType.label.copyWith(color: AppColors.primary, fontSize: 13),
              ),
          ],
        ),
      );
}

/// Picks a saved delivery address, with a shortcut to add one.
Future<Address?> pickAddress(BuildContext context, List<Address> addresses) =>
    showModalBottomSheet<Address>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Deliver to'), style: AppType.headline),
              const SizedBox(height: Insets.lg),
              if (addresses.isEmpty)
                const EmptyView(
                  icon: Icons.location_off_outlined,
                  title: 'No saved addresses',
                  message: 'Add one so we know where to send your order.',
                  compact: true,
                )
              else
                ...addresses.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: GatherCard(
                      onTap: () => Navigator.pop(context, a),
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(addressLabel(context, a.label), style: AppType.bodyStrong),
                                Text(
                                  context.isolate(a.oneLine),
                                  style: AppType.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (a.isDefault)
                            const StatusPill(
                              label: 'Default',
                              color: AppColors.primary,
                              compact: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Insets.md),
              GatherOutlineButton(
                label: 'Manage addresses',
                icon: Icons.add_location_alt_outlined,
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push(Routes.addresses);
                },
              ),
            ],
          ),
        ),
      ),
    );

/// The method a checkout should charge: what the person picked, as long as
/// it is still among the [usable] ones — an administrator may have switched
/// its option off since — otherwise [fallback] (the usable default).
SavedPaymentMethod? resolvePaymentMethod(
  SavedPaymentMethod? picked,
  List<SavedPaymentMethod> usable,
  SavedPaymentMethod? fallback,
) {
  if (picked != null) {
    for (final m in usable) {
      if (m.id == picked.id) return m;
    }
  }
  return fallback;
}

/// Picks a saved payment method (FR15). Pass only usable methods
/// ([usablePaymentMethodsProvider]); nothing here filters them again.
Future<SavedPaymentMethod?> pickPaymentMethod(
  BuildContext context,
  List<SavedPaymentMethod> methods,
) =>
    showModalBottomSheet<SavedPaymentMethod>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Pay with'), style: AppType.headline),
              const SizedBox(height: Insets.lg),
              if (methods.isEmpty)
                const EmptyView(
                  icon: Icons.credit_card_off_outlined,
                  title: 'No payment methods',
                  message: 'Add a card or wallet to complete your order.',
                  compact: true,
                )
              else
                ...methods.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: GatherCard(
                      onTap: m.isExpired ? null : () => Navigator.pop(context, m),
                      padding: const EdgeInsets.all(Insets.md),
                      child: Row(
                        children: [
                          Icon(paymentIcon(m.type), size: 22, color: AppColors.primary),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(context.isolate(m.label), style: AppType.bodyStrong),
                                if (m.type == PaymentMethodType.card)
                                  Text(
                                    m.isExpired
                                        ? context.tr('Expired')
                                        : context.tr('Expires {date}', {'date': m.expiryLabel}),
                                    style: AppType.caption.copyWith(
                                      color: m.isExpired ? AppColors.danger : AppColors.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (m.isDefault)
                            const StatusPill(
                              label: 'Default',
                              color: AppColors.primary,
                              compact: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Insets.md),
              GatherOutlineButton(
                label: 'Manage payment methods',
                icon: Icons.add_card_rounded,
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push(Routes.paymentMethods);
                },
              ),
            ],
          ),
        ),
      ),
    );

IconData paymentIcon(PaymentMethodType type) => switch (type) {
      PaymentMethodType.card => Icons.credit_card_rounded,
      PaymentMethodType.applePay => Icons.apple_rounded,
      PaymentMethodType.stcPay => Icons.account_balance_wallet_rounded,
      PaymentMethodType.other => Icons.account_balance_wallet_outlined,
    };

/// US15 — picks one of the person's rewards for this bill. Each is priced
/// against the order; one the order is too small for is shown, greyed, with
/// the reason. Returns `(reward: null)` for "no reward" and null when the
/// sheet is dismissed.
Future<({UserVoucher? reward})?> pickReward(
  BuildContext context, {
  required List<UserVoucher> rewards,
  required UserVoucher? current,
  required double subtotal,
  required double deliveryFee,
}) =>
    showModalBottomSheet<({UserVoucher? reward})>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('Use a reward'), style: AppType.headline),
              const SizedBox(height: Insets.lg),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final v in rewards)
                      _RewardOption(
                        reward: v,
                        selected: v.id == current?.id,
                        quote: RewardRules.quote(v, subtotal: subtotal, deliveryFee: deliveryFee),
                        onTap: () => Navigator.pop(context, (reward: v)),
                      ),
                  ],
                ),
              ),
              if (current != null) ...[
                const SizedBox(height: Insets.md),
                GatherOutlineButton(
                  label: 'Don\'t use a reward',
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context, (reward: null)),
                ),
              ],
            ],
          ),
        ),
      ),
    );

class _RewardOption extends StatelessWidget {
  const _RewardOption({
    required this.reward,
    required this.selected,
    required this.quote,
    required this.onTap,
  });

  final UserVoucher reward;
  final bool selected;
  final RewardQuote quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: GatherCard(
          onTap: quote.isOk ? onTap : null,
          padding: const EdgeInsets.all(Insets.md),
          color: selected ? AppColors.primarySoft : null,
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  size: 22, color: quote.isOk ? AppColors.primary : AppColors.inkFaint),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.isolate(reward.title),
                        style: AppType.bodyStrong.copyWith(
                            color: quote.isOk ? AppColors.ink : AppColors.inkMuted)),
                    Text('${context.isolate(reward.code)} · ${context.tr(reward.summary)}',
                        style: AppType.caption),
                    if (!quote.isOk)
                      Text(context.tr(quote.problem!),
                          style: AppType.caption.copyWith(color: AppColors.accentDeep)),
                  ],
                ),
              ),
              if (quote.isOk)
                Text('−${Money.format(quote.discount)}',
                    style: AppType.bodyStrong.copyWith(color: AppColors.success)),
            ],
          ),
        ),
      );
}
