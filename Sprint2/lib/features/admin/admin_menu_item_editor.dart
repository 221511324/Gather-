import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';

const _uuid = Uuid();

/// Create or edit a menu item, including its customization groups (FR4, FR31).
class MenuItemEditorSheet extends ConsumerStatefulWidget {
  const MenuItemEditorSheet({super.key, required this.restaurantId, this.existing});

  final String restaurantId;
  final MenuItem? existing;

  static Future<void> show(
    BuildContext context, {
    required String restaurantId,
    MenuItem? existing,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => MenuItemEditorSheet(restaurantId: restaurantId, existing: existing),
      );

  @override
  ConsumerState<MenuItemEditorSheet> createState() => _MenuItemEditorSheetState();
}

class _MenuItemEditorSheetState extends ConsumerState<MenuItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _price =
      TextEditingController(text: (widget.existing?.price ?? 0).toStringAsFixed(2));
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _rating =
      TextEditingController(text: (widget.existing?.rating ?? 0).toStringAsFixed(1));
  late final _calories = TextEditingController(text: '${widget.existing?.calories ?? ''}');

  late FoodCategory _category = widget.existing?.category ?? FoodCategory.meal;
  late bool _isAvailable = widget.existing?.isAvailable ?? true;
  late bool _isBestSeller = widget.existing?.isBestSeller ?? false;
  late final List<_GroupDraft> _groups = [
    for (final group in widget.existing?.optionGroups ?? const <OptionGroup>[])
      _GroupDraft.from(group),
  ];

  /// Groups the admin removed. Their controllers are kept until the sheet
  /// closes rather than disposed on the spot, because the fields bound to
  /// them are still being torn down in the same frame.
  final List<_GroupDraft> _retiredGroups = [];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _imageUrl.dispose();
    _rating.dispose();
    _calories.dispose();
    for (final group in [..._groups, ..._retiredGroups]) {
      group.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final item = MenuItem(
      id: widget.existing?.id ?? '',
      restaurantId: widget.restaurantId,
      name: _name.text.trim(),
      price: double.tryParse(_price.text) ?? 0,
      imageUrl: _imageUrl.text.trim(),
      category: _category,
      description: _description.text.trim(),
      // Groups with no choices would render as an empty, unfillable step on
      // the item sheet, so they are dropped rather than saved.
      optionGroups: _groups
          .map((g) => g.toGroup())
          .where((g) => g.choices.isNotEmpty)
          .toList(),
      rating: double.tryParse(_rating.text) ?? 0,
      isAvailable: _isAvailable,
      isBestSeller: _isBestSeller,
      calories: int.tryParse(_calories.text.trim()),
    );

    final result = await ref.read(catalogServiceProvider).upsertMenuItem(item);
    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        AppSnack.show(context, widget.existing == null ? 'Item added' : 'Item updated');
        Navigator.pop(context);
    }
  }

  void _addGroup() => setState(() => _groups.add(_GroupDraft(id: _uuid.v4())));

  void _removeGroup(int index) =>
      setState(() => _retiredGroups.add(_groups.removeAt(index)));

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
                  widget.existing == null ? 'New menu item' : 'Edit menu item',
                  style: AppType.headline,
                ),
                const SizedBox(height: Insets.xl),
                Wrap(
                  spacing: Insets.sm,
                  children: [
                    for (final category in FoodCategory.values)
                      ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                        showCheckmark: false,
                        labelStyle: AppType.label.copyWith(
                          fontSize: 12.5,
                          color: _category == category ? Colors.white : AppColors.ink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Name',
                  controller: _name,
                  hint: 'Double cheeseburger',
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Give it a name' : null,
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Description',
                  controller: _description,
                  hint: 'What is in it',
                  maxLines: 3,
                ),
                const SizedBox(height: Insets.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: GatherField(
                        label: 'Price (${Money.currencyCode})',
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null || parsed <= 0) return 'Above zero';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: Insets.md),
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
                  ],
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Image URL',
                  controller: _imageUrl,
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: Insets.lg),
                GatherField(
                  label: 'Calories',
                  controller: _calories,
                  keyboardType: TextInputType.number,
                  helper: 'Optional — leave blank to hide it',
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return null;
                    return (int.tryParse(text) ?? -1) < 0 ? 'Zero or more' : null;
                  },
                ),
                const SizedBox(height: Insets.sm),
                SwitchListTile(
                  value: _isAvailable,
                  onChanged: (v) => setState(() => _isAvailable = v),
                  title: Text('Available to order',
                      style: AppType.bodyLarge.copyWith(fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                ),
                SwitchListTile(
                  value: _isBestSeller,
                  onChanged: (v) => setState(() => _isBestSeller = v),
                  title: Text('Best seller', style: AppType.bodyLarge.copyWith(fontSize: 15)),
                  subtitle: Text('Featured on the home feed', style: AppType.caption),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: Colors.white,
                ),
                const SizedBox(height: Insets.lg),
                Text('Customization', style: AppType.label),
                const SizedBox(height: 2),
                Text(
                  'Each group is one question on the item sheet. Requiring a '
                  'pick means setting its minimum to 1.',
                  style: AppType.caption,
                ),
                const SizedBox(height: Insets.md),
                for (var i = 0; i < _groups.length; i++) ...[
                  _GroupEditor(
                    // Keyed by the group so removing one from the middle does
                    // not hand its form fields to the group below it.
                    key: ValueKey(_groups[i].id),
                    draft: _groups[i],
                    onChanged: () => setState(() {}),
                    onRemove: () => _removeGroup(i),
                  ),
                  const SizedBox(height: Insets.md),
                ],
                GatherOutlineButton(
                  label: 'Add option group',
                  icon: Icons.add_rounded,
                  compact: true,
                  onPressed: _addGroup,
                ),
                if (_error != null) ...[
                  const SizedBox(height: Insets.sm),
                  Text(_error!, style: AppType.caption.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: Insets.lg),
                GatherButton(
                  label: widget.existing == null ? 'Add item' : 'Save changes',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      );
}

class _GroupEditor extends StatelessWidget {
  const _GroupEditor({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _GroupDraft draft;

  /// Adding or removing a choice changes the list this builds from, so the
  /// sheet above has to rebuild — this editor holds no state of its own.
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => GatherCard(
        color: AppColors.background,
        shadows: const [],
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GatherField(
                    label: 'Group name',
                    controller: draft.name,
                    hint: 'Sauce',
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Name the group' : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 19),
                  color: AppColors.inkFaint,
                  tooltip: 'Remove group',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GatherField(
                    label: 'Min picks',
                    controller: draft.minSelect,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (int.tryParse(v ?? '') ?? -1) < 0 ? 'Zero or more' : null,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GatherField(
                    label: 'Max picks',
                    controller: draft.maxSelect,
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'At least 1' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            for (var i = 0; i < draft.choices.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: GatherField(
                      label: 'Choice',
                      controller: draft.choices[i].name,
                      hint: 'Garlic',
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Name it' : null,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    flex: 2,
                    child: GatherField(
                      label: '+ ${Money.currencyCode}',
                      controller: draft.choices[i].priceDelta,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'A number' : null,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.inkFaint,
                    tooltip: 'Remove choice',
                    onPressed: () {
                      draft.removeChoice(i);
                      onChanged();
                    },
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
            ],
            GatherOutlineButton(
              label: 'Add choice',
              icon: Icons.add_rounded,
              compact: true,
              expand: false,
              onPressed: () {
                draft.choices.add(_ChoiceDraft(id: _uuid.v4()));
                onChanged();
              },
            ),
          ],
        ),
      );
}

/// Option groups are edited in place, so each one keeps its own controllers
/// for the lifetime of the sheet rather than being rebuilt from the model on
/// every keystroke.
class _GroupDraft {
  _GroupDraft({
    required this.id,
    String name = '',
    int minSelect = 0,
    int maxSelect = 1,
    List<_ChoiceDraft>? choices,
  })  : name = TextEditingController(text: name),
        minSelect = TextEditingController(text: '$minSelect'),
        maxSelect = TextEditingController(text: '$maxSelect'),
        choices = choices ?? [];

  factory _GroupDraft.from(OptionGroup group) => _GroupDraft(
        id: group.id.isEmpty ? _uuid.v4() : group.id,
        name: group.name,
        minSelect: group.minSelect,
        maxSelect: group.maxSelect,
        choices: group.choices.map(_ChoiceDraft.from).toList(),
      );

  final String id;
  final TextEditingController name;
  final TextEditingController minSelect;
  final TextEditingController maxSelect;
  final List<_ChoiceDraft> choices;
  final List<_ChoiceDraft> _retiredChoices = [];

  void removeChoice(int index) => _retiredChoices.add(choices.removeAt(index));

  OptionGroup toGroup() {
    final max = int.tryParse(maxSelect.text) ?? 1;
    final min = int.tryParse(minSelect.text) ?? 0;
    return OptionGroup(
      id: id,
      name: name.text.trim(),
      choices: choices.map((c) => c.toChoice()).toList(),
      minSelect: min,
      // A minimum above the maximum would lock the "add to cart" button
      // forever, so the maximum is nudged up instead of saving the conflict.
      maxSelect: max < min ? min : max,
    );
  }

  void dispose() {
    name.dispose();
    minSelect.dispose();
    maxSelect.dispose();
    for (final choice in [...choices, ..._retiredChoices]) {
      choice.dispose();
    }
  }
}

class _ChoiceDraft {
  _ChoiceDraft({required this.id, String name = '', double priceDelta = 0})
      : name = TextEditingController(text: name),
        priceDelta = TextEditingController(text: priceDelta.toStringAsFixed(2));

  factory _ChoiceDraft.from(OptionChoice choice) => _ChoiceDraft(
        id: choice.id.isEmpty ? _uuid.v4() : choice.id,
        name: choice.name,
        priceDelta: choice.priceDelta,
      );

  final String id;
  final TextEditingController name;
  final TextEditingController priceDelta;

  OptionChoice toChoice() => OptionChoice(
        id: id,
        name: name.text.trim(),
        priceDelta: double.tryParse(priceDelta.text) ?? 0,
      );

  void dispose() {
    name.dispose();
    priceDelta.dispose();
  }
}
