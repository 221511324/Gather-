import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/l10n/tr.dart';
import 'package:gather/core/models/spin.dart';
import 'package:gather/core/models/voucher.dart';

/// A Random that hands back a fixed sequence, so a draw can be pinned.
class _Fixed implements Random {
  _Fixed(this.values);
  final List<int> values;
  var _i = 0;

  @override
  int nextInt(int max) => values[_i++ % values.length] % max;
  @override
  double nextDouble() => 0;
  @override
  bool nextBool() => false;
}

/// FR25 unit tests — Spin & Win, TC_SW_001+.
void main() {
  final now = DateTime(2026, 10, 31, 12);

  group('FR25 — one spin every 24 hours', () {
    test('TC_SW_001 somebody who never spun can spin', () {
      expect(SpinRules.canSpin(null, now), isTrue);
      expect(SpinRules.nextSpinAt(null, now), isNull);
      expect(SpinRules.timeUntilNextSpin(null, now), Duration.zero);
    });

    test('TC_SW_002 the window is a rolling 24 hours, not a calendar day', () {
      // Spun at 23:59 yesterday: a calendar-day rule would allow a spin now.
      final late = DateTime(2026, 10, 30, 23, 59);
      expect(SpinRules.canSpin(late, DateTime(2026, 10, 31, 0, 1)), isFalse);
      expect(SpinRules.canSpin(late, DateTime(2026, 10, 31, 23, 59)), isTrue);
    });

    test('TC_SW_003 the countdown is the time left until 24 hours have passed', () {
      final last = now.subtract(const Duration(hours: 10, minutes: 40));
      expect(SpinRules.timeUntilNextSpin(last, now),
          const Duration(hours: 13, minutes: 20));
      expect(SpinRules.nextSpinAt(last, now), last.add(const Duration(hours: 24)));
    });

    test('TC_SW_004 exactly 24 hours later the spin opens', () {
      final last = now.subtract(const Duration(hours: 24));
      expect(SpinRules.canSpin(last, now), isTrue);
      expect(SpinRules.canSpin(last.add(const Duration(seconds: 1)), now), isFalse);
    });
  });

  group('FR25 — picking a prize', () {
    const prizes = [
      SpinPrize(id: 'a', title: 'A', discountType: DiscountType.percentage, discountValue: 5, weight: 6),
      SpinPrize(id: 'b', title: 'B', discountType: DiscountType.percentage, discountValue: 10, weight: 3),
      SpinPrize(id: 'c', title: 'C', discountType: DiscountType.freeDelivery, weight: 1),
    ];

    test('TC_SW_005 each roll falls in the wedge its weight covers', () {
      // Total weight 10: rolls 0-5 are A, 6-8 are B, 9 is C.
      expect(SpinRules.pickIndex(prizes, _Fixed([0])), 0);
      expect(SpinRules.pickIndex(prizes, _Fixed([5])), 0);
      expect(SpinRules.pickIndex(prizes, _Fixed([6])), 1);
      expect(SpinRules.pickIndex(prizes, _Fixed([8])), 1);
      expect(SpinRules.pickIndex(prizes, _Fixed([9])), 2);
    });

    test('TC_SW_006 over many spins the odds follow the weights', () {
      final random = Random(42);
      final counts = List.filled(prizes.length, 0);
      for (var i = 0; i < 20000; i++) {
        counts[SpinRules.pickIndex(prizes, random)]++;
      }
      expect(counts[0] / 20000, closeTo(0.6, 0.02));
      expect(counts[1] / 20000, closeTo(0.3, 0.02));
      expect(counts[2] / 20000, closeTo(0.1, 0.02));
    });

    test('TC_SW_007 the built-in table always wins something, bigger prizes rarer', () {
      final table = SpinRules.defaultPrizes;
      expect(table.length, greaterThanOrEqualTo(4));
      expect(table.every((p) => p.weight > 0), isTrue);
      int weightOf(String id) => table.firstWhere((p) => p.id == id).weight;
      expect(weightOf('pct5'), greaterThan(weightOf('pct10')));
      expect(weightOf('pct10'), greaterThan(weightOf('pct15')));
      expect(weightOf('sar10'), greaterThan(weightOf('sar25')));
    });
  });

  group('FR25 — where the prizes come from', () {
    Voucher v(String code, {bool wheel = true, bool active = true, double value = 10}) => Voucher(
          id: code.toLowerCase(), code: code, title: '$code title',
          discountValue: value, isActive: active, onSpinWheel: wheel);

    test('TC_SW_008 with fewer than two flagged rewards the built-in table is used', () {
      expect(SpinRules.wheelFor([]), SpinRules.defaultPrizes);
      expect(SpinRules.wheelFor([v('ONE'), v('TWO', wheel: false)]), SpinRules.defaultPrizes);
      expect(SpinRules.wheelFor([v('ONE'), v('TWO', active: false)]), SpinRules.defaultPrizes,
          reason: 'a hidden reward is not on the wheel');
    });

    test('TC_SW_009 two or more flagged rewards become the wheel, weighted by worth', () {
      final wheel = SpinRules.wheelFor([v('BIG', value: 50), v('SMALL', value: 5), v('OFF', wheel: false)]);
      expect(wheel.map((p) => p.id), ['big', 'small']);
      expect(wheel[1].weight, greaterThan(wheel[0].weight));
    });
  });

  group('FR25 — the voucher that is won', () {
    test('TC_SW_010 a built-in prize gets its own code and a 7-day expiry', () {
      final prize = SpinRules.defaultPrizes.firstWhere((p) => p.id == 'sar10');
      final won = prize.toUserVoucher(id: 'x', code: 'SPIN-ABC123', now: now);
      expect(won.code, 'SPIN-ABC123');
      expect(won.voucherId, isEmpty);
      expect(won.expiresAt, now.add(const Duration(days: 7)));
      expect(won.discountType, DiscountType.fixedAmount);
      expect(won.minimumOrder, 50);
      expect(won.isUsable, isTrue);
    });

    test('TC_SW_011 an admin reward keeps its code, and never outlives the campaign', () {
      final campaign = Voucher(
        id: 'camp', code: 'WHEEL20', title: '20% off', discountValue: 20,
        onSpinWheel: true, validUntil: now.add(const Duration(days: 2)),
      );
      final won = SpinPrize.fromVoucher(campaign).toUserVoucher(id: 'x', code: 'SPIN-IGNORED', now: now);
      expect(won.code, 'WHEEL20');
      expect(won.voucherId, 'camp');
      expect(won.expiresAt, now.add(const Duration(days: 2)));
    });

    test('TC_SW_012 the wheel flag survives a round trip through Firestore', () {
      const flagged = Voucher(id: 'a', code: 'ABC', title: 'T', onSpinWheel: true);
      expect(Voucher.fromMap('a', flagged.toMap()).onSpinWheel, isTrue);
      expect(Voucher.fromMap('a', {'code': 'ABC'}).onSpinWheel, isFalse);
    });
  });

  test('TC_SW_013 Spin & Win reads in Arabic', () {
    expect(translate('ar', 'Spin & Win'), 'لف واربح');
    expect(translate('ar', 'Next spin in {time}', {'time': '13'}), contains('13'));
    expect(translate('ar', 'Your free spin is ready'), isNot(matches(RegExp('[A-Za-z]'))));
  });
}
