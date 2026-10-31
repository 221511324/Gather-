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
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import 'admin_shell.dart';

/// What the platform accepts as payment.
///
/// The options live in Firestore rather than in the app, so adding PayPal is
/// something an administrator does here — not something that needs a new
/// build and a new release.
class AdminPaymentsScreen extends ConsumerWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(adminPaymentOptionsProvider);

    return AdminShell(
      title: 'Payment methods',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded),
          tooltip: context.tr('New payment method'),
          onPressed: () {
            PaymentOptionEditor.show(context);
          },
        ),
      ],
      child: optionsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (options) {
          if (options.isEmpty) {
            return EmptyView(
              icon: Icons.credit_card_outlined,
              title: 'No payment methods yet',
              message: 'Add the ways customers are allowed to pay — '
                  'a card, a wallet, PayPal.',
              actionLabel: 'Add one',
              onAction: () => PaymentOptionEditor.show(context),
            );
          }

          final enabled = options.where((o) => o.isEnabled).length;
          return ListView(
            padding: const EdgeInsets.all(Insets.gutter),
            children: [
              Text(
                context.tr(
                  options.length == 1
                      ? '{count} method · {enabled} available to customers'
                      : '{count} methods · {enabled} available to customers|${countNote(options.length)}',
                  {'count': options.length, 'enabled': enabled},
                ),
                style: AppType.caption,
              ),
              const SizedBox(height: Insets.md),
              for (final option in options) ...[
                _OptionTile(option: option),
                const SizedBox(height: Insets.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OptionTile extends ConsumerWidget {
  const _OptionTile({required this.option});

  final PaymentOption option;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(paymentServiceProvider);

    return GatherCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: option.isEnabled
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.line,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: option.isEnabled ? AppColors.primary : AppColors.inkFaint,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(option.name, style: AppType.bodyStrong)),
                    if (!option.isEnabled) ...[
                      const SizedBox(width: Insets.sm),
                      const StatusPill(
                        label: 'Hidden',
                        color: AppColors.inkFaint,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                if (option.description.isNotEmpty)
                  Text(option.description, style: AppType.caption),
              ],
            ),
          ),
          Switch(
            value: option.isEnabled,
            activeTrackColor: AppColors.primary,
            onChanged: (value) async {
              final r = await service.setOptionEnabled(option.id, value);
              if (!context.mounted) return;
              if (r case Err(:final message)) AppSnack.show(context, message);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
            tooltip: context.tr('Payment method options'),
            onSelected: (value) async {
              if (value == 'edit') {
                PaymentOptionEditor.show(context, option: option);
                return;
              }
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.tr('Remove {name}?', {'name': option.name})),
                  content: Text(context.tr(
                    'Customers will no longer be able to choose it. Turning it '
                    'off instead keeps it on this list and can be undone.',
                  )),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.tr('Cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.tr('Remove'),
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              final r = await service.deleteOption(option.id);
              if (!context.mounted) return;
              AppSnack.show(
                context,
                switch (r) {
                  Err(:final message) => message,
                  Ok() => context.tr('{name} removed', {'name': option.name}),
                },
              );
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(context.tr('Edit'))),
              PopupMenuItem(
                value: 'delete',
                child: Text(context.tr('Remove'),
                    style: const TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add or rename a payment method.
class PaymentOptionEditor extends ConsumerStatefulWidget {
  const PaymentOptionEditor({super.key, this.option});

  final PaymentOption? option;

  static Future<void> show(BuildContext context, {PaymentOption? option}) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => PaymentOptionEditor(option: option),
      );

  @override
  ConsumerState<PaymentOptionEditor> createState() => _PaymentOptionEditorState();
}

class _PaymentOptionEditorState extends ConsumerState<PaymentOptionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.option?.name ?? '');
  late final _description =
      TextEditingController(text: widget.option?.description ?? '');
  late var _enabled = widget.option?.isEnabled ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.option;
    final result = await ref.read(paymentServiceProvider).upsertOption(
          PaymentOption(
            id: existing?.id ?? '',
            name: _name.text,
            description: _description.text.trim(),
            isEnabled: _enabled,
            sortOrder: existing?.sortOrder ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
            createdAt: existing?.createdAt,
          ),
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok(:final value):
        AppSnack.show(context, context.tr('{name} saved', {'name': value.name}));
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.option == null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.sm,
          Insets.gutter,
          Insets.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(isNew ? 'New payment method' : 'Edit payment method'),
                  style: AppType.headline),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Name',
                controller: _name,
                hint: 'PayPal',
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Enter a name for the payment method'
                    : null,
              ),
              const SizedBox(height: Insets.lg),
              GatherField(
                label: 'Description',
                controller: _description,
                hint: 'Shown to the customer — optional',
              ),
              const SizedBox(height: Insets.md),
              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primary,
                title: Text(context.tr('Available to customers'), style: AppType.body),
                subtitle: Text(
                  context.tr(_enabled
                      ? 'Customers can choose this now'
                      : 'Saved, but hidden from customers'),
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
