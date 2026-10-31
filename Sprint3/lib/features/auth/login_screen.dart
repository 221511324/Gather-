import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import 'auth_shell.dart';

/// Sign in (FR1 / US1-AC2, US1-AC3).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(authServiceProvider).signIn(
          email: _email.text,
          password: _password.text,
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        // The router's redirect takes over once auth state updates.
        AppSnack.show(context, 'Welcome back!');
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
        greeting: 'Hello!',
        title: 'Welcome back',
        showBack: false,
        showLogo: true,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GatherField(
                label: 'Email',
                controller: _email,
                hint: 'you@example.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validate.email,
              ),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Password',
                controller: _password,
                hint: 'Your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: Text(
                    context.tr('Forgot password?'),
                    style: AppType.label.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.sm),
                _ErrorBanner(message: _error!),
              ],
              const SizedBox(height: Insets.xl),
              GatherButton(label: 'Log in', onPressed: _submit),
              const SizedBox(height: Insets.xxl),
              // The website is for administrators, who are given an account
              // rather than signing themselves up.
              if (!kIsWeb)
                Center(
                  child: TextButton(
                    onPressed: () => context.push(Routes.register),
                    child: Text.rich(
                      TextSpan(
                        text: context.tr("Don't have an account? "),
                        style: AppType.body.copyWith(color: AppColors.inkMuted),
                        children: [
                          TextSpan(
                            text: context.tr('Sign up'),
                            style: AppType.label.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Insets.sm),
              Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.onboarding),
                  child: Text(
                    context.tr('What is Gather?'),
                    style: AppType.body.copyWith(color: AppColors.inkMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: Radii.brMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, size: 19, color: AppColors.danger),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                // Service errors arrive in English.
                context.tr(message),
                style: AppType.body.copyWith(color: AppColors.danger, fontSize: 13.5),
              ),
            ),
          ],
        ),
      );
}

/// Reusable inline error, exported for the other auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _ErrorBanner(message: message);
}
