import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../cart/cart_line_tile.dart';
import '../restaurant/item_sheet.dart';

/// The shared group cart (FR12) with a "My items" view (FR13).
///
/// Everyone can see the whole order; only the owner of a line can change it,
/// which is what stops the shared cart turning into a free-for-all.
class SessionSharedCartScreen extends ConsumerStatefulWidget {
  const SessionSharedCartScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionSharedCartScreen> createState() => _SessionSharedCartScreenState();
}

class _SessionSharedCartScreenState extends ConsumerState<SessionSharedCartScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    // Created here, not as a `late final` initialiser: a lazily-created
    // controller would be built for the first time inside dispose(), which
    // needs a Ticker from a widget that is already deactivated.
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider(widget.sessionId)).valueOrNull;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final linesAsync = ref.watch(sessionLinesProvider(widget.sessionId));
    final totals = ref.watch(sessionTotalsProvider(widget.sessionId));
    final menu = ref.watch(allMenuItemsProvider).valueOrNull ?? const <MenuItem>[];

    if (session == null || user == null) {
      return const BrandScaffold(title: 'Shared cart', showBack: true, child: LoadingView());
    }

    final lines = linesAsync.valueOrNull ?? const <CartLine>[];
    final myLines = lines.where((l) => l.ownerId == user.uid).toList();
    final editable = session.stage == SessionStage.ordering;

    return BrandScaffold(
      title: 'Shared cart',
      subtitle: session.restaurantName,
      showBack: true,
      padBody: false,
      bandContent: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: Radii.brPill,
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(color: Colors.white, borderRadius: Radii.brPill),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white,
          labelStyle: AppType.label,
          unselectedLabelStyle: AppType.body.copyWith(fontSize: 14),
          tabs: [
            Tab(text: 'Everyone (${lines.length})'),
            Tab(text: 'My items (${myLines.length})'),
          ],
        ),
      ),
      bottomBar: _Footer(session: session, totals: totals, lines: lines),
      child: TabBarView(
        controller: _tabs,
        children: [
          _EveryoneTab(
            session: session,
            lines: lines,
            currentUid: user.uid,
            editable: editable,
            menu: menu,
          ),
          _MyItemsTab(
            session: session,
            lines: myLines,
            editable: editable,
            menu: menu,
          ),
        ],
      ),
    );
  }
}

class _EveryoneTab extends ConsumerWidget {
  const _EveryoneTab({
    required this.session,
    required this.lines,
    required this.currentUid,
    required this.editable,
    required this.menu,
  });

  final GroupSession session;
  final List<CartLine> lines;
  final String currentUid;
  final bool editable;
  final List<MenuItem> menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) {
      return EmptyView(
        icon: Icons.shopping_basket_outlined,
        title: 'The cart is empty',
        message: 'Be the first to add something from ${session.restaurantName}.',
        actionLabel: 'Open the menu',
        onAction: () => context.push(Routes.restaurant(session.restaurantId ?? '')),
      );
    }

    // Group by member so the order reads as "whose food is whose".
    final grouped = <String, List<CartLine>>{};
    for (final line in lines) {
      grouped.putIfAbsent(line.ownerId, () => []).add(line);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
      children: [
        for (final member in session.members)
          if (grouped[member.uid] != null) ...[
            _MemberHeader(
              member: member,
              lines: grouped[member.uid]!,
              isMe: member.uid == currentUid,
            ),
            const SizedBox(height: Insets.md),
            for (final line in grouped[member.uid]!) ...[
              CartLineTile(
                line: line,
                readOnly: !(editable && line.ownerId == currentUid),
                onQuantityChanged: editable && line.ownerId == currentUid
                    ? (q) => ref.read(sessionServiceProvider).setLineQuantity(
                          sessionId: session.id,
                          lineId: line.id,
                          quantity: q,
                        )
                    : null,
                onRemove: editable && line.ownerId == currentUid
                    ? () => ref
                        .read(sessionServiceProvider)
                        .removeLine(sessionId: session.id, lineId: line.id)
                    : null,
                onTap: editable && line.ownerId == currentUid
                    ? () {
                        final item = menu.where((i) => i.id == line.itemId).firstOrNull;
                        if (item != null) {
                          ItemSheet.edit(context, item, line, sessionId: session.id);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: Insets.sm),
            ],
            const SizedBox(height: Insets.lg),
          ],
      ],
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.member, required this.lines, required this.isMe});

  final SessionMember member;
  final List<CartLine> lines;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<double>(0, (acc, l) => acc + l.lineTotal);

    return Row(
      children: [
        MemberAvatar.of(member, size: 30),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            isMe ? '${member.name} (you)' : member.name,
            style: AppType.bodyStrong.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(Money.format(total), style: AppType.money.copyWith(fontSize: 14)),
      ],
    );
  }
}

class _MyItemsTab extends ConsumerWidget {
  const _MyItemsTab({
    required this.session,
    required this.lines,
    required this.editable,
    required this.menu,
  });

  final GroupSession session;
  final List<CartLine> lines;
  final bool editable;
  final List<MenuItem> menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) {
      return EmptyView(
        icon: Icons.person_outline_rounded,
        title: 'You have not added anything',
        message: 'Pick what you want — the rest of the group can see it, '
            'but only you can change it.',
        actionLabel: 'Open the menu',
        onAction: () => context.push(Routes.restaurant(session.restaurantId ?? '')),
      );
    }

    final total = lines.fold<double>(0, (acc, l) => acc + l.lineTotal);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.gutter, Insets.xl, Insets.gutter, Insets.xxl),
      children: [
        for (final line in lines) ...[
          CartLineTile(
            line: line,
            readOnly: !editable,
            onQuantityChanged: editable
                ? (q) => ref.read(sessionServiceProvider).setLineQuantity(
                      sessionId: session.id,
                      lineId: line.id,
                      quantity: q,
                    )
                : null,
            onRemove: editable
                ? () => ref
                    .read(sessionServiceProvider)
                    .removeLine(sessionId: session.id, lineId: line.id)
                : null,
            onTap: editable
                ? () {
                    final item = menu.where((i) => i.id == line.itemId).firstOrNull;
                    if (item != null) {
                      ItemSheet.edit(context, item, line, sessionId: session.id);
                    }
                  }
                : null,
          ),
          const SizedBox(height: Insets.sm),
        ],
        const SizedBox(height: Insets.lg),
        GatherCard(
          child: Row(
            children: [
              Expanded(child: Text('Your items', style: AppType.bodyStrong)),
              Text(
                Money.format(total),
                style: AppType.money.copyWith(fontSize: 18, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        Text(
          'What you actually pay depends on the option the host picks: your own '
          'items, an equal split, or nothing at all if the host covers it.',
          style: AppType.caption.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.session, required this.totals, required this.lines});

  final GroupSession session;
  final CartTotals totals;
  final List<CartLine> lines;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.background,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(Insets.gutter, Insets.sm, Insets.gutter, Insets.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GatherCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: Insets.lg, vertical: Insets.md),
                child: TotalsPanel(totals: totals, dense: true),
              ),
              const SizedBox(height: Insets.md),
              GatherButton(
                label: session.stage == SessionStage.ordering
                    ? 'Add more items'
                    : 'Back to session',
                icon: session.stage == SessionStage.ordering ? Icons.add_rounded : null,
                onPressed: () {
                  if (session.stage == SessionStage.ordering) {
                    context.push(Routes.restaurant(session.restaurantId ?? ''));
                  } else {
                    context.pop();
                  }
                },
              ),
            ],
          ),
        ),
      );
}
