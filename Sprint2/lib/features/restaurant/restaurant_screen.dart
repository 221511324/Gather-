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
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_button.dart';
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
    final user = ref.watch(currentUserProvider).valueOrNull;
    final session = ref.watch(activeSessionProvider).valueOrNull;

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
          final isFavorite = user?.favoriteRestaurantIds.contains(restaurant.id) ?? false;

          return CustomScrollView(
            slivers: [
              _Header(restaurant: restaurant, isFavorite: isFavorite, user: user),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Insets.gutter, Insets.xl, Insets.gutter, Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Facts(restaurant: restaurant),
                      if (session != null && session.stage.isLive) ...[
                        const SizedBox(height: Insets.xl),
                        _GroupActions(session: session, restaurant: restaurant),
                      ],
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
                      final fav = user?.favoriteItemIds.contains(item.id) ?? false;
                      return FoodRow(
                        item: item,
                        isFavorite: fav,
                        onFavorite: user == null
                            ? null
                            : () => ref
                                .read(catalogServiceProvider)
                                .toggleFavoriteItem(user.uid, item.id, !fav),
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
      bottomNavigationBar: const _CartBar(),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.restaurant, required this.isFavorite, this.user});

  final Restaurant restaurant;
  final bool isFavorite;
  final AppUser? user;

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
          if (user != null)
            IconButton(
              icon: CircleAvatar(
                backgroundColor: Colors.black26,
                radius: 17,
                child: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 18,
                  color: isFavorite ? AppColors.coral : Colors.white,
                ),
              ),
              tooltip: isFavorite ? 'Remove from favourites' : 'Add to favourites',
              onPressed: () => ref
                  .read(catalogServiceProvider)
                  .toggleFavoriteRestaurant(user!.uid, restaurant.id, !isFavorite),
            ),
          const SizedBox(width: Insets.sm),
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

/// Suggest-for-the-wheel and host lock-in (FR10, US7).
class _GroupActions extends ConsumerWidget {
  const _GroupActions({required this.session, required this.restaurant});

  final GroupSession session;
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final isHost = session.isHostOf(user.uid);
    final isChosen = session.restaurantId == restaurant.id;

    // Each member puts one restaurant forward, so what this card offers
    // depends on how the host decided the choice is being made and on whether
    // this member has already used their pick.
    final mode = session.decisionMode;
    final mySuggestion = session.suggestionBy(user.uid);
    final suggestedThisOne = mySuggestion?.restaurantId == restaurant.id;

    if (isChosen) {
      return Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: Radii.brMd),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.success),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                'This is what "${session.name}" is ordering from',
                style: AppType.caption.copyWith(color: AppColors.success, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return GatherCard(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 19, color: AppColors.primary),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'You are in "${session.name}"',
                  style: AppType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (mode == null)
            Text(
              isHost
                  ? 'Open the session to choose whether to spin the wheel or '
                      'pick the restaurant yourself.'
                  : 'The host is deciding how the restaurant will be chosen.',
              style: AppType.caption,
            )
          else if (mode == RestaurantDecisionMode.spin && mySuggestion != null &&
              !suggestedThisOne)
            Text(
              'You have already suggested ${mySuggestion.restaurantName}. '
              'Each member puts one restaurant forward — remove yours in the '
              'session to swap it.',
              style: AppType.caption,
            ),
          if (mode != null)
          Row(
            children: [
              if (mode == RestaurantDecisionMode.spin)
                Expanded(
                  child: GatherOutlineButton(
                    label: suggestedThisOne
                        ? 'Your suggestion'
                        : (mySuggestion != null ? 'One each' : 'Suggest this'),
                    icon: suggestedThisOne ? Icons.check_rounded : Icons.add_rounded,
                    compact: true,
                    onPressed: mySuggestion != null
                        ? null
                        : () async {
                            final result = await ref.read(sessionServiceProvider)
                                .suggestRestaurant(
                                  sessionId: session.id,
                                  restaurant: restaurant,
                                  by: user,
                                );
                            if (!context.mounted) return;
                            switch (result) {
                              case Err(:final message):
                                AppSnack.error(context, message);
                              case Ok():
                                AppSnack.show(context, 'Added to the wheel');
                            }
                          },
                  ),
                ),
              if (isHost && mode == RestaurantDecisionMode.hostChoice) ...[
                Expanded(
                  child: GatherButton(
                    label: 'Order here',
                    compact: true,
                    onPressed: () async {
                      final result = await ref.read(sessionServiceProvider).chooseRestaurant(
                            sessionId: session.id,
                            restaurant: restaurant,
                          );
                      if (!context.mounted) return;
                      switch (result) {
                        case Err(:final message):
                          AppSnack.error(context, message);
                        case Ok():
                          if (context.mounted) {
                            AppSnack.show(context, 'The group is ordering from ${restaurant.name}');
                          }
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
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

/// Sticky summary of whichever cart the user is filling.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).valueOrNull;
    final inSession = session != null && session.stage.isLive && session.hasRestaurant;

    final lines = inSession
        ? (ref.watch(sessionLinesProvider(session.id)).valueOrNull ?? const [])
        : (ref.watch(cartProvider).valueOrNull ?? const []);
    if (lines.isEmpty) return const SizedBox.shrink();

    final count = lines.fold<int>(0, (acc, l) => acc + l.quantity);
    final total = lines.fold<double>(0, (acc, l) => acc + l.lineTotal);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(Insets.gutter, 0, Insets.gutter, Insets.md),
      child: GatherButton(
        label: '$count ${count == 1 ? 'item' : 'items'} · ${Money.format(total)}'
            '${inSession ? '  ·  Group cart' : ''}',
        icon: Icons.shopping_bag_rounded,
        onPressed: () {
          context.push(inSession ? Routes.sessionCart(session.id) : Routes.cart);
        },
      ),
    );
  }
}
