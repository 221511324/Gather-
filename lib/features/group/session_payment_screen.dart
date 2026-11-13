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
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../cart/cart_line_tile.dart';
import '../checkout/checkout_widgets.dart';

/// Group payment (FR14, FR16, FR17).
///
/// The host chooses how the bill is settled; everyone then pays their own
/// share and watches the status list fill in. The order cannot be placed until
/// nobody is still pending.
class SessionPaymentScreen extends ConsumerStatefulWidget {
  const SessionPaymentScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionPaymentScreen> createState() => _SessionPaymentScreenState();
}

class _SessionPaymentScreenState extends ConsumerState<SessionPaymentScreen> {
  SavedPaymentMethod? _method;
  bool _working = false;

  Future<void> _selectMode(GroupSession session, PaymentMode mode) async {
    final totals = ref.read(sessionTotalsProvider(widget.sessionId));
    final lines = ref.read(sessionLinesProvider(widget.sessionId)).valueOrNull ?? const <CartLine>[];

    setState(() => _working = true);
    final result = await ref.read(sessionServiceProvider).setPaymentMode(
          sessionId: session.id,
          mode: mode,
          totals: totals,
          lines: lines,
        );
    if (!mounted) return;
    setState(() => _working = false);

    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
    }
  }

  Future<void> _payMyShare(GroupSession session, SessionMember me) async {
    final method = resolvePaymentMethod(_method, ref.read(usablePaymentMethodsProvider),
        ref.read(defaultPaymentMethodProvider));
    if (method == null) {
      AppSnack.error(context, 'Add a payment method first');
      return;
    }

    setState(() => _working = true);
    try {
      final receipt = await ref.read(paymentServiceProvider).pay(
            amount: me.amountDue,
            method: method,
            description: 'Gather group order — ${session.name}',
          );

      if (receipt case Err(:final message)) {
        if (mounted) AppSnack.error(context, message);
        return;
      }

      await ref.read(sessionServiceProvider).markPaid(sessionId: session.id, uid: me.uid);


      if (mounted) AppSnack.show(context, 'Payment complete');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _placeOrder(GroupSession session) async {
    final totals = ref.read(sessionTotalsProvider(widget.sessionId));
    final lines = ref.read(sessionLinesProvider(widget.sessionId)).valueOrNull ?? const <CartLine>[];
    final restaurant =
        await ref.read(catalogServiceProvider).fetchRestaurant(session.restaurantId ?? '');
    final host = ref.read(currentUserOrNullProvider);
    final method = resolvePaymentMethod(_method, ref.read(usablePaymentMethodsProvider),
        ref.read(defaultPaymentMethodProvider));

    if (restaurant == null || host == null) return;

    final address = session.deliveryAddress ?? host.defaultAddress?.oneLine ?? '';
    if (address.isEmpty) {
      if (mounted) AppSnack.error(context, 'Set a delivery address first');
      return;
    }

    setState(() => _working = true);
    try {
      final placed = await ref.read(orderServiceProvider).placeGroupOrder(
            session: session,
            restaurant: restaurant,
            lines: lines,
            totals: totals,
            paymentMethodLabel: method?.label ?? session.paymentMode!.shortLabel,
            deliveryAddress: address,
          );

      if (!mounted) return;
      switch (placed) {
        case Err(:final message):
          AppSnack.error(context, message);
        case Ok(:final value):
          // The order exists now, so the reward is spent; a failure here is
          // reported but never undoes the order.
          final unspent = await _spendReward(session, host.uid, value.id);
          await ref
              .read(sessionServiceProvider)
              .markPlaced(sessionId: session.id, orderId: value.id);
          if (!mounted) return;
          if (unspent != null) {
            // English with the reason inside: AppSnack translates it through
            // the template, the reason included.
            AppSnack.error(
                context, 'Order placed, but the reward was not marked as used: $unspent');
          }
          context.pushReplacement(Routes.trackOrder(value.id));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// US15 — marks the session's reward used against [orderId]. Returns why
  /// it could not be, or null. Only the holder may write their rewards, and
  /// only the host can apply one (their own), so the host placing the order
  /// is always the holder; anything else is left alone.
  Future<String?> _spendReward(GroupSession session, String uid, String orderId) async {
    if (!RewardRules.shouldRedeem(session, uid)) return null;
    try {
      final held = (await ref.read(voucherServiceProvider).fetchMine(uid))
          .where((v) => v.id == session.voucherHeldId)
          .firstOrNull;
      if (held == null) return 'That reward has already been used';
      final spent = await ref
          .read(voucherServiceProvider)
          .redeem(uid: uid, held: held, orderId: orderId);
      return spent.errorOrNull;
    } catch (_) {
      return 'Could not apply that reward';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider(widget.sessionId)).valueOrNull;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final totals = ref.watch(sessionTotalsProvider(widget.sessionId));
    final lines = ref.watch(sessionLinesProvider(widget.sessionId)).valueOrNull ?? const <CartLine>[];
    final methods = ref.watch(usablePaymentMethodsProvider);

    if (session == null || user == null) {
      return const BrandScaffold(title: 'Group payment', showBack: true, child: LoadingView());
    }

    final isHost = session.isHostOf(user.uid);
    final me = session.memberOf(user.uid);
    final mode = session.paymentMode;
    final method = resolvePaymentMethod(_method, methods, ref.watch(defaultPaymentMethodProvider));

    return BrandScaffold(
      title: 'Group payment',
      subtitle: context.isolate(session.name),
      showBack: true,
      padBody: false,
      bottomBar: _Footer(
        session: session,
        me: me,
        isHost: isHost,
        working: _working,
        onPay: me == null ? null : () => _payMyShare(session, me),
        onPlace: () => _placeOrder(session),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
        children: [
          GatherCard(
            child: TotalsPanel(
              totals: totals,
              voucherCode: session.voucherCode,
              perPersonLabel: session.memberCount > 1
                  ? context.tr('{amount} each if split equally',
                      {'amount': Money.format(totals.total / session.memberCount)})
                  : null,
            ),
          ),
          const SizedBox(height: Insets.xxl),

          // US15 — only the host applies a reward, because it comes off the
          // group's bill rather than any one person's share.
          if (isHost) ...[
            _VoucherRow(session: session, totals: totals),
            const SizedBox(height: Insets.xxl),
          ],

          if (mode == null) ...[
            if (isHost) ...[
              CheckoutRow(
                icon: Icons.location_on_outlined,
                label: context.tr('DELIVER TO'),
                value: session.deliveryAddress?.isNotEmpty == true
                    ? context.isolate(session.deliveryAddress!)
                    : context.tr('Add a delivery address'),
                warning: session.deliveryAddress?.isNotEmpty != true,
                actionLabel: context
                    .tr(session.deliveryAddress?.isNotEmpty == true ? 'Change' : 'Add'),
                onTap: () async {
                  final picked = await pickAddress(context, user.addresses);
                  if (picked == null || !context.mounted) return;
                  await ref.read(sessionServiceProvider).setDeliveryAddress(
                        sessionId: session.id,
                        address: picked.oneLine,
                      );
                },
              ),
              const SizedBox(height: Insets.md),
              const SizedBox(height: Insets.xxl),
            ],
            SectionHeader(title: isHost ? 'How is the group paying?' : 'Waiting for the host'),
            if (isHost)
              for (final option in PaymentMode.values) ...[
                _ModeCard(
                  mode: option,
                  selected: false,
                  totals: totals,
                  session: session,
                  lines: lines,
                  onTap: _working ? null : () => _selectMode(session, option),
                ),
                const SizedBox(height: Insets.md),
              ]
            else
              const EmptyView(
                icon: Icons.hourglass_top_rounded,
                title: 'Waiting for the host',
                message: 'They are choosing how the bill gets split.',
                compact: true,
              ),
          ] else ...[
            _SelectedMode(mode: mode, isHost: isHost, sessionId: session.id, working: _working),
            const SizedBox(height: Insets.xxl),
            SectionHeader(
              title: context.tr('Payment status ({paid}/{total})',
                  {'paid': session.paidCount, 'total': session.memberCount}),
            ),
            for (final member in session.members) ...[
              _MemberPaymentTile(member: member, isMe: member.uid == user.uid),
              const SizedBox(height: Insets.sm),
            ],
            const SizedBox(height: Insets.lg),
            if (me != null && me.paymentStatus == MemberPaymentStatus.pending)
              CheckoutRow(
                icon: method == null ? Icons.credit_card_off_outlined : paymentIcon(method.type),
                label: context.tr('PAY WITH'),
                value: method?.label ?? context.tr('Add a payment method'),
                warning: method == null,
                actionLabel: context.tr(method == null ? 'Add' : 'Change'),
                onTap: () async {
                  final picked = await pickPaymentMethod(context, methods);
                  if (picked != null && mounted) setState(() => _method = picked);
                },
              ),
          ],

          const SizedBox(height: Insets.xxl),
          SectionHeader(title: context.tr('The order ({count})', {'count': lines.length})),
          for (final line in lines) ...[
            CartLineTile(line: line, readOnly: true, showOwner: true),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.totals,
    required this.session,
    required this.lines,
    this.onTap,
  });

  final PaymentMode mode;
  final bool selected;
  final CartTotals totals;
  final GroupSession session;
  final List<CartLine> lines;
  final VoidCallback? onTap;

  /// A concrete preview of what this option means in riyals, so the host is
  /// not choosing between three abstract labels.
  String _preview(BuildContext context) {
    switch (mode) {
      case PaymentMode.equalSplit:
        final each = session.memberCount == 0 ? 0.0 : totals.total / session.memberCount;
        return context.tr('{amount} each × {count}',
            {'amount': Money.format(each), 'count': session.memberCount});
      case PaymentMode.hostPays:
        return context.tr('{name} pays {amount}',
            {'name': context.isolate(session.hostName), 'amount': Money.format(totals.total)});
      case PaymentMode.individual:
        final owners = lines.map((l) => l.ownerId).toSet().length;
        return context.tr(
            owners == 1
                ? '{count} person pay for what they added, fees split evenly'
                : '{count} people pay for what they added, fees split evenly|${countNote(owners)}',
            {'count': owners});
    }
  }

  IconData get _icon => switch (mode) {
        PaymentMode.individual => Icons.person_outline_rounded,
        PaymentMode.equalSplit => Icons.safety_divider_rounded,
        PaymentMode.hostPays => Icons.volunteer_activism_outlined,
      };

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        color: selected ? AppColors.primarySoft : AppColors.surface,
        border: selected ? Border.all(color: AppColors.primary, width: 1.6) : null,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 23,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(mode.label), style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(_preview(context), style: AppType.caption, maxLines: 2),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: selected ? AppColors.primary : AppColors.inkFaint,
            ),
          ],
        ),
      );
}

class _SelectedMode extends ConsumerWidget {
  const _SelectedMode({
    required this.mode,
    required this.isHost,
    required this.sessionId,
    required this.working,
  });

  final PaymentMode mode;
  final bool isHost;
  final String sessionId;
  final bool working;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        color: AppColors.primarySoft,
        shadows: const [],
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded,
                size: 22, color: AppColors.primary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr(mode.label), style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(context.tr(mode.description), style: AppType.caption, maxLines: 3),
                ],
              ),
            ),
            if (isHost)
              TextButton(
                onPressed: working
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.tr('Change the payment option?')),
                            content: Text(
                              context.tr('Any payments already made will be reset and the group '
                                  'returns to adding items.'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(context.tr('Keep')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(context.tr('Change')),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await ref.read(sessionServiceProvider).reopenOrdering(sessionId);
                      },
                child: Text(context.tr('Change')),
              ),
          ],
        ),
      );
}

class _MemberPaymentTile extends StatelessWidget {
  const _MemberPaymentTile({required this.member, required this.isMe});

  final SessionMember member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final paid = member.paymentStatus == MemberPaymentStatus.paid;
    final covered = member.paymentStatus == MemberPaymentStatus.notRequired;

    return GatherCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        children: [
          MemberAvatar.of(member, size: 38),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe
                      ? context.tr('{name} (you)', {'name': context.isolate(member.name)})
                      : context.isolate(member.name),
                  style: AppType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  covered
                      ? context.tr('Nothing to pay')
                      : (paid
                          ? context.tr('Paid {amount}', {'amount': Money.format(member.amountDue)})
                          : context.tr('Owes')),
                  style: AppType.caption.copyWith(
                    color: paid ? AppColors.success : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!covered && !paid)
            Text(
              Money.format(member.amountDue),
              style: AppType.money.copyWith(fontSize: 15, color: AppColors.accentDeep),
            )
          else
            Icon(
              covered ? Icons.remove_rounded : Icons.check_circle_rounded,
              color: covered ? AppColors.inkFaint : AppColors.success,
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.session,
    required this.me,
    required this.isHost,
    required this.working,
    this.onPay,
    required this.onPlace,
  });

  final GroupSession session;
  final SessionMember? me;
  final bool isHost;
  final bool working;
  final Future<void> Function()? onPay;
  final Future<void> Function() onPlace;

  @override
  Widget build(BuildContext context) {
    if (session.paymentMode == null) return const SizedBox.shrink();

    final iOwe = me?.paymentStatus == MemberPaymentStatus.pending;

    return Container(
      color: AppColors.background,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iOwe)
              GatherButton(
                label: context.tr('Pay {amount}', {'amount': Money.format(me!.amountDue)}),
                icon: Icons.lock_rounded,
                busy: working,
                onPressed: onPay,
              )
            else if (isHost)
              GatherButton(
                label: session.everyonePaid
                    ? 'Place the group order'
                    : context.tr('Waiting for {count} to pay|${countNote(session.memberCount - session.paidCount)}',
                        {'count': session.memberCount - session.paidCount}),
                icon: session.everyonePaid ? Icons.check_rounded : null,
                busy: working,
                onPressed: session.everyonePaid ? onPlace : null,
              )
            else
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: Radii.brMd,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 19, color: AppColors.success),
                    const SizedBox(width: Insets.sm),
                    Flexible(
                      child: Text(
                        session.everyonePaid
                            ? context.tr('All paid — {name} will place the order',
                                {'name': context.isolate(session.hostName)})
                            : context.tr('You are settled. Waiting for the others.'),
                        style: AppType.caption.copyWith(color: AppColors.success),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


/// US15 — the reward applied to this session, and a way to change it.
class _VoucherRow extends ConsumerWidget {
  const _VoucherRow({required this.session, required this.totals});

  final GroupSession session;
  final CartTotals totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = session.voucherCode;
    final uid = ref.watch(currentUidProvider) ?? '';
    final mine = ref.watch(myVouchersProvider).valueOrNull ?? const <UserVoucher>[];
    // A reward already on another unplaced group order is not offered again.
    final usable = RewardRules.spendable(mine,
        heldElsewhere: RewardRules.heldInSessions(
            ref.watch(mySessionsProvider).valueOrNull ?? const <GroupSession>[],
            holderUid: uid,
            exceptSessionId: session.id));

    if (applied != null && applied.isNotEmpty) {
      return GatherCard(
        color: AppColors.primaryTint,
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined, color: AppColors.primary),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.isolate(applied), style: AppType.bodyStrong),
                  Text(
                      context.tr('−{amount} off this order',
                          {'amount': Money.format(session.voucherDiscount)}),
                      style: AppType.caption),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(sessionServiceProvider).clearVoucher(session.id),
              child: Text(context.tr('Remove')),
            ),
          ],
        ),
      );
    }

    if (usable.isEmpty) return const SizedBox.shrink();

    return GatherCard(
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_outlined, color: AppColors.primary),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              context.tr(
                  usable.length == 1
                      ? '{count} reward available'
                      : '{count} rewards available|${countNote(usable.length)}',
                  {'count': usable.length}),
              style: AppType.body,
            ),
          ),
          TextButton(
            onPressed: () async {
              final chosen = await showModalBottomSheet<UserVoucher>(
                context: context,
                useRootNavigator: true,
                backgroundColor: AppColors.surface,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: Insets.sm),
                      for (final v in usable)
                        ListTile(
                          leading: const Icon(Icons.local_offer_outlined,
                              color: AppColors.primary),
                          title: Text(context.isolate(v.title)),
                          subtitle: Text('${context.isolate(v.code)} · ${context.tr(v.summary)}'),
                          onTap: () => Navigator.pop(context, v),
                        ),
                      const SizedBox(height: Insets.lg),
                    ],
                  ),
                ),
              );
              if (chosen == null || !context.mounted) return;

              final r = await ref.read(sessionServiceProvider).applyVoucher(
                    sessionId: session.id,
                    holderUid: uid,
                    voucher: chosen,
                    subtotal: totals.subtotal,
                    deliveryFee: totals.deliveryFee,
                  );
              if (!context.mounted) return;
              switch (r) {
                case Err(:final message):
                  AppSnack.error(context, message);
                case Ok(:final value):
                  AppSnack.show(
                      context, context.tr('−{amount} applied', {'amount': Money.format(value)}));
              }
            },
            child: Text(context.tr('Apply')),
          ),
        ],
      ),
    );
  }
}
