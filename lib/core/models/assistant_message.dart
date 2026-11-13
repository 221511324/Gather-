import '../utils/parse.dart';

/// Who said it.
enum ChatRole { user, assistant }

/// What the assistant did to answer, kept so the interface can show its
/// working and so the transcript explains itself when read back later.
enum AssistantAction {
  /// No lookup — a greeting, a thank-you, something conversational.
  none,

  /// Searched the menu across every restaurant.
  searchMenu,

  /// Filtered the menu by category (vegan, dessert, drinks…).
  filterByCategory,

  /// Filtered by what the person said they wanted to spend.
  filterByBudget,

  /// Ranked by rating.
  topRated,

  /// Looked at one named restaurant.
  restaurantLookup,

  /// Ranked restaurants by how fast they deliver.
  fastestDelivery,

  /// Answered a question about using Gather itself.
  appHelp,
}

extension AssistantActionX on AssistantAction {
  /// Shown under the answer, so the person can see where it came from.
  String get label => switch (this) {
        AssistantAction.none => '',
        AssistantAction.searchMenu => 'Searched the menu',
        AssistantAction.filterByCategory => 'Filtered by category',
        AssistantAction.filterByBudget => 'Filtered by price',
        AssistantAction.topRated => 'Ranked by rating',
        AssistantAction.restaurantLookup => 'Looked up the restaurant',
        AssistantAction.fastestDelivery => 'Ranked by delivery time',
        AssistantAction.appHelp => 'Answered from the app guide',
      };
}

/// One turn of the conversation.
class AssistantMessage {
  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    this.action = AssistantAction.none,
    this.itemIds = const [],
    this.restaurantIds = const [],
    this.seq = 0,
    this.createdAt,
  });

  final String id;
  final ChatRole role;
  final String text;

  /// How the answer was produced. Always [AssistantAction.none] for a question.
  final AssistantAction action;

  /// Dishes the answer refers to, so the interface can offer to open them
  /// rather than making the person search for what was just suggested.
  final List<String> itemIds;
  final List<String> restaurantIds;

  /// Orders the transcript.
  ///
  /// A question and its answer are written in one batch, and every document in
  /// a batch is stamped with the *same* server time — so ordering by the
  /// timestamp alone let the answer sort above the question, depending on
  /// which random document id happened to come first.
  final int seq;

  final DateTime? createdAt;

  bool get isUser => role == ChatRole.user;

  factory AssistantMessage.fromMap(String id, Map<String, dynamic> m) => AssistantMessage(
        id: id,
        role: Parse.enumOf(ChatRole.values, m['role'], ChatRole.assistant),
        text: Parse.str(m['text']),
        action: Parse.enumOf(AssistantAction.values, m['action'], AssistantAction.none),
        itemIds: Parse.strList(m['itemIds']),
        restaurantIds: Parse.strList(m['restaurantIds']),
        seq: Parse.integer(m['seq']),
        createdAt: Parse.dateOrNull(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'text': text,
        'action': action.name,
        'itemIds': itemIds,
        'restaurantIds': restaurantIds,
        'seq': seq,
      };
}
