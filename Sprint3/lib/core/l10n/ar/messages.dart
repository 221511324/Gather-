/// Sentences finished in code before they reach the screen: service errors
/// with a name or an amount in them, notifications stored in Firestore as
/// English, and the assistant's replies. Each key is the template the
/// sentence was built from; `translate` matches the finished English against
/// it and fills the Arabic with the same values.
const Map<String, String> arMessages = {
  // Ordering
  '{restaurant} has a minimum order of {amount}':
      'الحد الأدنى للطلب من {restaurant} هو {amount}',

  // Group sessions
  'This session is full — it already has {n} people':
      'هذه الجلسة مكتملة — تضم بالفعل {n} أشخاص',
  '{code} needs an order of at least {amount} SAR':
      'يتطلب {code} طلبًا لا يقل عن {amount} SAR',
  '{name} has already been suggested — by you': 'لقد اقترحتَ {name} بالفعل',
  'You have already suggested {name}. Withdraw it first if you want to put forward a different one.':
      'لقد اقترحتَ {name} بالفعل. اسحب اقتراحك أولًا إن أردت اقتراح مطعم آخر.',
  '{name} has already been suggested': 'سبق أن اقترح أحدهم {name}',
  '{restaurant} is the restaurant for this order — that item is from somewhere else':
      'مطعم هذا الطلب هو {restaurant} — وهذا الصنف من مطعم آخر',
  'This group': 'هذه المجموعة',

  // Rewards
  '{code} has expired': 'انتهت صلاحية {code}',
  '{code} is not available': '{code} غير متاح',
  '{code} is already in use': 'الرمز {code} مستخدم بالفعل',
  'They already have {code}': 'لديه {code} بالفعل',
  'No reward found for {code}': 'لا توجد مكافأة بالرمز {code}',

  // Payment methods
  '{name} is already set up': 'تم إعداد {name} بالفعل',
  '{name} is already on the list': '{name} موجودة بالفعل في القائمة',

  // Accounts
  'Could not finish creating your account: {message}': 'تعذّر إكمال إنشاء حسابك: {message}',

  // Notifications
  'A driver has taken this delivery.': 'تولّى أحد السائقين توصيل هذا الطلب.',
  'Join "{session}" with code {code}.': 'انضم إلى "{session}" باستخدام الرمز {code}.',

  // Assistant — a named restaurant
  '{name} has nothing on the menu right now.': 'لا يوجد شيء في قائمة {name} حاليًا.',
  '{name} is open — {cuisine}, rated {rating}, about {minutes} minutes. The best rated there: {items}.':
      '{name} مفتوح الآن — {cuisine}، بتقييم {rating}، والتوصيل خلال {minutes} دقيقة تقريبًا. الأعلى تقييمًا هناك: {items}.',
  '{name} is closed at the moment — {cuisine}, rated {rating}, about {minutes} minutes. The best rated there: {items}.':
      '{name} مغلق حاليًا — {cuisine}، بتقييم {rating}، والتوصيل خلال {minutes} دقيقة تقريبًا. الأعلى تقييمًا هناك: {items}.',

  // Assistant — fastest delivery. A reply lists up to three restaurants; the
  // template with the most fixed text is tried first, so three are matched
  // before two and two before one.
  'Quickest right now: {list}.': 'الأسرع الآن: {list}.',
  '{a} (about {am} min)': '{a} (حوالي {am} د)',
  '{a} (about {am} min), {b} (about {bm} min)': '{a} (حوالي {am} د)، {b} (حوالي {bm} د)',
  '{a} (about {am} min), {b} (about {bm} min), {c} (about {cm} min)':
      '{a} (حوالي {am} د)، {b} (حوالي {bm} د)، {c} (حوالي {cm} د)',

  // Assistant — recommendations
  'Here is what I would order: {list}.': 'هذا ما كنت سأطلبه: {list}.',
  'For something {what}: {list}.': 'إن كنت تبحث عن شيء {what}: {list}.',
  'Nothing {what} is available right now.': 'لا يتوفر حاليًا أي شيء {what}.',
  'vegan': 'نباتي',
  'sweet': 'حلو',
  'to drink': 'للشرب',
  'light': 'خفيف',
  'filling': 'مُشبع',
  'under {amount} SAR': 'بأقل من {amount} SAR',
  '{what} under {amount} SAR': '{what} بأقل من {amount} SAR',

  // Assistant — lists of dishes, with and without where they are from
  '{a} ({ap} SAR)': '{a} ({ap} SAR)',
  '{a} ({ap} SAR), {b} ({bp} SAR)': '{a} ({ap} SAR)، {b} ({bp} SAR)',
  '{a} ({ap} SAR), {b} ({bp} SAR), {c} ({cp} SAR)': '{a} ({ap} SAR)، {b} ({bp} SAR)، {c} ({cp} SAR)',
  '{a} at {ar} ({ap} SAR)': '{a} من {ar} ({ap} SAR)',
  '{a} at {ar} ({ap} SAR), {b} at {br} ({bp} SAR)': '{a} من {ar} ({ap} SAR)، {b} من {br} ({bp} SAR)',
  '{a} at {ar} ({ap} SAR), {b} at {br} ({bp} SAR), {c} at {cr} ({cp} SAR)':
      '{a} من {ar} ({ap} SAR)، {b} من {br} ({bp} SAR)، {c} من {cr} ({cp} SAR)',
};
