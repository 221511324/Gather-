import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import '../checkout/checkout_widgets.dart';

/// Saved payment methods (FR15, FR28).
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return BrandScaffold(
      title: 'Payment methods',
      showBack: true,
      padBody: false,
      bottomBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
        child: Row(
          children: [
            Expanded(
              child: GatherButton(
                label: 'Add card',
                icon: Icons.add_card_rounded,
                onPressed: () => AddCardSheet.show(context),
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: GatherOutlineButton(
                label: 'Add wallet',
                icon: Icons.account_balance_wallet_outlined,
                onPressed: () async {
                  final type = await showModalBottomSheet<PaymentMethodType>(
                    context: context,
                    backgroundColor: AppColors.surface,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: Insets.sm),
                          for (final type in [
                            PaymentMethodType.applePay,
                            PaymentMethodType.stcPay,
                            PaymentMethodType.cash,
                          ])
                            ListTile(
                              leading: Icon(paymentIcon(type), color: AppColors.primary),
                              title: Text(type.label),
                              onTap: () => Navigator.pop(context, type),
                            ),
                          const SizedBox(height: Insets.lg),
                        ],
                      ),
                    ),
                  );
                  if (type == null || uid == null || !context.mounted) return;
                  final result = await ref
                      .read(paymentServiceProvider)
                      .addWallet(uid: uid, type: type);
                  if (!context.mounted) return;
                  switch (result) {
                    case Err(:final message):
                      AppSnack.error(context, message);
                    case Ok():
                      AppSnack.show(context, '${type.label} added');
                  }
                },
              ),
            ),
          ],
        ),
      ),
      child: methodsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (methods) {
          if (methods.isEmpty) {
            return const EmptyView(
              icon: Icons.credit_card_off_outlined,
              title: 'No payment methods',
              message: 'Add a card or wallet so you can pay for orders and your '
                  'share of a group bill.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
            children: [
              for (final method in methods) ...[
                GatherCard(
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: method.isExpired ? AppColors.dangerSoft : AppColors.primarySoft,
                          borderRadius: Radii.brSm,
                        ),
                        child: Icon(
                          paymentIcon(method.type),
                          size: 22,
                          color: method.isExpired ? AppColors.danger : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(child: Text(method.label, style: AppType.bodyStrong)),
                                if (method.isDefault) ...[
                                  const SizedBox(width: Insets.sm),
                                  const StatusPill(
                                    label: 'Default',
                                    color: AppColors.primary,
                                    compact: true,
                                  ),
                                ],
                              ],
                            ),
                            if (method.type == PaymentMethodType.card)
                              Text(
                                method.isExpired
                                    ? 'Expired ${method.expiryLabel}'
                                    : '${method.holderName} · expires ${method.expiryLabel}',
                                style: AppType.caption.copyWith(
                                  color:
                                      method.isExpired ? AppColors.danger : AppColors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
                        tooltip: 'Payment method options',
                        onSelected: (value) async {
                          if (uid == null) return;
                          final service = ref.read(paymentServiceProvider);
                          if (value == 'default') {
                            await service.setDefault(uid, method.id);
                          } else if (value == 'delete') {
                            await service.removeMethod(uid, method.id);
                            if (context.mounted) {
                              AppSnack.show(context, 'Payment method removed');
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          if (!method.isDefault && !method.isExpired)
                            const PopupMenuItem(
                              value: 'default',
                              child: Text('Set as default'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Remove', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
              ],
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: AppColors.inkFaint),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'Gather stores only the card brand and last four digits. '
                      'Full card numbers are validated on your device and never saved.',
                      style: AppType.caption.copyWith(fontSize: 11.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Add a card. Validates properly (Luhn plus expiry) before saving.
class AddCardSheet extends ConsumerStatefulWidget {
  const AddCardSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const AddCardSheet(),
      );

  @override
  ConsumerState<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  bool _makeDefault = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _expiry.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final parts = _expiry.text.split('/');
    final result = await ref.read(paymentServiceProvider).addCard(
          uid: uid,
          number: _number.text,
          holderName: _name.text,
          expiryMonth: int.tryParse(parts.first) ?? 0,
          expiryYear: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
          cvv: _cvv.text,
          makeDefault: _makeDefault,
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        AppSnack.show(context, 'Card added');
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = PaymentService.brandOf(_number.text.replaceAll(RegExp(r'\D'), ''));

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
              Text('Add a card', style: AppType.headline),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Card number',
                controller: _number,
                hint: '4242 4242 4242 4242',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.credit_card_rounded,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                suffix: brand == 'Card'
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: Insets.md),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            brand,
                            style: AppType.label.copyWith(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                validator: (v) =>
                    PaymentService.validateCardNumber((v ?? '').replaceAll(RegExp(r'\D'), '')),
              ),
              const SizedBox(height: Insets.lg),
              GatherField(
                label: 'Name on card',
                controller: _name,
                hint: 'RAMA ALRASHODI',
                textCapitalization: TextCapitalization.characters,
                prefixIcon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter the name on the card' : null,
              ),
              const SizedBox(height: Insets.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GatherField(
                      label: 'Expiry',
                      controller: _expiry,
                      hint: 'MM/YY',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryFormatter(),
                      ],
                      validator: (v) {
                        final parts = (v ?? '').split('/');
                        if (parts.length != 2) return 'MM/YY';
                        return PaymentService.validateExpiry(
                          int.tryParse(parts[0]) ?? 0,
                          int.tryParse(parts[1]) ?? 0,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: GatherField(
                      label: 'CVV',
                      controller: _cvv,
                      hint: '123',
                      obscure: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (v) =>
                          (v ?? '').length < 3 ? 'Enter the security code' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              SwitchListTile(
                value: _makeDefault,
                onChanged: (v) => setState(() => _makeDefault = v),
                title: Text(
                  'Use as my default method',
                  style: AppType.bodyLarge.copyWith(fontSize: 15),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.white,
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(_error!, style: AppType.caption.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: Insets.lg),
              GatherButton(label: 'Add card', onPressed: _submit),
              const SizedBox(height: Insets.md),
              Text(
                'This is a course project: payments are simulated and no real '
                'money moves. The card number never leaves your device.',
                style: AppType.caption.copyWith(fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Groups the card number into blocks of four as it is typed.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = PaymentService.formatCardNumber(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Inserts the slash in MM/YY.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
