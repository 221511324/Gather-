import '../utils/parse.dart';

/// A payment method the platform offers, managed by an administrator.
///
/// The saved methods on an account say what one person has set up;
/// this says what anybody is *allowed* to set up. It lives in Firestore
/// rather than in an enum so an administrator can add PayPal — or anything
/// else — without the app being rebuilt and re-released.
class PaymentOption {
  const PaymentOption({
    required this.id,
    required this.name,
    this.description = '',
    this.isEnabled = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;

  /// Disabled options stay on the list for the administrator but disappear
  /// from the customer's choices — turning one off is reversible, deleting
  /// it is not.
  final bool isEnabled;
  final int sortOrder;
  final DateTime? createdAt;

  PaymentOption copyWith({
    String? name,
    String? description,
    bool? isEnabled,
    int? sortOrder,
  }) =>
      PaymentOption(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isEnabled: isEnabled ?? this.isEnabled,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  factory PaymentOption.fromMap(String id, Map<String, dynamic> m) => PaymentOption(
        id: id,
        name: Parse.str(m['name']),
        description: Parse.str(m['description']),
        isEnabled: Parse.boolean(m['isEnabled']),
        sortOrder: Parse.integer(m['sortOrder']),
        createdAt: Parse.dateOrNull(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'isEnabled': isEnabled,
        'sortOrder': sortOrder,
      };
}
