import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/state_views.dart';

/// US16 — everything that has happened, newest first.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static IconData iconFor(NotificationKind kind) => switch (kind) {
        NotificationKind.groupInvite => Icons.group_add_outlined,
        NotificationKind.session => Icons.groups_outlined,
        NotificationKind.payment => Icons.payments_outlined,
        NotificationKind.order => Icons.receipt_long_outlined,
        NotificationKind.delivery => Icons.delivery_dining_outlined,
        NotificationKind.promotion => Icons.local_offer_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final notifications = ref.watch(notificationsProvider);
    final service = ref.read(notificationServiceProvider);
    final unread = ref.watch(unreadNotificationsProvider);

    return BrandScaffold(
      title: 'Notifications',
      showBack: true,
      actions: [
        if (unread > 0)
          BandIconButton(
            icon: Icons.done_all_rounded,
            tooltip: 'Mark all as read',
            onTap: () {
              if (uid != null) service.markAllRead(uid);
            },
          ),
      ],
      child: notifications.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyView(
              icon: Icons.notifications_none_rounded,
              title: 'Nothing yet',
              message: 'Invitations, order updates and offers will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(Insets.gutter),
            itemCount: all.length,
            itemBuilder: (context, i) {
              final n = all[i];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: AlignmentDirectional.centerEnd,
                  padding: const EdgeInsetsDirectional.only(end: Insets.lg),
                  margin: const EdgeInsets.only(bottom: Insets.sm),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                ),
                onDismissed: (_) {
                  if (uid != null) service.remove(uid, n.id);
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: _Tile(notification: n),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final uid = ref.watch(currentUidProvider);

    return GatherCard(
      // An unread one is tinted rather than badged: the whole row reads as
      // new at a glance, without a dot to hunt for.
      color: n.read ? null : AppColors.primaryTint,
      onTap: () {
        if (uid != null && !n.read) {
          ref.read(notificationServiceProvider).markRead(uid, n.id);
        }
        if (n.orderId != null) {
          context.push(Routes.order(n.orderId!));
        } else if (n.sessionId != null) {
          context.push(Routes.session(n.sessionId!));
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(NotificationsScreen.iconFor(n.kind),
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _say(context, n.title),
                        style: n.read ? AppType.body : AppType.bodyStrong,
                      ),
                    ),
                    if (n.createdAt != null)
                      Text(_ago(context, n.createdAt!), style: AppType.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_say(context, n.body), style: AppType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Notifications are stored as finished English. Most match a template
  /// ("Rama invited you"); an order update is titled "Kudu — Preparing",
  /// which has no fixed words to match, so its status is translated on its
  /// own and the restaurant name kept.
  static String _say(BuildContext context, String english) {
    final whole = context.tr(english);
    if (whole != english) return whole;
    final split = english.lastIndexOf(' — ');
    final status = split < 0 ? '' : english.substring(split + 3);
    final said = split < 0 ? status : context.tr(status);
    // Nothing to translate: it is data (a name, a dish), kept in its own order.
    if (split < 0 || said == status) return context.isolate(english);
    return '${context.isolate(english.substring(0, split))} — $said';
  }

  static String _ago(BuildContext context, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return context.tr('now');
    if (d.inMinutes < 60) return context.tr('{n}m', {'n': d.inMinutes});
    if (d.inHours < 24) return context.tr('{n}h', {'n': d.inHours});
    if (d.inDays < 7) return context.tr('{n}d', {'n': d.inDays});
    return Dates.dayMonth(context, at);
  }
}
