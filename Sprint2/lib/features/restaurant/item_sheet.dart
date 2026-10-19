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
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';

/// Item detail and customization (FR4).
///
/// Presented as a draggable sheet so the menu stays visible behind it — adding
/// three things in a row should not mean three full page transitions.
class ItemSheet extends ConsumerStatefulWidget {
  const ItemSheet._({required this.item, this.existingLine, this.sessionId});

  final MenuItem item;

  /// Set when editing a line already in a cart rather than adding a new one.
  final CartLine? existingLine;
  final String? sessionId;

  static Future<void> show(BuildContext context, MenuItem item) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ItemSheet._(item: item),
      );

  /// Reopens the sheet pre-filled so a member can change their own item.
  static Future<void> edit(
    BuildContext context,
    MenuItem item,
    CartLine line, {
    String? sessionId,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ItemSheet._(item: item, existingLine: line, sessionId: sessionId),
      );

  @override
  ConsumerState<ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<ItemSheet> {
  late int _quantity = widget.existingLine?.quantity ?? 1;
  late final TextEditingController _note =
      TextEditingController(text: widget.existingLine?.note ?? '');

  /// groupId -> selected choice ids.
  late final Map<String, Set<String>> _selection = _initialSelection();

  Map<String, Set<String>> _initialSelection() {
    final map = <String, Set<String>>{};
    for (final group in widget.item.optionGroups) {
      map[group.id] = {};
    }
    for (final option in widget.existingLine?.options ?? const <SelectedOption>[]) {
      map.putIfAbsent(option.groupId, () => {}).add(option.choiceId);
    }
    return map;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingLine != null;

  /// Required groups must be satisfied before the item can be added.
  List<OptionGroup> get _unmet => widget.item.optionGroups
      .where((g) => g.isRequired && (_selection[g.id]?.length ?? 0) < g.minSelect)
      .toList();

  List<SelectedOption> get _selectedOptions => [
        for (final group in widget.item.optionGroups)
          for (final choice in group.choices)
            if (_selection[group.id]?.contains(choice.id) ?? false)
              SelectedOption(
                groupId: group.id,
                groupName: group.name,
                choiceId: choice.id,
                choiceName: choice.name,
                priceDelta: choice.priceDelta,
              ),
      ];

  double get _unitPrice =>
      widget.item.price + _selectedOptions.fold<double>(0, (acc, o) => acc + o.priceDelta);

  double get _total => _unitPrice * _quantity;

  void _toggle(OptionGroup group, OptionChoice choice) {
    setState(() {
      final selected = _selection.putIfAbsent(group.id, () => {});
      if (group.maxSelect <= 1) {
        // Single-select behaves like a radio, but a non-required group can be
        // cleared by tapping the chosen option again.
        if (selected.contains(choice.id)) {
          if (!group.isRequired) selected.clear();
        } else {
          selected
            ..clear()
            ..add(choice.id);
        }
        return;
      }
      if (selected.contains(choice.id)) {
        selected.remove(choice.id);
      } else if (selected.length < group.maxSelect) {
        selected.add(choice.id);
      }
    });
  }

  /// The live session this item can be added to, if any.
  GroupSession? get _targetSession {
    final session = ref.read(activeSessionProvider).valueOrNull;
    if (session == null || !session.stage.isLive) return null;
    if (session.restaurantId != widget.item.restaurantId) return null;
    return session;
  }

  Future<void> _submit() async {
    final unmet = _unmet;
    if (unmet.isNotEmpty) {
      AppSnack.error(context, 'Choose ${unmet.first.name.toLowerCase()} first');
      return;
    }

    final user = ref.read(currentUserOrNullProvider);
    if (user == null) return;

    final sessionId = widget.sessionId ?? _targetSession?.id;

    if (_isEditing) {
      await _saveEdit(user, sessionId);
      return;
    }

    if (sessionId != null) {
      final result = await ref.read(sessionServiceProvider).addLine(
            sessionId: sessionId,
            item: widget.item,
            owner: user,
            quantity: _quantity,
            options: _selectedOptions,
            note: _note.text,
          );
      if (!mounted) return;
      switch (result) {
        case Err(:final message):
          AppSnack.error(context, message);
        case Ok():
          AppSnack.show(context, 'Added to the group cart');
          Navigator.of(context).pop();
      }
      return;
    }

    await _addToPersonalCart(user);
  }

  Future<void> _addToPersonalCart(AppUser user) async {
    final cart = ref.read(cartProvider).valueOrNull ?? const <CartLine>[];
    final service = ref.read(cartServiceProvider);

    // A cart can only hold one restaurant's food, so adding from a different
    // one has to be confirmed.
    if (cart.isNotEmpty && cart.first.restaurantId != widget.item.restaurantId) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
            'Your cart has items from another restaurant. Adding ${widget.item.name} '
            'will clear it.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep cart')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start new'),
            ),
          ],
        ),
      );
      if (replace != true) return;
      await service.clear(user.uid);
    }

    await service.add(
      user.uid,
      widget.item,
      quantity: _quantity,
      options: _selectedOptions,
      note: _note.text,
    );

    if (!mounted) return;
    // The router is captured before the pop: `context` belongs to the sheet
    // and is defunct once it closes.
    final router = GoRouter.of(context);
    AppSnack.show(
      context,
      '${widget.item.name} added to your cart',
      action: SnackBarAction(
        label: 'View cart',
        textColor: AppColors.band,
        onPressed: () => router.push(Routes.cart),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _saveEdit(AppUser user, String? sessionId) async {
    final line = widget.existingLine!;
    final updated = line.copyWith(
      quantity: _quantity,
      note: _note.text,
      options: _selectedOptions,
    );

    if (sessionId != null) {
      await ref.read(firestoreRefsProvider).sessionLines(sessionId).doc(line.id).update({
        'quantity': updated.quantity,
        'note': updated.note,
        'options': updated.options.map((o) => o.toMap()).toList(),
      });
    } else {
      await ref.read(cartServiceProvider).updateLine(user.uid, updated);
    }

    if (!mounted) return;
    AppSnack.show(context, 'Item updated');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final session = widget.sessionId != null
        ? ref.watch(sessionProvider(widget.sessionId!)).valueOrNull
        : _targetSession;
    final isFavorite = user?.favoriteItemIds.contains(widget.item.id) ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: Radii.sheetTop,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  _Header(item: widget.item, isFavorite: isFavorite, user: user),
                  Padding(
                    padding: const EdgeInsets.all(Insets.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (session != null) ...[
                          _GroupTargetBanner(session: session),
                          const SizedBox(height: Insets.xl),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(widget.item.name, style: AppType.title.copyWith(fontSize: 23)),
                            ),
                            const SizedBox(width: Insets.md),
                            Text(
                              Money.format(widget.item.price),
                              style: AppType.money.copyWith(
                                color: AppColors.primary,
                                fontSize: 19,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 3),
                            Text(widget.item.rating.toStringAsFixed(1), style: AppType.caption),
                            if (widget.item.calories != null) ...[
                              const SizedBox(width: Insets.md),
                              const Icon(Icons.local_fire_department_rounded,
                                  size: 15, color: AppColors.inkMuted),
                              const SizedBox(width: 3),
                              Text('${widget.item.calories} kcal', style: AppType.caption),
                            ],
                          ],
                        ),
                        const SizedBox(height: Insets.md),
                        Text(
                          widget.item.description,
                          style: AppType.bodyLarge.copyWith(
                            color: AppColors.inkMuted,
                            fontSize: 14.5,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: Insets.xxl),
                        for (final group in widget.item.optionGroups) ...[
                          _OptionGroupView(
                            group: group,
                            selected: _selection[group.id] ?? const {},
                            onToggle: (choice) => _toggle(group, choice),
                          ),
                          const SizedBox(height: Insets.xl),
                        ],
                        Text('Special request', style: AppType.label.copyWith(fontSize: 15)),
                        const SizedBox(height: Insets.sm),
                        TextField(
                          controller: _note,
                          maxLines: 2,
                          maxLength: 140,
                          style: AppType.bodyLarge.copyWith(fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'e.g. no onions, extra napkins',
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: Insets.xl),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Footer(
              quantity: _quantity,
              total: _total,
              isEditing: _isEditing,
              toGroup: session != null,
              onQuantity: (q) => setState(() => _quantity = q),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.item, required this.isFavorite, this.user});

  final MenuItem item;
  final bool isFavorite;
  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.7,
            child: FoodImage(url: item.imageUrl, width: double.infinity),
          ),
          Positioned(
            top: Insets.md,
            left: Insets.md,
            child: _CircleButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
              tooltip: 'Close',
            ),
          ),
          if (user != null)
            Positioned(
              top: Insets.md,
              right: Insets.md,
              child: _CircleButton(
                icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFavorite ? AppColors.coral : AppColors.ink,
                tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
                onTap: () => ref
                    .read(catalogServiceProvider)
                    .toggleFavoriteItem(user!.uid, item.id, !isFavorite),
              ),
            ),
        ],
      );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.color, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: Tooltip(
          message: tooltip ?? '',
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 20, color: color ?? AppColors.ink),
            ),
          ),
        ),
      );
}

/// Makes it unmistakable that this item is going into the shared cart and will
/// be visible to everyone in the session.
class _GroupTargetBanner extends StatelessWidget {
  const _GroupTargetBanner({required this.session});

  final GroupSession session;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: Radii.brMd),
        child: Row(
          children: [
            const Icon(Icons.groups_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                'Adding to "${session.name}" — the group will see this is yours',
                style: AppType.caption.copyWith(color: AppColors.primaryDark, fontSize: 12.5),
              ),
            ),
            MemberAvatarStack(members: session.members, size: 24, max: 3),
          ],
        ),
      );
}

class _OptionGroupView extends StatelessWidget {
  const _OptionGroupView({
    required this.group,
    required this.selected,
    required this.onToggle,
  });

  final OptionGroup group;
  final Set<String> selected;
  final ValueChanged<OptionChoice> onToggle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.name, style: AppType.headline.copyWith(fontSize: 17)),
              const SizedBox(width: Insets.sm),
              StatusPill(
                label: group.ruleLabel,
                color: group.isRequired ? AppColors.coral : AppColors.inkMuted,
                background: group.isRequired ? AppColors.coralSoft : AppColors.line,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          for (final choice in group.choices)
            _ChoiceTile(
              choice: choice,
              selected: selected.contains(choice.id),
              multi: group.isMultiSelect,
              onTap: () => onToggle(choice),
            ),
        ],
      );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.choice,
    required this.selected,
    required this.multi,
    required this.onTap,
  });

  final OptionChoice choice;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Material(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: Radii.brMd,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.md),
              child: Row(
                children: [
                  Icon(
                    multi
                        ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                        : (selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded),
                    size: 21,
                    color: selected ? AppColors.primary : AppColors.inkFaint,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      choice.name,
                      style: selected ? AppType.bodyStrong : AppType.bodyLarge.copyWith(fontSize: 15),
                    ),
                  ),
                  if (choice.priceDelta > 0)
                    Text(
                      '+${Money.plain(choice.priceDelta)}',
                      style: AppType.money.copyWith(fontSize: 14, color: AppColors.inkMuted),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.quantity,
    required this.total,
    required this.isEditing,
    required this.toGroup,
    required this.onQuantity,
    required this.onSubmit,
  });

  final int quantity;
  final double total;
  final bool isEditing;
  final bool toGroup;
  final ValueChanged<int> onQuantity;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
          Insets.gutter,
          Insets.lg,
          Insets.gutter,
          Insets.lg + MediaQuery.of(context).padding.bottom * 0.3,
        ),
        decoration: const BoxDecoration(color: AppColors.surface, boxShadow: Shadows.sheet),
        child: Row(
          children: [
            QuantityStepper(quantity: quantity, onChanged: onQuantity),
            const SizedBox(width: Insets.md),
            Expanded(
              child: GatherButton(
                label: isEditing
                    ? 'Save · ${Money.plain(total)}'
                    : '${toGroup ? 'Add to group' : 'Add to cart'} · ${Money.plain(total)}',
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      );
}
