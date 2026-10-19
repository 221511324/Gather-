import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/state_views.dart';
import 'admin_menu_item_editor.dart';
import 'admin_shell.dart';

/// One restaurant's menu (FR31).
class AdminMenuScreen extends ConsumerWidget {
  const AdminMenuScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantProvider(restaurantId)).valueOrNull;
    final menuAsync = ref.watch(menuProvider(restaurantId));

    return AdminShell(
      // The restaurant document streams in a beat after the route opens, so
      // the title falls back until its name arrives.
      title: restaurant?.name ?? 'Menu',
      subtitle: 'Menu',
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 23),
          tooltip: 'New item',
          onPressed: () => MenuItemEditorSheet.show(context, restaurantId: restaurantId),
        ),
      ],
      child: menuAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (items) {
          if (items.isEmpty) {
            return EmptyView(
              icon: Icons.restaurant_menu_outlined,
              title: 'The menu is empty',
              message: 'Add the first dish so people have something to order.',
              actionLabel: 'Add an item',
              onAction: () => MenuItemEditorSheet.show(context, restaurantId: restaurantId),
            );
          }

          // Grouped the same way the customer-facing restaurant page groups
          // them, and iterated over the enum rather than the map so the
          // categories always appear in their designed order.
          final grouped = <FoodCategory, List<MenuItem>>{};
          for (final item in items) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }
          for (final group in grouped.values) {
            group.sort((a, b) => a.name.compareTo(b.name));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
            children: [
              for (final category in FoodCategory.values)
                if (grouped[category] case final group?) ...[
                  SectionHeader(title: '${category.label} · ${group.length}'),
                  for (final item in group) ...[
                    _MenuItemRow(item: item),
                    const SizedBox(height: Insets.md),
                  ],
                  const SizedBox(height: Insets.lg),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _MenuItemRow extends ConsumerWidget {
  const _MenuItemRow({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        onTap: () => MenuItemEditorSheet.show(
          context,
          restaurantId: item.restaurantId,
          existing: item,
        ),
        child: Row(
          children: [
            FoodImage(url: item.imageUrl, width: 46, height: 46, radius: Radii.sm),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: AppType.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isBestSeller) ...[
                        const SizedBox(width: Insets.sm),
                        const Icon(Icons.star_rounded, size: 15, color: AppColors.accentDeep),
                      ],
                    ],
                  ),
                  Text(
                    Money.format(item.price),
                    style: AppType.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Switch(
              value: item.isAvailable,
              onChanged: (v) async {
                final result = await ref
                    .read(catalogServiceProvider)
                    .setItemAvailable(item.restaurantId, item.id, v);
                if (!context.mounted) return;
                if (result case Err(:final message)) AppSnack.error(context, message);
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
              tooltip: 'Item actions',
              onSelected: (value) => _handle(context, ref, value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          ],
        ),
      );

  Future<void> _handle(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'edit':
        await MenuItemEditorSheet.show(
          context,
          restaurantId: item.restaurantId,
          existing: item,
        );

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete ${item.name}?'),
            content: const Text(
              'It disappears from the menu straight away. Take it off sale '
              'instead if you only want to pause it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        final result = await ref
            .read(catalogServiceProvider)
            .deleteMenuItem(item.restaurantId, item.id);
        if (!context.mounted) return;
        switch (result) {
          case Err(:final message):
            AppSnack.error(context, message);
          case Ok():
            AppSnack.show(context, 'Item deleted');
        }
    }
  }
}
