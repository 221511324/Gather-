import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/catalog_service.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import '../restaurant/item_sheet.dart';

/// Search across restaurants and dishes (FR3).
///
/// Filtering happens client-side over the already-streamed catalogue, which
/// makes results instant as the user types — Firestore cannot do substring
/// matching anyway.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  FoodCategory? _category;
  _SortBy _sort = _SortBy.relevance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? const <Restaurant>[];
    final items = ref.watch(allMenuItemsProvider).valueOrNull ?? const <MenuItem>[];
    final loading = ref.watch(allMenuItemsProvider).isLoading && items.isEmpty;

    final matchedRestaurants = CatalogSearch.restaurants(restaurants, _query);
    var matchedItems = CatalogSearch.items(items, _query, category: _category);
    matchedItems = switch (_sort) {
      _SortBy.relevance => matchedItems,
      _SortBy.priceLow => matchedItems..sort((a, b) => a.price.compareTo(b.price)),
      _SortBy.priceHigh => matchedItems..sort((a, b) => b.price.compareTo(a.price)),
      _SortBy.rating => matchedItems..sort((a, b) => b.rating.compareTo(a.rating)),
    };

    final hasQuery = _query.trim().isNotEmpty || _category != null;

    return BrandScaffold(
      title: 'Search',
      leading: const SizedBox.shrink(),
      padBody: false,
      bandContent: GatherSearchField(
        controller: _controller,
        hint: 'Search restaurants or dishes',
        autofocus: false,
        onChanged: (v) => setState(() => _query = v),
        onTrailingTap: _openFilters,
      ),
      child: loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 140),
              children: [
                _Categories(
                  selected: _category,
                  onSelect: (c) => setState(() => _category = _category == c ? null : c),
                ),
                const SizedBox(height: Insets.xl),
                if (!hasQuery) ...[
                  const SectionHeader(title: 'All restaurants'),
                  for (final r in restaurants) ...[
                    RestaurantCard(
                      restaurant: r,
                      onTap: () => context.push(Routes.restaurant(r.id)),
                    ),
                    const SizedBox(height: Insets.lg),
                  ],
                ] else ...[
                  if (matchedRestaurants.isEmpty && matchedItems.isEmpty)
                    EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'Nothing found for "${_controller.text.trim()}". '
                          'Try a different word.',
                      actionLabel: 'Clear search',
                      onAction: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _category = null;
                        });
                      },
                    ),
                  if (matchedRestaurants.isNotEmpty) ...[
                    SectionHeader(title: 'Restaurants (${matchedRestaurants.length})'),
                    for (final r in matchedRestaurants) ...[
                      RestaurantCard(
                        restaurant: r,
                        onTap: () => context.push(Routes.restaurant(r.id)),
                      ),
                      const SizedBox(height: Insets.lg),
                    ],
                    const SizedBox(height: Insets.sm),
                  ],
                  if (matchedItems.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SectionHeader(
                            title: 'Dishes (${matchedItems.length})',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _openFilters,
                          icon: const Icon(Icons.sort_rounded, size: 18),
                          label: Text(_sort.label, style: AppType.label.copyWith(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    for (final item in matchedItems) ...[
                      FoodRow(item: item, onTap: () => ItemSheet.show(context, item)),
                      const SizedBox(height: Insets.md),
                    ],
                  ],
                ],
              ],
            ),
    );
  }

  Future<void> _openFilters() async {
    final sort = await showModalBottomSheet<_SortBy>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
              child: Text('Sort dishes by', style: AppType.headline),
            ),
            RadioGroup<_SortBy>(
              groupValue: _sort,
              onChanged: (v) => Navigator.pop(context, v),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in _SortBy.values)
                    RadioListTile<_SortBy>(
                      value: option,
                      title: Text(option.label, style: AppType.bodyLarge.copyWith(fontSize: 15)),
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
    if (sort != null && mounted) setState(() => _sort = sort);
  }
}

enum _SortBy {
  relevance('Best match'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  rating('Highest rated');

  const _SortBy(this.label);

  final String label;
}

class _Categories extends StatelessWidget {
  const _Categories({required this.selected, required this.onSelect});

  final FoodCategory? selected;
  final ValueChanged<FoodCategory> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: FoodCategory.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: Insets.lg),
          itemBuilder: (context, i) {
            final category = FoodCategory.values[i];
            return CategoryChip(
              category: category,
              selected: selected == category,
              onTap: () => onSelect(category),
            );
          },
        ),
      );
}
