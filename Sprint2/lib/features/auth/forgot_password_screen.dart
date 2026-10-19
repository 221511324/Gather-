import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import 'auth_shell.dart';
import 'login_screen.dart';

/// Password reset by email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(authServiceProvider).sendPasswordReset(_email.text);
    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
        greeting: 'No problem',
        title: _sent ? 'Check your inbox' : 'Reset your password',
        child: _sent ? _sentView() : _formView(),
      );

  Widget _sentView() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_outlined, size: 34, color: AppColors.success),
          ),
          const SizedBox(height: Insets.xl),
          Text(
            'We sent a reset link to ${_email.text.trim()}. Open it to choose a new password, '
            'then come back and log in.',
            style: AppType.bodyLarge.copyWith(color: AppColors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: Insets.xxl),
          GatherButton(label: 'Back to log in', onPressed: () => context.pop()),
          const SizedBox(height: Insets.md),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _sent = false),
              child: const Text('Use a different email'),
            ),
          ),
        ],
      );

  Widget _formView() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email on your account and we will send you a link to set a new password.',
              style: AppType.bodyLarge.copyWith(color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: Insets.xxl),
            GatherField(
              label: 'Email',
              controller: _email,
              hint: 'you@example.com',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              validator: Validate.email,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.lg),
              AuthErrorBanner(message: _error!),
            ],
            const SizedBox(height: Insets.xxl),
            GatherButton(label: 'Send reset link', onPressed: _submit),
          ],
        ),
      );
}
