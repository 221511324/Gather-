import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/member_avatar.dart';
import 'stories_screen.dart';
import 'story_groups.dart';

/// US19 — the row of story circles at the top of home.
///
/// "Your story" comes first, then one circle per person with a live story,
/// whoever posted most recently first. A coloured ring means there is
/// something this device has not watched yet; grey means all seen.
class StoryRail extends ConsumerWidget {
  const StoryRail({super.key});

  static const _height = 100.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUidProvider);
    final seen = ref.watch(seenStoriesProvider);
    final groups = groupStories([
      ...?ref.watch(storyFeedProvider).valueOrNull,
      ...?ref.watch(myStoriesProvider).valueOrNull,
    ]);
    final myGroup = groups.where((g) => g.authorId == me).firstOrNull;
    final others = groups.where((g) => g.authorId != me).toList();

    return SizedBox(
      key: const Key('story-rail'),
      height: _height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.gutter),
        children: [
          _YourStory(group: myGroup, seen: seen),
          for (final g in others)
            _StoryCircle(
              key: Key('story-circle-${g.authorId}'),
              label: context.isolate(g.authorName),
              ring: g.allSeen(seen) ? _Ring.seen : _Ring.unseen,
              thumb: _Thumb(group: g),
              onTap: () => context.push(Routes.storyViewer(g.authorId)),
            ),
          _StoryCircle(
            key: const Key('story-see-all'),
            label: context.tr('See all'),
            ring: _Ring.none,
            thumb: const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.grid_view_rounded, color: AppColors.primary),
            ),
            onTap: () => context.push(Routes.stories),
          ),
        ],
      ),
    );
  }
}

class _YourStory extends ConsumerWidget {
  const _YourStory({required this.group, required this.seen});

  final StoryGroup? group;
  final Set<String> seen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final g = group;
    void add() => ShareStorySheet.show(context);

    return _StoryCircle(
      key: const Key('story-your'),
      label: context.tr('Your story'),
      ring: g == null ? _Ring.none : (g.allSeen(seen) ? _Ring.seen : _Ring.unseen),
      thumb: g != null
          ? _Thumb(group: g)
          : MemberAvatar(
              uid: user?.uid ?? '',
              initials: user?.initials ?? '?',
              photoUrl: user?.photoUrl,
              size: _StoryCircle.inner,
            ),
      // With nothing posted the circle itself adds one; once there is a
      // story it plays it, and the badge is how you add another.
      onTap: g == null ? add : () => context.push(Routes.storyViewer(g.authorId)),
      badge: Tooltip(
        message: context.tr('Add to your story'),
        child: GestureDetector(
          key: const Key('story-add'),
          onTap: add,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }
}

/// The newest story's picture, or the author's avatar until it arrives.
class _Thumb extends ConsumerWidget {
  const _Thumb({required this.group});

  final StoryGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(storyImageProvider(group.latest.id)).valueOrNull;
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          // Decoded at thumbnail size: the full photo is ~1280px.
          cacheWidth: 200,
          fit: BoxFit.cover,
          width: _StoryCircle.inner,
          height: _StoryCircle.inner,
          gaplessPlayback: true,
        ),
      );
    }
    return MemberAvatar(
      uid: group.authorId,
      initials: storyInitials(group.authorName),
      photoUrl: group.authorPhotoUrl,
      size: _StoryCircle.inner,
    );
  }
}

enum _Ring { unseen, seen, none }

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    super.key,
    required this.label,
    required this.ring,
    required this.thumb,
    required this.onTap,
    this.badge,
  });

  static const outer = 68.0;
  static const inner = 58.0;

  /// Already translated or isolated by the caller.
  final String label;
  final _Ring ring;
  final Widget thumb;
  final VoidCallback onTap;
  final Widget? badge;

  static const _unseen = SweepGradient(
    colors: [AppColors.accent, AppColors.band, AppColors.bandDeep, AppColors.coral, AppColors.accent],
  );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: Insets.md),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: outer + 6,
              child: Column(
                children: [
                  SizedBox(
                    width: outer,
                    height: outer,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: outer,
                          height: outer,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ring == _Ring.unseen ? _unseen : null,
                            color: switch (ring) {
                              _Ring.unseen => null,
                              _Ring.seen => AppColors.inkFaint.withValues(alpha: 0.55),
                              _Ring.none => Colors.transparent,
                            },
                          ),
                          padding: const EdgeInsets.all(2.5),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: SizedBox(width: inner, height: inner, child: thumb),
                          ),
                        ),
                        if (badge != null)
                          PositionedDirectional(end: -2, bottom: -2, child: badge!),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xs + 2),
                  Text(
                    label,
                    style: AppType.caption.copyWith(color: AppColors.ink, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
