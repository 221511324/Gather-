import 'dart:math';
import 'dart:math' as math;

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
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/celebration.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/state_views.dart';
import 'spin_wheel.dart';

/// Restaurant Spin (FR10).
///
/// The winner is drawn before the wheel moves, then the animation is aimed at
/// that wedge. Only the host can spin, and the result is written to the
/// session so every member sees the same outcome.
class RestaurantSpinScreen extends ConsumerStatefulWidget {
  const RestaurantSpinScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<RestaurantSpinScreen> createState() => _RestaurantSpinScreenState();
}

class _RestaurantSpinScreenState extends ConsumerState<RestaurantSpinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _rotation = const AlwaysStoppedAnimation(0);
  int _celebration = 0;

  RestaurantSuggestion? _winner;
  bool _spinning = false;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    // Created here, not as a `late final` initialiser: a lazily-created
    // controller would be built for the first time inside dispose(), which
    // needs a Ticker from a widget that is already deactivated.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin(List<RestaurantSuggestion> suggestions) async {
    if (_spinning || suggestions.length < 2) return;

    final index = Random.secure().nextInt(suggestions.length);
    final target = rotationForWinner(winnerIndex: index, wedgeCount: suggestions.length);

    setState(() {
      _spinning = true;
      _settled = false;
      _winner = null;
    });

    _rotation = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    _controller.reset();
    await _controller.forward().orCancel.catchError((_) {});
    if (!mounted) return;

    setState(() {
      _spinning = false;
      _settled = true;
      _winner = suggestions[index];
      _celebration++;
    });
  }

  Future<void> _confirm(GroupSession session, RestaurantSuggestion winner) async {
    final restaurant = await ref.read(catalogServiceProvider).fetchRestaurant(winner.restaurantId);
    if (restaurant == null) {
      if (mounted) AppSnack.error(context, 'That restaurant is no longer available');
      return;
    }

    final result = await ref.read(sessionServiceProvider).chooseRestaurant(
          sessionId: session.id,
          restaurant: restaurant,
          bySpin: true,
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        if (mounted) {
          AppSnack.show(context, 'Locked in: ${restaurant.name}');
          context.pop();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider(widget.sessionId)).valueOrNull;
    final uid = ref.watch(currentUidProvider);

    if (session == null) {
      return const BrandScaffold(title: 'Restaurant Spin', showBack: true, child: LoadingView());
    }

    final suggestions = session.suggestions;
    final isHost = session.isHostOf(uid ?? '');

    // Resolved once per build, not on every animation frame: an ancestor
    // lookup inside the builder would also run after the route is popped.
    final wheelSize = math.min(MediaQuery.of(context).size.width * 0.78, 320.0);

    return BrandScaffold(
      title: 'Restaurant Spin',
      showBack: true,
      padBody: false,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxxl),
            children: [
              Text(
                _settled
                    ? 'The wheel picked…'
                    : (suggestions.length < 2
                        ? 'Add at least two suggestions'
                        : 'Cannot agree? Let the wheel decide.'),
                textAlign: TextAlign.center,
                style: AppType.title.copyWith(fontSize: 22),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                _settled
                    ? 'Every suggestion had an equal chance.'
                    : 'Each suggestion gets one slice. Nobody has to argue for it.',
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.inkMuted, fontSize: 14),
              ),
              const SizedBox(height: Insets.xxl),
              if (suggestions.length < 2)
                EmptyView(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Not enough suggestions',
                  message: 'The group needs to suggest at least two restaurants '
                      'before the wheel can decide.',
                  actionLabel: 'Browse restaurants',
                  onAction: () => context.go(Routes.search),
                )
              else ...[
                Center(
                  child: AnimatedBuilder(
                    animation: _rotation,
                    builder: (context, _) => SpinWheel(
                      labels: suggestions.map((s) => s.restaurantName).toList(),
                      rotation: _rotation.value,
                      size: wheelSize,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.xxl),
                if (_winner != null) _WinnerCard(winner: _winner!),
                const SizedBox(height: Insets.xl),
                if (!isHost)
                  Container(
                    padding: const EdgeInsets.all(Insets.md),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: Radii.brMd,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 19, color: AppColors.primary),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            'Only ${session.hostName} can spin the wheel for this session.',
                            style: AppType.caption.copyWith(color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_settled && _winner != null)
                  Column(
                    children: [
                      GatherButton(
                        label: 'Order from ${_winner!.restaurantName}',
                        icon: Icons.check_rounded,
                        onPressed: () => _confirm(session, _winner!),
                      ),
                      const SizedBox(height: Insets.md),
                      GatherOutlineButton(
                        label: 'Spin again',
                        icon: Icons.refresh_rounded,
                        onPressed: () => _spin(suggestions),
                      ),
                    ],
                  )
                else
                  GatherButton(
                    label: _spinning ? 'Spinning…' : 'Spin the wheel',
                    icon: _spinning ? null : Icons.casino_rounded,
                    color: AppColors.accent,
                    foreground: AppColors.ink,
                    busy: _spinning,
                    onPressed: () => _spin(suggestions),
                  ),
                const SizedBox(height: Insets.xxl),
                Text('On the wheel', style: AppType.label),
                const SizedBox(height: Insets.md),
                for (final s in suggestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: Row(
                      children: [
                        FoodImage(url: s.imageUrl, width: 34, height: 34, radius: Radii.sm),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Text(
                            s.restaurantName,
                            style: AppType.bodyLarge.copyWith(fontSize: 14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('by ${s.suggestedByName}', style: AppType.caption),
                      ],
                    ),
                  ),
              ],
            ],
          ),
          Positioned.fill(
            child: Celebration(
              trigger: _celebration,
              colors: SpinWheel.defaultColors,
            ),
          ),
        ],
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.winner});

  final RestaurantSuggestion winner;

  @override
  Widget build(BuildContext context) => GatherCard(
        color: AppColors.successSoft,
        shadows: const [],
        child: Row(
          children: [
            FoodImage(url: winner.imageUrl, width: 56, height: 56, radius: Radii.md),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('WINNER', style: AppType.overline.copyWith(color: AppColors.success)),
                  Text(
                    winner.restaurantName,
                    style: AppType.headline.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Suggested by ${winner.suggestedByName}', style: AppType.caption),
                ],
              ),
            ),
            const Icon(Icons.emoji_events_rounded, size: 30, color: AppColors.accent),
          ],
        ),
      );
}
