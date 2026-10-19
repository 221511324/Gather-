import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/providers/providers.dart';

/// Holds the five top-level destinations and the floating navigation bar.
///
/// "Group" sits in the middle and is raised, because opening a shared session
/// is the thing this app exists to do — it should never be two taps away.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Search'),
    _NavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Group'),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  void _go(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(activeOrdersProvider).length;
    final liveSessions = ref.watch(liveSessionsProvider).length;
    final invites = ref.watch(myInvitesProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.band,
      extendBody: true,
      body: Stack(
        children: [
          navigationShell,
          // Content scrolls behind the floating bar, so it is faded into the
          // page colour on the way down rather than being hard-cut by it.
          const Positioned(left: 0, right: 0, bottom: 0, child: _BottomFade()),
        ],
      ),
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _go,
        items: _items,
        badges: {2: liveSessions + invites, 3: activeOrders},
      ),
    );
  }
}

/// A soft fade into the page colour where content passes under the floating
/// navigation bar.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // The bar itself, plus enough room above it for the fade to do its work.
    final height = _navBarHeight + (bottomInset > 0 ? bottomInset * 0.5 + 6 : Insets.md) + 64;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00F9EFDF),
                Color(0xCCF9EFDF),
                Color(0xFFF9EFDF),
              ],
              stops: [0, 0.55, 0.85],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Height of the pill itself, shared by the bar and the fade above it.
const double _navBarHeight = 68;

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.badges = const {},
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, bottom > 0 ? bottom * 0.5 + 6 : Insets.md),
      child: Container(
        height: _navBarHeight,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: Radii.brPill,
          boxShadow: Shadows.floating,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  badge: badges[i] ?? 0,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.brPill,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent,
                      borderRadius: Radii.brPill,
                    ),
                    child: Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 23,
                      color: Colors.white,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: 2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 17),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: Radii.brPill,
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          textAlign: TextAlign.center,
                          style: AppType.overline.copyWith(
                            color: AppColors.ink,
                            fontSize: 9.5,
                            height: 1.25,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: AppType.overline.copyWith(
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
                  fontSize: 9.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
}
