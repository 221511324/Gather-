import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/state_views.dart';
import '../restaurant/item_sheet.dart';
import 'cart_line_tile.dart';

/// The personal cart (FR5).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final cartAsync = ref.watch(cartProvider);
    final restaurant = ref.watch(cartRestaurantProvider).valueOrNull;
    final totals = ref.watch(cartTotalsProvider);
    final menu = ref.watch(allMenuItemsProvider).valueOrNull ?? const <MenuItem>[];

    return BrandScaffold(
      title: 'My cart',
      showBack: true,
      padBody: false,
      actions: [
        if ((cartAsync.valueOrNull ?? const []).isNotEmpty)
          BandIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Clear cart',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear your cart?'),
                  content: const Text('This removes every item you have added.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirm == true && user != null) {
                await ref.read(cartServiceProvider).clear(user.uid);
              }
            },
          ),
      ],
      child: cartAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (lines) {
          if (lines.isEmpty) {
            return EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Find something you like and it will show up here.',
              actionLabel: 'Browse restaurants',
              onAction: () => context.go(Routes.search),
            );
          }

          final belowMinimum =
              restaurant != null && totals.subtotal < restaurant.minimumOrder;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
                  children: [
                    if (restaurant != null) ...[
                      _RestaurantStrip(restaurant: restaurant),
                      const SizedBox(height: Insets.lg),
                    ],
                    for (final line in lines) ...[
                      Dismissible(
                        key: ValueKey(line.id),
                        direction: DismissDirection.endToStart,
                        background: _SwipeBackground(),
                        onDismissed: (_) async {
                          if (user == null) return;
                          await ref.read(cartServiceProvider).remove(user.uid, line.id);
                          if (context.mounted) {
                            AppSnack.show(context, '${line.name} removed');
                          }
                        },
                        child: CartLineTile(
                          line: line,
                          onQuantityChanged: user == null
                              ? null
                              : (q) => ref
                                  .read(cartServiceProvider)
                                  .setQuantity(user.uid, line.id, q),
                          onRemove: user == null
                              ? null
                              : () => ref.read(cartServiceProvider).remove(user.uid, line.id),
                          onTap: () {
                            final item = menu.where((i) => i.id == line.itemId).firstOrNull;
                            if (item != null) ItemSheet.edit(context, item, line);
                          },
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                    const SizedBox(height: Insets.md),
                    GatherCard(child: TotalsPanel(totals: totals)),
                    if (belowMinimum) ...[
                      const SizedBox(height: Insets.md),
                      _MinimumWarning(
                        missing: restaurant.minimumOrder - totals.subtotal,
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(
                    Insets.gutter, Insets.sm, Insets.gutter, Insets.lg),
                child: GatherButton(
                  label: 'Checkout · ${Money.format(totals.total)}',
                  onPressed: belowMinimum ? null : () => context.push(Routes.checkout),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RestaurantStrip extends StatelessWidget {
  const _RestaurantStrip({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: () => context.push(Routes.restaurant(restaurant.id)),
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            const Icon(Icons.storefront_rounded, size: 20, color: AppColors.primary),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                restaurant.name,
                style: AppType.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('Add more', style: AppType.label.copyWith(color: AppColors.primary, fontSize: 13)),
            const Icon(Icons.chevron_right_rounded, size: 19, color: AppColors.primary),
          ],
        ),
      );
}

class _MinimumWarning extends StatelessWidget {
  const _MinimumWarning({required this.missing});

  final double missing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: Radii.brMd),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 19, color: AppColors.warning),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                'Add ${Money.format(missing)} more to reach this restaurant\'s minimum order.',
                style: AppType.caption.copyWith(color: AppColors.accentDeep, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}

class _SwipeBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Insets.xl),
        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: Radii.brLg),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      );
}
