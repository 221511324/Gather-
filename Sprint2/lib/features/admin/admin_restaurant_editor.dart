import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';

/// Create or edit a restaurant (FR31).
class RestaurantEditorSheet extends ConsumerStatefulWidget {
  const RestaurantEditorSheet({super.key, this.existing});

  final Restaurant? existing;

  static Future<void> show(BuildContext context, {Restaurant? existing}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => RestaurantEditorSheet(existing: existing),
      );

  @override
  ConsumerState<RestaurantEditorSheet> createState() => _RestaurantEditorSheetState();
}

class _RestaurantEditorSheetState extends ConsumerState<RestaurantEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _cuisine = TextEditingController(text: widget.existing?.cuisine ?? '');
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _rating =
      TextEditingController(text: (widget.existing?.rating ?? 0).toStringAsFixed(1));
  late final _ratingCount = TextEditingController(text: '${widget.existing?.ratingCount ?? 0}');
  late final _deliveryFee =
      TextEditingController(text: (widget.existing?.deliveryFee ?? 0).toStringAsFixed(0));
  late final _deliveryMinutes =
      TextEditingController(text: '${widget.existing?.deliveryMinutes ?? 30}');
  late final _minimumOrder =
      TextEditingController(text: (widget.existing?.minimumOrder ?? 0).toStringAsFixed(0));
  late final _tags = TextEditingController(text: (widget.existing?.tags ?? const []).join(', '));

  late int _priceLevel = widget.existing?.priceLevel ?? 2;
  late bool _isOpen = widget.existing?.isOpen ?? true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _cuisine.dispose();
    _imageUrl.dispose();
    _description.dispose();
    _rating.dispose();
    _ratingCount.dispose();
    _deliveryFee.dispose();
    _deliveryMinutes.dispose();
    _minimumOrder.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final restaurant = Restaurant(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      cuisine: _cuisine.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      description: _description.text.trim(),
      rating: double.tryParse(_rating.text) ?? 0,
      ratingCount: int.tryParse(_ratingCount.text) ?? 0,
      deliveryFee: double.tryParse(_deliveryFee.text) ?? 0,
      deliveryMinutes: int.tryParse(_deliveryMinutes.text) ?? 30,
      minimumOrder: double.tryParse(_minimumOrder.text) ?? 0,
      // A tag list is easier to type as one comma-separated line than as a
      // chip editor, and empty fragments from trailing commas are dropped.
      tags: _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      isOpen: _isOpen,
      priceLevel: _priceLevel,
    );

    final result = await ref.read(catalogServiceProvider).upsertRestaurant(restaurant);
    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        AppSnack.show(
          context,
          widget.existing == null ? 'Restaurant created' : 'Restaurant updated',
        );
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
                Text(
                  widget.existing == null ? 'New restaurant' : 'Edit restaurant',
                  style: AppType.headline,
                ),
                const SizedBox(height: Insets.xl),
                GatherField(
                  label: 'Name',
                  controller: _name,
                  hint: 'Burger Barn',
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Give it a name' : null,
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Cuisine',
                  controller: _cuisine,
                  hint: 'Burgers · American',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Say what kind of food it serves' : null,
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Image URL',
                  controller: _imageUrl,
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                  helper: 'Shown as the cover photo across the app',
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Description',
                  controller: _description,
                  hint: 'A short line for the restaurant page',
                  maxLines: 3,
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GatherField(
                        label: 'Rating',
                        controller: _rating,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null || parsed < 0 || parsed > 5) {
                            return 'Between 0 and 5';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: GatherField(
                        label: 'Reviews',
                        controller: _ratingCount,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            (int.tryParse(v ?? '') ?? -1) < 0 ? 'Zero or more' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GatherField(
                        label: 'Delivery fee',
                        controller: _deliveryFee,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        helper: Money.currencyCode,
                        validator: (v) =>
                            (double.tryParse(v ?? '') ?? -1) < 0 ? 'Zero or more' : null,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: GatherField(
                        label: 'Delivery mins',
                        controller: _deliveryMinutes,
                        keyboardType: TextInputType.number,
                        helper: 'Lower bound',
                        validator: (v) =>
                            (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Above zero' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Minimum order (${Money.currencyCode})',
                  controller: _minimumOrder,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  helper: 'Use 0 for no minimum',
                  validator: (v) =>
                      (double.tryParse(v ?? '') ?? -1) < 0 ? 'Zero or more' : null,
                ),
                const SizedBox(height: Insets.lg),
                Text('Price level', style: AppType.label),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.sm,
                  children: [
                    for (var level = 1; level <= 3; level++)
                      ChoiceChip(
                        label: Text(List.filled(level, r'$').join()),
                        selected: _priceLevel == level,
                        onSelected: (_) => setState(() => _priceLevel = level),
                        showCheckmark: false,
                        labelStyle: AppType.label.copyWith(
                          fontSize: 12.5,
                          color: _priceLevel == level ? Colors.white : AppColors.ink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Tags',
                  controller: _tags,
                  hint: 'halal, family friendly, late night',
                  helper: 'Separate with commas — these feed search',
                ),
                const SizedBox(height: Insets.sm),
                SwitchListTile(
                  value: _isOpen,
                  onChanged: (v) => setState(() => _isOpen = v),
                  title: Text('Open for orders',
                      style: AppType.bodyLarge.copyWith(fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                ),
                if (_error != null) ...[
                  const SizedBox(height: Insets.sm),
                  Text(_error!, style: AppType.caption.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: Insets.lg),
                GatherButton(
                  label: widget.existing == null ? 'Create restaurant' : 'Save changes',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      );
}
