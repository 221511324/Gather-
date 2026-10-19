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
    final method = _method ?? ref.read(defaultPaymentMethodProvider);
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
    final method = _method ?? ref.read(defaultPaymentMethodProvider);

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
          await ref
              .read(sessionServiceProvider)
              .markPlaced(sessionId: session.id, orderId: value.id);
          if (mounted) context.pushReplacement(Routes.trackOrder(value.id));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider(widget.sessionId)).valueOrNull;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final totals = ref.watch(sessionTotalsProvider(widget.sessionId));
    final lines = ref.watch(sessionLinesProvider(widget.sessionId)).valueOrNull ?? const <CartLine>[];
    final methods = ref.watch(paymentMethodsProvider).valueOrNull ?? const <SavedPaymentMethod>[];

    if (session == null || user == null) {
      return const BrandScaffold(title: 'Group payment', showBack: true, child: LoadingView());
    }

    final isHost = session.isHostOf(user.uid);
    final me = session.memberOf(user.uid);
    final mode = session.paymentMode;
    final method = _method ?? ref.watch(defaultPaymentMethodProvider);

    return BrandScaffold(
      title: 'Group payment',
      subtitle: session.name,
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
                  ? '${Money.format(totals.total / session.memberCount)} each if split equally'
                  : null,
            ),
          ),
          const SizedBox(height: Insets.xxl),

          if (mode == null) ...[
            if (isHost) ...[
              CheckoutRow(
                icon: Icons.location_on_outlined,
                label: 'DELIVER TO',
                value: session.deliveryAddress?.isNotEmpty == true
                    ? session.deliveryAddress!
                    : 'Add a delivery address',
                warning: session.deliveryAddress?.isNotEmpty != true,
                actionLabel:
                    session.deliveryAddress?.isNotEmpty == true ? 'Change' : 'Add',
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
              title: 'Payment status (${session.paidCount}/${session.memberCount})',
            ),
            for (final member in session.members) ...[
              _MemberPaymentTile(member: member, isMe: member.uid == user.uid),
              const SizedBox(height: Insets.sm),
            ],
            const SizedBox(height: Insets.lg),
            if (me != null && me.paymentStatus == MemberPaymentStatus.pending)
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
          ],

          const SizedBox(height: Insets.xxl),
          SectionHeader(title: 'The order (${lines.length})'),
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
  String get _preview {
    switch (mode) {
      case PaymentMode.equalSplit:
        final each = session.memberCount == 0 ? 0.0 : totals.total / session.memberCount;
        return '${Money.format(each)} each × ${session.memberCount}';
      case PaymentMode.hostPays:
        return '${session.hostName} pays ${Money.format(totals.total)}';
      case PaymentMode.individual:
        final owners = lines.map((l) => l.ownerId).toSet().length;
        return '$owners ${owners == 1 ? 'person' : 'people'} pay for what they added, '
            'fees split evenly';
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
                  Text(mode.label, style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(_preview, style: AppType.caption, maxLines: 2),
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
                  Text(mode.label, style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(mode.description, style: AppType.caption, maxLines: 3),
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
                            title: const Text('Change the payment option?'),
                            content: const Text(
                              'Any payments already made will be reset and the group '
                              'returns to adding items.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Keep'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        await ref.read(sessionServiceProvider).reopenOrdering(sessionId);
                      },
                child: const Text('Change'),
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
                  isMe ? '${member.name} (you)' : member.name,
                  style: AppType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  covered
                      ? 'Nothing to pay'
                      : (paid ? 'Paid ${Money.format(member.amountDue)}' : 'Owes'),
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
                label: 'Pay ${Money.format(me!.amountDue)}',
                icon: Icons.lock_rounded,
                busy: working,
                onPressed: onPay,
              )
            else if (isHost)
              GatherButton(
                label: session.everyonePaid
                    ? 'Place the group order'
                    : 'Waiting for ${session.memberCount - session.paidCount} to pay',
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
                            ? 'All paid — ${session.hostName} will place the order'
                            : 'You are settled. Waiting for the others.',
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
