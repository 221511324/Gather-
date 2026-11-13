import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';

/// Join a session by code or invite link (FR8 / US6).
class JoinSessionScreen extends ConsumerStatefulWidget {
  const JoinSessionScreen({super.key, this.code});

  /// Pre-filled when the user arrived from a shared link.
  final String? code;

  @override
  ConsumerState<JoinSessionScreen> createState() => _JoinSessionScreenState();
}

class _JoinSessionScreenState extends ConsumerState<JoinSessionScreen> {
  String? _error;
  bool _joining = false;
  bool _autoJoinAttempted = false;

  /// Auto-joins from an invite link, but only once the profile has loaded —
  /// opening the link on a cold start gets here before the user stream has
  /// produced anything.
  void _maybeAutoJoin() {
    if (_autoJoinAttempted) return;
    final code = widget.code;
    if (code == null || code.length != 4) return;
    if (ref.read(currentUserOrNullProvider) == null) return;
    _autoJoinAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _join(code));
  }

  Future<void> _join(String code) async {
    final user = ref.read(currentUserOrNullProvider);
    if (user == null || _joining) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    final result = await ref.read(sessionServiceProvider).joinByCode(code: code, user: user);

    if (!mounted) return;
    setState(() => _joining = false);

    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok(:final value):
        ref.read(activeSessionIdProvider.notifier).state = value.id;
        // Let the group know someone arrived.
        if (mounted) context.pushReplacement(Routes.session(value.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched rather than read, so a late-arriving profile still triggers the
    // auto-join from an invite link.
    ref.watch(currentUserProvider);
    _maybeAutoJoin();

    final invites = ref.watch(myInvitesProvider).valueOrNull ?? const [];

    return BrandScaffold(
      title: 'Join a session',
      showBack: true,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Enter the 4-digit code'), style: AppType.title.copyWith(fontSize: 21)),
          const SizedBox(height: Insets.sm),
          Text(
            context.tr('The host can find it at the top of their session.'),
            style: AppType.body.copyWith(color: AppColors.inkMuted, fontSize: 14.5),
          ),
          const SizedBox(height: Insets.xxxl),
          if (_joining)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.xxl),
              child: LoadingView(message: 'Joining the session…'),
            )
          else
            CodeInput(onCompleted: _join),
          if (_error != null) ...[
            const SizedBox(height: Insets.xl),
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: Radii.brMd),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 19, color: AppColors.danger),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      context.tr(_error!),
                      style: AppType.body.copyWith(color: AppColors.danger, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (invites.isNotEmpty) ...[
            const SizedBox(height: Insets.xxxl),
            const SectionHeader(title: 'Or accept an invitation'),
            for (final session in invites)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: ListTile(
                  onTap: () => _join(session.code),
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: Radii.brMd),
                  leading: MemberAvatarStack(members: session.members, size: 30, max: 2),
                  title: Text(context.isolate(session.name), style: AppType.bodyStrong),
                  subtitle: Text(context.tr('From {name}', {'name': context.isolate(session.hostName)}), style: AppType.caption),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
