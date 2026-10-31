/// Arabic count forms for the administration console (dashboard, users,
/// restaurants, orders, rewards, payment methods). The call sites pick the
/// form with `countNote` from qa1.dart; a form with no entry here uses the
/// plain key's Arabic.
const Map<String, String> arQa3 = {
  '{count} person|one': 'شخص واحد',

  '{shown} of {total} accounts|one': '{shown} من حساب واحد',
  '{shown} of {total} accounts|two': '{shown} من حسابين',
  '{shown} of {total} accounts|few': '{shown} من {total} حسابات',
  '{shown} of {total} accounts|many': '{shown} من {total} حسابًا',

  '{shown} of {total} restaurants|one': '{shown} من مطعم واحد',
  '{shown} of {total} restaurants|two': '{shown} من مطعمين',
  '{shown} of {total} restaurants|few': '{shown} من {total} مطاعم',
  '{shown} of {total} restaurants|many': '{shown} من {total} مطعمًا',

  '{count} rewards · {live} available to claim|one':
      'مكافأة واحدة · المتاح منها {live}',
  '{count} rewards · {live} available to claim|two':
      'مكافأتان · المتاح منها {live}',
  '{count} rewards · {live} available to claim|many':
      '{count} مكافأة · المتاح منها {live}',

  '{count} methods · {enabled} available to customers|two':
      'طريقتان · {enabled} متاحة للعملاء',
  '{count} methods · {enabled} available to customers|many':
      '{count} طريقة · {enabled} متاحة للعملاء',
};
