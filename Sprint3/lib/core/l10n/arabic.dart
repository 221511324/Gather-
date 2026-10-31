import 'ar/account.dart';
import 'ar/admin.dart';
import 'ar/assistant_ai.dart';
import 'ar/assistant_fab.dart';
import 'ar/common.dart';
import 'ar/core.dart';
import 'ar/group.dart';
import 'ar/messages.dart';
import 'ar/payments.dart';
import 'ar/qa1.dart';
import 'ar/qa2.dart';
import 'ar/qa3.dart';
import 'ar/rewards_fix.dart';
import 'ar/shop.dart';
import 'ar/spin.dart';
import 'ar/stories_home.dart';

/// Every Arabic translation, keyed by the English it replaces. Each area of
/// the app keeps its strings in its own file under `ar/`; a key repeated in
/// two files is fine; [arCommon] comes last so it settles any word the areas
/// translated differently.
final Map<String, String> arabic = {
  ...arAccount,
  ...arAdmin,
  ...arAssistantAi,
  ...arAssistantFab,
  ...arCore,
  ...arGroup,
  ...arShop,
  ...arMessages,
  ...arPayments,
  ...arQa1,
  ...arQa2,
  ...arQa3,
  ...arRewardsFix,
  ...arSpin,
  ...arStoriesHome,
  ...arCommon,
};
