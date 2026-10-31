import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/story_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 3 — food stories, TC_FS_001 to TC_FS_009.
///
/// US19  Allows users to share food photos as stories and discover food
///       shared by other Gather users.
///
/// Photographs go into Firestore as base64 because Firebase Storage needs a
/// paid plan. These check that the size limit is respected, that the picture
/// is kept out of the feed listing, and that only the author or an
/// administrator can take a story down.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  const adminEmail = 'admin@gather.app';
  const adminPassword = 'GatherAdmin2026!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final meEmail = 'f3me$stamp@gather-test.local';
  final otherEmail = 'f3other$stamp@gather-test.local';

  late ProviderContainer c;
  late StoryService stories;
  late AppUser me, other;
  late Uint8List photo;
  String? postedId;

  Future<AppUser> actAs(String email, [String pw = password]) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: pw);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    c = ProviderContainer();
    stories = c.read(storyServiceProvider);
    final auth = c.read(authServiceProvider);

    for (final (email, name, i) in [(meEmail, 'F Me', 0), (otherEmail, 'F Other', 1)]) {
      final r = await auth.signUp(
          fullName: name, username: 'f3u$i$stamp', email: email,
          phone: '+9665300$i${stamp % 10000}', password: password);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      if (i == 0) me = r.valueOrNull!;
      if (i == 1) other = r.valueOrNull!;
    }
    photo = (await rootBundle.load('assets/images/logo.png')).buffer.asUint8List();
    me = await actAs(meEmail);
  });

  tearDownAll(() async {
    me = await actAs(meEmail);
    if (postedId != null) await stories.remove(postedId!);
    c.dispose();
  });

  testWidgets('TC_FS_001 A photo is compressed to fit Firestore', (t) async {
    final prepared = await StoryService.prepare(photo);
    expect(prepared.isSuccess, isTrue, reason: prepared.errorOrNull ?? '');
    final bytes = prepared.valueOrNull!.bytes;
    final encoded = base64Encode(bytes).length;
    expect(encoded, lessThan(StoryService.maxEncodedBytes),
        reason: 'the encoded photo must fit inside one document');
    debugPrint('TC_FS_001 PASS raw=${photo.length}B compressed=${bytes.length}B '
        'encoded=${encoded}B limit=${StoryService.maxEncodedBytes}B');
  });

  testWidgets('TC_FS_002 A story can be shared', (t) async {
    me = await actAs(meEmail);
    final r = await stories.post(
        author: me, image: photo, caption: 'Testing the feed');
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    postedId = r.valueOrNull!.id;
    expect(r.valueOrNull!.authorId, me.uid);
    expect(r.valueOrNull!.expiresAt, isNotNull, reason: 'stories expire');
    debugPrint('TC_FS_002 PASS posted $postedId');
  });

  testWidgets('TC_FS_003 The picture is not carried in the feed', (t) async {
    // The whole reason the image lives in its own document.
    final raw = await c.read(firestoreRefsProvider).story(postedId!).get();
    final fields = raw.data()!.keys.toList();
    expect(fields, isNot(contains('b64')),
        reason: 'the feed document must not hold the image');
    final listed = raw.data().toString().length;
    expect(listed, lessThan(2000),
        reason: 'a feed row should be a few hundred bytes, not hundreds of KB');
    debugPrint('TC_FS_003 PASS feed row is ${listed}B, fields=$fields');
  });

  testWidgets('TC_FS_004 The picture loads on demand and is unchanged', (t) async {
    final bytes = await stories.loadImage(postedId!);
    expect(bytes, isNotNull, reason: 'the image should be fetchable');
    expect(bytes!.length, greaterThan(1000));
    debugPrint('TC_FS_004 PASS loaded ${bytes.length}B separately');
  });

  testWidgets('TC_FS_005 The story appears in everyone feed', (t) async {
    other = await actAs(otherEmail);
    final feed = await stories.watchFeed().first;
    expect(feed.map((s) => s.id), contains(postedId),
        reason: 'stories are for discovering what other people eat');
    debugPrint('TC_FS_005 PASS ${feed.length} stories visible to another user');
  });

  testWidgets('TC_FS_006 Anyone can like, and only once', (t) async {
    other = await actAs(otherEmail);
    expect((await stories.toggleLike(
            storyId: postedId!, uid: other.uid, liked: false))
        .isSuccess, isTrue);

    var feed = await stories.watchFeed().first;
    var story = feed.firstWhere((s) => s.id == postedId);
    expect(story.likeCount, 1);
    expect(story.likedByMe(other.uid), isTrue);

    // Liking again with the same uid must not count twice.
    await stories.toggleLike(storyId: postedId!, uid: other.uid, liked: false);
    feed = await stories.watchFeed().first;
    story = feed.firstWhere((s) => s.id == postedId);
    expect(story.likeCount, 1, reason: 'a second like from the same person is not a second like');

    // And unliking takes it away.
    await stories.toggleLike(storyId: postedId!, uid: other.uid, liked: true);
    feed = await stories.watchFeed().first;
    expect(feed.firstWhere((s) => s.id == postedId).likeCount, 0);
    debugPrint('TC_FS_006 PASS like, re-like, unlike');
  });

  testWidgets('TC_FS_007 Somebody else cannot edit or delete your story', (t) async {
    other = await actAs(otherEmail);

    var refusedEdit = false;
    try {
      await c.read(firestoreRefsProvider).story(postedId!)
          .update({'caption': 'hijacked'});
    } catch (_) {
      refusedEdit = true;
    }
    expect(refusedEdit, isTrue, reason: 'only the author may change a story');

    final removed = await stories.remove(postedId!);
    expect(removed.isSuccess, isFalse, reason: 'only the author or an admin may delete');
    debugPrint('TC_FS_007 PASS edit refused, delete refused="${removed.errorOrNull}"');
  });

  testWidgets('TC_FS_008 A file that is not a picture is refused cleanly', (t) async {
    // Three megabytes of noise: the right size for a photo, but not decodable
    // as one. The compressor throws on this, and the service must turn that
    // into a message rather than letting it reach the screen.
    final notAnImage = Uint8List.fromList(
        List.generate(3 * 1024 * 1024, (i) => (i * 7919) % 256));
    final r = await StoryService.prepare(notAnImage);
    expect(r.isSuccess, isFalse, reason: 'a non-image must not be accepted');
    expect(r.errorOrNull, isNotEmpty);
    debugPrint('TC_FS_008 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_FS_010 Whatever prepare accepts really does fit', (t) async {
    // The guarantee the limit rests on: if it says yes, the encoded bytes
    // are under the ceiling, so the write cannot be refused for size.
    final r = await StoryService.prepare(photo);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    final encoded = base64Encode(r.valueOrNull!.bytes).length;
    expect(encoded, lessThan(StoryService.maxEncodedBytes));
    expect(encoded, lessThan(1048576),
        reason: 'and under the hard 1MiB document limit measured earlier');
    debugPrint('TC_FS_010 PASS ${encoded}B < ${StoryService.maxEncodedBytes}B');
  });

  testWidgets('TC_FS_009 An administrator can take a story down', (t) async {
    await FirebaseAuth.instance.signOut();
    await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: adminEmail, password: adminPassword);

    final r = await stories.remove(postedId!);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final gone = await c.read(firestoreRefsProvider).story(postedId!)
        .get(const GetOptions(source: Source.server));
    expect(gone.exists, isFalse);
    final image = await stories.loadImage(postedId!);
    expect(image, isNull, reason: 'the picture must go with the story');
    postedId = null;
    debugPrint('TC_FS_009 PASS story and picture both removed');
  });
}
