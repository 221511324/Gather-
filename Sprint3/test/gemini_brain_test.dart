import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/models/assistant_message.dart';
import 'package:gather/core/models/restaurant.dart';
import 'package:gather/core/services/assistant_service.dart';
import 'package:gather/core/services/gemini_brain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// US14 — the Gemini-backed assistant, TC_UG_001+.
///
/// The HTTP client is mocked, so nothing here reaches Google or needs a key.
void main() {
  MenuItem item(String id, String name, FoodCategory c, double price,
          {String restaurant = 'r1', bool available = true}) =>
      MenuItem(
        id: id, restaurantId: restaurant, name: name, price: price,
        imageUrl: '', category: c, rating: 4.5, isAvailable: available,
      );

  final catalogue = AssistantContext(
    restaurants: const [
      Restaurant(
          id: 'r1', name: 'Sugar & Spice', cuisine: 'Lebanese', imageUrl: '',
          description: '', rating: 4.6, deliveryFee: 10, deliveryMinutes: 30,
          minimumOrder: 20, isOpen: true),
      Restaurant(
          id: 'r2', name: 'Closed Kitchen', cuisine: 'Italian', imageUrl: '',
          description: '', rating: 4.2, deliveryFee: 12, deliveryMinutes: 15,
          minimumOrder: 25, isOpen: false),
    ],
    items: [
      item('i1', 'Falafel Wrap', FoodCategory.vegan, 22),
      item('i2', 'Chocolate Cake', FoodCategory.dessert, 35),
      item('i3', 'Sold Out Soup', FoodCategory.meal, 30, available: false),
      item('i4', 'Pasta', FoodCategory.meal, 40, restaurant: 'r2'),
    ],
  );

  /// A generateContent response whose model output is [reply].
  http.Response gemini(Map<String, dynamic> reply, {String finish = 'STOP'}) =>
      http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': jsonEncode(reply)}
                ],
              },
              'finishReason': finish,
            }
          ],
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  GeminiBrain brain(MockClientHandler handler) => GeminiBrain(
        apiKey: 'test-key',
        client: MockClient(handler),
        timeout: const Duration(milliseconds: 200),
      );

  const local = RetrievalBrain();

  test('TC_UG_001 a good reply maps ids to the real dishes and restaurants',
      () async {
    final r = await brain((_) async => gemini({
          'text': 'Try the Falafel Wrap.',
          'itemIds': ['i1'],
          'restaurantIds': [],
          'action': 'filterByCategory',
        })).answer('something vegan', catalogue);
    expect(r.text, 'Try the Falafel Wrap.');
    expect(r.action, AssistantAction.filterByCategory);
    expect(r.items.single.name, 'Falafel Wrap');
    expect(r.restaurants.single.id, 'r1',
        reason: 'a dish brings its restaurant, as the local brain does');
  });

  test('TC_UG_002 ids outside the catalogue are dropped', () async {
    final r = await brain((_) async => gemini({
          'text': 'Here you go.',
          // invented, unavailable, and from a closed restaurant
          'itemIds': ['i2', 'ghost', 'i3', 'i4'],
          'restaurantIds': ['nowhere'],
          'action': 'searchMenu',
        })).answer('dessert', catalogue);
    expect(r.items.map((i) => i.id), ['i2']);
    expect(r.restaurants.map((x) => x.id), ['r1']);
  });

  test('TC_UG_003 an API error falls back to the local brain', () async {
    final r = await brain((_) async => http.Response('{"error":{}}', 429))
        .answer('how do i split the bill', catalogue);
    expect(r.text, local.answer('how do i split the bill', catalogue).text);
    expect(r.action, AssistantAction.appHelp);
  });

  test('TC_UG_004 a timeout, a block or broken JSON also fall back', () async {
    final expected = local.answer('something vegan', catalogue).text;

    final slow = brain((_) => Completer<http.Response>().future);
    expect((await slow.answer('something vegan', catalogue)).text, expected);

    final blocked = brain((_) async =>
        http.Response(jsonEncode({'promptFeedback': {'blockReason': 'SAFETY'}}), 200));
    expect((await blocked.answer('something vegan', catalogue)).text, expected);

    final cut = brain((_) async => gemini({'text': 'x'}, finish: 'MAX_TOKENS'));
    expect((await cut.answer('something vegan', catalogue)).text, expected);

    final broken = brain((_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'not json'}
                ]
              },
              'finishReason': 'STOP'
            }
          ]
        }),
        200));
    expect((await broken.answer('something vegan', catalogue)).text, expected);

    final offline = brain((_) async => throw http.ClientException('offline'));
    expect((await offline.answer('something vegan', catalogue)).text, expected);
  });

  test('TC_UG_005 the request carries the language, history and catalogue',
      () async {
    late http.Request sent;
    await brain((req) async {
      sent = req;
      return gemini({
        'text': 'جرّب لفافة الفلافل.',
        'itemIds': ['i1'],
        'restaurantIds': [],
        'action': 'searchMenu',
      });
    }).answer('شيء نباتي', catalogue, languageCode: 'ar', history: [
      for (var n = 0; n < 12; n++)
        AssistantMessage(
            id: '$n',
            role: n.isEven ? ChatRole.user : ChatRole.assistant,
            text: 'turn $n'),
    ]);

    expect(sent.url.toString(), contains(geminiModel));
    expect(sent.headers['x-goog-api-key'], 'test-key');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    final system = body['systemInstruction']['parts'][0]['text'] as String;
    expect(system, contains('Arabic'));
    expect(system, contains('Falafel Wrap'));
    expect(system, isNot(contains('Sold Out Soup')));
    expect(system, contains('Equal split'), reason: 'the app guide is included');

    final contents = body['contents'] as List;
    expect(contents, hasLength(9), reason: 'last 8 turns plus the question');
    expect(contents.first['parts'][0]['text'], 'turn 4');
    expect(contents[1]['role'], 'model');
    expect(contents.last['parts'][0]['text'], 'شيء نباتي');
    expect(body['generationConfig']['responseMimeType'], 'application/json');
  });

  test('TC_UG_006 English is asked for when the app is in English', () {
    final body = GeminiBrain.buildRequest('vegan', catalogue);
    final system = body['systemInstruction']['parts'][0]['text'] as String;
    expect(system, contains('Write "text" in English'));
  });

  test('TC_UG_007 with no key the app uses the local brain', () {
    expect(isUsableGeminiKey(''), isFalse);
    expect(isUsableGeminiKey('paste-your-key-here'), isFalse);
    expect(isUsableGeminiKey('AIza-something'), isTrue);
    // Tests are built without --dart-define-from-file.
    expect(isUsableGeminiKey(geminiApiKey), isFalse);
  });
}
