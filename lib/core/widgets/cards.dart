import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../models/restaurant.dart';
import '../utils/money.dart';
import 'food_image.dart';

/// A card surface with the app's rounded corners and soft lift.
class GatherCard extends StatelessWidget {
  const GatherCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Insets.lg),
    this.color,
    this.radius = Radii.lg,
    this.border,
    this.shadows,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          border: border,
          boxShadow: shadows ?? Shadows.card,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// The price chip that sits on the corner of a food photo.
class PriceBadge extends StatelessWidget {
  const PriceBadge({super.key, required this.price, this.compact = false});

  final double price;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? Insets.sm : Insets.md,
          vertical: compact ? 3 : 5,
        ),
        decoration: const BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(Radii.md),
            bottomRight: Radius.circular(Radii.lg),
          ),
        ),
        child: Text(
          Money.plain(price),
          style: AppType.money.copyWith(color: AppColors.ink, fontSize: compact ? 12 : 13.5),
        ),
      );
}

/// A menu item as a photo-first tile, used in the horizontal home rails and
/// the two-column menu grids.
class FoodTile extends StatelessWidget {
  const FoodTile({
    super.key,
    required this.item,
    this.onTap,
    this.width,
    this.showRating = true,
    this.isFavorite = false,
    this.onFavorite,
  });

  final MenuItem item;
  final VoidCallback? onTap;
  final double? width;
  final bool showRating;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: GatherCard(
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.18,
                    child: FoodImage(url: item.imageUrl, width: double.infinity),
                  ),
                  if (showRating)
                    Positioned(
                      top: Insets.sm,
                      left: Insets.sm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: Radii.brPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
                            const SizedBox(width: 2),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: AppType.overline.copyWith(
                                color: AppColors.ink,
                                fontSize: 11,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (onFavorite != null)
                    Positioned(
                      top: Insets.xs,
                      right: Insets.xs,
                      child: IconButton(
                        onPressed: onFavorite,
                        iconSize: 19,
                        visualDensity: VisualDensity.compact,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.9),
                          minimumSize: const Size(32, 32),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? AppColors.coral : AppColors.inkMuted,
                        ),
                        tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
                      ),
                    ),
                  Positioned(bottom: 0, right: 0, child: PriceBadge(price: item.price)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.md, Insets.md, Insets.md, Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyStrong,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// A menu item as a horizontal row — used inside a restaurant's menu list
/// where the description needs room to breathe.
class FoodRow extends StatelessWidget {
  const FoodRow({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
    this.isFavorite = false,
    this.onFavorite,
  });

  final MenuItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(url: item.imageUrl, width: 86, height: 86, radius: Radii.md),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyStrong.copyWith(fontSize: 15.5),
                        ),
                      ),
                      if (item.isBestSeller)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: Radii.brSm,
                          ),
                          child: Text(
                            'POPULAR',
                            style: AppType.overline.copyWith(
                              color: AppColors.accentDeep,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      if (onFavorite != null)
                        IconButton(
                          onPressed: onFavorite,
                          iconSize: 19,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.only(left: Insets.sm),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isFavorite ? AppColors.coral : AppColors.inkFaint,
                          ),
                          tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      Text(
                        Money.format(item.price),
                        style: AppType.money.copyWith(color: AppColors.primary, fontSize: 15),
                      ),
                      if (item.calories != null) ...[
                        const SizedBox(width: Insets.sm),
                        Text('· ${item.calories} kcal', style: AppType.caption),
                      ],
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// A restaurant as a wide photo card with its delivery facts underneath.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.trailing,
  });

  final Restaurant restaurant;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2.1,
                  child: FoodImage(url: restaurant.imageUrl, width: double.infinity),
                ),
                if (!restaurant.isOpen)
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: 0.55),
                      child: Center(
                        child: Text(
                          'Closed',
                          style: AppType.headline.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (onFavorite != null)
                  Positioned(
                    top: Insets.sm,
                    right: Insets.sm,
                    child: IconButton(
                      onPressed: onFavorite,
                      iconSize: 20,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                        minimumSize: const Size(36, 36),
                      ),
                      icon: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? AppColors.coral : AppColors.inkMuted,
                      ),
                      tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headline,
                        ),
                      ),
                      const Icon(Icons.star_rounded, size: 17, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(restaurant.rating.toStringAsFixed(1), style: AppType.bodyStrong),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    restaurant.cuisine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption,
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      Text(restaurant.deliveryLabel, style: AppType.caption),
                      const SizedBox(width: Insets.md),
                      const Icon(Icons.delivery_dining_rounded, size: 16, color: AppColors.inkMuted),
                      const SizedBox(width: 4),
                      Text(
                        restaurant.deliveryFee == 0
                            ? 'Free'
                            : Money.format(restaurant.deliveryFee),
                        style: AppType.caption,
                      ),
                      const Spacer(),
                      ?trailing,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// The circular category selector from the design's home screen.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final FoodCategory category;
  final bool selected;
  final VoidCallback onTap;

  static IconData iconFor(FoodCategory c) => switch (c) {
        FoodCategory.snacks => Icons.bakery_dining_rounded,
        FoodCategory.meal => Icons.restaurant_rounded,
        FoodCategory.vegan => Icons.eco_rounded,
        FoodCategory.dessert => Icons.icecream_rounded,
        FoodCategory.drinks => Icons.local_cafe_rounded,
      };

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Motion.fast,
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.primarySoft,
                shape: BoxShape.circle,
                boxShadow: selected ? Shadows.glow(AppColors.primary) : null,
              ),
              child: Icon(
                iconFor(category),
                size: 26,
                color: selected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              category.label,
              style: AppType.caption.copyWith(
                color: selected ? AppColors.primary : AppColors.inkMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}
