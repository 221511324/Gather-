import '../utils/parse.dart';
import 'restaurant.dart';

/// A customization the user picked, flattened onto the line so the line can be
/// rendered and priced without re-reading the menu item.
class SelectedOption {
  const SelectedOption({
    required this.groupId,
    required this.groupName,
    required this.choiceId,
    required this.choiceName,
    this.priceDelta = 0,
  });

  final String groupId;
  final String groupName;
  final String choiceId;
  final String choiceName;
  final double priceDelta;

  factory SelectedOption.fromMap(Map<String, dynamic> m) => SelectedOption(
        groupId: Parse.str(m['groupId']),
        groupName: Parse.str(m['groupName']),
        choiceId: Parse.str(m['choiceId']),
        choiceName: Parse.str(m['choiceName']),
        priceDelta: Parse.number(m['priceDelta']),
      );

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'groupName': groupName,
        'choiceId': choiceId,
        'choiceName': choiceName,
        'priceDelta': priceDelta,
      };
}

/// One line in a cart.
///
/// The same shape backs both the personal cart and the shared group cart. In a
/// group the [ownerId]/[ownerName] fields are what keep every item traceable
/// back to the member who added it (FR12).
class CartLine {
  const CartLine({
    required this.id,
    required this.itemId,
    required this.restaurantId,
    required this.name,
    required this.imageUrl,
    required this.basePrice,
    required this.quantity,
    this.options = const [],
    this.note = '',
    this.ownerId = '',
    this.ownerName = '',
    this.addedAt,
  });

  final String id;
  final String itemId;
  final String restaurantId;
  final String name;
  final String imageUrl;
  final double basePrice;
  final int quantity;
  final List<SelectedOption> options;

  /// Free-text request, e.g. "no onions".
  final String note;
  final String ownerId;
  final String ownerName;
  final DateTime? addedAt;

  double get optionsTotal => options.fold(0, (sum, o) => sum + o.priceDelta);
  double get unitPrice => basePrice + optionsTotal;
  double get lineTotal => unitPrice * quantity;

  /// "Large · Garlic sauce · Extra cheese" — the one-line customization summary
  /// shown under the item name in every cart list.
  String get optionSummary => options.map((o) => o.choiceName).join(' · ');

  bool get hasCustomization => options.isNotEmpty || note.trim().isNotEmpty;

  /// Two lines are mergeable when they are the same item with identical
  /// customizations and note, added by the same person.
  String get signature {
    final ids = options.map((o) => '${o.groupId}:${o.choiceId}').toList()..sort();
    return '$itemId|${ids.join(',')}|${note.trim().toLowerCase()}|$ownerId';
  }

  factory CartLine.fromMap(String id, Map<String, dynamic> m) => CartLine(
        id: id,
        itemId: Parse.str(m['itemId']),
        restaurantId: Parse.str(m['restaurantId']),
        name: Parse.str(m['name']),
        imageUrl: Parse.str(m['imageUrl']),
        basePrice: Parse.number(m['basePrice']),
        quantity: Parse.integer(m['quantity'], 1),
        options: Parse.mapList(m['options']).map(SelectedOption.fromMap).toList(),
        note: Parse.str(m['note']),
        ownerId: Parse.str(m['ownerId']),
        ownerName: Parse.str(m['ownerName']),
        addedAt: Parse.dateOrNull(m['addedAt']),
      );

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'restaurantId': restaurantId,
        'name': name,
        'imageUrl': imageUrl,
        'basePrice': basePrice,
        'quantity': quantity,
        'options': options.map((o) => o.toMap()).toList(),
        'note': note,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'addedAt': addedAt,
      };

  CartLine copyWith({int? quantity, String? note, List<SelectedOption>? options}) => CartLine(
        id: id,
        itemId: itemId,
        restaurantId: restaurantId,
        name: name,
        imageUrl: imageUrl,
        basePrice: basePrice,
        quantity: quantity ?? this.quantity,
        options: options ?? this.options,
        note: note ?? this.note,
        ownerId: ownerId,
        ownerName: ownerName,
        addedAt: addedAt,
      );

  static CartLine fromMenuItem(
    MenuItem item, {
    required String id,
    required int quantity,
    List<SelectedOption> options = const [],
    String note = '',
    String ownerId = '',
    String ownerName = '',
  }) =>
      CartLine(
        id: id,
        itemId: item.id,
        restaurantId: item.restaurantId,
        name: item.name,
        imageUrl: item.imageUrl,
        basePrice: item.price,
        quantity: quantity,
        options: options,
        note: note,
        ownerId: ownerId,
        ownerName: ownerName,
        addedAt: DateTime.now(),
      );
}

/// Totals derived from a set of lines. Kept as a value object so the cart
/// screen, the checkout screen and the order summary all price identically.
class CartTotals {
  const CartTotals({
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.serviceFee,
  });

  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double serviceFee;

  double get total {
    final value = subtotal + deliveryFee + serviceFee - discount;
    return value < 0 ? 0 : value;
  }

  static const empty = CartTotals(subtotal: 0, deliveryFee: 0, discount: 0, serviceFee: 0);
}
