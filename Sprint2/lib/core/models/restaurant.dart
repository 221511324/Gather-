import '../utils/parse.dart';

/// Menu categories. These mirror the tabs in the reference design and drive
/// the circular category chips on the home screen.
enum FoodCategory { snacks, meal, vegan, dessert, drinks }

extension FoodCategoryX on FoodCategory {
  String get label => switch (this) {
        FoodCategory.snacks => 'Snacks',
        FoodCategory.meal => 'Meals',
        FoodCategory.vegan => 'Vegan',
        FoodCategory.dessert => 'Dessert',
        FoodCategory.drinks => 'Drinks',
      };
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.imageUrl,
    this.description = '',
    this.rating = 0,
    this.ratingCount = 0,
    this.deliveryFee = 0,
    this.deliveryMinutes = 30,
    this.minimumOrder = 0,
    this.tags = const [],
    this.isOpen = true,
    this.priceLevel = 2,
  });

  final String id;
  final String name;
  final String cuisine;
  final String imageUrl;
  final String description;
  final double rating;
  final int ratingCount;
  final double deliveryFee;
  final int deliveryMinutes;
  final double minimumOrder;
  final List<String> tags;
  final bool isOpen;

  /// 1–3, rendered as $ / $$ / $$$.
  final int priceLevel;

  String get priceLabel => List.filled(priceLevel.clamp(1, 3), r'$').join();
  String get deliveryLabel => '$deliveryMinutes–${deliveryMinutes + 10} min';

  factory Restaurant.fromMap(String id, Map<String, dynamic> m) => Restaurant(
        id: id,
        name: Parse.str(m['name']),
        cuisine: Parse.str(m['cuisine']),
        imageUrl: Parse.str(m['imageUrl']),
        description: Parse.str(m['description']),
        rating: Parse.number(m['rating']),
        ratingCount: Parse.integer(m['ratingCount']),
        deliveryFee: Parse.number(m['deliveryFee']),
        deliveryMinutes: Parse.integer(m['deliveryMinutes'], 30),
        minimumOrder: Parse.number(m['minimumOrder']),
        tags: Parse.strList(m['tags']),
        isOpen: Parse.boolean(m['isOpen'], true),
        priceLevel: Parse.integer(m['priceLevel'], 2),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'nameLower': name.toLowerCase(),
        'cuisine': cuisine,
        'imageUrl': imageUrl,
        'description': description,
        'rating': rating,
        'ratingCount': ratingCount,
        'deliveryFee': deliveryFee,
        'deliveryMinutes': deliveryMinutes,
        'minimumOrder': minimumOrder,
        'tags': tags,
        'isOpen': isOpen,
        'priceLevel': priceLevel,
      };
}

/// One choice inside a customization group, e.g. "Garlic sauce (+2.00)".
class OptionChoice {
  const OptionChoice({required this.id, required this.name, this.priceDelta = 0});

  final String id;
  final String name;

  /// Added to the line's unit price when selected. May be zero.
  final double priceDelta;

  factory OptionChoice.fromMap(Map<String, dynamic> m) => OptionChoice(
        id: Parse.str(m['id']),
        name: Parse.str(m['name']),
        priceDelta: Parse.number(m['priceDelta']),
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'priceDelta': priceDelta};
}

/// A customization group on a menu item (FR4).
///
/// [minSelect] of 1 makes the group required, which the item sheet enforces
/// before the "add to cart" button unlocks.
class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.choices,
    this.minSelect = 0,
    this.maxSelect = 1,
  });

  final String id;
  final String name;
  final List<OptionChoice> choices;
  final int minSelect;
  final int maxSelect;

  bool get isRequired => minSelect > 0;
  bool get isMultiSelect => maxSelect > 1;

  String get ruleLabel {
    if (isRequired && maxSelect == 1) return 'Required · pick 1';
    if (isRequired) return 'Required · pick $minSelect–$maxSelect';
    if (maxSelect == 1) return 'Optional · pick 1';
    return 'Optional · up to $maxSelect';
  }

  factory OptionGroup.fromMap(Map<String, dynamic> m) => OptionGroup(
        id: Parse.str(m['id']),
        name: Parse.str(m['name']),
        choices: Parse.mapList(m['choices']).map(OptionChoice.fromMap).toList(),
        minSelect: Parse.integer(m['minSelect']),
        maxSelect: Parse.integer(m['maxSelect'], 1),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'choices': choices.map((c) => c.toMap()).toList(),
        'minSelect': minSelect,
        'maxSelect': maxSelect,
      };
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.description = '',
    this.optionGroups = const [],
    this.rating = 0,
    this.isAvailable = true,
    this.isBestSeller = false,
    this.calories,
  });

  final String id;
  final String restaurantId;
  final String name;
  final double price;
  final String imageUrl;
  final FoodCategory category;
  final String description;
  final List<OptionGroup> optionGroups;
  final double rating;
  final bool isAvailable;
  final bool isBestSeller;
  final int? calories;

  factory MenuItem.fromMap(String id, Map<String, dynamic> m) => MenuItem(
        id: id,
        restaurantId: Parse.str(m['restaurantId']),
        name: Parse.str(m['name']),
        price: Parse.number(m['price']),
        imageUrl: Parse.str(m['imageUrl']),
        category: Parse.enumOf(FoodCategory.values, m['category'], FoodCategory.meal),
        description: Parse.str(m['description']),
        optionGroups: Parse.mapList(m['optionGroups']).map(OptionGroup.fromMap).toList(),
        rating: Parse.number(m['rating']),
        isAvailable: Parse.boolean(m['isAvailable'], true),
        isBestSeller: Parse.boolean(m['isBestSeller']),
        calories: m['calories'] == null ? null : Parse.integer(m['calories']),
      );

  Map<String, dynamic> toMap() => {
        'restaurantId': restaurantId,
        'name': name,
        'nameLower': name.toLowerCase(),
        'price': price,
        'imageUrl': imageUrl,
        'category': category.name,
        'description': description,
        'optionGroups': optionGroups.map((g) => g.toMap()).toList(),
        'rating': rating,
        'isAvailable': isAvailable,
        'isBestSeller': isBestSeller,
        if (calories != null) 'calories': calories,
      };
}
