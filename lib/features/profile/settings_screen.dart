import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/state_views.dart';

/// US17 — language, notification, privacy and support preferences.
///
/// Each switch saves as soon as it is changed, so there is no Save button to
/// forget. The screen holds the pending value itself and puts it back if the
/// write fails, so what is shown always matches what is stored.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  UserSettings? _pending;
  var _saving = false;

  Future<void> _apply(UserSettings next, UserSettings previous) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _pending = next;
      _saving = true;
    });

    final result = await ref.read(authServiceProvider).saveSettings(uid, next);
    if (!mounted) return;

    switch (result) {
      case Err(:final message):
        // Put the switch back where it was — showing it on while it is off in
        // the database would be worse than the failure itself.
        setState(() {
          _pending = previous;
          _saving = false;
        });
        AppSnack.error(context, message);
      case Ok():
        setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) {
      return const BrandScaffold(
          title: 'Settings', showBack: true, child: LoadingView());
    }

    // The pending value wins while a write is in flight, so the switch moves
    // under the finger rather than after the round trip.
    final s = _pending ?? user.settings;
    void set(UserSettings next) => _apply(next, s);

    return BrandScaffold(
      title: 'Settings',
      showBack: true,
      child: ListView(
        padding: const EdgeInsets.all(Insets.gutter),
        children: [
          const SectionHeader(title: 'Language'),
          GatherCard(
            child: RadioGroup<String>(
              groupValue: s.language,
              onChanged: (v) {
                if (_saving) return;
                set(s.copyWith(language: v ?? 'en'));
              },
              child: Column(
                children: [
                  for (final (code, name, native) in const [
                    ('en', 'English', 'English'),
                    ('ar', 'Arabic', 'العربية'),
                  ])
                    RadioListTile<String>(
                      value: code,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr(name), style: AppType.body),
                      subtitle: Text(native, style: AppType.caption),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),

          const SectionHeader(title: 'Notifications'),
          GatherCard(
            child: Column(
              children: [
                _Toggle(
                  label: 'Push notifications',
                  description: 'Turning this off silences everything below',
                  value: s.pushNotifications,
                  enabled: !_saving,
                  onChanged: (v) => set(s.copyWith(pushNotifications: v)),
                ),
                const Divider(height: Insets.lg, color: AppColors.line),
                _Toggle(
                  label: 'Order updates',
                  description: 'When an order is accepted, on its way, or delivered',
                  value: s.orderUpdates,
                  // Nothing below the master switch can be changed while it is
                  // off, because none of it would be delivered.
                  enabled: !_saving && s.pushNotifications,
                  onChanged: (v) => set(s.copyWith(orderUpdates: v)),
                ),
                const Divider(height: Insets.lg, color: AppColors.line),
                _Toggle(
                  label: 'Group invitations',
                  description: 'When somebody invites you to a session',
                  value: s.groupInvites,
                  enabled: !_saving && s.pushNotifications,
                  onChanged: (v) => set(s.copyWith(groupInvites: v)),
                ),
                const Divider(height: Insets.lg, color: AppColors.line),
                _Toggle(
                  label: 'Offers',
                  description: 'Discounts and rewards',
                  value: s.promotions,
                  enabled: !_saving && s.pushNotifications,
                  onChanged: (v) => set(s.copyWith(promotions: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),

          const SectionHeader(title: 'Privacy'),
          GatherCard(
            child: Column(
              children: [
                _Toggle(
                  label: 'Show my photo to my group',
                  description: 'Off means your initials are shown instead',
                  value: s.shareProfileWithGroup,
                  enabled: !_saving,
                  onChanged: (v) => set(s.copyWith(shareProfileWithGroup: v)),
                ),
                const Divider(height: Insets.lg, color: AppColors.line),
                _Toggle(
                  label: 'Findable by username',
                  description: 'Lets a host invite you by your handle',
                  value: s.discoverableByUsername,
                  enabled: !_saving,
                  onChanged: (v) => set(s.copyWith(discoverableByUsername: v)),
                ),
                const Divider(height: Insets.lg, color: AppColors.line),
                _Toggle(
                  label: 'Findable by phone number',
                  description: 'Lets a host invite you by your number',
                  value: s.discoverableByPhone,
                  enabled: !_saving,
                  onChanged: (v) => set(s.copyWith(discoverableByPhone: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            context.tr(
                'Turning both off means nobody can find you to invite you. You can '
                'still join any session with its four-digit code.'),
            style: AppType.caption,
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(label),
                  style: AppType.body.copyWith(
                      color: enabled ? AppColors.ink : AppColors.inkFaint),
                ),
                Text(context.tr(description), style: AppType.caption),
              ],
            ),
          ),
          const SizedBox(width: Insets.md),
          Switch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      );
}
