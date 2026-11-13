import '../../core/models/food_story.dart';

/// One person's live stories, the unit the story rail and viewer work in.
///
/// [stories] run oldest first, the order they are watched in — the same as
/// every other story feed, so a day reads as it happened.
class StoryGroup {
  const StoryGroup({
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.stories,
  });

  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final List<FoodStory> stories;

  FoodStory get latest => stories.last;

  /// When the newest story was posted. A story still on its way to the server
  /// has no timestamp yet; it is the newest by definition.
  DateTime get latestAt => latest.createdAt ?? DateTime.now();

  bool allSeen(Set<String> seen) => stories.every((s) => seen.contains(s.id));

  /// Where to start watching: the first story not yet seen, or the beginning
  /// once all of them have been — which is what tapping a grey ring does.
  int firstUnseen(Set<String> seen) {
    final i = stories.indexWhere((s) => !seen.contains(s.id));
    return i < 0 ? 0 : i;
  }
}

DateTime _postedAt(FoodStory s) => s.createdAt ?? DateTime.now();

/// Groups live stories by author, each author's newest group first.
///
/// Expired stories are dropped here as well as in the service: the feed is a
/// live query, so a story can expire while it is still in the last snapshot.
/// Duplicates (the same story from the feed and from "mine") collapse.
List<StoryGroup> groupStories(Iterable<FoodStory> stories, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final byAuthor = <String, Map<String, FoodStory>>{};
  for (final s in stories) {
    if (s.expiresAt != null && s.expiresAt!.isBefore(at)) continue;
    if (s.authorId.isEmpty) continue;
    (byAuthor[s.authorId] ??= {})[s.id] = s;
  }

  final groups = <StoryGroup>[];
  for (final entry in byAuthor.entries) {
    final list = entry.value.values.toList()
      ..sort((a, b) => _postedAt(a).compareTo(_postedAt(b)));
    final newest = list.last;
    groups.add(StoryGroup(
      authorId: entry.key,
      authorName: newest.authorName,
      authorPhotoUrl: newest.authorPhotoUrl,
      stories: list,
    ));
  }
  groups.sort((a, b) => b.latestAt.compareTo(a.latestAt));
  return groups;
}

/// The order the viewer walks through: your own stories first when you open
/// them, otherwise everybody else's starting from the person tapped.
///
/// Opening someone else's never drops you into your own — the same as
/// Instagram, where your story is only reached from its own circle.
List<String> viewingOrder(List<StoryGroup> groups, String startAuthorId, String? me) {
  final others = [for (final g in groups) if (g.authorId != me) g.authorId];
  if (startAuthorId == me) return [startAuthorId, ...others];
  final i = others.indexOf(startAuthorId);
  if (i < 0) return const [];
  return others.sublist(i);
}

/// First letters of a name, for an avatar when there is no photo.
String storyInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
