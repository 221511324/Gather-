import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import '../rewards/spin_win_banner.dart';

/// US15 — the rewards a person holds, and claiming a new one by code.
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final result =
        await ref.read(voucherServiceProvider).claim(uid: uid, code: _code.text);
    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok(:final value):
        _code.clear();
        AppSnack.show(context, context.tr('{title} added to your rewards', {'title': context.isolate(value.title)}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myVouchersProvider);

    return BrandScaffold(
      title: 'Rewards',
      showBack: true,
      child: mine.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (vouchers) {
          final usable = vouchers.where((v) => v.isUsable).toList();
          final spent = vouchers.where((v) => !v.isUsable).toList();

          return ListView(
            padding: const EdgeInsets.all(Insets.gutter),
            children: [
              const _SpinCard(),
              const SizedBox(height: Insets.md),
              GatherCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Have a code?'), style: AppType.bodyStrong),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: [
                        Expanded(
                          child: GatherField(
                            label: 'Code',
                            controller: _code,
                            hint: 'GATHER10',
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        GatherButton(
                          label: 'Claim',
                          compact: true,
                          expand: false,
                          onPressed: _claim,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),

              if (usable.isEmpty && spent.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: Insets.xxl),
                  child: EmptyView(
                    icon: Icons.card_giftcard_outlined,
                    title: 'No rewards yet',
                    message: 'Claim a code above, or watch for offers.',
                  ),
                ),

              if (usable.isNotEmpty) ...[
                SectionHeader(title: context.tr('Available ({count})', {'count': usable.length})),
                for (final v in usable) _VoucherCard(voucher: v),
                const SizedBox(height: Insets.xl),
              ],

              if (spent.isNotEmpty) ...[
                const SectionHeader(title: 'Used and expired'),
                for (final v in spent) _VoucherCard(voucher: v),
              ],
              const SizedBox(height: Insets.xxl),
            ],
          );
        },
      ),
    );
  }
}

/// FR25 — the way into Spin & Win from the rewards screen. Same look as the
/// home banner, but it marks the trip so the wheel can send people back here.
class _SpinCard extends StatelessWidget {
  const _SpinCard();

  @override
  Widget build(BuildContext context) => SpinWinBanner(
        onTap: () => context.push('${Routes.spin}?from=rewards'),
      );
}

class _VoucherCard extends StatelessWidget {
  const _VoucherCard({required this.voucher});

  final UserVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final live = v.isUsable;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: GatherCard(
        color: live ? AppColors.primaryTint : null,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: live ? AppColors.primary : AppColors.line,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(
                v.discountType == DiscountType.freeDelivery
                    ? Icons.delivery_dining_outlined
                    : Icons.local_offer_outlined,
                color: live ? Colors.white : AppColors.inkFaint,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(context.isolate(v.title), style: AppType.bodyStrong)),
                      const SizedBox(width: Insets.sm),
                      StatusPill(
                        label: switch (v.status) {
                          VoucherStatus.used => 'Used',
                          VoucherStatus.expired => 'Expired',
                          VoucherStatus.available =>
                            v.hasExpired ? 'Expired' : _summary(context, v),
                        },
                        color: live ? AppColors.primary : AppColors.inkFaint,
                        compact: true,
                      ),
                    ],
                  ),
                  Text(context.isolate(v.code), style: AppType.caption.copyWith(letterSpacing: 1)),
                  if (v.minimumOrder > 0)
                    Text(
                        context.tr('On orders over {amount} SAR',
                            {'amount': v.minimumOrder.toStringAsFixed(0)}),
                        style: AppType.caption),
                  if (live && v.expiresAt != null)
                    Text(
                        context.tr('Expires {date}',
                            {'date': Dates.dayMonth(context, v.expiresAt!)}),
                        style: AppType.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [UserVoucher.summary] builds its English with the number inside, so
  /// the translated form is assembled here instead.
  static String _summary(BuildContext context, UserVoucher v) {
    final value = v.discountValue.toStringAsFixed(0);
    return switch (v.discountType) {
      DiscountType.percentage => context.tr('{value}% off', {'value': value}),
      DiscountType.fixedAmount => context.tr('{value} SAR off', {'value': value}),
      DiscountType.freeDelivery => context.tr('Free delivery'),
    };
  }
}
