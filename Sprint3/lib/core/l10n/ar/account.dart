/// Orders, tracking, profile, addresses, payment methods, rewards,
/// notifications, help and FAQs, food stories and the food assistant.
const Map<String, String> arAccount = {
  // Orders list
  'My orders': 'طلباتي',
  'Active ({count})': 'النشطة ({count})',
  'History ({count})': 'السابقة ({count})',
  'Nothing on the way': 'لا يوجد طلب في الطريق',
  'Your active orders will appear here so you can track them.':
      'ستظهر طلباتك النشطة هنا لتتمكن من تتبعها.',
  'No past orders': 'لا توجد طلبات سابقة',
  'Once an order is delivered it moves here.': 'ينتقل الطلب إلى هنا بعد توصيله.',
  'Browse restaurants': 'تصفح المطاعم',
  'Group': 'جماعي',
  '1 item': 'صنف واحد',
  '{count} items': '{count} أصناف',
  'just now': 'الآن',
  '{n} min ago': 'قبل {n} د',
  '{n}h ago': 'قبل {n} س',
  'yesterday': 'أمس',
  '{n} days ago': 'قبل {n} أيام',

  // Driver map
  'OpenStreetMap contributors': 'مساهمو OpenStreetMap',
  'Restaurant': 'المطعم',
  'You': 'أنت',
  'Updated just now': 'تم التحديث الآن',
  'Updated 1 min ago': 'تم التحديث قبل دقيقة',
  'Updated {minutes} min ago': 'تم التحديث قبل {minutes} د',
  'Your driver': 'سائقك',

  // Order tracking
  'Tracking': 'التتبع',
  'Order tracking': 'تتبع الطلب',
  'Order not found': 'الطلب غير موجود',
  'It may have been removed.': 'ربما تمت إزالته.',
  'Order details': 'تفاصيل الطلب',
  'Cancel': 'إلغاء',
  'RESTAURANT': 'المطعم',
  'DELIVERING TO': 'التوصيل إلى',
  'No address on file': 'لا يوجد عنوان محفوظ',
  'PAID WITH': 'طريقة الدفع',
  'Not recorded': 'غير مسجلة',
  'GROUP': 'المجموعة',
  'Group order': 'طلب جماعي',
  '{count} people': '{count} أشخاص',
  'Who paid what': 'من دفع ماذا',
  'Simulate next step (debug)': 'محاكاة الخطوة التالية (تصحيح)',
  'Assign a driver (debug)': 'تعيين سائق (تصحيح)',
  'Move driver (debug)': 'تحريك السائق (تصحيح)',
  'Order cancelled': 'تم إلغاء الطلب',
  'Arriving around {time}': 'يصل حوالي الساعة {time}',
  'Cancel this order?': 'إلغاء هذا الطلب؟',
  'Let us know why so we can improve.': 'أخبرنا بالسبب لنتمكن من التحسين.',
  'Ordered by mistake': 'طلبته بالخطأ',
  'Taking too long': 'يستغرق وقتاً طويلاً',
  'Changed my mind': 'غيرت رأيي',
  'Wrong items selected': 'اخترت أصنافاً خاطئة',
  'Other': 'أخرى',
  'Keep order': 'الإبقاء على الطلب',
  'Cancel order': 'إلغاء الطلب',

  // Order details
  'Order': 'الطلب',
  'Track order': 'تتبع الطلب',
  'Order again': 'اطلب مرة أخرى',
  'Leave a review': 'أضف تقييماً',
  'You rated this order': 'لقد قيّمت هذا الطلب',
  'Everything ordered ({count})': 'كل ما تم طلبه ({count})',
  'Your items ({count})': 'أصنافك ({count})',
  'Items ({count})': 'الأصناف ({count})',
  'Delivered to': 'تم التوصيل إلى',
  'Paid with': 'طريقة الدفع',
  'Order ID': 'رقم الطلب',
  '{date} at {time}': '{date} الساعة {time}',
  'Replace your cart?': 'استبدال سلتك؟',
  'Reordering clears whatever is in your cart right now.':
      'إعادة الطلب تفرغ كل ما في سلتك حالياً.',
  'Keep': 'إبقاء',
  'Replace': 'استبدال',
  'There was nothing of yours in that order': 'لم يكن لك أي صنف في ذلك الطلب',
  'Added {count} items back to your cart': 'تمت إعادة {count} أصناف إلى سلتك',
  'Thanks for the review!': 'شكراً على تقييمك!',
  '{name} (you)': '{name} (أنت)',
  'How was {name}?': 'كيف كان {name}؟',
  '1 star': 'نجمة واحدة',
  '{count} stars': '{count} نجوم',
  'Anything you want to add? (optional)': 'هل تريد إضافة شيء؟ (اختياري)',
  'Not now': 'ليس الآن',
  'Submit': 'إرسال',

  // Profile
  'Profile': 'الملف الشخصي',
  'Edit profile': 'تعديل الملف الشخصي',
  'Orders': 'الطلبات',
  'Groups': 'المجموعات',
  'Account': 'الحساب',
  'My profile': 'ملفي الشخصي',
  'Delivery addresses': 'عناوين التوصيل',
  'Payment methods': 'طرق الدفع',
  'Favourites': 'المفضلة',
  'Activity': 'النشاط',
  'App': 'التطبيق',
  'Food assistant': 'مساعد الطعام',
  'Food stories': 'قصص الطعام',
  'Rewards': 'المكافآت',
  'Notifications': 'الإشعارات',
  '{count} new': '{count} جديدة',
  'Settings': 'الإعدادات',
  'Help & support': 'المساعدة والدعم',
  'Admin dashboard': 'لوحة تحكم المشرف',
  'Log out': 'تسجيل الخروج',
  'Log out?': 'تسجيل الخروج؟',
  'You will need to sign in again to order.': 'ستحتاج إلى تسجيل الدخول مرة أخرى لتطلب.',
  'Stay': 'البقاء',
  'Gather · Senior Project · Prince Sultan University':
      'Gather · مشروع التخرج · جامعة الأمير سلطان',

  // Edit profile
  'Profile updated': 'تم تحديث الملف الشخصي',
  'Full name': 'الاسم الكامل',
  'Enter your full name': 'أدخل اسمك الكامل',
  'Phone number': 'رقم الجوال',
  'Friends can add you to a session with this': 'يمكن لأصدقائك إضافتك إلى جلسة باستخدامه',
  'Username': 'اسم المستخدم',
  'Usernames cannot be changed — they are how people add you.':
      'لا يمكن تغيير اسم المستخدم — فهو ما يستخدمه الآخرون لإضافتك.',
  'Email': 'البريد الإلكتروني',
  'Used to sign in and recover your account.': 'يُستخدم لتسجيل الدخول واستعادة حسابك.',
  'Save changes': 'حفظ التغييرات',

  // Notifications
  'Mark all as read': 'تعليم الكل كمقروء',
  'Nothing yet': 'لا شيء بعد',
  'Invitations, order updates and offers will appear here.':
      'ستظهر هنا الدعوات وتحديثات الطلبات والعروض.',
  'now': 'الآن',
  '{n}m': '{n} د',
  '{n}h': '{n} س',
  '{n}d': '{n} ي',

  // Addresses
  'Addresses': 'العناوين',
  'Add an address': 'إضافة عنوان',
  'No addresses yet': 'لا توجد عناوين بعد',
  'Add one so we know where to deliver your orders.': 'أضف عنواناً لنعرف أين نوصل طلباتك.',
  'Default': 'الافتراضي',
  'Address options': 'خيارات العنوان',
  'Set as default': 'تعيين كافتراضي',
  'Edit': 'تعديل',
  'Delete': 'حذف',
  'Edit address': 'تعديل العنوان',
  'Home': 'المنزل',
  'Work': 'العمل',
  'University': 'الجامعة',
  'Label': 'التسمية',
  'Give this address a label': 'أعط هذا العنوان تسمية',
  'Street address': 'عنوان الشارع',
  'Building, street, district': 'المبنى، الشارع، الحي',
  'Enter the address': 'أدخل العنوان',
  'City': 'المدينة',
  'Riyadh|hint': 'الرياض',
  'Delivery notes (optional)': 'ملاحظات التوصيل (اختياري)',
  'Gate code, floor, landmark': 'رمز البوابة، الطابق، معلم قريب',
  'Use as my default address': 'استخدامه كعنواني الافتراضي',
  'Add address': 'إضافة العنوان',

  // Payment methods
  'Add card': 'إضافة بطاقة',
  'Add method': 'إضافة طريقة',
  'No other payment methods are available yet': 'لا توجد طرق دفع أخرى متاحة بعد',
  '{name} added': 'تمت إضافة {name}',
  'No payment methods': 'لا توجد طرق دفع',
  'Add a card or wallet so you can pay for orders and your share of a group bill.':
      'أضف بطاقة أو محفظة لتدفع ثمن طلباتك وحصتك من فاتورة المجموعة.',
  'Expired {date}': 'منتهية {date}',
  'expires {date}': 'تنتهي {date}',
  'Payment method options': 'خيارات طريقة الدفع',
  'Payment method removed': 'تمت إزالة طريقة الدفع',
  'Remove': 'إزالة',
  'Gather stores only the card brand and last four digits. '
          'Full card numbers are validated on your device and never saved.':
      'لا يحفظ Gather إلا نوع البطاقة وآخر أربعة أرقام. '
          'يتم التحقق من رقم البطاقة كاملاً على جهازك ولا يُحفظ أبداً.',
  'Card added': 'تمت إضافة البطاقة',
  'Add a card': 'إضافة بطاقة',
  'Card number': 'رقم البطاقة',
  'Name on card': 'الاسم على البطاقة',
  'Enter the name on the card': 'أدخل الاسم المكتوب على البطاقة',
  'Expiry': 'تاريخ الانتهاء',
  'MM/YY': 'شهر/سنة',
  'CVV': 'رمز التحقق',
  'Enter the security code': 'أدخل رمز الأمان',
  'Use as my default method': 'استخدامها كطريقتي الافتراضية',
  'This is a course project: payments are simulated and no real '
          'money moves. The card number never leaves your device.':
      'هذا مشروع دراسي: المدفوعات محاكاة ولا تنتقل أي أموال حقيقية. '
          'رقم البطاقة لا يغادر جهازك أبداً.',

  // Rewards
  '{title} added to your rewards': 'تمت إضافة {title} إلى مكافآتك',
  'Have a code?': 'لديك رمز؟',
  'Code': 'الرمز',
  'Claim': 'استلام',
  'No rewards yet': 'لا توجد مكافآت بعد',
  'Claim a code above, or watch for offers.': 'استخدم رمزاً في الأعلى، أو ترقب العروض.',
  'Available ({count})': 'المتاحة ({count})',
  'Used and expired': 'المستخدمة والمنتهية',
  'Used': 'مستخدمة',
  'Expired': 'منتهية',
  '{value}% off': 'خصم {value}%',
  '{value} SAR off': 'خصم {value} SAR',
  'Free delivery': 'توصيل مجاني',
  'On orders over {amount} SAR': 'للطلبات التي تزيد على {amount} SAR',
  'Expires {date}': 'تنتهي في {date}',

  // Help
  'Get help': 'احصل على المساعدة',
  'Frequently asked questions': 'الأسئلة الشائعة',
  'Report an issue': 'الإبلاغ عن مشكلة',
  'Your requests ({count})': 'طلباتك ({count})',
  'GATHER SUPPORT': 'دعم GATHER',

  // Contact
  'Thanks — we will get back to you shortly': 'شكراً — سنتواصل معك قريباً',
  'Tell us what happened and an admin will look into it.': 'أخبرنا بما حدث وسيتابعه أحد المشرفين.',
  'What is this about?': 'بخصوص ماذا؟',
  'Related order (optional)': 'الطلب المرتبط (اختياري)',
  'None': 'لا يوجد',
  'Subject': 'الموضوع',
  'Short summary': 'ملخص قصير',
  'Add a short subject': 'أضف موضوعاً قصيراً',
  'What happened?': 'ماذا حدث؟',
  'Describe the issue in a few sentences': 'صف المشكلة في بضع جمل',
  'Add a little more detail': 'أضف مزيداً من التفاصيل',
  'Send to support': 'إرسال إلى الدعم',
  'Other ways to reach us': 'طرق أخرى للتواصل معنا',
  'Sunday–Thursday, 9am–6pm': 'الأحد–الخميس، 9 ص–6 م',

  // FAQ
  'Help & FAQs': 'المساعدة والأسئلة الشائعة',
  'Group ordering': 'الطلب الجماعي',
  'How do I start a group order?': 'كيف أبدأ طلباً جماعياً؟',
  'Open the Group tab and tap "New session". Give it a name, then share the '
          '4-digit code, send the invite link, or add people directly by their '
          'Gather username or phone number.':
      'افتح تبويب المجموعة واضغط "جلسة جديدة". أعطها اسماً، ثم شارك الرمز المكوّن '
          'من 4 أرقام، أو أرسل رابط الدعوة، أو أضف الأشخاص مباشرة باسم المستخدم '
          'في Gather أو رقم الجوال.',
  'How does someone join my session?': 'كيف ينضم أحدهم إلى جلستي؟',
  'They can enter your 4-digit code on the Join screen, tap your invite link, '
          'or accept the invitation that appears in their notifications when you '
          'add them by username or phone number.':
      'يمكنه إدخال رمزك المكوّن من 4 أرقام في شاشة الانضمام، أو الضغط على رابط '
          'الدعوة، أو قبول الدعوة التي تظهر في إشعاراته عندما تضيفه باسم المستخدم '
          'أو رقم الجوال.',
  'Can everyone change the order?': 'هل يمكن للجميع تعديل الطلب؟',
  'Everyone adds their own items to the shared cart, and everyone can see the '
          'whole order. Only the person who added an item can change or remove it.':
      'يضيف كل شخص أصنافه إلى السلة المشتركة، ويرى الجميع الطلب كاملاً. '
          'ولا يمكن تعديل الصنف أو حذفه إلا لمن أضافه.',
  'What happens if we cannot agree on a restaurant?': 'ماذا لو لم نتفق على مطعم؟',
  'Each member suggests a place. Those suggestions go on a wheel, and the host '
          'spins it. Every suggestion has an equal chance, and the whole group sees '
          'the same result.':
      'يقترح كل عضو مكاناً. توضع هذه الاقتراحات على عجلة ويديرها المضيف. '
          'لكل اقتراح فرصة متساوية، وترى المجموعة كلها النتيجة نفسها.',
  'Can I reuse the same group next time?': 'هل يمكنني استخدام المجموعة نفسها لاحقاً؟',
  'Yes. Open the session menu and tap "Save this group". It appears under '
          'Saved groups, and starting from it invites the same people again.':
      'نعم. افتح قائمة الجلسة واضغط "حفظ هذه المجموعة". ستظهر ضمن المجموعات '
          'المحفوظة، والبدء منها يدعو الأشخاص أنفسهم مرة أخرى.',
  'Payment': 'الدفع',
  'How is the bill split?': 'كيف تُقسم الفاتورة؟',
  'The host picks one of three options: everyone pays for their own items, the '
          'total is split equally, or the host pays for everyone.':
      'يختار المضيف أحد ثلاثة خيارات: كل شخص يدفع ثمن أصنافه، أو يُقسم المجموع '
          'بالتساوي، أو يدفع المضيف عن الجميع.',
  'Who pays the delivery fee?': 'من يدفع رسوم التوصيل؟',
  'When everyone pays for their own items, the delivery and service fees are '
          'divided evenly across the group, since they are charged once for the '
          'whole order.':
      'عندما يدفع كل شخص ثمن أصنافه، تُقسم رسوم التوصيل والخدمة بالتساوي على '
          'المجموعة، لأنها تُحتسب مرة واحدة للطلب كله.',
  'When is the order actually placed?': 'متى يُرسل الطلب فعلياً؟',
  'The host can place it once nobody is still pending on the payment screen. '
          'Until then, the order is held.':
      'يمكن للمضيف إرسال الطلب عندما لا يبقى أحد بانتظار الدفع في شاشة الدفع. '
          'وحتى ذلك الحين يبقى الطلب معلّقاً.',
  'Is my card information safe?': 'هل معلومات بطاقتي آمنة؟',
  'Gather stores only the card brand and the last four digits. The full number '
          'is validated on your device and is never written to our database.':
      'لا يحفظ Gather إلا نوع البطاقة وآخر أربعة أرقام. يتم التحقق من الرقم '
          'الكامل على جهازك ولا يُكتب أبداً في قاعدة بياناتنا.',
  'Orders and delivery': 'الطلبات والتوصيل',
  'How do I track my order?': 'كيف أتتبع طلبي؟',
  'Open the Orders tab and choose the active order. The timeline shows each '
          'step from confirmation to delivery, with times.':
      'افتح تبويب الطلبات واختر الطلب النشط. يعرض المخطط الزمني كل خطوة من '
          'التأكيد حتى التوصيل مع أوقاتها.',
  'Can I cancel an order?': 'هل يمكنني إلغاء الطلب؟',
  'Yes, while it is still confirmed or being prepared. Once it has left the '
          'restaurant it can no longer be cancelled from the app.':
      'نعم، ما دام مؤكداً أو قيد التحضير. بعد خروجه من المطعم لا يمكن إلغاؤه '
          'من التطبيق.',
  'Can I reorder something?': 'هل يمكنني إعادة طلب شيء؟',
  'Open a past order and tap "Order again". For a group order, only your own '
          'items are added back to your cart.':
      'افتح طلباً سابقاً واضغط "اطلب مرة أخرى". في الطلب الجماعي، تُعاد أصنافك '
          'أنت فقط إلى سلتك.',
  'How does Spin & Win work?': 'كيف تعمل ميزة لف واربح؟',
  'You get one free spin each day. Every spin wins something — a percentage '
          'off, an amount off, or free delivery. The bigger prizes are rarer.':
      'تحصل على لفة مجانية واحدة كل يوم. كل لفة تربح شيئاً — خصماً بنسبة، أو '
          'خصماً بمبلغ، أو توصيلاً مجانياً. الجوائز الأكبر أندر.',
  'How do I use a voucher?': 'كيف أستخدم القسيمة؟',
  'At checkout, tap the reward row and pick one from your wallet, or type a '
          'code. The discount comes off your total immediately.':
      'عند الدفع، اضغط على صف المكافآت واختر واحدة من محفظتك، أو اكتب رمزاً. '
          'يُخصم المبلغ من إجماليك فوراً.',
  'Do rewards expire?': 'هل تنتهي صلاحية المكافآت؟',
  'Yes — rewards expire 14 days after you win them. Your wallet shows the '
          'status of every one.':
      'نعم — تنتهي صلاحية المكافآت بعد 14 يوماً من ربحها. تعرض محفظتك حالة '
          'كل واحدة منها.',

  // Food stories
  'Share a photo': 'شارك صورة',
  'No stories yet': 'لا توجد قصص بعد',
  'Share what you are eating. Stories disappear after a day.':
      'شارك ما تأكله. تختفي القصص بعد يوم.',
  'Story options': 'خيارات القصة',
  'Remove your story?': 'إزالة قصتك؟',
  'Remove this story?': 'إزالة هذه القصة؟',
  'It disappears for everyone.': 'ستختفي لدى الجميع.',
  'Removing someone else’s story is an administrator action.':
      'إزالة قصة شخص آخر إجراء خاص بالمشرف.',
  'Unlike': 'إلغاء الإعجاب',
  'Like': 'إعجاب',
  'Order {item}': 'اطلب {item}',
  'Choose a photo first': 'اختر صورة أولاً',
  'Shared': 'تمت المشاركة',
  'Stories disappear after a day.': 'تختفي القصص بعد يوم.',
  'Camera': 'الكاميرا',
  'Gallery': 'المعرض',
  'Caption': 'التعليق',
  'Best mandi in Riyadh|hint': 'أفضل مندي في الرياض',
  'Where from (optional)': 'من أين؟ (اختياري)',
  'Not saying': 'أفضّل عدم الذكر',
  'Share': 'مشاركة',

  // Food assistant
  'Clear conversation': 'مسح المحادثة',
  'Clear this conversation?': 'مسح هذه المحادثة؟',
  'The messages are removed from your account.': 'ستُحذف الرسائل من حسابك.',
  'Clear': 'مسح',
  'What are you in the mood for?': 'ماذا تشتهي اليوم؟',
  'I answer from the restaurants and menus on Gather, so everything '
          'I suggest is something you can actually order.':
      'أجيب من المطاعم والقوائم الموجودة في Gather، لذا كل ما أقترحه يمكنك طلبه فعلاً.',
  'What is the best dessert?': 'ما أفضل حلوى؟',
  'Something vegan under 30': 'شيء نباتي بأقل من 30',
  'Which is the fastest delivery?': 'أيها الأسرع توصيلاً؟',
  'How do I split the bill?': 'كيف أقسم الفاتورة؟',
  'Ask': 'اسأل',
  'Ask about food, or about using Gather': 'اسأل عن الطعام، أو عن استخدام Gather',
};
