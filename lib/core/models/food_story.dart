import '../utils/parse.dart';

/// US19 — a food photo somebody shared.
///
/// The photograph itself is *not* on this object. It lives in a separate
/// document, `stories/{id}/media/image`, because Firestore reads whole
/// documents: with the image inline, listing twenty stories would pull
/// several megabytes before anything appeared on screen. Split like this the
/// feed costs a few kilobytes and each picture loads when it is scrolled to.
class FoodStory {
  const FoodStory({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.caption = '',
    this.restaurantId,
    this.restaurantName,
    this.itemId,
    this.itemName,
    this.likedBy = const [],
    this.width = 0,
    this.height = 0,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String caption;

  /// What was being eaten, so a story can be tapped through to something
  /// orderable — the "discover food" half of the story.
  final String? restaurantId;
  final String? restaurantName;
  final String? itemId;
  final String? itemName;

  /// Stored as the whole list rather than a count so the interface knows
  /// whether *this* viewer has already liked it without a second read.
  final List<String> likedBy;

  /// Kept so the feed can reserve the right space before the image arrives,
  /// instead of jumping as each one loads.
  final int width;
  final int height;

  final DateTime? createdAt;

  /// Stories are temporary — a day, like every other story feed.
  final DateTime? expiresAt;

  int get likeCount => likedBy.length;
  bool likedByMe(String uid) => likedBy.contains(uid);

  bool get hasExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  double get aspectRatio =>
      (width > 0 && height > 0) ? width / height : 1;

  factory FoodStory.fromMap(String id, Map<String, dynamic> m) => FoodStory(
        id: id,
        authorId: Parse.str(m['authorId']),
        authorName: Parse.str(m['authorName']),
        authorPhotoUrl: Parse.strOrNull(m['authorPhotoUrl']),
        caption: Parse.str(m['caption']),
        restaurantId: Parse.strOrNull(m['restaurantId']),
        restaurantName: Parse.strOrNull(m['restaurantName']),
        itemId: Parse.strOrNull(m['itemId']),
        itemName: Parse.strOrNull(m['itemName']),
        likedBy: Parse.strList(m['likedBy']),
        width: Parse.integer(m['width']),
        height: Parse.integer(m['height']),
        createdAt: Parse.dateOrNull(m['createdAt']),
        expiresAt: Parse.dateOrNull(m['expiresAt']),
      );

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorPhotoUrl': authorPhotoUrl,
        'caption': caption,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'itemId': itemId,
        'itemName': itemName,
        'likedBy': likedBy,
        'width': width,
        'height': height,
        'expiresAt': expiresAt,
      };
}
