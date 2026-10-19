import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/providers/providers.dart';
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
                Text('Administrators only',
                    style: AppType.headline.copyWith(fontSize: 22)),
                const SizedBox(height: Insets.sm),
                Text(
                  user == null
                      ? 'This site is for managing Gather. Sign in with an '
                          'administrator account to continue.'
                      : 'The account ${user.email} does not have administrator '
                          'access. Gather for customers is the mobile app.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: Insets.xxl),
                GatherButton(
                  label: 'Sign out',
                  icon: Icons.logout_rounded,
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
