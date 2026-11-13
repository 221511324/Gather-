import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/food_story.dart';
import '../models/restaurant.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// US19 — share a food photo, and see what other people are eating.
///
/// Photographs are stored as base64 inside Firestore rather than in Firebase
/// Storage, which needs a paid plan this project does not have. Measured
/// against the live project: base64 costs exactly 33% and Firestore accepts
/// 700KB of image but refuses 780KB, the wall being its 1MiB document limit.
/// Every photo is therefore compressed to comfortably under that before it is
/// encoded, and the encoded bytes live in their own document so listing the
/// feed does not drag them along.
class StoryService {
  StoryService(this.refs);

  final FirestoreRefs refs;
  static const _uuid = Uuid();

  /// How long a story is visible.
  static const visibleFor = Duration(hours: 24);

  /// The largest encoded payload we will write.
  ///
  /// Firestore's limit is 1MiB for the whole document; this leaves room for
  /// the other fields and for the limit being on the document rather than the
  /// field. A photo that will not fit under it is rejected rather than
  /// silently truncated.
  static const maxEncodedBytes = 900 * 1024;

  /// Longest edge after resizing. 1280 is plenty for a phone screen and keeps
  /// a typical food photo near 150KB at this quality.
  static const _maxEdge = 1280;
  static const _quality = 72;

  // ------------------------------------------------------------- reading ---

  /// The feed: everyone's stories, newest first, expired ones left out.
  ///
  /// The expiry is filtered here rather than in the query because a story
  /// written a second ago and one written yesterday differ only by a
  /// timestamp, and Firestore would need a composite index to order by one
  /// field while filtering on another.
  Stream<List<FoodStory>> watchFeed({int limit = 50}) => refs.stories
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.id != '_schema')
          .map((d) => FoodStory.fromMap(d.id, d.data()))
          .where((story) => !story.hasExpired)
          .toList());

  Stream<List<FoodStory>> watchMine(String uid) => refs.stories
      .where('authorId', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.id != '_schema')
          .map((d) => FoodStory.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0))));

  /// Fetches one story's picture. Separate from the story itself, so the feed
  /// can be listed cheaply and each image pulled only when it is needed.
  Future<Uint8List?> loadImage(String storyId) async {
    try {
      final doc = await refs.storyImage(storyId).get();
      final encoded = doc.data()?['b64'];
      if (encoded is! String || encoded.isEmpty) return null;
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- writing ---

  /// Shrinks a photo until it will fit, and reports its size.
  ///
  /// Returns an error rather than a half-sized picture if it cannot get there,
  /// so a story is never posted with an image the database will reject.
  static Future<Result<({Uint8List bytes, int width, int height})>> prepare(
      Uint8List original) async {
    var quality = _quality;
    var edge = _maxEdge;

    for (var attempt = 0; attempt < 4; attempt++) {
      final Uint8List compressed;
      try {
        compressed = await FlutterImageCompress.compressWithList(
          original,
          minWidth: edge,
          minHeight: edge,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      } catch (_) {
        // The compressor throws rather than returns when it is handed
        // something it cannot decode - a corrupt file, or a format the
        // device does not support. Without this the picker would take the
        // whole screen down instead of saying so.
        return const Err('That file is not a picture Gather can read.');
      }
      if (compressed.isEmpty) {
        return const Err('That file is not a picture Gather can read.');
      }
      // base64 is 4 bytes for every 3, so check the encoded size, not the raw.
      if ((compressed.length * 4 / 3).ceil() <= maxEncodedBytes) {
        return Ok((bytes: compressed, width: edge, height: edge));
      }
      // Still too big: try harder rather than give up on the first pass.
      quality = (quality * 0.75).round();
      edge = (edge * 0.8).round();
    }
    return const Err('That photo is too large to share. Try a smaller one.');
  }

  /// Posts a story. The picture and the story are written in one batch, so a
  /// story can never exist without its image or an image without its story.
  Future<Result<FoodStory>> post({
    required AppUser author,
    required Uint8List image,
    String caption = '',
    Restaurant? restaurant,
    MenuItem? item,
  }) async {
    final prepared = await prepare(image);
    if (prepared case Err(:final message)) return Err(message);
    final (bytes: bytes, width: width, height: height) =
        (prepared as Ok<({Uint8List bytes, int width, int height})>).value;

    final encoded = base64Encode(bytes);
    if (encoded.length > maxEncodedBytes) {
      return const Err('That photo is too large to share. Try a smaller one.');
    }

    try {
      final id = _uuid.v4();
      final story = FoodStory(
        id: id,
        authorId: author.uid,
        authorName: author.fullName.isEmpty ? author.username : author.fullName,
        authorPhotoUrl:
            author.settings.shareProfileWithGroup ? author.photoUrl : null,
        caption: caption.trim(),
        restaurantId: restaurant?.id,
        restaurantName: restaurant?.name,
        itemId: item?.id,
        itemName: item?.name,
        width: width,
        height: height,
        expiresAt: DateTime.now().add(visibleFor),
      );

      final batch = refs.db.batch();
      batch.set(refs.story(id), {
        ...story.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(refs.storyImage(id), {
        // Repeated here rather than read from the story: both are written in
        // one batch, so the story does not exist yet when the rule for this
        // document is evaluated.
        'authorId': author.uid,
        'b64': encoded,
        'bytes': bytes.length,
      });
      await batch.commit();
      return Ok(story);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not share that photo'));
    }
  }

  /// Likes or unlikes, whichever the viewer has not already done.
  ///
  /// Uses arrayUnion/arrayRemove rather than reading and rewriting the list,
  /// so two people liking at the same moment cannot overwrite each other.
  Future<Result<void>> toggleLike({
    required String storyId,
    required String uid,
    required bool liked,
  }) async {
    try {
      await refs.story(storyId).update({
        'likedBy': liked
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not do that just now'));
    }
  }

  /// Removes a story and its picture together.
  ///
  /// The rules allow the author or an administrator, which is what makes
  /// moderation possible without a separate reporting system.
  Future<Result<void>> remove(String storyId) async {
    try {
      final batch = refs.db.batch();
      batch.delete(refs.storyImage(storyId));
      batch.delete(refs.story(storyId));
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(_readable(e, 'Could not remove that story'));
    }
  }

  static String _readable(FirebaseException e, String fallback) =>
      e.code == 'permission-denied'
          ? 'You do not have permission to do that'
          : e.message ?? fallback;
}
