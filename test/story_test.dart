import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/models/food_story.dart';
import 'package:gather/core/providers/app_prefs.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/features/stories/story_groups.dart';
import 'package:gather/features/stories/story_viewer_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 10, 31, 12);

FoodStory _story(String id, String author, int minutesAgo, {bool expired = false}) => FoodStory(
      id: id,
      authorId: author,
      authorName: 'Name $author',
      createdAt: _now.subtract(Duration(minutes: minutesAgo)),
      expiresAt: expired
          ? _now.subtract(const Duration(minutes: 1))
          : _now.add(const Duration(hours: 20)),
    );

void main() {
  group('groupStories', () {
    test('groups by author, newest author first, stories oldest first', () {
      final groups = groupStories([
        _story('a1', 'ana', 30),
        _story('b1', 'bo', 5),
        _story('a2', 'ana', 10),
        _story('c1', 'cy', 60),
      ], now: _now);
      expect(groups.map((g) => g.authorId), ['bo', 'ana', 'cy']);
      expect(groups[1].stories.map((s) => s.id), ['a1', 'a2']);
      expect(groups[1].latest.id, 'a2');
    });

    test('drops expired stories and collapses duplicates', () {
      final groups = groupStories([
        _story('a1', 'ana', 30),
        _story('a1', 'ana', 30),
        _story('x', 'old', 2000, expired: true),
      ], now: _now);
      expect(groups, hasLength(1));
      expect(groups.single.stories, hasLength(1));
    });

    test('a story without a server timestamp yet counts as newest', () {
      final pending = FoodStory(
          id: 'p', authorId: 'me', authorName: 'Me', expiresAt: DateTime.now().add(const Duration(hours: 1)));
      final earlier = FoodStory(
          id: 'b1',
          authorId: 'bo',
          authorName: 'Bo',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          expiresAt: DateTime.now().add(const Duration(hours: 1)));
      final groups = groupStories([earlier, pending]);
      expect(groups.first.authorId, 'me');
    });

    test('seen state and where to start', () {
      final g = groupStories([_story('a1', 'ana', 30), _story('a2', 'ana', 10)], now: _now).single;
      expect(g.allSeen({}), isFalse);
      expect(g.firstUnseen({'a1'}), 1);
      expect(g.allSeen({'a1', 'a2'}), isTrue);
      expect(g.firstUnseen({'a1', 'a2'}), 0);
    });
  });

  group('viewingOrder', () {
    final groups = groupStories([
      _story('m', 'me', 1),
      _story('a', 'ana', 2),
      _story('b', 'bo', 3),
      _story('c', 'cy', 4),
    ], now: _now);

    test('from someone else: them and those after, never yourself', () {
      expect(viewingOrder(groups, 'bo', 'me'), ['bo', 'cy']);
    });

    test('from your own: you, then everyone else', () {
      expect(viewingOrder(groups, 'me', 'me'), ['me', 'ana', 'bo', 'cy']);
    });

    test('an author with nothing live gives nothing to show', () {
      expect(viewingOrder(groups, 'gone', 'me'), isEmpty);
    });
  });

  group('SeenStories', () {
    test('persists and caps what it keeps', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPrefs.load();
      final seen = SeenStories(prefs);
      for (var i = 0; i < SeenStories.keep + 5; i++) {
        seen.markSeen('s$i');
      }
      expect(seen.state, hasLength(SeenStories.keep));
      expect(seen.state.contains('s0'), isFalse);
      expect(seen.state.contains('s${SeenStories.keep + 4}'), isTrue);
      expect(SeenStories(prefs).state, seen.state);
    });
  });

  group('StoryViewerScreen', () {
    Future<void> pumpViewer(WidgetTester tester, List<FoodStory> stories, String author,
        {TextDirection direction = TextDirection.ltr}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPrefs.load();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
          GoRoute(
            path: '/v/:a',
            builder: (_, s) => Directionality(
              textDirection: direction,
              child: StoryViewerScreen(authorId: s.pathParameters['a']!),
            ),
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          appPrefsProvider.overrideWithValue(prefs),
          currentUidProvider.overrideWithValue('me'),
          isAdminProvider.overrideWithValue(false),
          storyFeedProvider.overrideWith((ref) => Stream.value(stories)),
          myStoriesProvider.overrideWith((ref) => Stream.value(const [])),
          storyImageProvider.overrideWith((ref, id) async => null as Uint8List?),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      router.push('/v/$author');
      // Not pumpAndSettle: the story timer never settles until the end.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Recent stories, so they are live whatever the clock says.
    FoodStory live(String id, String author, int minutesAgo) => FoodStory(
          id: id,
          authorId: author,
          authorName: 'Name $author',
          caption: 'caption $id',
          createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );

    testWidgets('advances by tap and by time, then on to the next author, then closes',
        (tester) async {
      await pumpViewer(tester, [live('a1', 'ana', 3), live('a2', 'ana', 2), live('b1', 'bo', 4)], 'ana');
      expect(find.text('caption a1'), findsOneWidget);
      expect(find.text('This photo could not be loaded'), findsOneWidget);

      // Right side moves forward in English.
      final size = tester.getSize(find.byKey(const Key('story-viewer')));
      await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
      await tester.pump();
      expect(find.text('caption a2'), findsOneWidget);

      // Left side goes back.
      await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
      await tester.pump();
      expect(find.text('caption a1'), findsOneWidget);

      // Waiting moves on: a1 -> a2 -> bo's b1. The timer starts once the
      // picture has loaded (here: failed to), a frame or two after the switch.
      Future<void> waitOneStory() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 5100));
        await tester.pump();
      }

      await waitOneStory();
      expect(find.text('caption a2'), findsOneWidget);
      await waitOneStory();
      expect(find.text('caption b1'), findsOneWidget);

      await waitOneStory();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('taps are mirrored in Arabic', (tester) async {
      await pumpViewer(tester, [live('a1', 'ana', 3), live('a2', 'ana', 2)], 'ana',
          direction: TextDirection.rtl);
      final size = tester.getSize(find.byKey(const Key('story-viewer')));
      // The left is "forward" when reading right to left.
      await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
      await tester.pump();
      // Captions are isolated in RTL, so match inside the marks.
      expect(find.textContaining('caption a2'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
      await tester.pump();
      expect(find.textContaining('caption a1'), findsOneWidget);
    });

    testWidgets('a gone author shows a message and closes', (tester) async {
      await pumpViewer(tester, [live('a1', 'ana', 3)], 'nobody');
      expect(find.text('This story is no longer available'), findsOneWidget);
      await tester.tap(find.byKey(const Key('story-close')));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
