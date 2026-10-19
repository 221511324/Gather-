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
import '../../core/widgets/state_views.dart';
import '../profile/profile_screen.dart';

/// Help hub (FR28 help options).
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(myTicketsProvider).valueOrNull ?? const <SupportTicket>[];

    return BrandScaffold(
      title: 'Help & support',
      showBack: true,
      padBody: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxxl),
        children: [
          const SectionHeader(title: 'Get help'),
          SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.quiz_outlined,
                label: 'Frequently asked questions',
                onTap: () => context.push(Routes.faq),
              ),
              SettingsRow(
                icon: Icons.mail_outline_rounded,
                label: 'Report an issue',
                onTap: () => context.push(Routes.contact),
              ),
            ],
          ),
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: Insets.xxl),
            SectionHeader(title: 'Your requests (${tickets.length})'),
            for (final ticket in tickets) ...[
              _TicketCard(ticket: ticket),
              const SizedBox(height: Insets.md),
            ],
          ],
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  static Color colorFor(TicketStatus status) => switch (status) {
        TicketStatus.open => AppColors.info,
        TicketStatus.inProgress => AppColors.accentDeep,
        TicketStatus.resolved => AppColors.success,
        TicketStatus.closed => AppColors.inkFaint,
      };

  @override
  Widget build(BuildContext context) => GatherCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.subject,
                    style: AppType.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusPill(
                  label: ticket.status.label,
                  color: colorFor(ticket.status),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Text(
              ticket.message,
              style: AppType.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (ticket.adminReply != null) ...[
              const SizedBox(height: Insets.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: Radii.brMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GATHER SUPPORT', style: AppType.overline.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 3),
                    Text(
                      ticket.adminReply!,
                      style: AppType.body.copyWith(fontSize: 13.5, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}
