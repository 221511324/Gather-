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
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';

/// The group ordering home: start a session, join one, or reuse a saved group
/// (FR6, FR8, FR21).
class GroupHubScreen extends ConsumerWidget {
  const GroupHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveSessionsProvider);
    final invites = ref.watch(myInvitesProvider).valueOrNull ?? const <GroupSession>[];
    final saved = ref.watch(savedSessionsProvider).valueOrNull ?? const <SavedSession>[];
    final past = (ref.watch(mySessionsProvider).valueOrNull ?? const <GroupSession>[])
        .where((s) => !s.stage.isLive)
        .toList();

    return BrandScaffold(
      title: 'Group orders',
      leading: const SizedBox.shrink(),
      padBody: false,
      bandContent: Row(
        children: [
          Expanded(
            child: GatherButton(
              label: 'New session',
              icon: Icons.add_rounded,
              compact: true,
              color: Colors.white,
              foreground: AppColors.primary,
              onPressed: () => CreateSessionSheet.show(context),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: GatherButton(
              label: 'Join',
              icon: Icons.pin_rounded,
              compact: true,
              color: AppColors.accent,
              foreground: AppColors.ink,
              // A block body, so the push future is not handed to the button:
              // the join flow ends in pushReplacement and leaving a session
              // calls go, and go_router completes a push future only on a pop.
              // Returning it left this button spinning and disabled for the
              // rest of the run.
              onPressed: () {
                context.push(Routes.joinSession);
              },
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, 140),
        children: [
          if (invites.isNotEmpty) ...[
            const SectionHeader(title: 'Invitations'),
            for (final s in invites) ...[
              _InviteTile(session: s),
              const SizedBox(height: Insets.md),
            ],
            const SizedBox(height: Insets.lg),
          ],
          if (live.isNotEmpty) ...[
            SectionHeader(title: 'Active sessions (${live.length})'),
            for (final s in live) ...[
              _SessionTile(session: s),
              const SizedBox(height: Insets.md),
            ],
            const SizedBox(height: Insets.lg),
          ],
          if (live.isEmpty && invites.isEmpty && saved.isEmpty && past.isEmpty)
            const EmptyView(
              icon: Icons.groups_outlined,
              title: 'No group orders yet',
              message: 'Start a session and invite the people you are eating with. '
                  'Everyone adds their own food to one shared cart.',
            ),
          if (saved.isNotEmpty) ...[
            const SectionHeader(title: 'Saved groups'),
            Text(
              'Start a new order with the same people, without inviting them again.',
              style: AppType.caption,
            ),
            const SizedBox(height: Insets.md),
            for (final s in saved) ...[
              _SavedTile(saved: s),
              const SizedBox(height: Insets.md),
            ],
            const SizedBox(height: Insets.lg),
          ],
          if (past.isNotEmpty) ...[
            const SectionHeader(title: 'Past sessions'),
            for (final s in past.take(8)) ...[
              _SessionTile(session: s, muted: true),
              const SizedBox(height: Insets.md),
            ],
          ],
        ],
      ),
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.session});

  final GroupSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        color: AppColors.accentSoft,
        shadows: const [],
        child: Row(
          children: [
            MemberAvatarStack(members: session.members, size: 32, borderColor: AppColors.accentSoft),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(session.name, style: AppType.bodyStrong),
                  Text('${session.hostName} invited you', style: AppType.caption),
                ],
              ),
            ),
            GatherButton(
              label: 'Join',
              compact: true,
              expand: false,
              color: AppColors.accentDeep,
              onPressed: () async {
                final user = ref.read(currentUserOrNullProvider);
                if (user == null) return;
                final result = await ref
                    .read(sessionServiceProvider)
                    .join(sessionId: session.id, user: user);
                if (!context.mounted) return;
                switch (result) {
                  case Err(:final message):
                    AppSnack.error(context, message);
                  case Ok():
                    ref.read(activeSessionIdProvider.notifier).state = session.id;
                    context.push(Routes.session(session.id));
                }
              },
            ),
          ],
        ),
      );
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session, this.muted = false});

  final GroupSession session;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(sessionLinesProvider(session.id)).valueOrNull ?? const [];

    return GatherCard(
      onTap: () {
        ref.read(activeSessionIdProvider.notifier).state = session.id;
        context.push(Routes.session(session.id));
      },
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: muted ? AppColors.line : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              session.stage == SessionStage.placed
                  ? Icons.check_rounded
                  : (session.stage == SessionStage.cancelled
                      ? Icons.close_rounded
                      : Icons.groups_rounded),
              color: muted ? AppColors.inkFaint : AppColors.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.name,
                  style: AppType.bodyStrong,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.restaurantName ?? 'No restaurant yet'} · '
                  '${session.memberCount} members · ${lines.length} items',
                  style: AppType.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          StatusPill(
            label: session.stage.label,
            color: switch (session.stage) {
              SessionStage.placed => AppColors.success,
              SessionStage.cancelled => AppColors.danger,
              SessionStage.payment => AppColors.accentDeep,
              _ => AppColors.primary,
            },
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.saved});

  final SavedSession saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        child: Row(
          children: [
            MemberAvatarStack(members: saved.members, size: 32),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(saved.name, style: AppType.bodyStrong),
                  Text(
                    '${saved.members.length} people'
                    '${saved.timesUsed > 0 ? ' · used ${saved.timesUsed}×' : ''}',
                    style: AppType.caption,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
              tooltip: 'Saved group options',
              onSelected: (value) async {
                final uid = ref.read(currentUidProvider);
                if (uid == null) return;
                final service = ref.read(sessionServiceProvider);

                if (value == 'rename') {
                  final name = await _promptForName(context, saved.name);
                  if (name == null || !context.mounted) return;
                  await service.renameSavedSession(uid, saved.id, name);
                  if (context.mounted) AppSnack.show(context, 'Group renamed');
                  return;
                }

                if (value == 'delete') {
                  await service.deleteSavedSession(uid, saved.id);
                  if (context.mounted) AppSnack.show(context, 'Saved group removed');
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete saved group', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
            GatherButton(
              label: 'Start',
              compact: true,
              expand: false,
              onPressed: () async {
                final user = ref.read(currentUserOrNullProvider);
                if (user == null) return;
                final result = await ref
                    .read(sessionServiceProvider)
                    .startFromSaved(host: user, saved: saved);
                if (!context.mounted) return;
                switch (result) {
                  case Err(:final message):
                    AppSnack.error(context, message);
                  case Ok(:final value):
                    // Let everyone know the group is ordering again.
                    ref.read(activeSessionIdProvider.notifier).state = value.id;
                    if (context.mounted) context.push(Routes.session(value.id));
                }
              },
            ),
          ],
        ),
      );
}

Future<String?> _promptForName(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename group'),
      content: GatherField(label: 'Name', controller: controller, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.pop(context, value.isEmpty ? null : value);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Names the session and creates it (FR6 / US4).
class CreateSessionSheet extends ConsumerStatefulWidget {
  const CreateSessionSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const CreateSessionSheet(),
      );

  @override
  ConsumerState<CreateSessionSheet> createState() => _CreateSessionSheetState();
}

class _CreateSessionSheetState extends ConsumerState<CreateSessionSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = ref.read(currentUserOrNullProvider);
    if (user == null) return;

    final result = await ref.read(sessionServiceProvider).createSession(
          host: user,
          name: _name.text.trim().isEmpty ? 'Group order' : _name.text.trim(),
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok(:final value):
        ref.read(activeSessionIdProvider.notifier).state = value.id;
        final router = GoRouter.of(context);
        Navigator.pop(context);
        router.push(Routes.session(value.id));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Insets.gutter,
            Insets.sm,
            Insets.gutter,
            Insets.xl + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start a group order', style: AppType.headline),
              const SizedBox(height: Insets.xs),
              Text(
                'Give it a name so everyone knows which one they are joining.',
                style: AppType.caption,
              ),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Session name',
                controller: _name,
                hint: 'Friday dinner',
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 40,
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: Insets.xl),
              GatherButton(label: 'Create session', onPressed: _create),
            ],
          ),
        ),
      );
}
