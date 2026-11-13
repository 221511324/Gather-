import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import 'admin_shell.dart';

/// Support ticket triage (US17-AC3, AC4).
class AdminTicketsScreen extends ConsumerStatefulWidget {
  const AdminTicketsScreen({super.key});

  @override
  ConsumerState<AdminTicketsScreen> createState() => _AdminTicketsScreenState();
}

class _AdminTicketsScreenState extends ConsumerState<AdminTicketsScreen> {
  TicketStatus? _filter = TicketStatus.open;

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(adminTicketsProvider);

    return AdminShell(
      title: 'Support tickets',
      child: ticketsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (tickets) {
          final filtered =
              _filter == null ? tickets : tickets.where((t) => t.status == _filter).toList();

          return Column(
            children: [
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.fromLTRB(Insets.gutter, Insets.md, Insets.gutter, 0),
                  children: [
                    _Chip(
                      label: context.tr('All ({count})', {'count': tickets.length}),
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final status in TicketStatus.values)
                      _Chip(
                        label: '${context.tr(status.label)} '
                            '(${tickets.where((t) => t.status == status).length})',
                        selected: _filter == status,
                        onTap: () =>
                            setState(() => _filter = _filter == status ? null : status),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyView(
                        icon: Icons.support_agent_outlined,
                        title: 'Nothing to triage',
                        message: 'No tickets match this filter.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.gutter, Insets.md, Insets.gutter, Insets.xxl),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
                        itemBuilder: (context, i) => _TicketRow(ticket: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: Insets.sm),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          backgroundColor: AppColors.surface,
          labelStyle: AppType.label.copyWith(
            fontSize: 12.5,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      );
}

class _TicketRow extends ConsumerWidget {
  const _TicketRow({required this.ticket});

  final SupportTicket ticket;

  static Color colorFor(TicketStatus status) => switch (status) {
        TicketStatus.open => AppColors.info,
        TicketStatus.inProgress => AppColors.accentDeep,
        TicketStatus.resolved => AppColors.success,
        TicketStatus.closed => AppColors.inkFaint,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) => GatherCard(
        onTap: () => _respond(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MemberAvatar(
                  uid: ticket.userId,
                  initials: _initials(ticket.userName),
                  size: 34,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ticket.subject,
                        style: AppType.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${ticket.userName} · ${context.tr(ticket.category.label)}',
                        style: AppType.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  label: context.tr(ticket.status.label),
                  color: colorFor(ticket.status),
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text(
              ticket.message,
              style: AppType.body.copyWith(fontSize: 13.5, height: 1.45),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (ticket.adminReply != null) ...[
              const SizedBox(height: Insets.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.md),
                decoration:
                    BoxDecoration(color: AppColors.primarySoft, borderRadius: Radii.brMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('YOUR REPLY'),
                        style: AppType.overline.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 3),
                    Text(
                      ticket.adminReply!,
                      style: AppType.body
                          .copyWith(fontSize: 13, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  Future<void> _respond(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<(String, TicketStatus)>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _ReplySheet(ticket: ticket),
    );
    if (result == null) return;

    final saved = await ref.read(supportServiceProvider).respond(
          ticketId: ticket.id,
          reply: result.$1,
          status: result.$2,
        );

    if (!context.mounted) return;
    switch (saved) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        if (context.mounted) AppSnack.show(context, 'Reply sent');
    }
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.ticket});

  final SupportTicket ticket;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final _reply = TextEditingController(text: widget.ticket.adminReply ?? '');
  late TicketStatus _status =
      widget.ticket.status == TicketStatus.open ? TicketStatus.inProgress : widget.ticket.status;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
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
              Text(context.tr('Respond to ticket'), style: AppType.headline),
              const SizedBox(height: Insets.xs),
              Text(widget.ticket.subject, style: AppType.caption),
              const SizedBox(height: Insets.xl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.md),
                decoration:
                    BoxDecoration(color: AppColors.background, borderRadius: Radii.brMd),
                child: Text(
                  widget.ticket.message,
                  style: AppType.body.copyWith(fontSize: 13.5, height: 1.45),
                ),
              ),
              const SizedBox(height: Insets.xl),
              Text(context.tr('Status'), style: AppType.label.copyWith(fontSize: 15)),
              const SizedBox(height: Insets.sm),
              Wrap(
                spacing: Insets.sm,
                children: [
                  for (final status in TicketStatus.values)
                    ChoiceChip(
                      label: Text(context.tr(status.label)),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                      showCheckmark: false,
                      labelStyle: AppType.label.copyWith(
                        fontSize: 12.5,
                        color: _status == status ? Colors.white : AppColors.ink,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              Text(context.tr('Reply'), style: AppType.label.copyWith(fontSize: 15)),
              const SizedBox(height: Insets.sm),
              TextField(
                controller: _reply,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: context.tr('What did you do about it?'),
                  counterText: '',
                ),
              ),
              const SizedBox(height: Insets.lg),
              GatherButton(
                label: 'Send reply',
                icon: Icons.send_rounded,
                onPressed: () {
                  if (_reply.text.trim().isEmpty) {
                    AppSnack.error(context, 'Write a reply first');
                    return;
                  }
                  Navigator.pop(context, (_reply.text.trim(), _status));
                },
              ),
            ],
          ),
        ),
      );
}
