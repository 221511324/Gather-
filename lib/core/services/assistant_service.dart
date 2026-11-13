import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/assistant_message.dart';
import '../models/restaurant.dart';
import 'firestore_refs.dart';
import 'result.dart';

/// What the assistant knows about when it answers. Supplied by the caller so
/// the brain itself touches no network and can be tested without Firebase.
class AssistantContext {
  const AssistantContext({required this.restaurants, required this.items});

  final List<Restaurant> restaurants;
  final List<MenuItem> items;

  Restaurant? restaurantFor(MenuItem item) {
    for (final r in restaurants) {
      if (r.id == item.restaurantId) return r;
    }
    return null;
  }
}

/// What a single turn produced.
class AssistantReply {
  const AssistantReply({
    required this.text,
    this.action = AssistantAction.none,
    this.items = const [],
    this.restaurants = const [],
  });

  final String text;
  final AssistantAction action;
  final List<MenuItem> items;
  final List<Restaurant> restaurants;
}

/// Anything that can turn a question into an answer.
///
/// [RetrievalBrain] answers from the catalogue on the device and needs
/// nothing else. [GeminiBrain] (gemini_brain.dart) asks a hosted model when
/// the build carries an API key, and falls back to [RetrievalBrain] whenever
/// that call fails. Nothing above this interface knows which one it has.
///
/// [languageCode] is the app's language, so a model can reply in it, and
/// [history] the conversation so far; the local brain needs neither.
abstract interface class AssistantBrain {
  FutureOr<AssistantReply> answer(
    String question,
    AssistantContext context, {
    String languageCode,
    List<AssistantMessage> history,
  });
}

/// Answers food questions from Gather's own catalogue.
///
/// The shape is the one a tool-calling assistant uses: read the question,
/// decide which lookup answers it, run that lookup against real data, and
/// write the answer from what came back. The difference from a hosted model
/// is only in how the first step is done — here it is matched against known
/// phrasings rather than inferred by a language model — so every answer is
/// grounded in a dish that actually exists and the assistant cannot invent a
/// restaurant or a price.
class RetrievalBrain implements AssistantBrain {
  const RetrievalBrain();

  static const _maxSuggestions = 3;

  // Which words point at which lookup. Order matters: the first match wins,
  // so the more specific intents are listed before the general ones.
  static const _categoryWords = {
    FoodCategory.vegan: ['vegan', 'vegetarian', 'plant based', 'plant-based', 'veggie'],
    FoodCategory.dessert: ['dessert', 'sweet', 'cake', 'ice cream', 'pudding', 'pastry'],
    FoodCategory.drinks: ['drink', 'juice', 'coffee', 'tea', 'latte', 'smoothie', 'thirsty'],
    FoodCategory.snacks: ['snack', 'light bite', 'starter', 'appetiser', 'appetizer'],
    FoodCategory.meal: ['meal', 'lunch', 'dinner', 'main', 'hungry', 'filling'],
  };

  /// How to use Gather. Also handed to [GeminiBrain] as its app guide.
  static const helpTopics = {
    'split': 'Open the session, tap Payment, and choose how to divide it. '
        'Equal split shares the bill evenly, Individual charges each person for '
        'what they added, and Host pays covers everyone. The split is worked out '
        'in whole halalas so the parts always add back to the total.',
    'invite': 'Open your session and tap Invite. You can share the four-digit '
        'code, send the link, or search for someone by username. A session holds '
        'up to 20 people.',
    'join': 'Go to the Group tab and tap Join, then type the four-digit code the '
        'host gave you.',
    'track': 'Open the order from the Orders tab. You will see each stage and, '
        'once a driver is assigned, their position on the map.',
    'cancel': 'A host can cancel a session from the session menu. An order can be '
        'cancelled from the order screen while it is still being prepared.',
    'favourite': 'Tap the heart on any restaurant or dish and it is saved to your '
        'favourites in the Profile tab.',
    'pay': 'Add a card or another payment method under Profile, Payment methods. '
        'The methods offered are the ones the administrator has enabled.',
  };

  @override
  AssistantReply answer(
    String question,
    AssistantContext context, {
    String languageCode = 'en',
    List<AssistantMessage> history = const [],
  }) {
    final q = question.toLowerCase().trim();
    if (q.isEmpty) {
      return const AssistantReply(text: 'Ask me what to eat and I will look.');
    }

    // 1 — is this about using Gather rather than about food?
    final help = _appHelp(q);
    if (help != null) return help;

    // 2 — a named restaurant.
    final named = _namedRestaurant(q, context);
    if (named != null) return named;

    // 3 — otherwise it is a dish search, narrowed by whatever was asked for.
    return _recommend(q, context);
  }

  // ------------------------------------------------------------- lookups ---

  AssistantReply? _appHelp(String q) {
    const asksHow = ['how do i', 'how can i', 'how to', 'where do i', 'what is'];
    if (!asksHow.any(q.contains)) return null;
    for (final entry in helpTopics.entries) {
      if (q.contains(entry.key)) {
        return AssistantReply(text: entry.value, action: AssistantAction.appHelp);
      }
    }
    return null;
  }

  AssistantReply? _namedRestaurant(String q, AssistantContext context) {
    for (final r in context.restaurants) {
      final name = r.name.toLowerCase();
      // Only treat it as a restaurant question if the whole name is mentioned;
      // a one-word match would catch far too much.
      if (name.length >= 4 && q.contains(name)) {
        final menu = context.items
            .where((i) => i.restaurantId == r.id && i.isAvailable)
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        if (menu.isEmpty) {
          return AssistantReply(
            text: '${r.name} has nothing on the menu right now.',
            action: AssistantAction.restaurantLookup,
            restaurants: [r],
          );
        }
        final picks = menu.take(_maxSuggestions).toList();
        return AssistantReply(
          text: '${r.name} is ${r.isOpen ? 'open' : 'closed at the moment'} — '
              '${r.cuisine}, rated ${r.rating.toStringAsFixed(1)}, about '
              '${r.deliveryMinutes} minutes. The best rated there: '
              '${_list(picks)}.',
          action: AssistantAction.restaurantLookup,
          items: picks,
          restaurants: [r],
        );
      }
    }
    return null;
  }

  AssistantReply _recommend(String q, AssistantContext context) {
    var pool = context.items.where((i) => i.isAvailable).toList();
    var action = AssistantAction.searchMenu;
    final describedAs = <String>[];

    // Narrow by category.
    final category = _categoryIn(q);
    if (category != null) {
      pool = pool.where((i) => i.category == category).toList();
      action = AssistantAction.filterByCategory;
      describedAs.add(_categoryName(category));
    }

    // Narrow by budget.
    final budget = _budgetIn(q);
    if (budget != null) {
      pool = pool.where((i) => i.price <= budget).toList();
      action = AssistantAction.filterByBudget;
      describedAs.add('under ${budget.toStringAsFixed(0)} SAR');
    }

    // Narrow by anything else named in the question — a dish, an ingredient.
    final words = q
        .split(RegExp(r'[^a-z]+'))
        .where((w) => w.length > 3 && !_stopWords.contains(w))
        .toList();
    if (words.isNotEmpty) {
      final matched = pool.where((i) {
        final hay = '${i.name} ${i.description}'.toLowerCase();
        return words.any(hay.contains);
      }).toList();
      if (matched.isNotEmpty) pool = matched;
    }

    // Fastest delivery is about restaurants, not dishes.
    if (q.contains('fast') || q.contains('quick') || q.contains('soon')) {
      final open = context.restaurants.where((r) => r.isOpen).toList()
        ..sort((a, b) => a.deliveryMinutes.compareTo(b.deliveryMinutes));
      if (open.isNotEmpty) {
        final picks = open.take(_maxSuggestions).toList();
        return AssistantReply(
          text: 'Quickest right now: ${picks.map((r) => '${r.name} '
              '(about ${r.deliveryMinutes} min)').join(', ')}.',
          action: AssistantAction.fastestDelivery,
          restaurants: picks,
        );
      }
    }

    if (pool.isEmpty) {
      return AssistantReply(
        text: describedAs.isEmpty
            ? 'I could not find anything matching that. Try naming a dish, a '
                'category like dessert or vegan, or a budget.'
            : 'Nothing ${describedAs.join(' ')} is available right now.',
        action: action,
      );
    }

    // Rank: by rating, unless the question is about price.
    final wantsCheap = q.contains('cheap') || q.contains('budget') ||
        q.contains('afford') || budget != null;
    if (wantsCheap) {
      pool.sort((a, b) => a.price.compareTo(b.price));
    } else {
      pool.sort((a, b) {
        final byBest = (b.isBestSeller ? 1 : 0).compareTo(a.isBestSeller ? 1 : 0);
        return byBest != 0 ? byBest : b.rating.compareTo(a.rating);
      });
      if (q.contains('best') || q.contains('top') || q.contains('popular')) {
        action = AssistantAction.topRated;
      }
    }

    final picks = pool.take(_maxSuggestions).toList();
    final lead = describedAs.isEmpty
        ? 'Here is what I would order'
        : 'For something ${describedAs.join(' ')}';
    return AssistantReply(
      text: '$lead: ${_listWithContext(picks, context)}.',
      action: action,
      items: picks,
      restaurants: [
        for (final i in picks)
          if (context.restaurantFor(i) != null) context.restaurantFor(i)!,
      ],
    );
  }

  // ------------------------------------------------------------- helpers ---

  static const _stopWords = {
    'what', 'some', 'something', 'want', 'like', 'have', 'there', 'that', 'this',
    'with', 'from', 'about', 'would', 'could', 'should', 'please', 'give', 'show',
    'find', 'under', 'less', 'than', 'good', 'best', 'cheap', 'food', 'order',
    'recommend', 'suggestion', 'suggest', 'anything', 'eat',
  };

  FoodCategory? _categoryIn(String q) {
    for (final entry in _categoryWords.entries) {
      if (entry.value.any(q.contains)) return entry.key;
    }
    return null;
  }

  static String _categoryName(FoodCategory c) => switch (c) {
        FoodCategory.vegan => 'vegan',
        FoodCategory.dessert => 'sweet',
        FoodCategory.drinks => 'to drink',
        FoodCategory.snacks => 'light',
        FoodCategory.meal => 'filling',
      };

  /// Pulls a number out of "under 30", "less than 25 riyals", "max 40".
  double? _budgetIn(String q) {
    final m = RegExp(r'(?:under|below|less than|max|maximum|up to|within)\s*'
            r'(\d+(?:\.\d+)?)')
        .firstMatch(q);
    if (m != null) return double.tryParse(m.group(1)!);
    final riyals = RegExp(r'(\d+(?:\.\d+)?)\s*(?:sar|riyal|riyals)').firstMatch(q);
    if (riyals != null) return double.tryParse(riyals.group(1)!);
    return null;
  }

  String _list(List<MenuItem> items) =>
      items.map((i) => '${i.name} (${i.price.toStringAsFixed(0)} SAR)').join(', ');

  String _listWithContext(List<MenuItem> items, AssistantContext context) =>
      items.map((i) {
        final r = context.restaurantFor(i);
        final where = r == null ? '' : ' at ${r.name}';
        return '${i.name}$where (${i.price.toStringAsFixed(0)} SAR)';
      }).join(', ');
}

/// US14 — the food assistant.
///
/// Holds the conversation in Firestore under the person's own account, and
/// hands each question to an [AssistantBrain] along with the catalogue it may
/// answer from.
class AssistantService {
  AssistantService(this.refs, {this.brain = const RetrievalBrain()});

  final FirestoreRefs refs;
  final AssistantBrain brain;
  static const _uuid = Uuid();

  Stream<List<AssistantMessage>> watchConversation(String uid) => refs
      .aiChat(uid)
      .orderBy('seq')
      .snapshots()
      .map((s) => s.docs
          .where((d) => d.id != '_schema')
          .map((d) => AssistantMessage.fromMap(d.id, d.data()))
          .toList());

  /// Answers one question and stores both sides of the exchange.
  ///
  /// [languageCode] and [history] are passed to the brain so a hosted model
  /// can answer in the app's language and follow the conversation.
  Future<Result<AssistantMessage>> ask({
    required String uid,
    required String question,
    required AssistantContext context,
    String languageCode = 'en',
    List<AssistantMessage> history = const [],
  }) async {
    final text = question.trim();
    if (text.isEmpty) return const Err('Type a question first');

    try {
      final reply = await brain.answer(text, context,
          languageCode: languageCode, history: history);

      // Two slots per exchange, so the question always precedes its answer.
      final slot = DateTime.now().millisecondsSinceEpoch * 2;

      final batch = refs.db.batch();
      batch.set(refs.aiChat(uid).doc(_uuid.v4()), {
        ...AssistantMessage(id: '', role: ChatRole.user, text: text, seq: slot)
            .toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      final answerId = _uuid.v4();
      final answer = AssistantMessage(
        id: answerId,
        role: ChatRole.assistant,
        text: reply.text,
        action: reply.action,
        itemIds: reply.items.map((i) => i.id).toList(),
        restaurantIds: reply.restaurants.map((r) => r.id).toSet().toList(),
        seq: slot + 1,
      );
      batch.set(refs.aiChat(uid).doc(answerId), {
        ...answer.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return Ok(answer);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'The assistant could not answer just now');
    }
  }

  /// Clears the transcript. The person's own data, so their own decision.
  Future<Result<void>> clear(String uid) async {
    try {
      final docs = await refs.aiChat(uid).get();
      final batch = refs.db.batch();
      for (final d in docs.docs) {
        if (d.id != '_schema') batch.delete(d.reference);
      }
      await batch.commit();
      return const Ok(null);
    } on FirebaseException catch (e) {
      return Err(e.message ?? 'Could not clear the conversation');
    }
  }
}
