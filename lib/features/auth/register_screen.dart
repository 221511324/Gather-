import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/result.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/state_views.dart';
import 'auth_shell.dart';
import 'login_screen.dart';

/// Create an account (FR1 / US1-AC1).
///
/// The username field checks availability as the user types, because the
/// handle is what other people use to invite them (FR7) and a clash after
/// submitting would be a frustrating way to find out.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _error;
  Timer? _usernameDebounce;
  _HandleState _handle = _HandleState.idle;

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    final handle = value.trim();
    if (AuthService.validateUsername(handle) != null) {
      setState(() => _handle = _HandleState.idle);
      return;
    }
    setState(() => _handle = _HandleState.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () async {
      final free = await ref.read(authServiceProvider).isUsernameAvailable(handle);
      if (!mounted || _username.text.trim() != handle) return;
      setState(() => _handle = free ? _HandleState.available : _HandleState.taken);
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_handle == _HandleState.taken) {
      setState(() => _error = 'That username is already taken');
      return;
    }

    final result = await ref.read(authServiceProvider).signUp(
          fullName: _name.text,
          username: _username.text,
          email: _email.text,
          phone: _phone.text.replaceAll(RegExp(r'[\s-]'), ''),
          password: _password.text,
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        AppSnack.show(context, 'Welcome to Gather!');
    }
  }

  @override
  Widget build(BuildContext context) => AuthShell(
        greeting: 'Welcome!',
        title: 'Create your account',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GatherField(
                label: 'Full name',
                controller: _name,
                hint: 'Rama Alrashodi',
                prefixIcon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => Validate.required(v, 'full name'),
              ),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Username',
                controller: _username,
                hint: 'rama',
                helper: 'Friends can add you to a session with this',
                prefixIcon: Icons.alternate_email_rounded,
                textInputAction: TextInputAction.next,
                maxLength: 20,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                ],
                onChanged: _onUsernameChanged,
                validator: (v) => AuthService.validateUsername(v ?? ''),
                suffix: _handleIndicator(),
              ),
              const SizedBox(height: Insets.xl),
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
                label: 'Phone number',
                controller: _phone,
                hint: '+966 5X XXX XXXX',
                helper: 'Used so friends can add you by number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: Validate.phone,
              ),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Password',
                controller: _password,
                hint: 'At least 6 characters',
                prefixIcon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validate.password,
              ),
              const SizedBox(height: Insets.xl),
              GatherField(
                label: 'Confirm password',
                controller: _confirm,
                hint: 'Repeat your password',
                prefixIcon: Icons.lock_reset_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: Insets.lg),
                AuthErrorBanner(message: _error!),
              ],
              const SizedBox(height: Insets.xxl),
              GatherButton(label: 'Create account', onPressed: _submit),
              const SizedBox(height: Insets.lg),
              Center(
                child: TextButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go(Routes.login),
                  child: Text.rich(
                    TextSpan(
                      text: context.tr('Already have an account? '),
                      style: AppType.body.copyWith(color: AppColors.inkMuted),
                      children: [
                        TextSpan(
                          text: context.tr('Log in'),
                          style: AppType.label.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget? _handleIndicator() => switch (_handle) {
        _HandleState.idle => null,
        _HandleState.checking => const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        _HandleState.available =>
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 21),
        _HandleState.taken =>
          const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 21),
      };
}

enum _HandleState { idle, checking, available, taken }
