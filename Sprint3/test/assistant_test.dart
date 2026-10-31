import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/models/assistant_message.dart';
import 'package:gather/core/models/restaurant.dart';
import 'package:gather/core/services/assistant_service.dart';

/// US14 unit tests — the assistant answers from the catalogue, TC_UA_001+.
///
/// The brain takes a question and a catalogue and returns an answer, touching
/// no network, so every one of these runs without a device or Firebase.
void main() {
  MenuItem item(String id, String name, FoodCategory c, double price,
          {double rating = 4.0, bool best = false, String desc = '',
          String restaurant = 'r1', bool available = true}) =>
      MenuItem(
        id: id, restaurantId: restaurant, name: name, price: price,
        imageUrl: '', category: c, description: desc, rating: rating,
        isAvailable: available, isBestSeller: best,
      );

  final restaurants = [
    const Restaurant(
        id: 'r1', name: 'Sugar & Spice', cuisine: 'Lebanese', imageUrl: '',
        description: '', rating: 4.6, deliveryFee: 10, deliveryMinutes: 30,
        minimumOrder: 20, isOpen: true),
    const Restaurant(
        id: 'r2', name: 'Olive Grove', cuisine: 'Italian', imageUrl: '',
        description: '', rating: 4.2, deliveryFee: 12, deliveryMinutes: 15,
        minimumOrder: 25, isOpen: true),
  ];

  final items = [
    item('i1', 'Falafel Wrap', FoodCategory.vegan, 22, rating: 4.8, desc: 'chickpea'),
    item('i2', 'Chocolate Cake', FoodCategory.dessert, 35, rating: 4.9, best: true),
    item('i3', 'Mint Lemonade', FoodCategory.drinks, 14, rating: 4.3),
    item('i4', 'Lamb Mandi', FoodCategory.meal, 75, rating: 4.7, restaurant: 'r2'),
    item('i5', 'Cheap Cookie', FoodCategory.dessert, 8, rating: 3.9),
    item('i6', 'Sold Out Soup', FoodCategory.meal, 30, available: false),
  ];

  final context = AssistantContext(restaurants: restaurants, items: items);
  const brain = RetrievalBrain();

  group('US14 — food recommendations', () {
    test('TC_UA_001 a category question returns only that category', () {
      final r = brain.answer('I want something vegan', context);
      expect(r.action, AssistantAction.filterByCategory);
      expect(r.items, isNotEmpty);
      expect(r.items.every((i) => i.category == FoodCategory.vegan), isTrue);
      expect(r.text, contains('Falafel Wrap'));
    });

    test('TC_UA_002 a budget is respected', () {
      final r = brain.answer('something sweet under 10', context);
      expect(r.action, AssistantAction.filterByBudget);
      expect(r.items, isNotEmpty);
      expect(r.items.every((i) => i.price <= 10), isTrue,
          reason: 'nothing above the stated budget may be suggested');
      expect(r.text, contains('Cheap Cookie'));
    });

    test('TC_UA_003 an unavailable dish is never suggested', () {
      final r = brain.answer('soup', context);
      expect(r.items.map((i) => i.name), isNot(contains('Sold Out Soup')));
    });

    test('TC_UA_004 asking for the best ranks by rating and bestseller', () {
      final r = brain.answer('what is the best dessert', context);
      expect(r.items.first.name, 'Chocolate Cake');
    });

    test('TC_UA_005 naming a restaurant looks that restaurant up', () {
      final r = brain.answer('what is good at Sugar & Spice', context);
      expect(r.action, AssistantAction.restaurantLookup);
      expect(r.restaurants.single.id, 'r1');
      expect(r.text, contains('Lebanese'));
    });

    test('TC_UA_006 asking what is fastest ranks restaurants by delivery time', () {
      final r = brain.answer('which is the fastest delivery', context);
      expect(r.action, AssistantAction.fastestDelivery);
      expect(r.restaurants.first.name, 'Olive Grove');
    });

    test('TC_UA_007 every suggestion is a dish that actually exists', () {
      // The point of answering from the catalogue: nothing can be invented.
      final ids = items.map((i) => i.id).toSet();
      for (final q in ['vegan', 'dessert', 'something cheap', 'lamb', 'a drink']) {
        for (final suggested in brain.answer(q, context).items) {
          expect(ids, contains(suggested.id), reason: 'invented a dish for "$q"');
        }
      }
    });
  });

  group('US14 — help with using Gather', () {
    test('TC_UA_008 a question about splitting the bill is answered', () {
      final r = brain.answer('how do i split the bill', context);
      expect(r.action, AssistantAction.appHelp);
      expect(r.text.toLowerCase(), contains('equal split'));
    });

    test('TC_UA_009 a question about joining is answered', () {
      final r = brain.answer('how do I join a session', context);
      expect(r.action, AssistantAction.appHelp);
      expect(r.text, contains('code'));
    });
  });

  group('US14 — when it does not know', () {
    test('TC_UA_010 an empty question asks for one', () {
      expect(brain.answer('   ', context).items, isEmpty);
    });

    test('TC_UA_011 nothing matching says so rather than guessing', () {
      final r = brain.answer('something vegan under 1', context);
      expect(r.items, isEmpty);
      expect(r.text.toLowerCase(), contains('available'));
    });

    test('TC_UA_012 an empty catalogue does not crash', () {
      const empty = AssistantContext(restaurants: [], items: []);
      expect(brain.answer('vegan food', empty).items, isEmpty);
    });
  });
}
