import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';

/// All four invitation methods in one place (FR7 / US5): the 4-digit code, a
/// shareable link, a username, or a phone number.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.session});

  final GroupSession session;

  static Future<void> show(BuildContext context, GroupSession session) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => InviteSheet(session: session),
      );

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _lookup = TextEditingController();
  bool _searching = false;
  String? _error;
  AppUser? _found;

  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _lookup.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });

    final result = await ref.read(authServiceProvider).findInvitee(query);
    if (!mounted) return;
    setState(() => _searching = false);

    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok(:final value):
        if (widget.session.hasMember(value.uid)) {
          setState(() => _error = '${value.fullName} is already in this session');
          return;
        }
        setState(() => _found = value);
    }
  }

  Future<void> _invite(AppUser invitee) async {
    final host = ref.read(currentUserOrNullProvider);
    if (host == null) return;

    final result = await ref
        .read(sessionServiceProvider)
        .inviteUser(sessionId: widget.session.id, inviteeUid: invitee.uid);

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        if (mounted) {
          setState(() {
            _found = null;
            _lookup.clear();
          });
          AppSnack.show(context, 'Invitation sent to ${invitee.username}');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = Routes.inviteLink(widget.session.code);

    return SafeArea(
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
            Text('Invite people', style: AppType.headline),
            const SizedBox(height: Insets.xs),
            Text('Four ways to get everyone into this session.', style: AppType.caption),
            const SizedBox(height: Insets.xl),

            // 1 — the code.
            Text('SESSION CODE', style: AppType.overline),
            const SizedBox(height: Insets.sm),
            _CodeDisplay(code: widget.session.code),
            const SizedBox(height: Insets.xl),

            // 2 — the link.
            Row(
              children: [
                Expanded(
                  child: GatherOutlineButton(
                    label: 'Copy link',
                    icon: Icons.link_rounded,
                    compact: true,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) AppSnack.show(context, 'Invite link copied');
                    },
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GatherButton(
                    label: 'Share',
                    icon: Icons.ios_share_rounded,
                    compact: true,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text: 'Join my Gather order "${widget.session.name}"\n'
                            'Code: ${widget.session.code}\n$link',
                        subject: 'Join my Gather order',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xxl),
            const Divider(),
            const SizedBox(height: Insets.lg),

            // 3 and 4 — username or phone number.
            Text('ADD BY USERNAME OR PHONE', style: AppType.overline),
            const SizedBox(height: Insets.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _lookup,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'username or +9665…',
                      prefixIcon: Icon(Icons.person_search_outlined, size: 20),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: Insets.md),
                GatherButton(
                  label: 'Find',
                  compact: true,
                  expand: false,
                  busy: _searching,
                  onPressed: _search,
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.sm),
              Text(_error!, style: AppType.caption.copyWith(color: AppColors.danger)),
            ],
            if (_found != null) ...[
              const SizedBox(height: Insets.md),
              GatherCard(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: [
                    MemberAvatar(
                      uid: _found!.uid,
                      initials: _found!.initials,
                      photoUrl: _found!.photoUrl,
                      size: 40,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_found!.fullName, style: AppType.bodyStrong),
                          Text('@${_found!.username}', style: AppType.caption),
                        ],
                      ),
                    ),
                    GatherButton(
                      label: 'Invite',
                      compact: true,
                      expand: false,
                      onPressed: () => _invite(_found!),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Insets.lg),
          ],
        ),
      ),
    );
  }
}

class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (context.mounted) AppSnack.show(context, 'Code copied');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Insets.lg),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: Radii.brLg,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final digit in code.split(''))
                    Container(
                      width: 46,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: Insets.xs + 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: Radii.brMd,
                      ),
                      child: Text(
                        digit,
                        style: AppType.title.copyWith(fontSize: 26, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              Text('Tap to copy', style: AppType.caption.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
      );
}
