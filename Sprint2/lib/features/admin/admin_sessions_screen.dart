import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import 'admin_shell.dart';

/// Live and past group sessions (US17-AC2).
class AdminSessionsScreen extends ConsumerWidget {
  const AdminSessionsScreen({super.key});

  static Color colorFor(SessionStage stage) => switch (stage) {
        SessionStage.placed => AppColors.success,
        SessionStage.cancelled => AppColors.danger,
        SessionStage.payment => AppColors.accentDeep,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(adminSessionsProvider);

    return AdminShell(
      title: 'Group sessions',
      child: sessionsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyView(
              icon: Icons.groups_outlined,
              title: 'No sessions yet',
              message: 'Group sessions created by users will show up here.',
            );
          }

          final live = sessions.where((s) => s.stage.isLive).toList();
          final done = sessions.where((s) => !s.stage.isLive).toList();

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
            children: [
              if (live.isNotEmpty) ...[
                SectionHeader(title: 'Live now (${live.length})'),
                for (final s in live) ...[
                  _SessionRow(session: s),
                  const SizedBox(height: Insets.md),
                ],
                const SizedBox(height: Insets.lg),
              ],
              if (done.isNotEmpty) ...[
                SectionHeader(title: 'Finished (${done.length})'),
                for (final s in done.take(40)) ...[
                  _SessionRow(session: s, muted: true),
                  const SizedBox(height: Insets.md),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session, this.muted = false});

  final GroupSession session;
  final bool muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(sessionLinesProvider(session.id)).valueOrNull ?? const [];

    return GatherCard(
      onTap: session.orderId == null
          ? null
          : () => context.push(Routes.order(session.orderId!)),
      child: Column(
        children: [
          Row(
            children: [
              MemberAvatarStack(members: session.members, size: 30),
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
                    Text(
                      'Host: ${session.hostName} · code ${session.code}',
                      style: AppType.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: session.stage.label,
                color: muted ? AppColors.inkFaint : AdminSessionsScreen.colorFor(session.stage),
                compact: true,
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.md),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              _Fact(icon: Icons.people_alt_rounded, label: '${session.memberCount}'),
              const SizedBox(width: Insets.lg),
              _Fact(icon: Icons.shopping_basket_rounded, label: '${lines.length}'),
              const SizedBox(width: Insets.lg),
              _Fact(
                icon: Icons.storefront_rounded,
                label: session.restaurantName ?? 'Not chosen',
              ),
              const Spacer(),
              if (session.decidedBySpin)
                const Icon(Icons.casino_rounded, size: 16, color: AppColors.accentDeep),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.inkMuted),
          const SizedBox(width: 4),
          Text(label, style: AppType.caption.copyWith(fontSize: 12)),
        ],
      );
}
