import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/state_views.dart';
import 'item_sheet.dart';

/// Restaurant detail and menu (FR3).
///
/// When the user is in a live session that has not picked a restaurant yet,
/// this screen also offers the two group actions: suggest it for the wheel, or
/// (for the host) lock it in for everyone.
class RestaurantScreen extends ConsumerStatefulWidget {
  const RestaurantScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> {
  FoodCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final restaurantAsync = ref.watch(restaurantProvider(widget.restaurantId));
    final menuAsync = ref.watch(menuProvider(widget.restaurantId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: restaurantAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(restaurantProvider)),
        data: (restaurant) {
          if (restaurant == null) {
            return const EmptyView(
              icon: Icons.storefront_outlined,
              title: 'Restaurant not found',
              message: 'It may have been removed.',
            );
          }

          final items = menuAsync.valueOrNull ?? const <MenuItem>[];
          final categories = items.map((i) => i.category).toSet().toList()
            ..sort((a, b) => a.index.compareTo(b.index));
          final shown =
              _filter == null ? items : items.where((i) => i.category == _filter).toList();

          return CustomScrollView(
            slivers: [
              _Header(restaurant: restaurant),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.xl, Insets.gutter, Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Facts(restaurant: restaurant),
                      const SizedBox(height: Insets.xl),
                      Text('Menu', style: AppType.title.copyWith(fontSize: 21)),
                    ],
                  ),
                ),
              ),
              if (categories.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final c in categories)
                          _FilterChip(
                            label: c.label,
                            selected: _filter == c,
                            onTap: () => setState(() => _filter = _filter == c ? null : c),
                          ),
                      ],
                    ),
                  ),
                ),
              if (menuAsync.isLoading && items.isEmpty)
                const SliverFillRemaining(hasScrollBody: false, child: LoadingView())
              else if (shown.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.restaurant_menu_rounded,
                    title: 'Nothing here yet',
                    message: 'Try a different category.',
                    compact: true,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.lg, Insets.gutter, Insets.xxxl),
                  sliver: SliverList.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
                    itemBuilder: (context, i) {
                      final item = shown[i];
                      return FoodRow(
                        item: item,
                        onTap: () => ItemSheet.show(context, item),
                        trailing: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, size: 19, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SliverAppBar(
        expandedHeight: 232,
        pinned: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.black26,
            radius: 17,
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: Colors.white),
          ),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        actions: [
        ],
        flexibleSpace: FlexibleSpaceBar(
          titlePadding: const EdgeInsets.symmetric(horizontal: 56, vertical: Insets.md),
          title: Text(
            restaurant.name,
            style: AppType.headline.copyWith(color: Colors.white, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          background: Stack(
            fit: StackFit.expand,
            children: [
              FoodImage(url: restaurant.imageUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.ink.withValues(alpha: 0.45),
                      Colors.transparent,
                      AppColors.ink.withValues(alpha: 0.7),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Facts extends StatelessWidget {
  const _Facts({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(restaurant.cuisine, style: AppType.caption.copyWith(fontSize: 13)),
          const SizedBox(height: Insets.sm),
          Text(
            restaurant.description,
            style: AppType.bodyLarge.copyWith(
              color: AppColors.inkMuted,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: [
              _Fact(
                icon: Icons.star_rounded,
                label: restaurant.rating.toStringAsFixed(1),
                sub: '${restaurant.ratingCount} ratings',
                color: AppColors.accent,
              ),
              _Fact(
                icon: Icons.schedule_rounded,
                label: restaurant.deliveryLabel,
                sub: 'Delivery',
              ),
              _Fact(
                icon: Icons.delivery_dining_rounded,
                label: restaurant.deliveryFee == 0
                    ? 'Free'
                    : Money.plain(restaurant.deliveryFee),
                sub: 'Fee',
              ),
              _Fact(
                icon: Icons.shopping_basket_outlined,
                label: Money.plain(restaurant.minimumOrder),
                sub: 'Minimum',
              ),
            ],
          ),
        ],
      );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.sub, this.color});

  final IconData icon;
  final String label;
  final String sub;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 19, color: color ?? AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppType.bodyStrong.copyWith(fontSize: 13.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(sub, style: AppType.overline.copyWith(fontSize: 10)),
          ],
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          labelStyle: AppType.label.copyWith(
            color: selected ? Colors.white : AppColors.ink,
            fontSize: 13.5,
          ),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary,
          showCheckmark: false,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
        ),
      );
}
