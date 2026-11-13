/// Arabic count forms for the customer's main screens (home, orders, group
/// hub, checkout, profile).
///
/// Arabic says a count differently for one, two, three to ten and eleven
/// up, so a call site that shows a count picks its key with [countNote]:
/// `context.tr('{count} items|${countNote(n)}', {'count': n})`. The note is
/// never shown, so the English is the same for every count, and a form with
/// no entry of its own here uses the plain key's Arabic (the 3–10 plural).
const Map<String, String> arQa1 = {
  '{count} items|zero': 'لا أصناف',
  '{count} items|one': 'صنف واحد',
  '{count} items|two': 'صنفان',
  '{count} items|many': '{count} صنفًا',

  '{count} members|one': 'عضو واحد',
  '{count} members|two': 'عضوان',
  '{count} members|many': '{count} عضوًا',

  '{count} people|one': 'شخص واحد',
  '{count} people|two': 'شخصان',
  '{count} people|many': '{count} شخصًا',

  '{n} days ago|one': 'قبل يوم',
  '{n} days ago|two': 'قبل يومين',

  'used {count}×|one': 'استُخدمت مرة واحدة',
  'used {count}×|two': 'استُخدمت مرتين',
  'used {count}×|few': 'استُخدمت {count} مرات',

  'From {restaurant} · arrives in about {minutes} min|few':
      'من {restaurant} · يصل خلال {minutes} دقائق تقريباً',
};

/// The note that picks the Arabic form of a count: `zero`, `one`, `two`,
/// `few` (3–10) or `many` (11 and up).
String countNote(int n) => switch (n) {
      0 => 'zero',
      1 => 'one',
      2 => 'two',
      >= 3 && <= 10 => 'few',
      _ => 'many',
    };
