import 'dart:math';

import 'voucher.dart';

/// Spin & Win (FR25) — the rules, kept free of Firebase so they can be tested.
abstract final class SpinRules {
  /// One spin per rolling 24 hours, counted from the last spin — not one per
  /// calendar day, which would let somebody spin at 23:59 and again at 00:01.
  static const cooldown = Duration(hours: 24);

  /// How long a won voucher stays usable.
  static const prizeLifetime = Duration(days: 7);

  /// When the next spin opens, or null if one is open already.
  static DateTime? nextSpinAt(DateTime? lastSpinAt, DateTime now) {
    if (lastSpinAt == null) return null;
    final next = lastSpinAt.add(cooldown);
    return next.isAfter(now) ? next : null;
  }

  static bool canSpin(DateTime? lastSpinAt, DateTime now) =>
      nextSpinAt(lastSpinAt, now) == null;

  /// Time left until the next spin; zero when one is open.
  static Duration timeUntilNextSpin(DateTime? lastSpinAt, DateTime now) {
    final next = nextSpinAt(lastSpinAt, now);
    return next == null ? Duration.zero : next.difference(now);
  }

  /// Picks a wedge, each with a chance proportional to its weight.
  ///
  /// [random] is injected so a test can pin the draw.
  static int pickIndex(List<SpinPrize> prizes, Random random) {
    if (prizes.isEmpty) throw ArgumentError('A wheel needs at least one prize');
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);
    if (total <= 0) return random.nextInt(prizes.length);
    var roll = random.nextInt(total);
    for (var i = 0; i < prizes.length; i++) {
      roll -= prizes[i].weight;
      if (roll < 0) return i;
    }
    return prizes.length - 1;
  }

  /// The prizes on the wheel.
  ///
  /// When an administrator has put at least two live rewards on the wheel
  /// those are the wheel; otherwise the built-in table is, so the feature
  /// works before anybody has set up a campaign. One flagged reward alone
  /// would make a one-slice wheel, which is no spin at all.
  static List<SpinPrize> wheelFor(List<Voucher> catalogue) {
    final flagged = catalogue.where((v) => v.onSpinWheel && v.isOffered).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    if (flagged.length < 2) return defaultPrizes;
    return flagged.map(SpinPrize.fromVoucher).toList();
  }

  /// Every spin wins something; the bigger prizes are rarer (as the FAQ says).
  /// Ordered so that big and small prizes alternate around the wheel.
  static const defaultPrizes = <SpinPrize>[
    SpinPrize(id: 'pct5', title: '5% off', discountType: DiscountType.percentage, discountValue: 5, weight: 35),
    SpinPrize(id: 'sar10', title: '10 SAR off', discountType: DiscountType.fixedAmount, discountValue: 10, minimumOrder: 50, weight: 7),
    SpinPrize(id: 'pct10', title: '10% off', discountType: DiscountType.percentage, discountValue: 10, weight: 25),
    SpinPrize(id: 'pct15', title: '15% off', discountType: DiscountType.percentage, discountValue: 15, weight: 10),
    SpinPrize(id: 'delivery', title: 'Free delivery', discountType: DiscountType.freeDelivery, weight: 20),
    SpinPrize(id: 'sar25', title: '25 SAR off', discountType: DiscountType.fixedAmount, discountValue: 25, minimumOrder: 100, weight: 3),
  ];
}

/// One wedge of the Spin & Win wheel.
class SpinPrize {
  const SpinPrize({
    required this.id,
    required this.title,
    required this.discountType,
    this.discountValue = 0,
    this.minimumOrder = 0,
    this.weight = 1,
    this.voucher,
  });

  /// A wedge made from an administrator's reward. Its chance is worked out
  /// from what it is worth — rarer the bigger it is — so the admin only has
  /// to flag it. A fixed amount is weighed as a percentage of a 100 SAR
  /// order, and free delivery as about 10%.
  factory SpinPrize.fromVoucher(Voucher v) {
    final worth = switch (v.discountType) {
      DiscountType.percentage || DiscountType.fixedAmount => v.discountValue,
      DiscountType.freeDelivery => 10.0,
    };
    return SpinPrize(
      id: v.id,
      title: v.title,
      discountType: v.discountType,
      discountValue: v.discountValue,
      minimumOrder: v.minimumOrder,
      weight: (100 / worth.clamp(1, 100)).round().clamp(1, 100),
      voucher: v,
    );
  }

  final String id;

  /// English, stored on the won voucher as its name.
  final String title;
  final DiscountType discountType;
  final double discountValue;
  final double minimumOrder;

  /// Relative chance of landing here.
  final int weight;

  /// The catalogue reward behind this wedge, if an administrator made it.
  final Voucher? voucher;

  /// The voucher the winner receives. Admin rewards keep their code and
  /// catalogue id, so redeeming one counts against the campaign; built-in
  /// prizes get a code of their own.
  UserVoucher toUserVoucher({
    required String id,
    required String code,
    required DateTime now,
  }) {
    var expires = now.add(SpinRules.prizeLifetime);
    final until = voucher?.validUntil;
    if (until != null && until.isBefore(expires)) expires = until;
    return UserVoucher(
      id: id,
      voucherId: voucher?.id ?? '',
      code: voucher?.code ?? code,
      title: voucher == null ? 'Spin & Win · $title' : title,
      description: voucher?.description ?? 'Won on Spin & Win',
      discountType: discountType,
      discountValue: discountValue,
      minimumOrder: minimumOrder,
      grantedAt: now,
      expiresAt: expires,
    );
  }
}

/// What a spin produced: which wedge, and the voucher now in the wallet.
class SpinOutcome {
  const SpinOutcome({required this.index, required this.prize, required this.voucher});

  final int index;
  final SpinPrize prize;
  final UserVoucher voucher;
}
