import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/ar/qa1.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/catalog_service.dart';
import '../../core/services/result.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import 'admin_restaurant_editor.dart';
import 'admin_shell.dart';

/// Restaurant management (FR31).
class AdminRestaurantsScreen extends ConsumerStatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  ConsumerState<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends ConsumerState<AdminRestaurantsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final restaurantsAsync = ref.watch(adminRestaurantsProvider);

    return AdminShell(
      title: 'Restaurants',
      bandContent: GatherSearchField(
        hint: 'Search name or cuisine',
        onChanged: (v) => setState(() => _query = v),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 23),
          tooltip: context.tr('New restaurant'),
          onPressed: () => RestaurantEditorSheet.show(context),
        ),
      ],
      child: restaurantsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (restaurants) {
          if (restaurants.isEmpty) {
            return EmptyView(
              icon: Icons.storefront_outlined,
              title: 'No restaurants yet',
              message: 'Add one so there is something to order from.',
              actionLabel: 'Add a restaurant',
              onAction: () => RestaurantEditorSheet.show(context),
            );
          }

          // The same in-memory filter the customer-facing search uses, so an
          // admin finds a restaurant by the words they would type anywhere else.
          final filtered = CatalogSearch.restaurants(restaurants, _query);
          if (filtered.isEmpty) {
            return const EmptyView(
              icon: Icons.search_off_rounded,
              title: 'No restaurants match',
              message: 'Try a different search.',
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.lg, Insets.gutter, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    context.tr('{shown} of {total} restaurants|${countNote(restaurants.length)}',
                        {'shown': filtered.length, 'total': restaurants.length}),
                    style: AppType.caption,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.lg, Insets.gutter, Insets.xxl),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
                  itemBuilder: (context, i) => _RestaurantRow(restaurant: filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantRow extends ConsumerWidget {
  const _RestaurantRow({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ref.watch(menuProvider(restaurant.id)).valueOrNull?.length;

    return GatherCard(
      onTap: () => context.push(Routes.adminMenu(restaurant.id)),
      child: Column(
        children: [
          Row(
            children: [
              FoodImage(
                url: restaurant.imageUrl,
                width: 46,
                height: 46,
                radius: Radii.sm,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      restaurant.name,
                      style: AppType.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${restaurant.cuisine} · ${restaurant.priceLabel}',
                      style: AppType.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: restaurant.isOpen,
                onChanged: (v) async {
                  final result =
                      await ref.read(catalogServiceProvider).setRestaurantOpen(restaurant.id, v);
                  if (!context.mounted) return;
                  if (result case Err(:final message)) AppSnack.error(context, message);
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.sm),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              StatusPill(
                label: '${restaurant.rating.toStringAsFixed(1)} ★ (${restaurant.ratingCount})',
                color: AppColors.accentDeep,
                background: AppColors.accentSoft,
                compact: true,
              ),
              const SizedBox(width: Insets.sm),
              StatusPill(
                // Null while the menu stream is still opening — showing a
                // dash beats flashing a wrong "0 items".
                label: itemCount == null
                    ? context.tr('Menu …')
                    : context.tr('{count} items|${countNote(itemCount)}', {'count': itemCount}),
                color: AppColors.primary,
                compact: true,
              ),
              const Spacer(),
              if (!restaurant.isOpen)
                const StatusPill(label: 'Closed', color: AppColors.inkFaint, compact: true),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
                tooltip: context.tr('Restaurant actions'),
                onSelected: (value) => _handle(context, ref, value),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Text(context.tr('Edit'))),
                  PopupMenuItem(value: 'menu', child: Text(context.tr('Manage menu'))),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.tr('Delete'),
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'edit':
        await RestaurantEditorSheet.show(context, existing: restaurant);

      case 'menu':
        context.push(Routes.adminMenu(restaurant.id));

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr('Delete {name}?', {'name': restaurant.name})),
            content: Text(context.tr(
              'Every menu item under this restaurant is deleted with it, and '
              'anyone holding it in their cart will have to start again. '
              'Placed orders keep their own copy of the details.',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('Cancel')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.tr('Delete')),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        final result = await ref.read(catalogServiceProvider).deleteRestaurant(restaurant.id);
        if (!context.mounted) return;
        switch (result) {
          case Err(:final message):
            AppSnack.error(context, message);
          case Ok():
            AppSnack.show(context, 'Restaurant deleted');
        }
    }
  }
}
