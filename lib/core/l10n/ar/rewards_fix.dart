/// Spending rewards: the reward row and picker at checkout, and the messages
/// when a reward cannot be applied or marked used.
const Map<String, String> arRewardsFix = {
  // Checkout
  'REWARD': 'المكافأة',
  'Use': 'استخدام',
  'Use a reward': 'استخدم مكافأة',
  "Don't use a reward": 'عدم استخدام مكافأة',
  '{code} · −{amount}': '{code} · −{amount}',

  // Why a reward cannot be used
  'That reward takes nothing off this order': 'هذه المكافأة لا تخفض شيئًا من هذا الطلب',
  'That reward is already applied to another group order':
      'هذه المكافأة مطبقة بالفعل على طلب جماعي آخر',
  'Order placed, but the reward was not marked as used: {reason}':
      'تم تقديم الطلب، لكن تعذّر تسجيل المكافأة كمستخدمة: {reason}',
};
