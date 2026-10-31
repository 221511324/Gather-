import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';
import 'stories_screen.dart';
import 'story_groups.dart';

/// US19 — full-screen story viewer, opened from the home rail.
///
/// Built from the route alone ([authorId], and optionally the [storyId] to
/// start on), so a deep link or a restored route works without anything
/// handed over in memory. Walks one author's stories, then on to the next
/// author's, the way every story feed does.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({super.key, required this.authorId, this.storyId});

  final String authorId;
  final String? storyId;

  /// How long each story stays up before moving on.
  static const perStory = Duration(seconds: 5);

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(
        vsync: this,
        duration: StoryViewerScreen.perStory,
        // This is the story's clock, not decoration. With "remove
        // animations" on, Android shortens normal animations about twenty
        // times, and each story would be gone in a quarter of a second.
        animationBehavior: AnimationBehavior.preserve,
      )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _next();
        });

  /// The authors to walk through, fixed when the viewer opens. Taken once so
  /// a new story arriving mid-watch does not reshuffle what comes next.
  List<String>? _order;
  var _authorIndex = 0;
  String? _storyId;

  /// The story the progress bar is currently timing.
  String? _timing;
  var _held = false;
  var _closing = false;
  var _dragDy = 0.0;

  // Latest data, kept for the gesture handlers.
  Map<String, StoryGroup> _groups = const {};

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  StoryGroup? get _group =>
      (_order == null || _authorIndex >= _order!.length) ? null : _groups[_order![_authorIndex]];

  int get _index {
    final g = _group;
    if (g == null) return 0;
    final i = g.stories.indexWhere((s) => s.id == _storyId);
    return i < 0 ? 0 : i;
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _progress.stop();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  void _show(int authorIndex, String storyId) {
    if (!mounted) return;
    setState(() {
      _authorIndex = authorIndex;
      _storyId = storyId;
    });
  }

  /// The next author that still has stories, from [from] on; -1 if none.
  int _nextAuthorFrom(int from) {
    final order = _order ?? const [];
    for (var i = from; i < order.length; i++) {
      if (_groups[order[i]] != null) return i;
    }
    return -1;
  }

  void _next() {
    final g = _group;
    if (g == null) return _close();
    final i = _index;
    if (i + 1 < g.stories.length) return _show(_authorIndex, g.stories[i + 1].id);
    final a = _nextAuthorFrom(_authorIndex + 1);
    if (a < 0) return _close();
    final next = _groups[_order![a]]!;
    _show(a, next.stories[next.firstUnseen(ref.read(seenStoriesProvider))].id);
  }

  void _previous() {
    final g = _group;
    if (g == null) return;
    final i = _index;
    if (i > 0) return _show(_authorIndex, g.stories[i - 1].id);
    for (var a = _authorIndex - 1; a >= 0; a--) {
      final prev = _groups[_order![a]];
      if (prev != null) return _show(a, prev.stories.first.id);
    }
    // Already at the very first story: start it again.
    _progress.forward(from: 0);
  }

  void _pause() {
    _held = true;
    _progress.stop();
    setState(() {});
  }

  void _resume() {
    if (!mounted) return;
    setState(() => _held = false);
    _sync();
  }

  /// Runs [action] with the story paused — a dialog, a sheet, another screen.
  Future<void> _paused(Future<void> Function() action) async {
    _pause();
    try {
      await action();
    } finally {
      _resume();
    }
  }

  /// Keeps the timer in step with what is on screen: restarts it for a new
  /// story, and only runs it once the picture is there to be looked at.
  void _sync() {
    if (!mounted || _closing) return;
    final g = _group;
    if (g == null) return;
    final story = g.stories[_index];
    if (_timing != story.id) {
      _timing = story.id;
      _progress.reset();
    }
    final image = ref.read(storyImageProvider(story.id));
    if (image.isLoading) return;
    ref.read(seenStoriesProvider.notifier).markSeen(story.id);
    if (!_held && !_progress.isAnimating && _progress.value < 1) _progress.forward();
  }

  void _onTapUp(TapUpDetails d) {
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final x = d.localPosition.dx;
    // Back is the leading third — the left in English, the right in Arabic.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final back = rtl ? x > width * 2 / 3 : x < width / 3;
    if (back) {
      _previous();
    } else {
      _next();
    }
  }

  Future<void> _delete(FoodStory story) => _paused(() async {
        final mine = story.authorId == ref.read(currentUidProvider);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.tr(mine ? 'Remove your story?' : 'Remove this story?')),
            content: Text(context.tr(mine
                ? 'It disappears for everyone.'
                : 'Removing someone else’s story is an administrator action.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.tr('Cancel'))),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(context.tr('Remove'),
                      style: const TextStyle(color: AppColors.danger))),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;

        // Decide where to go before the story vanishes from the feed.
        final g = _group!;
        final i = _index;
        final stay = g.stories.length > 1
            ? g.stories[i + 1 < g.stories.length ? i + 1 : i - 1].id
            : null;

        final r = await ref.read(storyServiceProvider).remove(story.id);
        if (!mounted) return;
        if (r case Err(:final message)) {
          AppSnack.error(context, message);
          return;
        }
        if (stay != null) {
          _show(_authorIndex, stay);
          return;
        }
        final a = _nextAuthorFrom(_authorIndex + 1);
        if (a < 0) {
          _close();
        } else {
          _show(a, _groups[_order![a]]!.stories.first.id);
        }
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUidProvider);
    final feed = ref.watch(storyFeedProvider);
    final mine = ref.watch(myStoriesProvider);
    final groups = groupStories([
      ...?feed.valueOrNull,
      ...?mine.valueOrNull,
    ]);
    _groups = {for (final g in groups) g.authorId: g};

    // Both, so opening your own story never starts before "mine" arrives.
    final waiting = (feed.isLoading && !feed.hasValue) || (mine.isLoading && !mine.hasValue);
    if (_order == null && !waiting) {
      _order = viewingOrder(groups, widget.authorId, me);
      if (_order!.isNotEmpty) {
        final first = _groups[_order!.first]!;
        final asked = first.stories.indexWhere((s) => s.id == widget.storyId);
        _storyId = first.stories[
            asked >= 0 ? asked : first.firstUnseen(ref.read(seenStoriesProvider))].id;
      }
    }

    // The author being watched ran out of stories (expired, or removed
    // elsewhere): move along rather than show an empty screen.
    if (_order != null && _order!.isNotEmpty && _group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final a = _nextAuthorFrom(_authorIndex);
        if (a < 0) return _close();
        _show(a, _groups[_order![a]]!.stories.first.id);
      });
    }

    final g = _group;
    final Widget body;
    if (waiting) {
      body = const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (g == null) {
      body = _Unavailable(onClose: _close);
    } else {
      final i = _index;
      final story = g.stories[i];
      final image = ref.watch(storyImageProvider(story.id));
      // Fetch the one after while this one is being watched.
      final upcoming = i + 1 < g.stories.length
          ? g.stories[i + 1]
          : (() {
              final a = _nextAuthorFrom(_authorIndex + 1);
              return a < 0 ? null : _groups[_order![a]]!.stories.first;
            })();
      if (upcoming != null) ref.watch(storyImageProvider(upcoming.id));
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());

      body = _StoryPage(
        story: story,
        group: g,
        index: i,
        image: image,
        progress: _progress,
        overlaysVisible: !_held,
        me: me,
        isAdmin: ref.watch(isAdminProvider),
        onClose: _close,
        onDelete: () => _delete(story),
        onAddAnother: () => _paused(() => ShareStorySheet.show(context)),
        onOpenRestaurant: (id) => _paused(() => context.push(Routes.restaurant(id))),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('story-viewer'),
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: g == null ? null : _onTapUp,
          onLongPressStart: g == null ? null : (_) => _pause(),
          onLongPressEnd: g == null ? null : (_) => _resume(),
          onVerticalDragUpdate: (d) =>
              setState(() => _dragDy = (_dragDy + d.delta.dy).clamp(0, double.infinity)),
          onVerticalDragEnd: (d) {
            if (_dragDy > 120 || (d.primaryVelocity ?? 0) > 700) return _close();
            setState(() => _dragDy = 0);
          },
          child: Transform.translate(
            offset: Offset(0, _dragDy),
            child: Opacity(
              opacity: (1 - _dragDy / 600).clamp(0.4, 1),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.story,
    required this.group,
    required this.index,
    required this.image,
    required this.progress,
    required this.overlaysVisible,
    required this.me,
    required this.isAdmin,
    required this.onClose,
    required this.onDelete,
    required this.onAddAnother,
    required this.onOpenRestaurant,
  });

  final FoodStory story;
  final StoryGroup group;
  final int index;
  final AsyncValue<Uint8List?> image;
  final Animation<double> progress;
  final bool overlaysVisible;
  final String? me;
  final bool isAdmin;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onAddAnother;
  final void Function(String restaurantId) onOpenRestaurant;

  @override
  Widget build(BuildContext context) {
    final mine = me != null && story.authorId == me;
    final bytes = image.valueOrNull;

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: image.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : bytes == null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
                        const SizedBox(height: Insets.md),
                        Text(context.tr('This photo could not be loaded'),
                            style: AppType.body.copyWith(color: Colors.white70)),
                      ],
                    )
                  : Image.memory(bytes,
                      key: ValueKey(story.id),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      gaplessPlayback: true),
        ),
        AnimatedOpacity(
          opacity: overlaysVisible ? 1 : 0,
          duration: Motion.fast,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Shades behind the text so it reads on a bright photo.
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.18, 0.62, 1],
                      colors: [Colors.black54, Colors.transparent, Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(Insets.sm, Insets.sm, Insets.sm, 0),
                      child: _ProgressBars(count: group.stories.length, index: index, progress: progress),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(Insets.md, Insets.sm, Insets.xs, 0),
                      child: Row(
                        children: [
                          MemberAvatar(
                            uid: story.authorId,
                            initials: storyInitials(story.authorName),
                            photoUrl: story.authorPhotoUrl,
                            size: 34,
                          ),
                          const SizedBox(width: Insets.sm),
                          Flexible(
                            child: Text(
                              mine ? context.tr('Your story') : context.isolate(story.authorName),
                              style: AppType.bodyStrong.copyWith(color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Insets.sm),
                          Text(storyAge(context, story.createdAt),
                              style: AppType.caption.copyWith(color: Colors.white70)),
                          const Spacer(),
                          if (mine || isAdmin)
                            IconButton(
                              key: const Key('story-delete'),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                              tooltip: context.tr('Delete story'),
                              onPressed: onDelete,
                            ),
                          IconButton(
                            key: const Key('story-close'),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            tooltip: context.tr('Close'),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _Footer(
                      story: story,
                      mine: mine,
                      me: me,
                      onAddAnother: onAddAnother,
                      onOpenRestaurant: onOpenRestaurant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({
    required this.story,
    required this.mine,
    required this.me,
    required this.onAddAnother,
    required this.onOpenRestaurant,
  });

  final FoodStory story;
  final bool mine;
  final String? me;
  final VoidCallback onAddAnother;
  final void Function(String restaurantId) onOpenRestaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = me != null && story.likedByMe(me!);
    final restaurant = story.restaurantName;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Insets.gutter, 0, Insets.md, Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (story.caption.isNotEmpty) ...[
            Text(
              context.isolate(story.caption),
              style: AppType.bodyLarge.copyWith(color: Colors.white),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.md),
          ],
          Row(
            children: [
              if (restaurant != null)
                Flexible(
                  child: ActionChip(
                    avatar: const Icon(Icons.storefront_rounded, size: 18, color: AppColors.ink),
                    label: Text(
                      context.isolate(story.itemName == null
                          ? restaurant
                          : '${story.itemName} · $restaurant'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    onPressed: story.restaurantId == null
                        ? null
                        : () => onOpenRestaurant(story.restaurantId!),
                  ),
                )
              else
                const Spacer(),
              if (restaurant != null) const SizedBox(width: Insets.sm),
              if (mine)
                TextButton.icon(
                  key: const Key('story-add-another'),
                  onPressed: onAddAnother,
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  label: Text(context.tr('Add another'),
                      style: AppType.label.copyWith(color: Colors.white)),
                ),
              IconButton(
                key: const Key('story-like'),
                icon: Icon(
                  liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? AppColors.coral : Colors.white,
                ),
                tooltip: context.tr(liked ? 'Unlike' : 'Like'),
                onPressed: me == null
                    ? null
                    : () async {
                        final r = await ref
                            .read(storyServiceProvider)
                            .toggleLike(storyId: story.id, uid: me!, liked: liked);
                        if (!context.mounted) return;
                        if (r case Err(:final message)) AppSnack.error(context, message);
                      },
              ),
              Text('${story.likeCount}', style: AppType.label.copyWith(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}

/// One bar per story: full for those watched, filling for this one, empty
/// for those to come. Fills from the leading edge, so it runs right to left
/// in Arabic.
class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.count, required this.index, required this.progress});

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 3,
                  child: ColoredBox(
                    color: Colors.white38,
                    child: AnimatedBuilder(
                      animation: progress,
                      builder: (_, _) => FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: i < index ? 1 : (i == index ? progress.value : 0),
                        child: const ColoredBox(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_empty_rounded, color: Colors.white70, size: 48),
                const SizedBox(height: Insets.md),
                Text(
                  context.tr('This story is no longer available'),
                  textAlign: TextAlign.center,
                  style: AppType.bodyLarge.copyWith(color: Colors.white),
                ),
                const SizedBox(height: Insets.lg),
                TextButton(
                  key: const Key('story-close'),
                  onPressed: onClose,
                  child: Text(context.tr('Close'),
                      style: AppType.label.copyWith(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
}

/// "just now", "12 min ago", "3h ago" — a story is never older than a day.
String storyAge(BuildContext context, DateTime? postedAt, {DateTime? now}) {
  // Not yet stamped by the server means it was posted a moment ago.
  if (postedAt == null) return context.tr('just now');
  final diff = (now ?? DateTime.now()).difference(postedAt);
  if (diff.inMinutes < 1) return context.tr('just now');
  if (diff.inMinutes < 60) return context.tr('{n} min ago', {'n': diff.inMinutes});
  return context.tr('{n}h ago', {'n': diff.inHours});
}
