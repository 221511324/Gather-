import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/ar/qa1.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import 'admin_shell.dart';

/// US15 — the reward catalogue, as the administrator sees it.
class AdminRewardsScreen extends ConsumerWidget {
  const AdminRewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(adminVouchersProvider);

    return AdminShell(
      title: 'Rewards',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: context.tr('New reward'),
          onPressed: () {
            RewardEditor.show(context);
          },
        ),
      ],
      child: catalogue.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return EmptyView(
              icon: Icons.card_giftcard_outlined,
              title: 'No rewards yet',
              message: 'Create a discount customers can claim with a code.',
              actionLabel: 'Create one',
              onAction: () => RewardEditor.show(context),
            );
          }
          final live = vouchers.where((v) => v.isOffered).length;
          return ListView(
            padding: const EdgeInsets.all(Insets.gutter),
            children: [
              Text(
                  context.tr('{count} rewards · {live} available to claim|${countNote(vouchers.length)}',
                      {'count': vouchers.length, 'live': live}),
                  style: AppType.caption),
              const SizedBox(height: Insets.md),
              for (final v in vouchers) ...[
                _RewardTile(voucher: v),
                const SizedBox(height: Insets.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RewardTile extends ConsumerWidget {
  const _RewardTile({required this.voucher});

  final Voucher voucher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = voucher;
    final service = ref.read(voucherServiceProvider);

    // Why it is not claimable is more useful than simply that it is not.
    final blocked = switch (true) {
      _ when !v.isActive => 'Hidden',
      _ when v.hasExpired => 'Expired',
      _ when v.isExhausted => 'All claimed',
      _ => null,
    };

    return GatherCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(context.isolate(v.title), style: AppType.bodyStrong)),
                    const SizedBox(width: Insets.sm),
                    StatusPill(
                      label: blocked ?? v.summary,
                      color: blocked == null ? AppColors.success : AppColors.inkFaint,
                      compact: true,
                    ),
                  ],
                ),
                Text(v.code, style: AppType.caption.copyWith(letterSpacing: 1)),
                if (v.onSpinWheel)
                  Text(context.tr('On the Spin & Win wheel'),
                      style: AppType.caption.copyWith(color: AppColors.accentDeep)),
                Text(
                  [
                    if (v.minimumOrder > 0)
                      context.tr('min {amount} SAR',
                          {'amount': v.minimumOrder.toStringAsFixed(0)}),
                    v.maxRedemptions > 0
                        ? context.tr('{claimed}/{max} claimed',
                            {'claimed': v.redeemedCount, 'max': v.maxRedemptions})
                        : context.tr('{claimed} claimed', {'claimed': v.redeemedCount}),
                    if (v.validUntil != null)
                      context.tr('until {date}',
                          {'date': Dates.dayMonth(context, v.validUntil!)}),
                  ].join(' · '),
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: v.isActive,
            activeTrackColor: AppColors.primary,
            onChanged: (value) async {
              final r = await service.setActive(v.id, value);
              if (!context.mounted) return;
              if (r case Err(:final message)) AppSnack.error(context, message);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
            tooltip: context.tr('Reward options'),
            onSelected: (value) async {
              if (value == 'edit') {
                RewardEditor.show(context, voucher: v);
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr('Remove {name}?', {'name': v.code})),
                  content: Text(context.tr(
                    'Rewards people have already claimed keep working — they '
                    'hold their own copy. Turning it off instead stops new '
                    'claims and can be undone.',
                  )),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.tr('Cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.tr('Remove'),
                            style: const TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (confirmed != true) return;
              final r = await service.delete(v.id);
              if (!context.mounted) return;
              AppSnack.show(context, switch (r) {
                Err(:final message) => message,
                Ok() => context.tr('{name} removed', {'name': v.code}),
              });
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(context.tr('Edit'))),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(context.tr('Remove'),
                      style: const TextStyle(color: AppColors.danger))),
            ],
          ),
        ],
      ),
    );
  }
}

/// Create or change a reward.
class RewardEditor extends ConsumerStatefulWidget {
  const RewardEditor({super.key, this.voucher});

  final Voucher? voucher;

  static Future<void> show(BuildContext context, {Voucher? voucher}) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => RewardEditor(voucher: voucher),
      );

  @override
  ConsumerState<RewardEditor> createState() => _RewardEditorState();
}

class _RewardEditorState extends ConsumerState<RewardEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.voucher?.code ?? '');
  late final _title = TextEditingController(text: widget.voucher?.title ?? '');
  late final _value = TextEditingController(
      text: widget.voucher == null || widget.voucher!.discountValue == 0
          ? ''
          : widget.voucher!.discountValue.toStringAsFixed(0));
  late final _minimum = TextEditingController(
      text: widget.voucher == null || widget.voucher!.minimumOrder == 0
          ? ''
          : widget.voucher!.minimumOrder.toStringAsFixed(0));
  late final _limit = TextEditingController(
      text: widget.voucher == null || widget.voucher!.maxRedemptions == 0
          ? ''
          : '${widget.voucher!.maxRedemptions}');
  late var _type = widget.voucher?.discountType ?? DiscountType.percentage;
  late DateTime? _until = widget.voucher?.validUntil;
  late var _onWheel = widget.voucher?.onSpinWheel ?? false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _value.dispose();
    _minimum.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(voucherServiceProvider).upsert(Voucher(
          id: widget.voucher?.id ?? '',
          code: _code.text,
          title: _title.text,
          discountType: _type,
          discountValue: double.tryParse(_value.text) ?? 0,
          minimumOrder: double.tryParse(_minimum.text) ?? 0,
          maxRedemptions: int.tryParse(_limit.text) ?? 0,
          validUntil: _until,
          isActive: widget.voucher?.isActive ?? true,
          onSpinWheel: _onWheel,
        ));

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok(:final value):
        AppSnack.show(context, context.tr('{name} saved', {'name': value.code}));
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.voucher == null;
    final needsValue = _type != DiscountType.freeDelivery;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter,
            Insets.xl + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(isNew ? 'New reward' : 'Edit reward'), style: AppType.headline),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Code',
                controller: _code,
                hint: 'GATHER10',
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v ?? '').trim().length < 3
                    ? 'At least three characters'
                    : null,
              ),
              const SizedBox(height: Insets.lg),
              GatherField(
                label: 'Name',
                controller: _title,
                hint: '10% off your group order|hint',
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Give the reward a name' : null,
              ),
              const SizedBox(height: Insets.lg),
              Text(context.tr('Discount'), style: AppType.label),
              const SizedBox(height: Insets.xs),
              SegmentedButton<DiscountType>(
                segments: [
                  const ButtonSegment(value: DiscountType.percentage, label: Text('%')),
                  const ButtonSegment(value: DiscountType.fixedAmount, label: Text('SAR')),
                  ButtonSegment(
                      value: DiscountType.freeDelivery, label: Text(context.tr('Delivery'))),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              if (needsValue) ...[
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: _type == DiscountType.percentage
                      ? 'Per cent off'
                      : 'Riyals off',
                  controller: _value,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter an amount';
                    if (_type == DiscountType.percentage && n > 100) {
                      return 'A percentage cannot be over 100';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: Insets.lg),
              GatherField(
                label: 'Minimum order',
                controller: _minimum,
                hint: 'Leave empty for none',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: Insets.lg),
              GatherField(
                label: 'How many can be claimed',
                controller: _limit,
                hint: 'Leave empty for unlimited',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: Insets.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('Expires'), style: AppType.body),
                subtitle: Text(
                  _until == null
                      ? context.tr('No expiry')
                      : Dates.dayMonthYear(context, _until!),
                  style: AppType.caption,
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _until ?? now.add(const Duration(days: 30)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => _until = picked);
                  },
                  child: Text(context.tr(_until == null ? 'Set' : 'Change')),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _onWheel,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _onWheel = v),
                title: Text(context.tr('Show on Spin & Win'), style: AppType.body),
                subtitle: Text(
                  context.tr('Customers can win it on the daily wheel. With fewer '
                      'than two rewards on the wheel, the built-in prizes are used.'),
                  style: AppType.caption,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.md),
                Text(context.tr(_error!),
                    style: AppType.caption.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: Insets.xl),
              GatherButton(label: 'Save', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
