import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
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

    final catalog = ref.watch(paymentCatalogProvider).valueOrNull ?? const <PaymentOption>[];
    final effectiveDefault = ref.watch(defaultPaymentMethodProvider);
    bool isUsable(SavedPaymentMethod m) => PaymentService.isUsable(m, catalog);

    return BrandScaffold(
      title: 'Payment methods',
      showBack: true,
      padBody: false,
      bottomBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
        child: GatherButton(
          label: 'Add payment method',
          icon: Icons.add_card_rounded,
          onPressed: () {
            // Not `() => start(...)`: GatherButton awaits whatever the
            // callback returns, and the sheet's future only completes when it
            // closes, so the button sat disabled behind it.
            AddPaymentMethodSheet.start(context, ref);
          },
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
                // A method whose option the administrator switched off stays
                // listed — it is the person's own — but greyed out and never
                // offered for paying.
                Opacity(
                  opacity: isUsable(method) ? 1 : 0.55,
                  child: GatherCard(
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
                                  Flexible(child: Text(context.isolate(method.label), style: AppType.bodyStrong)),
                                  if (method.id == effectiveDefault?.id) ...[
                                    const SizedBox(width: Insets.sm),
                                    const StatusPill(
                                      label: 'Default',
                                      color: AppColors.primary,
                                      compact: true,
                                    ),
                                  ],
                                ],
                              ),
                              if (!isUsable(method))
                                Text(
                                  context.tr('Currently unavailable'),
                                  style: AppType.caption.copyWith(color: AppColors.danger),
                                )
                              else if (method.type == PaymentMethodType.card)
                                Text(
                                  method.isExpired
                                      ? context.tr('Expired {date}', {'date': method.expiryLabel})
                                      : '${context.isolate(method.holderName)} · '
                                          '${context.tr('expires {date}', {'date': method.expiryLabel})}',
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
                          tooltip: context.tr('Payment method options'),
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
                            if (method.id != effectiveDefault?.id &&
                                isUsable(method) &&
                                !method.isExpired)
                              PopupMenuItem(
                                value: 'default',
                                child: Text(context.tr('Set as default')),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.tr('Remove'),
                                  style: const TextStyle(color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                      context.tr(
                          'Gather stores only the card brand and last four digits. '
                          'Full card numbers are validated on your device and never saved.'),
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

/// The one way in for adding a payment method (US20).
///
/// Lists whatever the administrator has enabled, live, cards first. Card
/// continues to [AddCardSheet]; a wallet such as Apple Pay or STC Pay is set
/// up on the spot. When cards are the only option the list is skipped.
class AddPaymentMethodSheet extends ConsumerWidget {
  const AddPaymentMethodSheet({super.key});

  static Future<void> start(BuildContext context, WidgetRef ref) async {
    final enabled = ref.read(paymentOptionsProvider).valueOrNull;
    if (enabled != null &&
        enabled.length == 1 &&
        PaymentService.typeForOption(enabled.single.name) == PaymentMethodType.card) {
      return AddCardSheet.show(context);
    }

    final option = await showModalBottomSheet<PaymentOption>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const AddPaymentMethodSheet(),
    );
    if (option == null || !context.mounted) return;

    if (PaymentService.typeForOption(option.name) == PaymentMethodType.card) {
      return AddCardSheet.show(context);
    }

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final result = await ref.read(paymentServiceProvider).addOption(uid: uid, option: option);
    if (!context.mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        AppSnack.show(context, context.tr('{name} added', {'name': context.isolate(option.name)}));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsAsync = ref.watch(paymentOptionsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            Insets.gutter, Insets.sm, Insets.gutter, Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Add payment method'), style: AppType.headline),
            const SizedBox(height: Insets.lg),
            optionsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Insets.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(message: '$e'),
              data: (enabled) {
                final options = PaymentService.offeredOptions(enabled);
                if (options.isEmpty) {
                  return const EmptyView(
                    icon: Icons.credit_card_off_outlined,
                    title: 'No payment methods available',
                    message: 'Gather is not accepting new payment methods right now. '
                        'Please check back later.',
                    compact: true,
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          paymentIcon(PaymentService.typeForOption(option.name)),
                          color: AppColors.primary,
                        ),
                        title: Text(context.isolate(option.name)),
                        subtitle: option.description.isEmpty
                            ? null
                            : Text(context.isolate(option.description)),
                        trailing:
                            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                        onTap: () => Navigator.pop(context, option),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Add a card. Validates properly (Luhn plus expiry) before saving.
class AddCardSheet extends ConsumerStatefulWidget {
  const AddCardSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
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
        padding: EdgeInsetsDirectional.fromSTEB(
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
              Text(context.tr('Add a card'), style: AppType.headline),
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
                        padding: const EdgeInsetsDirectional.only(end: Insets.md),
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
                  context.tr('Use as my default method'),
                  style: AppType.bodyLarge.copyWith(fontSize: 15),
                ),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.white,
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                Text(context.tr(_error!), style: AppType.caption.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: Insets.lg),
              GatherButton(label: 'Add card', onPressed: _submit),
              const SizedBox(height: Insets.md),
              Text(
                context.tr('This is a course project: payments are simulated and no real '
                    'money moves. The card number never leaves your device.'),
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
