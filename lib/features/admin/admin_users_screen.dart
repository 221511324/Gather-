import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/ar/qa1.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import 'admin_shell.dart';

/// User account management (FR30, US17-AC5).
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';
  bool _suspendedOnly = false;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider);

    return AdminShell(
      title: 'User accounts',
      bandContent: GatherSearchField(
        hint: 'Search name, username or email',
        onChanged: (v) => setState(() => _query = v),
      ),
      child: usersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (users) {
          final q = _query.trim().toLowerCase();
          final filtered = users.where((u) {
            if (_suspendedOnly && !u.isSuspended) return false;
            if (q.isEmpty) return true;
            return u.fullName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.phone.contains(q);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.lg, Insets.gutter, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('{shown} of {total} accounts|${countNote(users.length)}',
                            {'shown': filtered.length, 'total': users.length}),
                        style: AppType.caption,
                      ),
                    ),
                    FilterChip(
                      label: Text(context.tr('Suspended only')),
                      selected: _suspendedOnly,
                      onSelected: (v) => setState(() => _suspendedOnly = v),
                      labelStyle: AppType.label.copyWith(
                        fontSize: 12.5,
                        color: _suspendedOnly ? Colors.white : AppColors.ink,
                      ),
                      selectedColor: AppColors.danger,
                      showCheckmark: false,
                      backgroundColor: AppColors.surface,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyView(
                        icon: Icons.person_search_outlined,
                        title: 'No accounts match',
                        message: 'Try a different search.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            Insets.gutter, Insets.lg, Insets.gutter, Insets.xxl),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: Insets.md),
                        itemBuilder: (context, i) => _UserCard(user: filtered[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUidProvider);
    final isSelf = me == user.uid;

    return GatherCard(
      child: Row(
        children: [
          MemberAvatar(
            uid: user.uid,
            initials: user.initials,
            photoUrl: user.photoUrl,
            size: 44,
          ),
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
                        user.fullName.isEmpty ? user.username : user.fullName,
                        style: AppType.bodyStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isAdmin) ...[
                      const SizedBox(width: Insets.sm),
                      const StatusPill(
                        label: 'Admin',
                        color: AppColors.accentDeep,
                        background: AppColors.accentSoft,
                        compact: true,
                      ),
                    ],
                    if (user.isSuspended) ...[
                      const SizedBox(width: Insets.sm),
                      const StatusPill(
                        label: 'Suspended',
                        color: AppColors.danger,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(context.isolate('@${user.username} · ${user.email}'),
                    style: AppType.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (user.phone.isNotEmpty)
                  Text(context.isolate(user.phone),
                      style: AppType.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.inkFaint),
            tooltip: context.tr('Account actions'),
            enabled: !isSelf,
            onSelected: (value) => _handle(context, ref, value),
            itemBuilder: (context) => [
              if (user.isSuspended)
                PopupMenuItem(value: 'restore', child: Text(context.tr('Restore account')))
              else
                PopupMenuItem(
                  value: 'suspend',
                  child: Text(context.tr('Suspend account'),
                      style: const TextStyle(color: AppColors.danger)),
                ),
              if (user.isAdmin)
                PopupMenuItem(value: 'demote', child: Text(context.tr('Remove admin role')))
              else
                PopupMenuItem(value: 'promote', child: Text(context.tr('Make admin'))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref, String value) async {
    final admin = ref.read(adminServiceProvider);

    switch (value) {
      case 'suspend':
      case 'restore':
        final suspend = value == 'suspend';
        if (suspend) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.tr('Suspend {name}?', {'name': user.fullName})),
              content: Text(context.tr(
                'They will be signed out and blocked from signing in again until '
                'the account is restored.',
              )),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.tr('Suspend')),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        }
        final result = await admin.setAccountStatus(
          uid: user.uid,
          status: suspend ? AccountStatus.suspended : AccountStatus.active,
        );
        if (!context.mounted) return;
        switch (result) {
          case Err(:final message):
            AppSnack.error(context, message);
          case Ok():
            AppSnack.show(context, suspend ? 'Account suspended' : 'Account restored');
        }

      case 'promote':
      case 'demote':
        final result = await admin.setRole(
          uid: user.uid,
          role: value == 'promote' ? UserRole.admin : UserRole.customer,
        );
        if (!context.mounted) return;
        switch (result) {
          case Err(:final message):
            AppSnack.error(context, message);
          case Ok():
            AppSnack.show(
              context,
              value == 'promote' ? 'Admin role granted' : 'Admin role removed',
            );
        }

    }
  }
}
