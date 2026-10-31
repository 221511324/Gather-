import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../core/l10n/tr.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/result.dart';
import '../../core/widgets/brand_scaffold.dart';
import '../../core/widgets/cards.dart';
import '../../core/widgets/gather_button.dart';
import '../../core/widgets/gather_field.dart';
import '../../core/widgets/member_avatar.dart';
import '../../core/widgets/state_views.dart';

/// US19 — food photos people have shared.
class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(storyFeedProvider);

    return BrandScaffold(
      title: 'Food stories',
      showBack: true,
      actions: [
        BandIconButton(
          icon: Icons.add_a_photo_outlined,
          tooltip: 'Share a photo',
          onTap: () => ShareStorySheet.show(context),
        ),
      ],
      child: feed.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (stories) {
          if (stories.isEmpty) {
            return EmptyView(
              icon: Icons.photo_camera_outlined,
              title: 'No stories yet',
              message: 'Share what you are eating. Stories disappear after a day.',
              actionLabel: 'Share a photo',
              onAction: () => ShareStorySheet.show(context),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(Insets.gutter),
            itemCount: stories.length,
            itemBuilder: (context, i) => _StoryCard(story: stories[i]),
          );
        },
      ),
    );
  }
}

/// First letters of a name, for the avatar when there is no photo.
String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

class _StoryCard extends ConsumerWidget {
  const _StoryCard({required this.story});

  final FoodStory story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUidProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final service = ref.read(storyServiceProvider);
    final mine = uid != null && story.authorId == uid;
    final liked = uid != null && story.likedByMe(uid);

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: GatherCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Row(
                children: [
                  MemberAvatar(
                    uid: story.authorId,
                    initials: _initialsOf(story.authorName),
                    photoUrl: story.authorPhotoUrl,
                    size: 34,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.isolate(story.authorName), style: AppType.bodyStrong),
                        if (story.restaurantName != null)
                          Text(context.isolate(story.restaurantName!), style: AppType.caption),
                      ],
                    ),
                  ),
                  if (mine || isAdmin)
                    IconButton(
                      icon: const Icon(Icons.more_horiz_rounded,
                          color: AppColors.inkFaint),
                      tooltip: context.tr('Story options'),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(context.tr(mine
                                ? 'Remove your story?'
                                : 'Remove this story?')),
                            content: Text(context.tr(mine
                                ? 'It disappears for everyone.'
                                : 'Removing someone else’s story is an '
                                    'administrator action.')),
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
                        if (confirmed != true) return;
                        final r = await service.remove(story.id);
                        if (!context.mounted) return;
                        if (r case Err(:final message)) {
                          AppSnack.error(context, message);
                        }
                      },
                    ),
                ],
              ),
            ),
            _StoryImage(storyId: story.id, aspectRatio: story.aspectRatio),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: liked ? AppColors.danger : AppColors.inkFaint,
                        ),
                        tooltip: context.tr(liked ? 'Unlike' : 'Like'),
                        onPressed: uid == null
                            ? null
                            : () => service.toggleLike(
                                storyId: story.id, uid: uid, liked: liked),
                      ),
                      const SizedBox(width: Insets.xs),
                      Text('${story.likeCount}', style: AppType.caption),
                      const Spacer(),
                      if (story.itemName != null && story.restaurantId != null)
                        TextButton(
                          onPressed: () =>
                              context.push(Routes.restaurant(story.restaurantId!)),
                          child: Text(context.tr('Order {item}', {'item': context.isolate(story.itemName!)})),
                        ),
                    ],
                  ),
                  if (story.caption.isNotEmpty) ...[
                    const SizedBox(height: Insets.xs),
                    Text(context.isolate(story.caption), style: AppType.body),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads one story's picture on demand.
///
/// The image lives in its own document, so it is fetched only when the card
/// is built — the feed itself carries none of these bytes.
class _StoryImage extends ConsumerStatefulWidget {
  const _StoryImage({required this.storyId, required this.aspectRatio});

  final String storyId;
  final double aspectRatio;

  @override
  ConsumerState<_StoryImage> createState() => _StoryImageState();
}

class _StoryImageState extends ConsumerState<_StoryImage> {
  Uint8List? _bytes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await ref.read(storyServiceProvider).loadImage(widget.storyId);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _failed = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        // Reserved from the stored dimensions, so the feed does not jump
        // about as each picture arrives.
        aspectRatio: widget.aspectRatio <= 0 ? 1 : widget.aspectRatio,
        child: Container(
          color: AppColors.surfaceAlt,
          alignment: Alignment.center,
          child: switch ((_bytes, _failed)) {
            (final Uint8List b, _) => Image.memory(b, fit: BoxFit.cover,
                width: double.infinity, height: double.infinity),
            (_, true) => const Icon(Icons.broken_image_outlined,
                color: AppColors.inkFaint),
            _ => const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
          },
        ),
      );
}

/// Pick a photo, say something about it, post it.
class ShareStorySheet extends ConsumerStatefulWidget {
  const ShareStorySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (_) => const ShareStorySheet(),
      );

  @override
  ConsumerState<ShareStorySheet> createState() => _ShareStorySheetState();
}

class _ShareStorySheetState extends ConsumerState<ShareStorySheet> {
  final _caption = TextEditingController();
  Uint8List? _picked;
  Restaurant? _restaurant;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      // A first pass at the source, so a 12 megapixel photo is not held in
      // memory in full before the compressor sees it.
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _picked = bytes;
      _error = null;
    });
  }

  Future<void> _post() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    final image = _picked;
    if (user == null || image == null) {
      setState(() => _error = 'Choose a photo first');
      return;
    }

    final result = await ref.read(storyServiceProvider).post(
          author: user,
          image: image,
          caption: _caption.text,
          restaurant: _restaurant,
        );

    if (!mounted) return;
    switch (result) {
      case Err(:final message):
        setState(() => _error = message);
      case Ok():
        AppSnack.show(context, 'Shared');
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? const [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.fromSTEB(Insets.gutter, Insets.sm, Insets.gutter,
            Insets.xl + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Share a photo'), style: AppType.headline),
            const SizedBox(height: Insets.xs),
            Text(context.tr('Stories disappear after a day.'), style: AppType.caption),
            const SizedBox(height: Insets.lg),

            if (_picked != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: Image.memory(_picked!,
                    height: 200, width: double.infinity, fit: BoxFit.cover),
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.photo_outlined,
                    size: 36, color: AppColors.inkFaint),
              ),
            const SizedBox(height: Insets.md),
            Row(
              children: [
                Expanded(
                  child: GatherOutlineButton(
                    label: 'Camera',
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: GatherOutlineButton(
                    label: 'Gallery',
                    icon: Icons.photo_library_outlined,
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            GatherField(
              label: 'Caption',
              controller: _caption,
              hint: 'Best mandi in Riyadh|hint',
            ),
            const SizedBox(height: Insets.lg),
            DropdownButtonFormField<Restaurant>(
              initialValue: _restaurant,
              decoration: InputDecoration(labelText: context.tr('Where from (optional)')),
              items: [
                DropdownMenuItem<Restaurant>(
                    value: null, child: Text(context.tr('Not saying'))),
                for (final r in restaurants)
                  DropdownMenuItem(value: r, child: Text(context.isolate(r.name))),
              ],
              onChanged: (r) => setState(() => _restaurant = r),
            ),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              Text(context.tr(_error!),
                  style: AppType.caption.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: Insets.xl),
            GatherButton(label: 'Share', onPressed: _post),
          ],
        ),
      ),
    );
  }
}
