/// Arabic for the order-progress notifications and their pop-up (US16).
/// The bodies are templates: a stored "Kudu has accepted your order." is
/// matched back to its template and the restaurant name kept.
const Map<String, String> arOrderAlerts = {
  'Ready for pickup': 'جاهز للاستلام',
  'Your food is ready and a rider is collecting it.': 'طعامك جاهز والمندوب في طريقه لاستلامه.',
  'Order confirmed': 'تم تأكيد الطلب',
  'Your food is being prepared': 'جارٍ تحضير طعامك',
  'Your order is ready': 'طلبك جاهز',
  'Your order is on its way': 'طلبك في الطريق إليك',
  'Order delivered': 'تم توصيل الطلب',
  'Order cancelled': 'تم إلغاء الطلب',
  '{restaurant} has accepted your order.': 'قبِل {restaurant} طلبك.',
  '{restaurant} has started preparing your food.': 'بدأ {restaurant} بتحضير طعامك.',
  'Ready for pickup. A rider is collecting it from {restaurant}.':
      'جاهز للاستلام. المندوب يستلمه الآن من {restaurant}.',
  'Your rider has picked up your order from {restaurant} and is heading to you.':
      'استلم المندوب طلبك من {restaurant} وهو في الطريق إليك.',
  'Your order from {restaurant} has arrived. Enjoy your meal!':
      'وصل طلبك من {restaurant}. بالهناء والعافية!',
  'Your order from {restaurant} was cancelled.': 'تم إلغاء طلبك من {restaurant}.',
};
