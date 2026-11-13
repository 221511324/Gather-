import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import '../auth/auth_shell.dart';

/// View and update profile details (FR2 / US2).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController? _name;
  TextEditingController? _phone;

  @override
  void dispose() {
    _name?.dispose();
    _phone?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    final result = await ref.read(authServiceProvider).updateProfile(
          uid: uid,
          fullName: _name?.text,
          phone: _phone?.text.replaceAll(RegExp(r'[\s-]'), ''),
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        AppSnack.error(context, message);
      case Ok():
        AppSnack.show(context, 'Profile updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const BrandScaffold(title: 'My profile', showBack: true, child: LoadingView());
    }

    // Seed the controllers once the profile has loaded.
    _name ??= TextEditingController(text: user.fullName);
    _phone ??= TextEditingController(text: user.phone);

    return BrandScaffold(
      title: 'My profile',
      showBack: true,
      scrollable: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: MemberAvatar(
                uid: user.uid,
                initials: user.initials,
                photoUrl: user.photoUrl,
                size: 92,
              ),
            ),
            const SizedBox(height: Insets.xxl),
            GatherField(
              label: 'Full name',
              controller: _name,
              prefixIcon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) => Validate.required(v, 'full name'),
            ),
            const SizedBox(height: Insets.xl),
            GatherField(
              label: 'Phone number',
              controller: _phone,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              helper: 'Friends can add you to a session with this',
              validator: Validate.phone,
            ),
            const SizedBox(height: Insets.xl),

            // Identity fields are shown but not editable: the handle is how
            // invitations resolve, and the email is the sign-in credential.
            _ReadOnlyField(
              label: 'Username',
              value: '@${user.username}',
              icon: Icons.alternate_email_rounded,
              note: 'Usernames cannot be changed — they are how people add you.',
            ),
            const SizedBox(height: Insets.xl),
            _ReadOnlyField(
              label: 'Email',
              value: user.email,
              icon: Icons.mail_outline_rounded,
              note: 'Used to sign in and recover your account.',
            ),
            const SizedBox(height: Insets.xxxl),
            GatherButton(label: 'Save changes', onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr(label), style: AppType.label.copyWith(fontSize: 15)),
          const SizedBox(height: Insets.sm),
          GatherCard(
            shadows: const [],
            color: AppColors.line.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.lg),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.inkFaint),
                const SizedBox(width: Insets.md),
                Expanded(
                  // The values are a handle and an email, which read left to
                  // right in Arabic too; they still line up with the label.
                  child: Text(
                    value,
                    textDirection: TextDirection.ltr,
                    textAlign: Directionality.of(context) == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                    style: AppType.bodyLarge.copyWith(fontSize: 15, color: AppColors.inkMuted),
                  ),
                ),
                const Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.inkFaint),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: Insets.xs),
            Text(context.tr(note!), style: AppType.caption.copyWith(fontSize: 11.5)),
          ],
        ],
      );
}
