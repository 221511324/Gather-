import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/state_views.dart';
import '../restaurant/item_sheet.dart';

/// Saved restaurants and dishes (FR23 / US12).
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final restaurants = ref.watch(favoriteRestaurantsProvider);
    final items = ref.watch(favoriteItemsProvider);
    final isEmpty = restaurants.isEmpty && items.isEmpty;

    return BrandScaffold(
      title: 'Favourites',
      showBack: true,
      padBody: false,
      child: isEmpty
          ? EmptyView(
              icon: Icons.favorite_border_rounded,
              title: 'No favourites yet',
              message: 'Tap the heart on a restaurant or dish to keep it here.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go(Routes.search),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 140),
              children: [
                if (restaurants.isNotEmpty) ...[
                  SectionHeader(
                      title: context.tr('Restaurants ({count})', {'count': restaurants.length})),
                  for (final r in restaurants) ...[
                    RestaurantCard(
                      restaurant: r,
                      isFavorite: true,
                      onFavorite: user == null
                          ? null
                          : () => ref
                              .read(catalogServiceProvider)
                              .toggleFavoriteRestaurant(user.uid, r.id, false),
                      onTap: () => context.push(Routes.restaurant(r.id)),
                    ),
                    const SizedBox(height: Insets.lg),
                  ],
                ],
                if (items.isNotEmpty) ...[
                  SectionHeader(title: context.tr('Dishes ({count})', {'count': items.length})),
                  for (final item in items) ...[
                    FoodRow(
                      item: item,
                      isFavorite: true,
                      onFavorite: user == null
                          ? null
                          : () => ref
                              .read(catalogServiceProvider)
                              .toggleFavoriteItem(user.uid, item.id, false),
                      onTap: () => ItemSheet.show(context, item),
                    ),
                    const SizedBox(height: Insets.md),
                  ],
                ],
              ],
            ),
    );
  }
}
