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

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return sessionAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: ErrorView(message: '$e')),
      data: (session) {
        if (session == null || user == null) {
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

        final isHost = session.isHostOf(user.uid);

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
          bandContent: _BandSummary(session: session),
          bottomBar: _SessionActionBar(session: session, isHost: isHost),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 120),
            children: [
              _StageBanner(session: session, isHost: isHost),
              const SizedBox(height: Insets.xl),
              _MembersSection(session: session, isHost: isHost, currentUid: user.uid),
              const SizedBox(height: Insets.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _BandSummary extends StatelessWidget {
  const _BandSummary({required this.session});

  final GroupSession session;

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
              '${session.memberCount} ${session.memberCount == 1 ? 'member' : 'members'}',
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
              ? 'Share the code above so everyone can join.'
              : 'You are in. Waiting for the rest of the group.',
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

class _SessionActionBar extends ConsumerWidget {
  const _SessionActionBar({required this.session, required this.isHost});

  final GroupSession session;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!session.stage.isLive) return const SizedBox.shrink();

    return _Bar(
      child: isHost
          ? GatherButton(
              label: 'Invite people',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: () => InviteSheet.show(context, session),
            )
          : GatherOutlineButton(
              label: 'Share code ${session.code}',
              icon: Icons.ios_share_rounded,
              onPressed: () => InviteSheet.show(context, session),
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

    switch (value) {
      case 'leave':
      case 'cancel':
        final isCancel = value == 'cancel';
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isCancel ? 'Cancel this session?' : 'Leave this session?'),
            content: Text(
              isCancel
                  ? 'Everyone will be removed from this session.'
                  : 'You will be removed from this session.',
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
            if (context.mounted) context.go(Routes.group);
        }
    }
  }
}
