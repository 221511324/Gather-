import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/assistant_message.dart';
import 'assistant_service.dart';

/// The hosted model the assistant talks to. One place to change it.
const geminiModel = 'gemini-3.5-flash-lite';

/// Supplied at build time with `--dart-define-from-file=config/secrets.json`.
/// Empty in tests, CI and any build made without the file, which keeps the
/// assistant on [RetrievalBrain].
const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Whether [key] is a real key rather than nothing or the committed
/// placeholder from config/secrets.example.json.
bool isUsableGeminiKey(String key) =>
    key.trim().isNotEmpty && key.trim() != 'paste-your-key-here';

/// Answers with Google's Gemini, grounded in Gather's own catalogue.
///
/// The model sees only the open restaurants and available dishes it is sent,
/// and replies in a fixed JSON shape naming dishes by id. Every id is checked
/// against that catalogue and anything unknown is dropped, so the cards under
/// an answer can only ever point at something that can actually be ordered.
/// Whenever the call fails — offline, timed out, blocked, a reply that does
/// not parse — the question goes to [fallback] instead, so the person always
/// gets an answer and never sees an API error.
class GeminiBrain implements AssistantBrain {
  GeminiBrain({
    required this.apiKey,
    http.Client? client,
    this.fallback = const RetrievalBrain(),
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final AssistantBrain fallback;
  final Duration timeout;
  final http.Client _client;

  static final endpoint = Uri.parse('https://generativelanguage.googleapis.com'
      '/v1beta/models/$geminiModel:generateContent');

  // Keeps the request small however large the catalogue grows.
  static const _maxItems = 120;
  static const _maxRestaurants = 40;
  static const _maxDescription = 80;
  static const _historyTurns = 8;
  static const _maxSuggestions = 4;

  @override
  Future<AssistantReply> answer(
    String question,
    AssistantContext context, {
    String languageCode = 'en',
    List<AssistantMessage> history = const [],
  }) async {
    Future<AssistantReply> local() async => fallback.answer(question, context,
        languageCode: languageCode, history: history);

    if (question.trim().isEmpty) return local();
    try {
      final res = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode(buildRequest(question.trim(), context,
                languageCode: languageCode, history: history)),
          )
          .timeout(timeout);
      if (res.statusCode != 200) return await local();
      return parseReply(utf8.decode(res.bodyBytes), context) ?? await local();
    } catch (_) {
      // Network, timeout or a body that is not JSON: answer locally instead.
      return local();
    }
  }

  // ------------------------------------------------------------ request ---

  /// The generateContent body. Public so tests can inspect it.
  static Map<String, dynamic> buildRequest(
    String question,
    AssistantContext context, {
    String languageCode = 'en',
    List<AssistantMessage> history = const [],
  }) {
    final turns = history.length > _historyTurns
        ? history.sublist(history.length - _historyTurns)
        : history;
    return {
      'systemInstruction': {
        'parts': [
          {'text': _instructions(languageCode, context)}
        ],
      },
      'contents': [
        for (final m in turns)
          if (m.text.trim().isNotEmpty)
            {
              'role': m.isUser ? 'user' : 'model',
              'parts': [
                {'text': m.text}
              ],
            },
        {
          'role': 'user',
          'parts': [
            {'text': question}
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 2048,
        'responseMimeType': 'application/json',
        'responseSchema': _schema,
      },
    };
  }

  static final _schema = {
    'type': 'OBJECT',
    'properties': {
      'text': {'type': 'STRING'},
      'itemIds': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'restaurantIds': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'action': {
        'type': 'STRING',
        'enum': [for (final a in AssistantAction.values) a.name],
      },
    },
    'required': ['text', 'itemIds', 'restaurantIds', 'action'],
    'propertyOrdering': ['text', 'itemIds', 'restaurantIds', 'action'],
  };

  static String _instructions(String languageCode, AssistantContext context) {
    final language = languageCode == 'ar'
        ? 'Arabic (clear Modern Standard Arabic; keep dish and restaurant names '
            'as they appear in the catalogue)'
        : 'English';
    final help = RetrievalBrain.helpTopics.entries
        .map((e) => '- ${e.key}: ${e.value}')
        .join('\n');
    return '''
You are the food assistant inside Gather, a group food-ordering app for a university campus in Saudi Arabia. Friends start a group session, each adds dishes, and they split the bill.

Rules:
- Only recommend restaurants and dishes from the CATALOGUE below. Never invent a dish, restaurant, price or rating. If nothing fits, say so and suggest something close that is in the catalogue.
- Prices are in Saudi riyals (SAR).
- You may also explain how to use Gather, using only the APP GUIDE below.
- Politely decline anything unrelated to food or to using Gather.
- Be concise: two or three short sentences, friendly, no markdown, no ids in the text.
- Write "text" in $language.
- Put the ids of the dishes you recommend in "itemIds" (at most $_maxSuggestions) and of the restaurants you mention in "restaurantIds".
- "action" says how you answered: searchMenu, filterByCategory, filterByBudget, topRated, restaurantLookup, fastestDelivery, appHelp, or none for small talk.

APP GUIDE:
$help

CATALOGUE (JSON; restaurants: id, name, cuisine, rating, deliveryMinutes, deliveryFee, open, tags; items: id, restaurantId, name, price, category, rating, calories, bestSeller, description):
${jsonEncode(catalogue(context))}
''';
  }

  /// The compact catalogue the model may answer from: every restaurant (so it
  /// can say one is closed) and the available dishes of the open ones.
  static Map<String, dynamic> catalogue(AssistantContext context) {
    final restaurants = [...context.restaurants]
      ..sort((a, b) => (b.isOpen ? 1 : 0).compareTo(a.isOpen ? 1 : 0));
    final open = {for (final r in context.restaurants) if (r.isOpen) r.id};
    final items = context.items
        .where((i) => i.isAvailable && open.contains(i.restaurantId))
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return {
      'restaurants': [
        for (final r in restaurants.take(_maxRestaurants))
          {
            'id': r.id,
            'name': r.name,
            'cuisine': r.cuisine,
            'rating': _round(r.rating),
            'deliveryMinutes': r.deliveryMinutes,
            'deliveryFee': _round(r.deliveryFee),
            'open': r.isOpen,
            if (r.tags.isNotEmpty) 'tags': r.tags,
          },
      ],
      'items': [
        for (final i in items.take(_maxItems))
          {
            'id': i.id,
            'restaurantId': i.restaurantId,
            'name': i.name,
            'price': _round(i.price),
            'category': i.category.name,
            'rating': _round(i.rating),
            if (i.calories != null) 'calories': i.calories,
            if (i.isBestSeller) 'bestSeller': true,
            if (i.description.isNotEmpty)
              'description': i.description.length > _maxDescription
                  ? '${i.description.substring(0, _maxDescription)}…'
                  : i.description,
          },
      ],
    };
  }

  static num _round(double v) =>
      v == v.roundToDouble() ? v.round() : double.parse(v.toStringAsFixed(1));

  // ----------------------------------------------------------- response ---

  /// Turns a generateContent response into a reply, or null when it cannot be
  /// trusted — blocked, cut off, empty, or not the JSON that was asked for.
  static AssistantReply? parseReply(String body, AssistantContext context) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final reason = first['finishReason'];
    if (reason != null && reason != 'STOP') return null;
    final parts = (first['content'] as Map?)?['parts'];
    if (parts is! List) return null;
    final raw = parts
        .whereType<Map>()
        .map((p) => p['text'])
        .whereType<String>()
        .join();
    if (raw.trim().isEmpty) return null;

    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final text = json['text'];
    if (text is! String || text.trim().isEmpty) return null;

    // Only what was actually in the catalogue survives.
    final sent = catalogue(context);
    final itemIds = {for (final i in sent['items'] as List) (i as Map)['id']};
    final restaurantIds = {
      for (final r in sent['restaurants'] as List) (r as Map)['id']
    };
    List<String> ids(Object? v) =>
        v is List ? v.whereType<String>().toSet().toList() : const [];

    final items = [
      for (final id in ids(json['itemIds']))
        if (itemIds.contains(id))
          context.items.firstWhere((i) => i.id == id),
    ].take(_maxSuggestions).toList();
    final restaurants = [
      for (final id in ids(json['restaurantIds']))
        if (restaurantIds.contains(id))
          context.restaurants.firstWhere((r) => r.id == id),
    ];
    // The dishes' own restaurants, as the local brain gives them.
    for (final i in items) {
      final r = context.restaurantFor(i);
      if (r != null && !restaurants.any((x) => x.id == r.id)) restaurants.add(r);
    }

    final named = json['action'];
    var action = AssistantAction.values
            .where((a) => a.name == named)
            .firstOrNull ??
        AssistantAction.none;
    if (action == AssistantAction.none && items.isNotEmpty) {
      action = AssistantAction.searchMenu;
    }

    return AssistantReply(
      text: text.trim(),
      action: action,
      items: items,
      restaurants: restaurants,
    );
  }
}
