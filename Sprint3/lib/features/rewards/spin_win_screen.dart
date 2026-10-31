import 'dart:math' as math;

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
import '../../core/utils/dates.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/state_views.dart';
import '../group/spin_wheel.dart';
import 'spin_clock.dart';

/// FR25 — Spin & Win: one free spin every 24 hours, and every spin wins a
/// voucher that lands in the person's rewards.
///
/// The prize is drawn and saved by [SpinService] before the wheel moves; the
/// animation is then aimed at that wedge, exactly as Restaurant Spin does.
class SpinWinScreen extends ConsumerStatefulWidget {
  const SpinWinScreen({super.key, this.fromRewards = false});

  /// Opened from the rewards screen, so "See my rewards" goes back to it
  /// rather than stacking a second copy.
  final bool fromRewards;

  @override
  ConsumerState<SpinWinScreen> createState() => _SpinWinScreenState();
}

class _SpinWinScreenState extends ConsumerState<SpinWinScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation(0);
  int _celebration = 0;

  /// The wheel frozen at the moment of the spin, so a catalogue change while
  /// it turns cannot move the wedges under the pointer.
  List<SpinPrize>? _frozen;
  SpinOutcome? _outcome;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 4600));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin(List<SpinPrize> prizes) async {
    final uid = ref.read(currentUidProvider);
    if (_spinning || uid == null) return;
    setState(() {
      _spinning = true;
      _frozen = prizes;
      _outcome = null;
    });

    final result = await ref.read(spinServiceProvider).spin(uid: uid, prizes: prizes);
    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() {
          _spinning = false;
          _frozen = null;
        });
        AppSnack.error(context, message);
      case Ok(:final value):
        final target = rotationForWinner(
          winnerIndex: value.index,
          wedgeCount: prizes.length,
          turns: 6,
        );
        _rotation = Tween<double>(
          begin: 0,
          end: target,
        ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
        _controller.reset();
        await _controller.forward().orCancel.catchError((_) {});
        if (!mounted) return;
        setState(() {
          _spinning = false;
          _outcome = value;
          _celebration++;
        });
    }
  }

  void _openRewards() {
    if (widget.fromRewards && context.canPop()) {
      context.pop();
    } else {
      context.pushReplacement(Routes.rewards);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wheel = ref.watch(spinWheelProvider);

    return BrandScaffold(
      title: 'Spin & Win',
      showBack: true,
      padBody: false,
      child: wheel.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (live) {
          final prizes = _frozen ?? live;
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // The wheel shrinks on a short phone so the Spin button is on
              // screen without scrolling; the headings and the button take
              // about 250 points.
              LayoutBuilder(
                builder: (context, box) {
                  final wheelSize = math.max(
                    150.0,
                    math.min(math.min(box.maxWidth * 0.8, 320.0), box.maxHeight - 250),
                  );
                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      Insets.gutter,
                      Insets.xl,
                      Insets.gutter,
                      Insets.xxxl,
                    ),
                    children: [
                      Text(
                        context.tr(_outcome != null ? 'You won!' : 'Spin the wheel, win a reward'),
                        textAlign: TextAlign.center,
                        style: AppType.title.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        context.tr('One free spin every 24 hours. Every spin wins something.'),
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: AppColors.inkMuted, fontSize: 14),
                      ),
                      const SizedBox(height: Insets.xxl),
                      Center(
                        child: AnimatedBuilder(
                          animation: _rotation,
                          builder: (context, _) => SpinWheel(
                            labels: [for (final p in prizes) spinPrizeLabel(context, p)],
                            rotation: _rotation.value,
                            size: wheelSize,
                            centerIcon: Icons.card_giftcard_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.xxl),
                      if (_spinning)
                        const GatherButton(
                          label: 'Spinning…',
                          busy: true,
                          color: AppColors.accent,
                          foreground: AppColors.ink,
                        )
                      else if (_outcome != null)
                        _PrizeCard(outcome: _outcome!, onOpenRewards: _openRewards)
                      else
                        SpinClock(
                          builder: (context, remaining) {
                            final ready = remaining == Duration.zero;
                            return Column(
                              children: [
                                if (!ready) ...[
                                  Text(
                                    context.tr('Next spin in {time}', {
                                      'time': spinCountdownText(context, remaining),
                                    }),
                                    key: const ValueKey('spin-countdown'),
                                    textAlign: TextAlign.center,
                                    style: AppType.bodyStrong,
                                  ),
                                  const SizedBox(height: Insets.xs),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      spinClockText(remaining),
                                      textAlign: TextAlign.center,
                                      style: AppType.money.copyWith(
                                        fontSize: 30,
                                        color: AppColors.primary,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: Insets.md),
                                ],
                                GatherButton(
                                  key: const ValueKey('spin-button'),
                                  label: 'Spin',
                                  icon: Icons.casino_rounded,
                                  color: AppColors.accent,
                                  foreground: AppColors.ink,
                                  onPressed: ready && prizes.isNotEmpty
                                      ? () => _spin(prizes)
                                      : null,
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: Insets.xxl),
                      Text(context.tr('On the wheel'), style: AppType.label),
                      const SizedBox(height: Insets.xs),
                      Text(context.tr('The bigger prizes are rarer.'), style: AppType.caption),
                      const SizedBox(height: Insets.md),
                      for (final p in prizes) _PrizeRow(prize: p),
                    ],
                  );
                },
              ),
              Positioned.fill(
                child: Celebration(trigger: _celebration, colors: SpinWheel.defaultColors),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The short name of a prize, in the person's language — "10% off".
String spinPrizeLabel(BuildContext context, SpinPrize p) {
  final value = p.discountValue.toStringAsFixed(0);
  return switch (p.discountType) {
    DiscountType.percentage => context.tr('{value}% off', {'value': value}),
    DiscountType.fixedAmount => context.tr('{value} SAR off', {'value': value}),
    DiscountType.freeDelivery => context.tr('Free delivery'),
  };
}

class _PrizeCard extends StatelessWidget {
  const _PrizeCard({required this.outcome, required this.onOpenRewards});

  final SpinOutcome outcome;
  final VoidCallback onOpenRewards;

  @override
  Widget build(BuildContext context) {
    final v = outcome.voucher;
    return GatherCard(
      key: const ValueKey('spin-prize'),
      color: AppColors.successSoft,
      shadows: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, size: 34, color: AppColors.accent),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('YOU WON'),
                      style: AppType.overline.copyWith(color: AppColors.success),
                    ),
                    Text(
                      spinPrizeLabel(context, outcome.prize),
                      style: AppType.headline.copyWith(fontSize: 20),
                    ),
                    Text(
                      context.tr('Saved to your rewards'),
                      style: AppType.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            context.tr('Code: {code}', {'code': context.isolate(v.code)}),
            style: AppType.caption.copyWith(letterSpacing: 1),
          ),
          if (v.minimumOrder > 0)
            Text(
              context.tr('On orders over {amount} SAR', {
                'amount': v.minimumOrder.toStringAsFixed(0),
              }),
              style: AppType.caption,
            ),
          if (v.expiresAt != null)
            Text(
              context.tr('Expires {date}', {'date': Dates.dayMonth(context, v.expiresAt!)}),
              style: AppType.caption,
            ),
          const SizedBox(height: Insets.lg),
          GatherButton(
            label: 'See my rewards',
            icon: Icons.card_giftcard_rounded,
            onPressed: onOpenRewards,
          ),
        ],
      ),
    );
  }
}

class _PrizeRow extends StatelessWidget {
  const _PrizeRow({required this.prize});

  final SpinPrize prize;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: Insets.sm),
    child: Row(
      children: [
        Icon(
          prize.discountType == DiscountType.freeDelivery
              ? Icons.delivery_dining_outlined
              : Icons.local_offer_outlined,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Text(
            spinPrizeLabel(context, prize),
            style: AppType.bodyLarge.copyWith(fontSize: 14.5),
          ),
        ),
        if (prize.minimumOrder > 0)
          Text(
            context.tr('On orders over {amount} SAR', {
              'amount': prize.minimumOrder.toStringAsFixed(0),
            }),
            style: AppType.caption,
          ),
      ],
    ),
  );
}
