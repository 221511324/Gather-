import 'package:flutter/widgets.dart';

import 'arabic.dart';

/// Gather's own copy, in the language chosen in settings.
///
/// The English text is the key: a screen writes `context.tr('Settings')` and
/// gets the Arabic from [arabic] when the app is in Arabic. A string with no
/// entry falls back to the English, so a missing translation shows English
/// rather than a blank. Placeholders are written `{name}` and filled from
/// [args]: `context.tr('{count} items', {'count': 3})`.
///
/// When one English word needs different Arabic in different places, the key
/// carries a note after a bar — `'Home|address'` — which is never shown. A
/// noted key with no entry of its own uses the plain word's entry.
///
/// Reading the locale through [Localizations] makes the calling widget
/// rebuild when the language changes.
extension Tr on BuildContext {
  String tr(String english, [Map<String, Object?> args = const {}]) =>
      translate(Localizations.localeOf(this).languageCode, english, args);

  /// Wraps [text] in a first-strong isolate when the screen reads right to
  /// left, so data written left to right — an email, a phone number, an order
  /// code, a reward title starting with "10%" — keeps its own order instead of
  /// having its symbols and numbers flipped to the wrong end. English is
  /// returned unchanged.
  ///
  /// This is for data (names, descriptions, addresses), never for copy that
  /// went through [tr]; and the result is no longer a translation key, so it
  /// must not be handed to a widget that translates its own text.
  String isolate(String text) =>
      Directionality.of(this) == TextDirection.rtl ? '\u2068$text\u2069' : text;
}

/// The context-free form, for code that knows the language code itself.
String translate(String languageCode, String english, [Map<String, Object?> args = const {}]) {
  // Data already wrapped by [Tr.isolate] is never a key: show it as it is.
  if (english.startsWith('\u2068')) return english;
  final bar = english.lastIndexOf('|');
  final plain = bar < 0 ? english : english.substring(0, bar);
  var text = languageCode == 'ar'
      ? (arabic[english] ?? arabic[plain] ?? (args.isEmpty ? _fromTemplate(plain) : null) ?? plain)
      : plain;
  args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
  return text;
}

/// A sentence that was finished in code before it reached the screen — a
/// stored notification ("Ali invited you"), a service error with a name in
/// it — has no entry of its own, but the template it was built from does.
/// This matches it against the templates and fills the Arabic with the same
/// values, translating each value too when it is itself a known word or a
/// sentence some other template was built from (a list of dishes inside an
/// assistant reply, say). A value is always shorter than the text it came
/// from, so that never loops. A value left as it was — a name, a code — is
/// data inside Arabic, so it is wrapped in a first-strong isolate (see
/// [Tr.isolate]) to keep its own order.
String? _fromTemplate(String text) {
  if (_matched.containsKey(text)) return _matched[text];
  String? found;
  for (final t in _templates) {
    final m = t.pattern.firstMatch(text);
    if (m == null) continue;
    var out = t.arabic;
    for (var i = 0; i < t.names.length; i++) {
      final value = m.group(i + 1)!;
      out = out.replaceAll(
          '{${t.names[i]}}', arabic[value] ?? _fromTemplate(value) ?? '\u2068$value\u2069');
    }
    found = out;
    break;
  }
  if (_matched.length > 500) _matched.clear();
  return _matched[text] = found;
}

final _matched = <String, String?>{};

typedef _Template = ({RegExp pattern, List<String> names, String arabic});

final List<_Template> _templates = () {
  final placeholder = RegExp(r'\{(\w+)\}');
  final templates = <(int, _Template)>[];
  for (final MapEntry(:key, :value) in arabic.entries) {
    if (!key.contains('{')) continue;
    // A noted key ('{count} items|two') is one form of its plain key, picked
    // at the call site; as a template it would claim every "N items".
    if (key.contains('|')) continue;
    final bar = key.lastIndexOf('|');
    final english = bar < 0 ? key : key.substring(0, bar);
    // A template that is all placeholders and punctuation ("{a} · {b}")
    // would swallow restaurant names and other data, so it needs real words.
    final literal = english.replaceAll(placeholder, '');
    if (RegExp('[A-Za-z]').allMatches(literal).length < 3) continue;

    final names = <String>[];
    var source = '';
    var last = 0;
    for (final m in placeholder.allMatches(english)) {
      source += '${RegExp.escape(english.substring(last, m.start))}(.+?)';
      names.add(m[1]!);
      last = m.end;
    }
    source += RegExp.escape(english.substring(last));
    templates.add((
      literal.length,
      (pattern: RegExp('^$source\$', dotAll: true), names: names, arabic: value),
    ));
  }
  // The template with the most fixed text is the most specific match.
  templates.sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, t) in templates) t];
}();
