import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../splash/splash_screen.dart';

/// Shared chrome for the sign-in, sign-up and reset screens: a greeting on the
/// brand band, the form on a rounded sheet below it.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.greeting,
    required this.title,
    required this.child,
    this.showBack = true,
    this.showLogo = false,
  });

  /// The large line inside the band, e.g. "Hello!".
  final String greeting;

  /// The heading at the top of the form sheet.
  final String title;
  final Widget child;
  final bool showBack;

  /// Puts the Gather mark above the greeting. Used on the entry screen, where
  /// there is room for it.
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.band,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppColors.bandGradient),
              padding: EdgeInsets.fromLTRB(
                Insets.gutter,
                media.padding.top + Insets.sm,
                Insets.gutter,
                Insets.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: showBack
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 19),
                              tooltip: 'Back',
                            ),
                          )
                        : null,
                  ),
                  if (showLogo) ...[
                    const GatherLogo(size: 74, markOnly: true),
                    const SizedBox(height: Insets.lg),
                  ] else
                    const SizedBox(height: Insets.sm),
                  Text(
                    greeting,
                    style: AppType.display.copyWith(color: Colors.white, fontSize: 32),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: Radii.sheetTop,
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    Insets.gutter,
                    Insets.xxxl,
                    Insets.gutter,
                    Insets.xxl + media.viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.title),
                      const SizedBox(height: Insets.xxl),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field validators shared by the auth forms.
abstract final class Validate {
  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email address';
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v)) {
      return 'That email address does not look right';
    }
    return null;
  }

  static String? required(String? value, String label) =>
      (value ?? '').trim().isEmpty ? 'Enter your $label' : null;

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Choose a password';
    if (v.length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your phone number';
    final digits = v.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(digits)) {
      return 'That phone number does not look right';
    }
    return null;
  }
}
