import 'package:cloud_firestore/cloud_firestore.dart';

/// Small, forgiving readers for Firestore maps.
///
/// Documents are written by several clients over the life of a session, so
/// every read tolerates a missing or unexpectedly-typed field rather than
/// throwing and tearing down a stream.
abstract final class Parse {
  static String str(Object? v, [String fallback = '']) => v is String ? v : fallback;

  static String? strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

  static int integer(Object? v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  static double number(Object? v, [double fallback = 0]) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  static bool boolean(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

  static DateTime? dateOrNull(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  static DateTime date(Object? v) => dateOrNull(v) ?? DateTime.fromMillisecondsSinceEpoch(0);

  static List<String> strList(Object? v) =>
      v is List ? v.whereType<Object>().map((e) => e.toString()).toList() : const [];

  static Map<String, dynamic> map(Object? v) =>
      v is Map ? v.map((k, value) => MapEntry(k.toString(), value)) : const {};

  static List<Map<String, dynamic>> mapList(Object? v) =>
      v is List ? v.whereType<Map>().map((e) => map(e)).toList() : const [];

  /// Resolves an enum from its stored name, falling back when the stored value
  /// is unknown (for example a document written by a newer app version).
  static T enumOf<T extends Enum>(List<T> values, Object? v, T fallback) {
    if (v is! String) return fallback;
    for (final value in values) {
      if (value.name == v) return value;
    }
    return fallback;
  }
}
