import 'cart_line.dart';
import 'group_session.dart';
import 'voucher.dart';

/// What a held reward would do to one bill: the amount it takes off, or the
/// reason it cannot be used (an English sentence, translated where shown).
class RewardQuote {
  const RewardQuote._(this.discount, this.problem);

  const RewardQuote.ok(double discount) : this._(discount, null);
  const RewardQuote.refused(String problem) : this._(0, problem);

  final double discount;
  final String? problem;

  bool get isOk => problem == null;
}

/// US15 — the bookkeeping around spending a reward, kept free of Firebase so
/// it can be unit-tested: which rewards can be offered, what one is worth on
/// a given bill, and what a session records about the reward applied to it.
abstract final class RewardRules {
  /// Prices [reward] against a bill. Refuses one that is spent or expired,
  /// one whose minimum the order does not reach, and one that would take
  /// nothing off (free delivery on an order whose delivery is already free).
  static RewardQuote quote(
    UserVoucher reward, {
    required double subtotal,
    required double deliveryFee,
  }) {
    if (!reward.isUsable) {
      return RewardQuote.refused(reward.hasExpired
          ? 'That reward has expired'
          : 'That reward has already been used');
    }
    if (subtotal < reward.minimumOrder) {
      return RewardQuote.refused('${reward.code} needs an order of at least '
          '${reward.minimumOrder.toStringAsFixed(0)} SAR');
    }
    final discount = reward.discountOn(subtotal: subtotal, deliveryFee: deliveryFee);
    if (discount <= 0) {
      return const RewardQuote.refused('That reward takes nothing off this order');
    }
    return RewardQuote.ok(discount);
  }

  /// Ids of [holderUid]'s rewards already applied to a live session other
  /// than [exceptSessionId]. A reward is only marked used when an order is
  /// placed, so until then this is what stops it being promised twice.
  static Set<String> heldInSessions(
    Iterable<GroupSession> sessions, {
    required String holderUid,
    String? exceptSessionId,
  }) =>
      {
        for (final s in sessions)
          if (s.stage.isLive &&
              s.id != exceptSessionId &&
              s.voucherHolderUid == holderUid &&
              (s.voucherHeldId ?? '').isNotEmpty)
            s.voucherHeldId!,
      };

  /// The rewards worth offering at a checkout: usable, and not already
  /// applied to a group order that has not been placed yet.
  static List<UserVoucher> spendable(
    Iterable<UserVoucher> held, {
    Set<String> heldElsewhere = const {},
  }) =>
      held.where((v) => v.isUsable && !heldElsewhere.contains(v.id)).toList();

  /// The reward the user picked, re-read from the live list so one spent or
  /// expired on another device since it was picked is dropped, not charged.
  static UserVoucher? resolve(UserVoucher? picked, List<UserVoucher> spendable) {
    if (picked == null) return null;
    for (final v in spendable) {
      if (v.id == picked.id) return v;
    }
    return null;
  }

  /// [totals] with [discount] taken off.
  static CartTotals withDiscount(CartTotals totals, double discount) => CartTotals(
        subtotal: totals.subtotal,
        deliveryFee: totals.deliveryFee,
        serviceFee: totals.serviceFee,
        discount: discount,
      );

  /// What a session stores when [reward] is applied to it. The held reward's
  /// id and holder are kept alongside the code so the reward can be marked
  /// used when the order is placed — the code alone cannot find it.
  static Map<String, Object?> appliedFields(
    UserVoucher reward, {
    required String holderUid,
    required double discount,
  }) =>
      {
        'voucherCode': reward.code,
        'voucherDiscount': discount,
        'voucherHeldId': reward.id,
        'voucherHolderUid': holderUid,
      };

  /// What a session stores once its reward is taken off.
  static const Map<String, Object?> clearedFields = {
    'voucherCode': null,
    'voucherDiscount': 0,
    'voucherHeldId': null,
    'voucherHolderUid': null,
  };

  /// Whether [uid] is the one who must mark this session's reward used.
  /// Only the holder can write their own rewards, so nobody else tries.
  static bool shouldRedeem(GroupSession session, String uid) =>
      (session.voucherHeldId ?? '').isNotEmpty && session.voucherHolderUid == uid;
}
