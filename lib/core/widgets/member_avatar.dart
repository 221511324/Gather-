import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../models/group_session.dart';
import 'food_image.dart';

/// A member's avatar.
///
/// The fallback colour is derived from the uid, so a person keeps the same
/// colour in the lobby, the shared cart and the payment list — which is how
/// you tell at a glance whose item is whose.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.uid,
    required this.initials,
    this.photoUrl,
    this.size = 40,
    this.isHost = false,
    this.borderColor,
  });

  final String uid;
  final String initials;
  final String? photoUrl;
  final double size;
  final bool isHost;
  final Color? borderColor;

  factory MemberAvatar.of(SessionMember member, {double size = 40, Color? borderColor}) =>
      MemberAvatar(
        uid: member.uid,
        initials: member.initials,
        photoUrl: member.photoUrl,
        size: size,
        isHost: member.isHost,
        borderColor: borderColor,
      );

  @override
  Widget build(BuildContext context) {
    final color = AppColors.memberColor(uid);
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: (photoUrl ?? '').isEmpty
          ? Text(
              initials,
              style: AppType.label.copyWith(
                color: Colors.white,
                fontSize: size * 0.36,
                letterSpacing: 0,
              ),
            )
          : FoodImage(url: photoUrl!, width: size, height: size),
    );

    if (!isHost) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        PositionedDirectional(
          end: -1,
          bottom: -1,
          child: Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1.6),
            ),
            child: Icon(Icons.star_rounded, size: size * 0.24, color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

/// Overlapping avatars with a "+N" overflow bubble.
class MemberAvatarStack extends StatelessWidget {
  const MemberAvatarStack({
    super.key,
    required this.members,
    this.size = 34,
    this.max = 4,
    this.borderColor = AppColors.surface,
  });

  final List<SessionMember> members;
  final double size;
  final int max;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const SizedBox.shrink();
    final shown = members.take(max).toList();
    final overflow = members.length - shown.length;
    final overlap = size * 0.32;

    return SizedBox(
      height: size,
      width: shown.length * (size - overlap) + overlap + (overflow > 0 ? size - overlap : 0),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: i * (size - overlap),
              child: MemberAvatar.of(shown[i], size: size, borderColor: borderColor),
            ),
          if (overflow > 0)
            PositionedDirectional(
              start: shown.length * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflow',
                  style: AppType.overline.copyWith(
                    color: AppColors.primary,
                    fontSize: size * 0.3,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The −/qty/+ control used in carts and the item sheet.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 50,
    this.compact = false,
    this.allowRemove = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;

  /// When true the minus button turns into a delete at the minimum.
  final bool allowRemove;

  @override
  Widget build(BuildContext context) {
    final atMin = quantity <= min;
    final size = compact ? 30.0 : 36.0;

    return Container(
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: Radii.brPill),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(
            icon: atMin && allowRemove ? Icons.delete_outline_rounded : Icons.remove_rounded,
            size: size,
            color: atMin && allowRemove ? AppColors.danger : AppColors.primary,
            onTap: atMin && !allowRemove ? null : () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: compact ? 30 : 38,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppType.bodyStrong.copyWith(fontSize: compact ? 14 : 16),
            ),
          ),
          _Btn(
            icon: Icons.add_rounded,
            size: size,
            color: AppColors.primary,
            onTap: quantity >= max ? null : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.size, required this.color, this.onTap});

  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: onTap == null ? AppColors.line : AppColors.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: onTap == null ? AppColors.inkFaint : color),
          ),
        ),
      );
}
