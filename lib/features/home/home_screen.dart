import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../restaurant/item_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  FoodCategory? _category;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingSub {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Rise and shine — breakfast time';
    if (hour < 17) return 'What is everyone having today?';
    return 'Who are you eating with tonight?';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final firstName = user == null
        ? ''
        : (user.fullName.isEmpty ? user.username : user.fullName.split(' ').first);

    final restaurants = ref.watch(restaurantsProvider);
    final live = ref.watch(liveSessionsProvider);
    final invites = ref.watch(myInvitesProvider).valueOrNull ?? const [];

    return BrandScaffold(
      padBody: false,
      titleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName.isEmpty ? _greeting : '$_greeting, $firstName',
            style: AppType.display.copyWith(color: Colors.white, fontSize: 27),
          ),
          const SizedBox(height: 2),
          Text(
            _greetingSub,
            style: AppType.body.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
          ),
        ],
      ),
      leading: const SizedBox.shrink(),
      actions: [
        BandIconButton(
          icon: Icons.dialpad_rounded,
          onTap: () => context.push(Routes.joinSession),
          tooltip: 'Join with a code',
        ),
      ],
      bandContent: GatherSearchField(
        hint: 'Search restaurants or dishes',
        readOnly: true,
        onTap: () => context.go(Routes.search),
        onTrailingTap: () => context.go(Routes.search),
        trailingIcon: Icons.tune_rounded,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(restaurantsProvider);
          ref.invalidate(allMenuItemsProvider);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          padding: const EdgeInsets.only(top: Insets.xxl, bottom: 140),
          children: [
            if (invites.isNotEmpty) ...[
              _InviteBanner(session: invites.first),
              const SizedBox(height: Insets.lg),
            ],
            if (live.isNotEmpty) ...[
              _LiveSessionCard(session: live.first),
              const SizedBox(height: Insets.lg),
            ],
            _CategoryRow(
              selected: _category,
              onSelect: (c) => setState(() => _category = _category == c ? null : c),
            ),
            const SizedBox(height: Insets.xl),
            if (_category == null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.gutter),
                child: _GroupCallToAction(),
              ),
              const SizedBox(height: Insets.xxl),
              _BestSellersRail(),
              const SizedBox(height: Insets.xxl),
              _RestaurantsSection(restaurants: restaurants),
              const SizedBox(height: Insets.xxl),
              _RecommendedGrid(),
            ] else
              _CategoryResults(category: _category!),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onSelect});

  final FoodCategory? selected;
  final ValueChanged<FoodCategory> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
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

/// Surfaces a session the user has been added to but has not joined (FR8).
class _InviteBanner extends ConsumerWidget {
  const _InviteBanner({required this.session});

  final GroupSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: GatherCard(
          color: AppColors.accentSoft,
          shadows: const [],
          onTap: () => context.push('${Routes.joinSession}?code=${session.code}'),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                child: const Icon(Icons.mail_rounded, color: AppColors.ink, size: 22),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${session.hostName} invited you', style: AppType.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      'Join "${session.name}" and add your order',
                      style: AppType.caption.copyWith(color: AppColors.accentDeep),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.accentDeep),
            ],
          ),
        ),
      );
}

/// "Pick up where you left off" for a session already in progress.
class _LiveSessionCard extends ConsumerWidget {
  const _LiveSessionCard({required this.session});

  final GroupSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: GatherCard(
        onTap: () => context.push(Routes.session(session.id)),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: const BoxDecoration(
                gradient: AppColors.bandGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(Radii.lg),
                  topRight: Radius.circular(Radii.lg),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.groups_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      session.name,
                      style: AppType.bodyStrong.copyWith(color: Colors.white, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill(
                    label: session.stage.label,
                    color: AppColors.ink,
                    background: Colors.white.withValues(alpha: 0.9),
                    compact: true,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Row(
                children: [
                  MemberAvatarStack(members: session.members, size: 32),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.restaurantName ?? 'Choosing a restaurant',
                          style: AppType.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${session.memberCount} '
                          '${session.memberCount == 1 ? 'member' : 'members'} · tap to open',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCallToAction extends StatelessWidget {
  const _GroupCallToAction();

  @override
  Widget build(BuildContext context) => GatherCard(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Eating with people?', style: AppType.headline),
                      const SizedBox(height: 2),
                      Text(
                        'Everyone picks their own food into one cart.',
                        style: AppType.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: [
                Expanded(
                  child: GatherButton(
                    label: 'Start a group',
                    icon: Icons.add_rounded,
                    compact: true,
                    onPressed: () => context.go(Routes.group),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GatherOutlineButton(
                    label: 'Join with code',
                    icon: Icons.pin_rounded,
                    compact: true,
                    onPressed: () => context.push(Routes.joinSession),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _BestSellersRail extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(bestSellersProvider);
    final loading = ref.watch(allMenuItemsProvider).isLoading;

    if (loading && items.isEmpty) {
      return const SizedBox(height: 240, child: LoadingView());
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
          child: SectionHeader(
            title: 'Best sellers',
            actionLabel: 'View all',
            onAction: () => context.go(Routes.search),
          ),
        ),
        SizedBox(
          height: 244,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: Insets.md),
            itemBuilder: (context, i) => FoodTile(
              item: items[i],
              width: 168,
              onTap: () => ItemSheet.show(context, items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecommendedGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recommendedProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'You might like'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length > 6 ? 6 : items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: Insets.md,
              mainAxisSpacing: Insets.md,
              childAspectRatio: 0.69,
            ),
            itemBuilder: (context, i) => FoodTile(
              item: items[i],
              onTap: () => ItemSheet.show(context, items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantsSection extends StatelessWidget {
  const _RestaurantsSection({required this.restaurants});

  final AsyncValue<List<Restaurant>> restaurants;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Restaurants'),
            restaurants.when(
              loading: () => const SizedBox(height: 180, child: LoadingView()),
              error: (e, _) => ErrorView(message: '$e'),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyView(
                    icon: Icons.storefront_outlined,
                    title: 'No restaurants yet',
                    message: 'The catalogue is still being set up.',
                    compact: true,
                  );
                }
                return Column(
                  children: [
                    for (final r in list.take(4)) ...[
                      RestaurantCard(
                        restaurant: r,
                        onTap: () => context.push(Routes.restaurant(r.id)),
                      ),
                      const SizedBox(height: Insets.lg),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
}

class _CategoryResults extends ConsumerWidget {
  const _CategoryResults({required this.category});

  final FoodCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allMenuItemsProvider).valueOrNull ?? const [];
    final items = all.where((i) => i.category == category).toList();

    if (items.isEmpty) {
      return EmptyView(
        icon: CategoryChip.iconFor(category),
        title: 'Nothing in ${category.label} yet',
        message: 'Try another category.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: category.label),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: Insets.md,
              mainAxisSpacing: Insets.md,
              childAspectRatio: 0.69,
            ),
            itemBuilder: (context, i) => FoodTile(
              item: items[i],
              onTap: () => ItemSheet.show(context, items[i]),
            ),
          ),
        ],
      ),
    );
  }
}
