/// Arabic count forms and shorter labels for the session, order and
/// restaurant screens. Count keys carry a `countNote` (see `qa1.dart`) after
/// the bar, so the English is the same for every count.
const Map<String, String> arQa2 = {
  // Session overview.
  'You have added {count} items · {amount}|two': 'أضفت صنفين · {amount}',
  'You have added {count} items · {amount}|many': 'أضفت {count} صنفًا · {amount}',
  'Lock & pay': 'اقفل وادفع',
  'Wait': 'انتظر',

  // Group payment.
  '{count} people pay for what they added, fees split evenly|zero':
      'يدفع كل شخص ثمن ما أضافه، وتُقسَّم الرسوم بالتساوي',
  '{count} people pay for what they added, fees split evenly|two':
      'شخصان يدفع كل منهما ثمن ما أضافه، وتُقسَّم الرسوم بالتساوي',
  '{count} people pay for what they added, fees split evenly|many':
      '{count} شخصًا يدفع كل منهم ثمن ما أضافه، وتُقسَّم الرسوم بالتساوي',
  'Waiting for {count} to pay|zero': 'بانتظار الدفع',
  'Waiting for {count} to pay|one': 'بانتظار دفع عضو واحد',
  'Waiting for {count} to pay|two': 'بانتظار دفع عضوين',
  'Waiting for {count} to pay|few': 'بانتظار دفع {count} أعضاء',
  'Waiting for {count} to pay|many': 'بانتظار دفع {count} عضوًا',
  '{count} rewards available|zero': 'لا توجد مكافآت متاحة',
  '{count} rewards available|two': 'مكافأتان متاحتان',
  '{count} rewards available|many': '{count} مكافأة متاحة',

  // Restaurant cart bar and order screens.
  '{count} item · {total}': 'صنف واحد · {total}',
  '{count} items · {total}|zero': 'لا أصناف · {total}',
  '{count} items · {total}|two': 'صنفان · {total}',
  '{count} items · {total}|many': '{count} صنفًا · {total}',
  'Added {count} items back to your cart|one': 'تمت إعادة صنف واحد إلى سلتك',
  'Added {count} items back to your cart|two': 'تمت إعادة صنفين إلى سلتك',
  'Added {count} items back to your cart|many': 'تمت إعادة {count} صنفًا إلى سلتك',
  'Order details|button': 'التفاصيل',

  // Assistant: the hint is cut off on a phone at full length.
  'Ask about food, or about using Gather': 'اسأل عن الطعام أو عن Gather',
};
