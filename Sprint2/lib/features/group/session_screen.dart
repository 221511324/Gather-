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
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/food_image.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import 'invite_sheet.dart';

/// The live group session (FR9, FR10, FR12, FR13, FR17).
///
/// Everything on this screen is driven by snapshot streams, so a member
/// joining, an item being added, or the host picking a restaurant appears for
/// everyone without a refresh (NFR7).
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  @override
  void initState() {
    super.initState();
    // Marks this as the session the rest of the app adds items to. Guarded:
    // if the screen is popped before this frame lands, the element is gone
    // and writing to a provider through it would tear down the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeSessionIdProvider.notifier).state = widget.sessionId;
    });
  }

  /// Stops this session being the one the rest of the app adds food to.
  ///
  /// Leaving through the menu is only one way out: the host can remove a
  /// member, cancel the session, or the user can leave on another device. All
  /// of those land in [build] rather than in the menu handler, and a session
  /// id left pointing at a session the user is no longer in keeps the app
  /// offering a shared cart the rules will refuse. Deferred to after the
  /// frame, because a provider must not be written to during a build.
  bool _leaving = false;

  void _dropActiveSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(activeSessionIdProvider.notifier);
      if (notifier.state == widget.sessionId) notifier.state = null;
    });
  }

  /// Once this user is out of the session there is nothing on this screen for
  /// them, and which path removed them — leaving, being removed, the host
  /// cancelling — should not decide whether they get stranded here. Take them
  /// back to the group tab and say what happened.
  void _bounceToGroup(String reason) {
    if (_leaving) return;
    _leaving = true;
    final router = GoRouter.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeSessionIdProvider.notifier).state = null;
      router.go(Routes.group);
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.showSnackBar(SnackBar(content: Text(reason)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final linesAsync = ref.watch(sessionLinesProvider(widget.sessionId));
    // A failed read and an empty cart look identical through valueOrNull, and
    // telling a host "nothing added yet" when the read was refused sends them
    // looking for the wrong problem.
    final lines = linesAsync.valueOrNull ?? const <CartLine>[];
    final cartUnreadable = linesAsync.hasError;
    final totals = ref.watch(sessionTotalsProvider(widget.sessionId));

    return sessionAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      // A refused or failed read is reported as something to act on, never as
      // a Firebase exception and never as a spinner that never ends.
      error: (_, _) => Scaffold(
        body: ErrorView(
          message: 'We could not load this session. Check your connection and '
              'try again.',
          onRetry: () => ref.invalidate(sessionProvider(widget.sessionId)),
        ),
      ),
      data: (session) {
        if (session == null) {
          _dropActiveSession();
          return const BrandScaffold(
            title: 'Session',
            showBack: true,
            child: EmptyView(
              icon: Icons.group_off_outlined,
              title: 'Session not found',
              message: 'It may have been cancelled by the host.',
            ),
          );
        }

        if (user == null) {
          // Nothing here can be judged without a profile — whose items are
          // whose, who the host is — so this waits, or says why it cannot.
          return Scaffold(
            body: userAsync.hasError
                ? ErrorView(
                    message: 'We could not load your profile, so this session '
                        'cannot be opened yet.',
                    onRetry: () => ref.invalidate(currentUserProvider),
                  )
                : const LoadingView(),
          );
        }

        if (!session.hasMember(user.uid)) {
          _bounceToGroup('You are no longer in "${session.name}"');
          return const Scaffold(body: LoadingView());
        }

        final isHost = session.isHostOf(user.uid);
        final me = session.memberOf(user.uid);
        final myLines = lines.where((l) => l.ownerId == user.uid).toList();

        return BrandScaffold(
          title: session.name,
          showBack: true,
          padBody: false,
          bandHeight: null,
          actions: [
            if (isHost && session.stage.isLive)
              BandIconButton(
                icon: Icons.person_add_alt_1_rounded,
                tooltip: 'Invite people',
                onTap: () => InviteSheet.show(context, session),
              ),
            const SizedBox(width: Insets.sm),
            _SessionMenu(session: session, isHost: isHost),
          ],
          bandContent: _BandSummary(
            session: session,
            itemCount: cartUnreadable ? null : lines.length,
          ),
          bottomBar: _SessionActionBar(
            session: session,
            isHost: isHost,
            lines: lines,
            totals: totals,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 120),
            children: [
              _StageBanner(session: session, isHost: isHost),
              const SizedBox(height: Insets.xl),
              _MembersSection(session: session, isHost: isHost, currentUid: user.uid),
              const SizedBox(height: Insets.xxl),
              if (!session.hasRestaurant)
                _RestaurantDecision(session: session, isHost: isHost)
              else ...[
                _ChosenRestaurant(session: session, isHost: isHost),
                const SizedBox(height: Insets.xxl),
                if (cartUnreadable)
                  _CartUnreadable(
                    onRetry: () =>
                        ref.invalidate(sessionLinesProvider(widget.sessionId)),
                  )
                else
                  _SharedCartSummary(
                    session: session,
                    lines: lines,
                    myLines: myLines,
                    totals: totals,
                  ),
                if (session.stage == SessionStage.ordering) ...[
                  const SizedBox(height: Insets.lg),
                  _ReadyToggle(session: session, me: me, hasItems: myLines.isNotEmpty),
                ],
              ],
              const SizedBox(height: Insets.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _BandSummary extends StatelessWidget {
  const _BandSummary({required this.session, required this.itemCount});

  final GroupSession session;

  /// Null when the shared cart could not be read, so the band says so rather
  /// than reporting zero.
  final int? itemCount;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: Radii.brMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pin_rounded, size: 15, color: Colors.white),
                const SizedBox(width: Insets.xs + 2),
                Text(
                  session.code,
                  style: AppType.money.copyWith(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              '${session.memberCount} '
              '${session.memberCount == 1 ? 'member' : 'members'} · '
              '${itemCount == null ? 'cart unavailable' : '$itemCount '
                  '${itemCount == 1 ? 'item' : 'items'}'}',
              style: AppType.body.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 13.5,
              ),
            ),
          ),
          MemberAvatarStack(
            members: session.members,
            size: 30,
            borderColor: AppColors.bandDeep,
          ),
        ],
      );
}

/// Tells the member, in plain words, what the session is waiting on.
class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.session, required this.isHost});

  final GroupSession session;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final (icon, message, color) = switch (session.stage) {
      SessionStage.lobby => (
          Icons.hourglass_empty_rounded,
          isHost
              ? 'Invite everyone, then pick where you are ordering from.'
              : 'Waiting for the host to choose a restaurant.',
          AppColors.primary,
        ),
      SessionStage.choosingRestaurant => (
          Icons.how_to_vote_rounded,
          isHost
              ? 'Members are suggesting places. Spin the wheel or pick one yourself.'
              : 'Suggest a restaurant — the host will spin to decide.',
          AppColors.primary,
        ),
      SessionStage.ordering => (
          Icons.restaurant_menu_rounded,
          'Everyone adds their own items to the shared cart.',
          AppColors.primary,
        ),
      SessionStage.payment => (
          Icons.account_balance_wallet_rounded,
          'The cart is locked. ${session.paidCount} of ${session.memberCount} have paid.',
          AppColors.accentDeep,
        ),
      SessionStage.placed => (
          Icons.check_circle_rounded,
          'This order has been placed.',
          AppColors.success,
        ),
      SessionStage.cancelled => (
          Icons.cancel_rounded,
          'This session was cancelled.',
          AppColors.danger,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: Radii.brMd,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              message,
              style: AppType.body.copyWith(color: color, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// The roster, with host controls for removing members (FR9).
class _MembersSection extends ConsumerWidget {
  const _MembersSection({
    required this.session,
    required this.isHost,
    required this.currentUid,
  });

  final GroupSession session;
  final bool isHost;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Members (${session.memberCount})',
            actionLabel: isHost && session.stage.isLive ? 'Invite' : null,
            onAction:
                isHost && session.stage.isLive ? () => InviteSheet.show(context, session) : null,
          ),
          for (final member in session.members)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: GatherCard(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    MemberAvatar.of(member, size: 40),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.uid == currentUid ? '${member.name} (you)' : member.name,
                                  style: AppType.bodyStrong,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (member.isHost) ...[
                                const SizedBox(width: Insets.sm),
                                const StatusPill(
                                  label: 'Host',
                                  color: AppColors.accentDeep,
                                  background: AppColors.accentSoft,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                          Text('@${member.username}', style: AppType.caption),
                        ],
                      ),
                    ),
                    if (session.stage == SessionStage.payment)
                      StatusPill(
                        label: member.paymentStatus == MemberPaymentStatus.pending
                            ? Money.format(member.amountDue)
                            : member.paymentStatus.label,
                        color: member.paymentStatus == MemberPaymentStatus.pending
                            ? AppColors.accentDeep
                            : AppColors.success,
                        icon: member.paymentStatus == MemberPaymentStatus.paid
                            ? Icons.check_rounded
                            : null,
                        compact: true,
                      )
                    else if (member.hasConfirmedItems && session.stage == SessionStage.ordering)
                      const StatusPill(
                        label: 'Ready',
                        color: AppColors.success,
                        icon: Icons.check_rounded,
                        compact: true,
                      ),
                    if (isHost && !member.isHost && session.stage.isLive)
                      IconButton(
                        icon: const Icon(Icons.person_remove_outlined, size: 19),
                        color: AppColors.inkFaint,
                        tooltip: 'Remove ${member.name}',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Remove ${member.name}?'),
                              content: const Text(
                                'Their items will be removed from the shared cart too.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.danger),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          final result = await ref.read(sessionServiceProvider).removeMember(
                                sessionId: session.id,
                                memberUid: member.uid,
                              );
                          if (!context.mounted) return;
                          if (result case Err(:final message)) {
                            AppSnack.error(context, message);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// Suggestions and the route into Restaurant Spin (FR10 / US7).
class _RestaurantDecision extends ConsumerWidget {
  const _RestaurantDecision({required this.session, required this.isHost});

  final GroupSession session;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    // The host decides how the restaurant gets chosen before anything else
    // happens, so members are never asked to suggest into a decision that is
    // not theirs to make.
    if (session.decisionMode == null) {
      return _DecisionModeChooser(session: session, isHost: isHost);
    }

    if (session.decisionMode == RestaurantDecisionMode.hostChoice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Where are we eating?'),
          EmptyView(
            icon: Icons.storefront_outlined,
            title: isHost ? 'Pick the restaurant' : 'The host is choosing',
            message: isHost
                ? 'Browse restaurants and tap "Order here" on the one you want.'
                : 'You will see the menu as soon as the host has chosen.',
            compact: true,
          ),
          // Browsing is already the action bar's job at the bottom of the
          // screen, so this offers only the way back to the wheel.
          if (isHost) ...[
            const SizedBox(height: Insets.sm),
            Center(
              child: TextButton(
                onPressed: () => ref.read(sessionServiceProvider).setDecisionMode(
                    sessionId: session.id, mode: RestaurantDecisionMode.spin),
                child: Text('Use the wheel instead', style: AppType.label),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Where are we eating?',
          actionLabel: 'Browse',
          onAction: () => context.go(Routes.search),
        ),
        if (session.suggestions.isEmpty)
          const EmptyView(
            icon: Icons.lightbulb_outline_rounded,
            title: 'No suggestions yet',
            message: 'Browse restaurants and tap "Suggest this" to add one to the wheel.',
            compact: true,
          )
        else
          for (final suggestion in session.suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: GatherCard(
                onTap: () => context.push(Routes.restaurant(suggestion.restaurantId)),
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    FoodImage(
                      url: suggestion.imageUrl,
                      width: 48,
                      height: 48,
                      radius: Radii.sm,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            suggestion.restaurantName,
                            style: AppType.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Suggested by ${suggestion.suggestedByName}',
                            style: AppType.caption,
                          ),
                        ],
                      ),
                    ),
                    _VoteButton(session: session, suggestion: suggestion, uid: user?.uid),
                    // Your own pick is yours to take back; the host can clear
                    // any of them.
                    if (isHost || suggestion.suggestedBy == user?.uid)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.inkFaint,
                        tooltip: suggestion.suggestedBy == user?.uid
                            ? 'Withdraw your suggestion'
                            : 'Remove suggestion',
                        onPressed: user == null
                            ? null
                            : () => ref.read(sessionServiceProvider).removeSuggestion(
                                  sessionId: session.id,
                                  restaurantId: suggestion.restaurantId,
                                  byUid: user.uid,
                                ),
                      ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: Insets.md),
        if (session.suggestions.length >= 2 && isHost)
          GatherButton(
            label: 'Spin the wheel',
            icon: Icons.casino_rounded,
            color: AppColors.accent,
            foreground: AppColors.ink,
            onPressed: () {
              context.push(Routes.sessionSpin(session.id));
            },
          )
        else if (session.suggestions.length < 2 && isHost)
          Text(
            'Add at least two suggestions to spin the wheel.',
            style: AppType.caption,
          ),
        if (isHost) ...[
          const SizedBox(height: Insets.sm),
          Center(
            child: TextButton(
              onPressed: () => ref.read(sessionServiceProvider).setDecisionMode(
                  sessionId: session.id, mode: RestaurantDecisionMode.hostChoice),
              child: Text('Skip the wheel and choose myself', style: AppType.label),
            ),
          ),
        ],
      ],
    );
  }
}

/// The host's first decision: let the wheel settle it, or choose themselves.
class _DecisionModeChooser extends ConsumerWidget {
  const _DecisionModeChooser({required this.session, required this.isHost});

  final GroupSession session;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isHost) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Where are we eating?'),
          EmptyView(
            icon: Icons.hourglass_empty_rounded,
            title: 'Waiting for the host',
            message: 'The host is deciding whether to spin the wheel or pick '
                'the restaurant themselves.',
            compact: true,
          ),
        ],
      );
    }

    Future<void> choose(RestaurantDecisionMode mode) async {
      final r = await ref.read(sessionServiceProvider)
          .setDecisionMode(sessionId: session.id, mode: mode);
      if (!context.mounted) return;
      if (r case Err(:final message)) AppSnack.error(context, message);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'How are we deciding?'),
        Text(
          'Pick one. You can change your mind later.',
          style: AppType.caption,
        ),
        const SizedBox(height: Insets.lg),
        _ModeCard(
          icon: Icons.casino_rounded,
          title: 'Spin the wheel',
          detail: 'Everyone puts one restaurant forward and the wheel decides.',
          accent: AppColors.accent,
          onTap: () => choose(RestaurantDecisionMode.spin),
        ),
        const SizedBox(height: Insets.md),
        _ModeCard(
          icon: Icons.storefront_rounded,
          title: 'I will choose',
          detail: 'You pick the restaurant and nobody is asked to suggest.',
          accent: AppColors.primary,
          onTap: () => choose(RestaurantDecisionMode.hostChoice),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GatherCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent == AppColors.accent
                  ? AppColors.accentDeep : accent, size: 23),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppType.bodyStrong),
                  const SizedBox(height: 2),
                  Text(detail, style: AppType.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      );
}

class _VoteButton extends ConsumerWidget {
  const _VoteButton({required this.session, required this.suggestion, this.uid});

  final GroupSession session;
  final RestaurantSuggestion suggestion;
  final String? uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voted = uid != null && suggestion.votes.contains(uid);

    return TextButton.icon(
      onPressed: uid == null
          ? null
          : () => ref.read(sessionServiceProvider).toggleVote(
                sessionId: session.id,
                restaurantId: suggestion.restaurantId,
                uid: uid!,
              ),
      icon: Icon(
        voted ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
        size: 17,
        color: voted ? AppColors.primary : AppColors.inkFaint,
      ),
      label: Text(
        '${suggestion.votes.length}',
        style: AppType.label.copyWith(
          color: voted ? AppColors.primary : AppColors.inkFaint,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ChosenRestaurant extends ConsumerWidget {
  const _ChosenRestaurant({required this.session, required this.isHost});

  final GroupSession session;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        onTap: () => context.push(Routes.restaurant(session.restaurantId!)),
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            FoodImage(
              url: session.restaurantImageUrl ?? '',
              width: 56,
              height: 56,
              radius: Radii.md,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ORDERING FROM', style: AppType.overline),
                  const SizedBox(height: 2),
                  Text(
                    session.restaurantName ?? '',
                    style: AppType.headline.copyWith(fontSize: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (session.decidedBySpin) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.casino_rounded, size: 13, color: AppColors.accentDeep),
                        const SizedBox(width: 3),
                        Text(
                          'Picked by the wheel',
                          style: AppType.caption.copyWith(
                            color: AppColors.accentDeep,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isHost && session.stage == SessionStage.ordering)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                tooltip: 'Change restaurant',
                color: AppColors.inkMuted,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Change restaurant?'),
                      content: const Text(
                        'Everything in the shared cart will be removed, because those '
                        'items only exist on this restaurant\'s menu.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  await ref.read(sessionServiceProvider).reopenOrdering(session.id);
                  if (context.mounted) context.go(Routes.search);
                },
              ),
          ],
        ),
      );
}

/// Shown when the shared cart could not be read. Without this the screen
/// reports an empty cart, which reads as "nobody has added anything" and
/// sends the host looking for the wrong problem.
class _CartUnreadable extends StatelessWidget {
  const _CartUnreadable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GatherCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.danger),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text('Could not load the shared cart',
                      style: AppType.bodyStrong),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'This is a connection or permission problem, not an empty cart. '
              'Anything the group has added is still there.',
              style: AppType.caption,
            ),
            const SizedBox(height: Insets.md),
            GatherOutlineButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              compact: true,
              onPressed: onRetry,
            ),
          ],
        ),
      );
}

class _SharedCartSummary extends StatelessWidget {
  const _SharedCartSummary({
    required this.session,
    required this.lines,
    required this.myLines,
    required this.totals,
  });

  final GroupSession session;
  final List<CartLine> lines;
  final List<CartLine> myLines;
  final CartTotals totals;

  @override
  Widget build(BuildContext context) {
    // Count how many items each member has contributed.
    final byMember = <String, int>{};
    for (final line in lines) {
      byMember[line.ownerId] = (byMember[line.ownerId] ?? 0) + line.quantity;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Shared cart',
          actionLabel: lines.isEmpty ? null : 'See all',
          onAction: lines.isEmpty ? null : () => context.push(Routes.sessionCart(session.id)),
        ),
        if (lines.isEmpty)
          const EmptyView(
            icon: Icons.shopping_basket_outlined,
            title: 'Nothing added yet',
            message: 'Open the menu and add what you want. Everyone sees it here.',
            compact: true,
          )
        else
          GatherCard(
            child: Column(
              children: [
                for (final member in session.members) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.xs + 2),
                    child: Row(
                      children: [
                        MemberAvatar.of(member, size: 28),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Text(
                            member.name,
                            style: AppType.bodyLarge.copyWith(fontSize: 14.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          byMember[member.uid] == null
                              ? 'nothing yet'
                              : '${byMember[member.uid]} '
                                  '${byMember[member.uid] == 1 ? 'item' : 'items'}',
                          style: AppType.caption.copyWith(
                            color: byMember[member.uid] == null
                                ? AppColors.inkFaint
                                : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.sm),
                  child: Divider(height: 1),
                ),
                TotalsPanelCompact(totals: totals, memberCount: session.memberCount),
              ],
            ),
          ),
        if (myLines.isNotEmpty) ...[
          const SizedBox(height: Insets.md),
          Text(
            'You have added ${myLines.length} ${myLines.length == 1 ? 'item' : 'items'} '
            '· ${Money.format(myLines.fold<double>(0, (acc, l) => acc + l.lineTotal))}',
            style: AppType.caption,
          ),
        ],
      ],
    );
  }
}

/// A trimmed totals block for the session overview.
class TotalsPanelCompact extends StatelessWidget {
  const TotalsPanelCompact({super.key, required this.totals, required this.memberCount});

  final CartTotals totals;
  final int memberCount;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Group total', style: AppType.overline),
                Text(
                  Money.format(totals.total),
                  style: AppType.money.copyWith(fontSize: 19, color: AppColors.primary),
                ),
              ],
            ),
          ),
          if (memberCount > 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Split equally', style: AppType.overline),
                Text(
                  Money.format(totals.total / memberCount),
                  style: AppType.money.copyWith(fontSize: 15),
                ),
              ],
            ),
        ],
      );
}

/// Lets a member say they are done choosing (FR13), which is what the host
/// watches before locking the cart.
class _ReadyToggle extends ConsumerWidget {
  const _ReadyToggle({required this.session, required this.me, required this.hasItems});

  final GroupSession session;
  final SessionMember? me;
  final bool hasItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = me?.hasConfirmedItems ?? false;

    return GatherOutlineButton(
      label: ready ? "I'm not done yet" : "I'm done choosing",
      icon: ready ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
      color: ready ? AppColors.inkMuted : AppColors.success,
      onPressed: !hasItems && !ready
          ? null
          : () => ref.read(sessionServiceProvider).setItemsConfirmed(
                sessionId: session.id,
                uid: me?.uid ?? '',
                confirmed: !ready,
              ),
    );
  }
}

/// The stage-appropriate primary action, pinned to the bottom.
class _SessionActionBar extends ConsumerWidget {
  const _SessionActionBar({
    required this.session,
    required this.isHost,
    required this.lines,
    required this.totals,
  });

  final GroupSession session;
  final bool isHost;
  final List<CartLine> lines;
  final CartTotals totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.stage == SessionStage.cancelled) return const SizedBox.shrink();

    if (session.stage == SessionStage.placed) {
      return _Bar(
        child: GatherButton(
          label: 'View the order',
          icon: Icons.receipt_long_rounded,
          onPressed: () {
            context.push(Routes.order(session.orderId ?? ''));
          },
        ),
      );
    }

    if (!session.hasRestaurant) {
      return _Bar(
        child: GatherButton(
          label: 'Browse restaurants',
          icon: Icons.storefront_rounded,
          onPressed: () => context.go(Routes.search),
        ),
      );
    }

    if (session.stage == SessionStage.payment) {
      return _Bar(
        child: GatherButton(
          label: 'Go to payment',
          icon: Icons.account_balance_wallet_rounded,
          onPressed: () {
            context.push(Routes.sessionPayment(session.id));
          },
        ),
      );
    }

    // Ordering stage.
    final everyoneReady = session.members.every((m) => m.hasConfirmedItems);
    return _Bar(
      child: Row(
        children: [
          Expanded(
            child: GatherOutlineButton(
              label: 'Add items',
              icon: Icons.add_rounded,
              onPressed: () => context.push(Routes.restaurant(session.restaurantId!)),
            ),
          ),
          if (isHost) ...[
            const SizedBox(width: Insets.md),
            Expanded(
              child: GatherButton(
                label: 'Lock & pay',
                onPressed: lines.isEmpty
                    ? null
                    : () async {
                        if (!everyoneReady) {
                          final proceed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Not everyone is ready'),
                              content: Text(
                                '${session.members.where((m) => !m.hasConfirmedItems).length} '
                                'member(s) have not confirmed their items yet. '
                                'Lock the cart anyway?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Wait'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Lock anyway'),
                                ),
                              ],
                            ),
                          );
                          if (proceed != true) return;
                        }
                        if (!context.mounted) return;
                        context.push(Routes.sessionPayment(session.id));
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.background,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
          child: child,
        ),
      );
}

class _SessionMenu extends ConsumerWidget {
  const _SessionMenu({required this.session, required this.isHost});

  final GroupSession session;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        tooltip: 'Session options',
        icon: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.more_horiz_rounded, size: 19, color: Colors.white),
        ),
        onSelected: (value) => _handle(context, ref, value),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'save', child: Text('Save this group')),
          if (session.stage.isLive)
            PopupMenuItem(
              value: isHost ? 'cancel' : 'leave',
              child: Text(
                isHost ? 'Cancel session' : 'Leave session',
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      );

  Future<void> _handle(BuildContext context, WidgetRef ref, String value) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final service = ref.read(sessionServiceProvider);
    // Leaving removes this user from the session, which rebuilds the screen
    // into the "you are not in this session" state. That can unmount the
    // element this context belongs to before the await returns, so the router
    // is taken now rather than reached for afterwards — otherwise the person
    // who just chose to leave is stranded on a dead end.
    final router = GoRouter.of(context);

    switch (value) {
      case 'save':
        final result = await service.saveAsGroup(session: session, ownerId: uid);
        if (!context.mounted) return;
        switch (result) {
          case Err(:final message):
            AppSnack.error(context, message);
          case Ok():
            AppSnack.show(context, 'Saved — you can reuse this group any time');
        }

      case 'leave':
      case 'cancel':
        final isCancel = value == 'cancel';
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isCancel ? 'Cancel this session?' : 'Leave this session?'),
            content: Text(
              isCancel
                  ? 'Everyone will be removed and the shared cart is discarded.'
                  : 'Your items will be removed from the shared cart.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                onPressed: () => Navigator.pop(context, true),
                child: Text(isCancel ? 'Cancel session' : 'Leave'),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        final result = isCancel
            ? await service.cancel(session.id)
            : await service.leave(sessionId: session.id, uid: uid);

        if (!context.mounted) return;
        switch (result) {
          case Err(:final message):
            AppSnack.error(context, message);
          case Ok():
            ref.read(activeSessionIdProvider.notifier).state = null;
            router.go(Routes.group);
        }
    }
  }
}
