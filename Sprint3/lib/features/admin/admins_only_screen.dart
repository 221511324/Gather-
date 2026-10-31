import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/directional_icons.dart';
import '../../core/widgets/gather_button.dart';

/// Shown on the web build when the signed-in account is not an administrator.
///
/// The website exists for administration; ordinary customers use the mobile
/// application. The Firestore rules refuse their reads regardless, so this
/// screen explains the situation rather than leaving them on empty tables.
class AdminsOnlyScreen extends ConsumerWidget {
  const AdminsOnlyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    gradient: AppColors.bandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 38, color: Colors.white),
                ),
                const SizedBox(height: Insets.xl),
                Text(context.tr('Administrators only'),
                    style: AppType.headline.copyWith(fontSize: 22)),
                const SizedBox(height: Insets.sm),
                Text(
                  user == null
                      ? context.tr('This site is for managing Gather. Sign in with an '
                          'administrator account to continue.')
                      : context.tr(
                          'The account {email} does not have administrator '
                          'access. Gather for customers is the mobile app.',
                          {'email': user.email}),
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: Insets.xxl),
                GatherButton(
                  label: 'Sign out',
                  icon: DirectionalIcons.logout,
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
