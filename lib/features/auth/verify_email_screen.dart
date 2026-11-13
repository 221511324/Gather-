import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/state_views.dart';
import 'auth_shell.dart';

/// The one screen a new account can reach until its email is verified (FR1).
///
/// Clearing the flag on the profile moves the router on, so this screen never
/// navigates by itself. It also checks by itself every few seconds, so someone
/// who opened the link and came back does not have to press anything.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _checkEvery = Duration(seconds: 5);
  static const _resendAfter = 60;

  Timer? _check;
  Timer? _tick;
  // Signing up has just sent the first email.
  int _wait = _resendAfter;

  @override
  void initState() {
    super.initState();
    _check = Timer.periodic(_checkEvery, (_) => _confirm(quiet: true));
    _countDown();
  }

  @override
  void dispose() {
    _check?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _countDown() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _confirm({bool quiet = false}) async {
    final result = await ref.read(authServiceProvider).confirmEmailVerified();
    if (!mounted || quiet) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok(:final value):
        if (!value) {
          AppSnack.error(
              context, 'Not verified yet. Open the link in the email, then try again.');
        }
    }
  }

  Future<void> _resend() async {
    final language = Localizations.localeOf(context).languageCode;
    final result = await ref
        .read(authServiceProvider)
        .sendVerificationEmail(languageCode: language);
    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        AppSnack.show(context, 'Email sent. Check your inbox.');
        setState(() => _wait = _resendAfter);
        _countDown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserOrNullProvider)?.email ??
        ref.read(authServiceProvider).currentUser?.email ??
        '';
    return AuthShell(
      greeting: 'One last step',
      title: 'Check your email',
      child: Column(
        key: const ValueKey('verify-email'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: Insets.lg),
          Text(
            context.tr(
              'We sent a verification link to {email}. Open it to finish creating your account.',
              {'email': context.isolate(email)},
            ),
            style: AppType.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            context.tr("Can't find it? Check your spam folder."),
            style: AppType.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Insets.xxl),
          GatherButton(label: "I've verified", onPressed: () => _confirm()),
          const SizedBox(height: Insets.md),
          GatherOutlineButton(
            label: _wait > 0
                ? context.tr('Resend in {seconds}s', {'seconds': _wait})
                : 'Resend email',
            onPressed: _wait > 0 ? null : _resend,
          ),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: Text(context.tr('Use a different account')),
          ),
        ],
      ),
    );
  }
}
