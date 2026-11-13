import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gather/core/models/models.dart';
import 'package:gather/core/providers/providers.dart';
import 'package:gather/core/services/assistant_service.dart';
import 'package:gather/firebase_options.dart';

/// Sprint 3 — the food assistant, TC_A_001 to TC_A_006.
///
/// US14  As a user, I want food recommendations and answers to food and
///       restaurant questions, so that I can decide what to order.
///
/// These run against the real catalogue and the real database, so they also
/// prove the transcript is stored under the right account and that one person
/// cannot read another's conversation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const password = 'TestPass123!';
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final meEmail = 'a3me$stamp@gather-test.local';
  final otherEmail = 'a3other$stamp@gather-test.local';

  late ProviderContainer c;
  late AssistantService assistant;
  late AssistantContext catalogue;
  late AppUser me;

  Future<AppUser> actAs(String email) async {
    await FirebaseAuth.instance.signOut();
    final r = await c.read(authServiceProvider).signIn(email: email, password: password);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    return r.valueOrNull!;
  }

  setUpAll(() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    c = ProviderContainer();
    assistant = c.read(assistantServiceProvider);
    final auth = c.read(authServiceProvider);

    for (final (email, name, i) in [(meEmail, 'A Me', 0), (otherEmail, 'A Other', 1)]) {
      final r = await auth.signUp(
          fullName: name, username: 'a3u$i$stamp', email: email,
          phone: '+9665900$i${stamp % 10000}', password: password);
      expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
      if (i == 0) me = r.valueOrNull!;
    }

    me = await actAs(meEmail);
    final catalog = c.read(catalogServiceProvider);
    final restaurants = await catalog.fetchRestaurants();
    final items = <MenuItem>[];
    for (final r in restaurants) {
      items.addAll(await catalog.fetchMenu(r.id));
    }
    catalogue = AssistantContext(restaurants: restaurants, items: items);
    expect(items, isNotEmpty, reason: 'the catalogue must be seeded');
    debugPrint('CATALOGUE ${restaurants.length} restaurants, ${items.length} dishes');
  });

  tearDownAll(() async {
    me = await actAs(meEmail);
    await assistant.clear(me.uid);
    c.dispose();
  });

  testWidgets('TC_A_001 It recommends real dishes from the live menu', (t) async {
    me = await actAs(meEmail);
    final r = await assistant.ask(
        uid: me.uid, question: 'what is the best dessert?', context: catalogue);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final answer = r.valueOrNull!;
    expect(answer.text, isNotEmpty);
    expect(answer.itemIds, isNotEmpty, reason: 'it should name something');

    // Everything it named must be a dish that really exists and is available.
    final live = {for (final i in catalogue.items) i.id: i};
    for (final id in answer.itemIds) {
      expect(live.containsKey(id), isTrue, reason: 'invented dish $id');
      expect(live[id]!.isAvailable, isTrue, reason: 'suggested an unavailable dish');
    }
    debugPrint('TC_A_001 PASS "${answer.text}"');
  });

  testWidgets('TC_A_002 It respects a budget', (t) async {
    final r = await assistant.ask(
        uid: me.uid, question: 'something to eat under 25 SAR', context: catalogue);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');

    final live = {for (final i in catalogue.items) i.id: i};
    for (final id in r.valueOrNull!.itemIds) {
      expect(live[id]!.price, lessThanOrEqualTo(25),
          reason: '${live[id]!.name} is over the budget that was asked for');
    }
    debugPrint('TC_A_002 PASS "${r.valueOrNull!.text}"');
  });

  testWidgets('TC_A_003 It answers a question about using Gather', (t) async {
    final r = await assistant.ask(
        uid: me.uid, question: 'how do I split the bill?', context: catalogue);
    expect(r.isSuccess, isTrue, reason: r.errorOrNull ?? '');
    expect(r.valueOrNull!.action, AssistantAction.appHelp);
    debugPrint('TC_A_003 PASS "${r.valueOrNull!.text}"');
  });

  testWidgets('TC_A_004 The conversation is kept, question and answer', (t) async {
    final conversation = await assistant.watchConversation(me.uid).first;
    expect(conversation.length, greaterThanOrEqualTo(6),
        reason: 'three exchanges so far, two messages each');
    expect(conversation.where((m) => m.isUser).length,
        conversation.where((m) => !m.isUser).length,
        reason: 'every question should have exactly one answer');
    // Stored in order.
    for (var i = 0; i < conversation.length - 1; i += 2) {
      expect(conversation[i].isUser, isTrue);
      expect(conversation[i + 1].isUser, isFalse);
    }
    debugPrint('TC_A_004 PASS ${conversation.length} messages in order');
  });

  testWidgets('TC_A_005 An empty question is refused', (t) async {
    final r = await assistant.ask(uid: me.uid, question: '   ', context: catalogue);
    expect(r.isSuccess, isFalse);
    debugPrint('TC_A_005 PASS refused="${r.errorOrNull}"');
  });

  testWidgets('TC_A_006 Nobody can read somebody else conversation', (t) async {
    await actAs(otherEmail);
    // Signed in as someone else, reading my transcript must fail.
    // Forced to the server: a snapshot listener can hand back what this
    // device already cached while signed in as the other account, which looks
    // like a successful read but never reached Firestore.
    var refused = false;
    String detail = 'no error - the read SUCCEEDED';
    try {
      final stolen = await c
          .read(firestoreRefsProvider)
          .aiChat(me.uid)
          .get(const GetOptions(source: Source.server));
      detail = 'read ${stolen.docs.length} messages belonging to someone else';
    } catch (e) {
      refused = true;
      detail = e.toString().split('\n').first;
    }
    debugPrint('TC_A_006 refused=$refused detail="$detail"');
    expect(refused, isTrue,
        reason: 'a conversation is private to the account that holds it');
    debugPrint('TC_A_006 PASS the database refused the read');
  });
}
