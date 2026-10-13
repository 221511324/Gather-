import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_button.dart';

/// Menu item detail (FR4 / US3).
///
/// Phase 1 browses the menu, so the sheet reports what an item is and what it
/// would cost, including the choices available on it. Adding it to a cart is
/// Phase 2 (US7, US8), so there is nothing to submit here yet.
class ItemSheet extends ConsumerWidget {
  const ItemSheet._({required this.item});

  final MenuItem item;

  static Future<void> show(BuildContext context, MenuItem item) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ItemSheet._(item: item),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          child: ColoredBox(
            color: AppColors.surface,
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                _Header(item: item),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.gutter,
                    Insets.xl,
                    Insets.gutter,
                    Insets.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(item.name, style: AppType.headline.copyWith(fontSize: 21)),
                          ),
                          const SizedBox(width: Insets.md),
                          Text(
                            Money.format(item.price),
                            style: AppType.headline.copyWith(
                              fontSize: 19,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.sm),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 17, color: AppColors.accentDeep),
                          const SizedBox(width: 3),
                          Text(item.rating.toStringAsFixed(1), style: AppType.caption),
                          if (item.calories != null) ...[
                            const SizedBox(width: Insets.md),
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 17,
                              color: AppColors.inkFaint,
                            ),
                            const SizedBox(width: 3),
                            Text('${item.calories} kcal', style: AppType.caption),
                          ],
                          if (item.isBestSeller) ...[
                            const SizedBox(width: Insets.md),
                            const _Pill(label: 'Best seller'),
                          ],
                        ],
                      ),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: Insets.lg),
                        Text(item.description, style: AppType.body),
                      ],
                      if (item.optionGroups.isNotEmpty) ...[
                        const SizedBox(height: Insets.xxl),
                        Text('Choices available', style: AppType.bodyStrong),
                        const SizedBox(height: 2),
                        Text(
                          'You will pick these when you add the item to a shared '
                          'cart in Phase 2.',
                          style: AppType.caption,
                        ),
                        const SizedBox(height: Insets.md),
                        for (final group in item.optionGroups) ...[
                          _OptionGroupView(group: group),
                          const SizedBox(height: Insets.lg),
                        ],
                      ],
                      const SizedBox(height: Insets.xl),
                      GatherButton(
                        label: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + Insets.md),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          FoodImage(url: item.imageUrl, height: 210, width: double.infinity),
          Positioned(
            top: Insets.md,
            right: Insets.md,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.close_rounded, size: 21, color: AppColors.ink),
                ),
              ),
            ),
          ),
          if (!item.isAvailable)
            Positioned(
              left: Insets.md,
              top: Insets.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: Radii.brPill),
                child: Text(
                  'Unavailable',
                  style: AppType.overline.copyWith(color: Colors.white),
                ),
              ),
            ),
        ],
      );
}

/// Lists one group of choices and what each would add to the price.
class _OptionGroupView extends StatelessWidget {
  const _OptionGroupView({required this.group});

  final OptionGroup group;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.name, style: AppType.bodyStrong.copyWith(fontSize: 14.5)),
              const SizedBox(width: Insets.sm),
              _Pill(label: group.minSelect > 0 ? 'Required' : 'Optional'),
            ],
          ),
          const SizedBox(height: Insets.sm),
          for (final choice in group.choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: AppColors.inkFaint),
                  const SizedBox(width: Insets.sm),
                  Expanded(child: Text(choice.name, style: AppType.body.copyWith(fontSize: 14))),
                  if (choice.priceDelta != 0)
                    Text(
                      '+ ${Money.format(choice.priceDelta)}',
                      style: AppType.caption.copyWith(color: AppColors.primary),
                    ),
                ],
              ),
            ),
        ],
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 2),
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: Radii.brPill),
        child: Text(label, style: AppType.overline.copyWith(color: AppColors.primary)),
      );
}
