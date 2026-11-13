/// Models, services, the router and the shared cards.
///
/// Services have no BuildContext, so their messages (Err text, validation,
/// enum labels) are listed here and translated where they are shown.
const Map<String, String> arCore = {
  // Router
  'We could not find {location}': 'تعذّر العثور على {location}',
  'Go home': 'العودة إلى الرئيسية',

  // Shared cards
  'Remove from favourites': 'إزالة من المفضلة',
  'Add to favourites': 'إضافة إلى المفضلة',
  'POPULAR': 'الأكثر طلبًا',
  '· {calories} kcal': '· {calories} سعرة',
  'Closed': 'مغلق',
  'Free': 'مجاني',
  '{min}–{max} min': '{min}–{max} دقيقة',

  // Restaurant categories and option rules
  'Snacks': 'وجبات خفيفة',
  'Meals': 'وجبات',
  'Vegan': 'نباتي',
  'Dessert': 'حلويات',
  'Drinks': 'مشروبات',
  'Required · pick 1': 'إلزامي · اختر 1',
  'Required · pick {min}–{max}': 'إلزامي · اختر {min}–{max}',
  'Optional · pick 1': 'اختياري · اختر 1',
  'Optional · up to {max}': 'اختياري · حتى {max}',

  // Notification kinds
  'Invitation': 'دعوة',
  'Session': 'جلسة',
  'Payment': 'الدفع',
  'Order': 'طلب',
  'Delivery': 'التوصيل',
  'Offer': 'عرض',

  // Assistant actions
  'Searched the menu': 'تم البحث في القائمة',
  'Filtered by category': 'تمت التصفية حسب الفئة',
  'Filtered by price': 'تمت التصفية حسب السعر',
  'Ranked by rating': 'مرتبة حسب التقييم',
  'Looked up the restaurant': 'تم البحث عن المطعم',
  'Ranked by delivery time': 'مرتبة حسب وقت التوصيل',
  'Answered from the app guide': 'الإجابة من دليل التطبيق',

  // Group sessions
  'Everyone pays their own': 'كل شخص يدفع حسابه',
  'Split equally': 'تقسيم بالتساوي',
  'Host pays for everyone': 'المضيف يدفع عن الجميع',
  'Individual': 'فردي',
  'Equal split': 'تقسيم متساوٍ',
  'Host pays': 'المضيف يدفع',
  'Each member is charged for the items they added to the shared cart.':
      'يدفع كل عضو ثمن الأصناف التي أضافها إلى السلة المشتركة.',
  'The total is divided evenly between every member in the session.':
      'يُقسَّم المبلغ الإجمالي بالتساوي على جميع أعضاء الجلسة.',
  'You pay the full amount. No one else is asked for payment.':
      'تدفع المبلغ كاملًا، ولن يُطلب الدفع من أي شخص آخر.',
  'Spin the wheel': 'أدر العجلة',
  'Host chooses': 'المضيف يختار',
  'Waiting for members': 'بانتظار الأعضاء',
  'Choosing a restaurant': 'اختيار مطعم',
  'Adding items': 'إضافة الأصناف',
  'Order placed': 'تم تقديم الطلب',
  'Cancelled': 'ملغى',
  'Pending': 'قيد الانتظار',
  'Paid': 'مدفوع',
  'Covered': 'مغطّى',
  'Group order': 'طلب جماعي',
  'Saved group': 'مجموعة محفوظة',
  'Address': 'العنوان',

  // Orders and the driver
  'Confirmed': 'مؤكد',
  'Preparing': 'قيد التحضير',
  'On the way': 'في الطريق',
  'Delivered': 'تم التوصيل',
  'The restaurant has received your order.': 'استلم المطعم طلبك.',
  'Your food is being prepared.': 'يجري تحضير طعامك.',
  'Your driver is on the way to you.': 'السائق في الطريق إليك.',
  'Delivered. Enjoy your meal!': 'تم التوصيل. بالهناء والعافية!',
  'This order was cancelled.': 'تم إلغاء هذا الطلب.',
  'Driver assigned': 'تم تعيين السائق',
  'Heading to the restaurant': 'متجه إلى المطعم',
  'At the restaurant': 'في المطعم',
  'Picked up your order': 'استلم طلبك',
  'On the way to you': 'في الطريق إليك',
  'Arrived at your address': 'وصل إلى عنوانك',
  'Driving to the restaurant to collect the order.': 'في طريقه إلى المطعم لاستلام الطلب.',
  'Waiting at the restaurant for the order to be handed over.': 'ينتظر في المطعم لاستلام الطلب.',
  'The order is with the driver and about to leave.': 'الطلب مع السائق وعلى وشك الانطلاق.',
  'Driving to your address.': 'في طريقه إلى عنوانك.',
  'The driver is at your address.': 'السائق عند عنوانك.',

  // Payment methods
  'Card': 'بطاقة',
  'Payment method': 'وسيلة الدفع',

  // Support tickets
  'Open': 'مفتوحة',
  'In progress': 'قيد المعالجة',
  'Resolved': 'تم الحل',
  // 'Closed' is shared with the restaurant card above.
  'Order issue': 'مشكلة في الطلب',
  'Payment issue': 'مشكلة في الدفع',
  'Delivery issue': 'مشكلة في التوصيل',
  'Account issue': 'مشكلة في الحساب',
  'Group session issue': 'مشكلة في الجلسة الجماعية',
  'Something else': 'أمر آخر',

  // Vouchers
  'Percentage off': 'خصم بنسبة مئوية',
  'Amount off': 'خصم بمبلغ ثابت',
  'Free delivery': 'توصيل مجاني',
  '{value}% off': 'خصم {value}%',
  '{value} SAR off': 'خصم {value} SAR',

  // Accounts and sign-in
  'Could not update that account': 'تعذّر تحديث هذا الحساب',
  'Username must be at least 3 characters': 'يجب أن يتكون اسم المستخدم من 3 أحرف على الأقل',
  'Username must be 20 characters or fewer': 'يجب ألا يزيد اسم المستخدم على 20 حرفًا',
  'Use letters, numbers, dots and underscores only': 'استخدم الحروف والأرقام والنقاط والشرطات السفلية فقط',
  'That username is already taken': 'اسم المستخدم هذا مستخدم بالفعل',
  'That username was just taken': 'تم حجز اسم المستخدم هذا للتو',
  'No Gather profile is linked to this account': 'لا يوجد ملف Gather مرتبط بهذا الحساب',
  'This account has been suspended. Contact support for help.':
      'تم إيقاف هذا الحساب. تواصل مع الدعم للمساعدة.',
  'Could not save your profile': 'تعذّر حفظ ملفك الشخصي',
  'Could not save your settings': 'تعذّر حفظ إعداداتك',
  'Could not save your addresses': 'تعذّر حفظ عناوينك',
  'Enter a username or phone number': 'أدخل اسم مستخدم أو رقم جوال',
  'No Gather user has that phone number': 'لا يوجد مستخدم في Gather بهذا الرقم',
  'That user cannot be added by phone number': 'لا يمكن إضافة هذا المستخدم برقم الجوال',
  'No Gather user with that username': 'لا يوجد مستخدم في Gather بهذا الاسم',
  'That user cannot be added by username': 'لا يمكن إضافة هذا المستخدم باسم المستخدم',
  'That email address is not valid': 'عنوان البريد الإلكتروني غير صالح',
  'This account has been disabled': 'تم تعطيل هذا الحساب',
  'Incorrect email or password': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
  'An account already exists for that email': 'يوجد حساب بالفعل لهذا البريد الإلكتروني',
  'Choose a password with at least 6 characters': 'اختر كلمة مرور من 6 أحرف على الأقل',
  'Too many attempts. Try again in a moment.': 'محاولات كثيرة جدًا. حاول مرة أخرى بعد قليل.',
  'No internet connection': 'لا يوجد اتصال بالإنترنت',
  'Please sign in again to continue': 'يرجى تسجيل الدخول مرة أخرى للمتابعة',
  'Something went wrong. Please try again.': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
  'You do not have permission to do that': 'ليست لديك صلاحية للقيام بذلك',

  // Catalogue administration
  'Give the restaurant a name': 'أدخل اسمًا للمطعم',
  'Say what kind of food it serves': 'حدد نوع الطعام الذي يقدمه',
  'A rating must be between 0 and 5': 'يجب أن يكون التقييم بين 0 و5',
  'The rating count cannot be negative': 'لا يمكن أن يكون عدد التقييمات سالبًا',
  'The delivery fee cannot be negative': 'لا يمكن أن تكون رسوم التوصيل سالبة',
  'Delivery time must be at least one minute': 'يجب أن يكون وقت التوصيل دقيقة واحدة على الأقل',
  'The minimum order cannot be negative': 'لا يمكن أن يكون الحد الأدنى للطلب سالبًا',
  'Price level runs from 1 to 3': 'مستوى السعر من 1 إلى 3',
  'Could not save that restaurant': 'تعذّر حفظ هذا المطعم',
  'Could not delete that restaurant': 'تعذّر حذف هذا المطعم',
  'Could not update that restaurant': 'تعذّر تحديث هذا المطعم',
  'Give the item a name': 'أدخل اسمًا للصنف',
  'Enter a price greater than zero': 'أدخل سعرًا أكبر من صفر',
  'This item has no restaurant': 'هذا الصنف غير مرتبط بمطعم',
  'Could not save that menu item': 'تعذّر حفظ هذا الصنف',
  'Could not delete that menu item': 'تعذّر حذف هذا الصنف',
  'Could not update that menu item': 'تعذّر تحديث هذا الصنف',

  // Notifications
  'Could not send that notification': 'تعذّر إرسال هذا الإشعار',
  'Could not update that notification': 'تعذّر تحديث هذا الإشعار',
  'Could not update your notifications': 'تعذّر تحديث إشعاراتك',
  'Could not remove that notification': 'تعذّر حذف هذا الإشعار',
  'Could not clear your notifications': 'تعذّر مسح إشعاراتك',

  // Ordering
  'Your cart is empty': 'سلتك فارغة',
  'The shared cart is empty': 'السلة المشتركة فارغة',
  'Choose how the group is paying first': 'اختر طريقة دفع المجموعة أولًا',
  'Some members still have a payment pending': 'لا يزال لدى بعض الأعضاء دفعات معلقة',
  'Could not place your order': 'تعذّر تقديم طلبك',
  'Could not update that order': 'تعذّر تحديث هذا الطلب',
  'Could not update the driver location': 'تعذّر تحديث موقع السائق',
  'Order not found': 'الطلب غير موجود',
  'This order can no longer be cancelled — it has already left the restaurant':
      'لم يعد بالإمكان إلغاء هذا الطلب — فقد غادر المطعم بالفعل',
  'Could not cancel that order': 'تعذّر إلغاء هذا الطلب',
  'Could not save your review': 'تعذّر حفظ تقييمك',
  'The driver has already arrived': 'وصل السائق بالفعل',

  // Payments
  'There is nothing to pay': 'لا يوجد مبلغ للدفع',
  'Your payment was declined. Try a different method.': 'تم رفض عملية الدفع. جرّب وسيلة أخرى.',
  'Enter the 3 or 4 digit security code': 'أدخل رمز الأمان المكوّن من 3 أو 4 أرقام',
  'Enter the name on the card': 'أدخل الاسم المكتوب على البطاقة',
  'Could not save that card': 'تعذّر حفظ هذه البطاقة',
  'Could not add that payment method': 'تعذّر إضافة وسيلة الدفع هذه',
  'Enter a name for the payment method': 'أدخل اسمًا لوسيلة الدفع',
  'Could not save that payment method': 'تعذّر حفظ وسيلة الدفع هذه',
  'Could not change that payment method': 'تعذّر تعديل وسيلة الدفع هذه',
  'Could not remove that payment method': 'تعذّر حذف وسيلة الدفع هذه',
  'That card has expired. Add a new one.': 'انتهت صلاحية هذه البطاقة. أضف بطاقة جديدة.',
  'Enter your card number': 'أدخل رقم بطاقتك',
  'Card numbers contain digits only': 'رقم البطاقة يتكون من أرقام فقط',
  'That card number looks incomplete': 'يبدو أن رقم البطاقة غير مكتمل',
  'That card number is not valid': 'رقم البطاقة غير صالح',
  'Enter a month between 01 and 12': 'أدخل شهرًا بين 01 و12',
  'That card has already expired': 'انتهت صلاحية هذه البطاقة بالفعل',
  'Check the expiry year': 'تحقق من سنة الانتهاء',

  // Group sessions (service)
  'Could not generate a session code. Please try again.': 'تعذّر إنشاء رمز الجلسة. يرجى المحاولة مرة أخرى.',
  'Could not create the session': 'تعذّر إنشاء الجلسة',
  'Session codes are 4 digits': 'رموز الجلسات مكونة من 4 أرقام',
  'No active session with that code': 'لا توجد جلسة نشطة بهذا الرمز',
  'That session is no longer available': 'لم تعد هذه الجلسة متاحة',
  'That session has already finished': 'انتهت هذه الجلسة بالفعل',
  'Session not found': 'الجلسة غير موجودة',
  'Could not join that session': 'تعذّر الانضمام إلى هذه الجلسة',
  'Could not send that invite': 'تعذّر إرسال هذه الدعوة',
  'That reward has expired': 'انتهت صلاحية هذه المكافأة',
  'That reward has already been used': 'تم استخدام هذه المكافأة بالفعل',
  'Could not apply that reward': 'تعذّر تطبيق هذه المكافأة',
  'Could not remove that reward': 'تعذّر حذف هذه المكافأة',
  'The host cannot be removed': 'لا يمكن إزالة المضيف',
  'Could not remove that member': 'تعذّر إزالة هذا العضو',
  'Could not set how the restaurant is chosen': 'تعذّر تحديد طريقة اختيار المطعم',
  'The host is choosing the restaurant for this order': 'المضيف هو من يختار المطعم لهذا الطلب',
  'The wheel is full — remove a suggestion first': 'العجلة ممتلئة — احذف اقتراحًا أولًا',
  'Could not add that suggestion': 'تعذّر إضافة هذا الاقتراح',
  'Could not record that vote': 'تعذّر تسجيل هذا التصويت',
  'That suggestion is no longer there': 'لم يعد هذا الاقتراح موجودًا',
  "Only the host can remove someone else's suggestion": 'المضيف وحده يمكنه حذف اقتراحات الآخرين',
  'Could not remove that suggestion': 'تعذّر حذف هذا الاقتراح',
  'Could not set the restaurant': 'تعذّر تحديد المطعم',
  'Could not read the shared cart': 'تعذّر قراءة السلة المشتركة',
  'Could not add that item': 'تعذّر إضافة هذا الصنف',
  'Could not update that item': 'تعذّر تحديث هذا الصنف',
  'Could not remove that item': 'تعذّر حذف هذا الصنف',
  'Could not update the session': 'تعذّر تحديث الجلسة',
  'This session has no members': 'لا يوجد أعضاء في هذه الجلسة',
  'Could not set the payment option': 'تعذّر تحديد خيار الدفع',
  'Could not reopen the session': 'تعذّر إعادة فتح الجلسة',
  'Could not set the address': 'تعذّر تحديد العنوان',
  'Could not cancel the session': 'تعذّر إلغاء الجلسة',
  'Could not save this group': 'تعذّر حفظ هذه المجموعة',

  // Stories
  'That file is not a picture Gather can read.': 'هذا الملف ليس صورة يستطيع Gather قراءتها.',
  'That photo is too large to share. Try a smaller one.': 'الصورة كبيرة جدًا للمشاركة. جرّب صورة أصغر.',
  'Could not share that photo': 'تعذّر مشاركة هذه الصورة',
  'Could not do that just now': 'تعذّر تنفيذ ذلك الآن',
  'Could not remove that story': 'تعذّر حذف هذه القصة',

  // Support
  'Give your issue a short subject': 'أضف عنوانًا قصيرًا لمشكلتك',
  'Add a little more detail so we can help': 'أضف مزيدًا من التفاصيل حتى نتمكن من مساعدتك',
  'Could not send your message': 'تعذّر إرسال رسالتك',
  'Could not update that ticket': 'تعذّر تحديث هذه التذكرة',

  // Rewards
  'A code needs at least three characters': 'يجب أن يتكون الرمز من ثلاثة أحرف على الأقل',
  'Give the reward a name': 'أدخل اسمًا للمكافأة',
  'The discount must be more than zero': 'يجب أن يكون الخصم أكبر من صفر',
  'A percentage cannot be over 100': 'لا يمكن أن تتجاوز النسبة 100',
  'Could not save that reward': 'تعذّر حفظ هذه المكافأة',
  'Could not change that reward': 'تعذّر تعديل هذه المكافأة',
  'Could not give out that reward': 'تعذّر منح هذه المكافأة',
  'Enter a code': 'أدخل رمزًا',
  'Could not claim that code': 'تعذّر استخدام هذا الرمز',

  // Assistant
  'Type a question first': 'اكتب سؤالًا أولًا',
  'The assistant could not answer just now': 'تعذّر على المساعد الإجابة الآن',
  'Could not clear the conversation': 'تعذّر مسح المحادثة',
  'Ask me what to eat and I will look.': 'اسألني ماذا تأكل وسأبحث لك.',
  'I could not find anything matching that. Try naming a dish, a category like dessert or vegan, or a budget.':
      'لم أجد شيئًا مطابقًا. جرّب ذكر طبق، أو فئة مثل الحلويات أو النباتي، أو ميزانية.',
  'Open the session, tap Payment, and choose how to divide it. Equal split shares the bill evenly, Individual charges each person for what they added, and Host pays covers everyone. The split is worked out in whole halalas so the parts always add back to the total.':
      'افتح الجلسة، واضغط على الدفع، واختر طريقة التقسيم. التقسيم المتساوي يوزّع الفاتورة بالتساوي، والفردي يحاسب كل شخص على ما أضافه، والمضيف يدفع يغطي الجميع. يُحسب التقسيم بالهللات الكاملة حتى يساوي مجموع الأجزاء المبلغ الإجمالي دائمًا.',
  'Open your session and tap Invite. You can share the four-digit code, send the link, or search for someone by username. A session holds up to 20 people.':
      'افتح جلستك واضغط على دعوة. يمكنك مشاركة الرمز المكوّن من أربعة أرقام، أو إرسال الرابط، أو البحث عن شخص باسم المستخدم. تتسع الجلسة لما يصل إلى 20 شخصًا.',
  'Go to the Group tab and tap Join, then type the four-digit code the host gave you.':
      'انتقل إلى تبويب المجموعة واضغط على انضمام، ثم اكتب الرمز المكوّن من أربعة أرقام الذي أعطاك إياه المضيف.',
  'Open the order from the Orders tab. You will see each stage and, once a driver is assigned, their position on the map.':
      'افتح الطلب من تبويب الطلبات. سترى كل مرحلة، وموقع السائق على الخريطة بمجرد تعيينه.',
  'A host can cancel a session from the session menu. An order can be cancelled from the order screen while it is still being prepared.':
      'يمكن للمضيف إلغاء الجلسة من قائمة الجلسة. ويمكن إلغاء الطلب من شاشة الطلب ما دام قيد التحضير.',
  'Tap the heart on any restaurant or dish and it is saved to your favourites in the Profile tab.':
      'اضغط على القلب في أي مطعم أو طبق ليُحفظ في مفضلتك ضمن تبويب الملف الشخصي.',
  'Add a card or another payment method under Profile, Payment methods. The methods offered are the ones the administrator has enabled.':
      'أضف بطاقة أو وسيلة دفع أخرى من الملف الشخصي، ثم وسائل الدفع. الوسائل المتاحة هي التي فعّلها المسؤول.',
};
