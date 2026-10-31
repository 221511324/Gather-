import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/l10n/tr.dart';
import 'package:gather/core/models/cart_line.dart';
import 'package:gather/core/models/group_session.dart';
import 'package:gather/core/models/reward_rules.dart';
import 'package:gather/core/models/voucher.dart';

/// US15 unit tests — spending a reward at checkout and on a group order,
/// TC_RS_001+.
void main() {
  UserVoucher reward({
    String id = 'r1',
    DiscountType type = DiscountType.percentage,
    double value = 20,
    double minimum = 0,
    VoucherStatus status = VoucherStatus.available,
    DateTime? expires,
  }) =>
      UserVoucher(
        id: id,
        voucherId: '',
        code: 'SPIN-AB12CD',
        title: 'Spin & Win · 20% off',
        discountType: type,
        discountValue: value,
        minimumOrder: minimum,
        status: status,
        expiresAt: expires,
      );

  GroupSession session(
    String id, {
    SessionStage stage = SessionStage.payment,
    String? heldId,
    String? holder,
  }) =>
      GroupSession.fromMap(id, {
        'code': '1234',
        'hostId': 'host',
        'hostName': 'Host',
        'stage': stage.name,
        'voucherHeldId': heldId,
        'voucherHolderUid': holder,
      });

  group('TC_RS quote — what a reward takes off this bill', () {
    test('TC_RS_001 a usable reward is priced against the order', () {
      final q = RewardRules.quote(reward(), subtotal: 100, deliveryFee: 10);
      expect(q.isOk, isTrue);
      expect(q.discount, 20);
    });

    test('TC_RS_002 below the minimum it is refused with the minimum', () {
      final q = RewardRules.quote(reward(minimum: 50), subtotal: 49, deliveryFee: 10);
      expect(q.isOk, isFalse);
      expect(q.discount, 0);
      expect(q.problem, 'SPIN-AB12CD needs an order of at least 50 SAR');
      // And it reads in Arabic through the existing template.
      expect(translate('ar', q.problem!), isNot(contains('needs')));
    });

    test('TC_RS_003 a used or expired reward is refused', () {
      expect(
          RewardRules.quote(reward(status: VoucherStatus.used),
                  subtotal: 100, deliveryFee: 10)
              .problem,
          'That reward has already been used');
      expect(
          RewardRules.quote(reward(expires: DateTime(2000)),
                  subtotal: 100, deliveryFee: 10)
              .problem,
          'That reward has expired');
    });

    test('TC_RS_004 free delivery on a free-delivery order takes nothing off', () {
      final q = RewardRules.quote(reward(type: DiscountType.freeDelivery),
          subtotal: 100, deliveryFee: 0);
      expect(q.isOk, isFalse);
      expect(q.problem, 'That reward takes nothing off this order');
    });

    test('TC_RS_005 the discount is shown in the totals and lowers the total', () {
      const base = CartTotals(subtotal: 100, deliveryFee: 10, serviceFee: 3, discount: 0);
      final t = RewardRules.withDiscount(base, 20);
      expect(t.discount, 20);
      expect(t.total, 93);
      expect(t.subtotal, base.subtotal);
    });
  });

  group('TC_RS which rewards are offered', () {
    test('TC_RS_006 spent, expired and session-held rewards are not offered', () {
      final held = [
        reward(id: 'a'),
        reward(id: 'b', status: VoucherStatus.used),
        reward(id: 'c', expires: DateTime(2000)),
        reward(id: 'd'),
      ];
      final offered = RewardRules.spendable(held, heldElsewhere: {'d'});
      expect(offered.map((v) => v.id), ['a']);
    });

    test('TC_RS_007 only live sessions, held by this person, reserve a reward', () {
      final sessions = [
        session('s1', heldId: 'a', holder: 'me'),
        session('s2', heldId: 'b', holder: 'me', stage: SessionStage.placed),
        session('s3', heldId: 'c', holder: 'me', stage: SessionStage.cancelled),
        session('s4', heldId: 'd', holder: 'someone-else'),
        session('s5'),
      ];
      expect(RewardRules.heldInSessions(sessions, holderUid: 'me'), {'a'});
      // The session being edited does not reserve against itself.
      expect(
          RewardRules.heldInSessions(sessions, holderUid: 'me', exceptSessionId: 's1'),
          isEmpty);
    });

    test('TC_RS_008 a picked reward is dropped once it stops being offered', () {
      final a = reward(id: 'a');
      expect(RewardRules.resolve(a, [a]), same(a));
      expect(RewardRules.resolve(a, const []), isNull);
      expect(RewardRules.resolve(null, [a]), isNull);
    });
  });

  group('TC_RS group sessions — apply, clear, redeem', () {
    test('TC_RS_009 applying records the code, amount, reward and holder', () {
      final fields = RewardRules.appliedFields(reward(id: 'r9'), holderUid: 'host', discount: 12.5);
      expect(fields, {
        'voucherCode': 'SPIN-AB12CD',
        'voucherDiscount': 12.5,
        'voucherHeldId': 'r9',
        'voucherHolderUid': 'host',
      });
      final s = GroupSession.fromMap('s', {'stage': 'payment', ...fields});
      expect(s.voucherHeldId, 'r9');
      expect(s.voucherHolderUid, 'host');
      expect(s.toMap()['voucherHeldId'], 'r9');
    });

    test('TC_RS_010 clearing removes every trace of the reward', () {
      final s = GroupSession.fromMap('s', {
        'stage': 'payment',
        ...RewardRules.appliedFields(reward(), holderUid: 'host', discount: 5),
        ...RewardRules.clearedFields,
      });
      expect(s.voucherCode, isNull);
      expect(s.voucherDiscount, 0);
      expect(s.voucherHeldId, isNull);
      expect(s.voucherHolderUid, isNull);
      expect(RewardRules.shouldRedeem(s, 'host'), isFalse);
    });

    test('TC_RS_011 only the holder redeems, and only when a reward is applied', () {
      final s = session('s', heldId: 'r1', holder: 'host');
      expect(RewardRules.shouldRedeem(s, 'host'), isTrue);
      expect(RewardRules.shouldRedeem(s, 'member'), isFalse);
      expect(RewardRules.shouldRedeem(session('s'), 'host'), isFalse);
    });
  });

  test('TC_RS_012 every new message has Arabic', () {
    for (final english in [
      'REWARD',
      'Use a reward',
      "Don't use a reward",
      'That reward takes nothing off this order',
      'That reward is already applied to another group order',
    ]) {
      expect(translate('ar', english), isNot(english), reason: english);
    }
    final soft = translate('ar',
        'Order placed, but the reward was not marked as used: That reward has already been used');
    expect(soft, isNot(contains('Order placed')));
    expect(soft, isNot(contains('already been used')));
  });
}
