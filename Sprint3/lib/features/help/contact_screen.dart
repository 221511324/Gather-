import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';

/// Report an issue to the admins (US17-AC3).
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  TicketCategory _category = TicketCategory.other;
  String? _orderId;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(currentUserOrNullProvider);
    if (user == null) return;

    final result = await ref.read(supportServiceProvider).submit(
          user: user,
          subject: _subject.text,
          message: _message.text,
          category: _category,
          orderId: _orderId,
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        AppSnack.show(context, 'Thanks — we will get back to you shortly');
        context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(myOrdersProvider).valueOrNull ?? const <FoodOrder>[];

    return BrandScaffold(
      title: 'Report an issue',
      showBack: true,
      scrollable: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Tell us what happened and an admin will look into it.'),
              style: AppType.bodyLarge.copyWith(color: AppColors.inkMuted, fontSize: 14.5),
            ),
            const SizedBox(height: Insets.xxl),
            Text(context.tr('What is this about?'), style: AppType.label.copyWith(fontSize: 15)),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: [
                for (final category in TicketCategory.values)
                  ChoiceChip(
                    label: Text(context.tr(category.label)),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                    showCheckmark: false,
                    labelStyle: AppType.label.copyWith(
                      fontSize: 13,
                      color: _category == category ? Colors.white : AppColors.ink,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.xl),
            if (orders.isNotEmpty) ...[
              Text(context.tr('Related order (optional)'), style: AppType.label.copyWith(fontSize: 15)),
              const SizedBox(height: Insets.sm),
              GatherCard(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _orderId,
                    isExpanded: true,
                    hint: Text(context.tr('None'), style: AppType.body.copyWith(fontSize: 14.5)),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(context.tr('None'))),
                      for (final order in orders.take(10))
                        DropdownMenuItem<String?>(
                          value: order.id,
                          child: Text(
                            '${context.isolate(order.restaurantName)} · ${context.tr(order.status.label)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _orderId = v),
                  ),
                ),
              ),
              const SizedBox(height: Insets.xl),
            ],
            GatherField(
              label: 'Subject',
              controller: _subject,
              hint: 'Short summary',
              maxLength: 60,
              validator: (v) => (v ?? '').trim().length < 3 ? 'Add a short subject' : null,
            ),
            const SizedBox(height: Insets.xl),
            GatherField(
              label: 'What happened?',
              controller: _message,
              hint: 'Describe the issue in a few sentences',
              maxLines: 5,
              maxLength: 600,
              validator: (v) =>
                  (v ?? '').trim().length < 10 ? 'Add a little more detail' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(context.tr(_error!), style: AppType.caption.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: Insets.xxl),
            GatherButton(label: 'Send to support', icon: Icons.send_rounded, onPressed: _submit),
            const SizedBox(height: Insets.xl),
            GatherCard(
              color: AppColors.primaryTint,
              shadows: const [],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Other ways to reach us'), style: AppType.bodyStrong),
                  const SizedBox(height: Insets.sm),
                  _ContactLine(icon: Icons.mail_outline_rounded, text: 'support@gather.app'),
                  const SizedBox(height: Insets.xs),
                  _ContactLine(icon: Icons.schedule_rounded, text: 'Sunday–Thursday, 9am–6pm'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: Insets.sm),
          Text(context.tr(text), style: AppType.caption.copyWith(fontSize: 13)),
        ],
      );
}
