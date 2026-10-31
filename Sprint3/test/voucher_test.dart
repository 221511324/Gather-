import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/models/voucher.dart';

/// US15 unit tests — how a reward reduces a bill, TC_UV_001+.
void main() {
  Voucher v({
    DiscountType type = DiscountType.percentage,
    double value = 10,
    double minimum = 0,
    int max = 0,
    int redeemed = 0,
    DateTime? until,
    bool active = true,
  }) =>
      Voucher(
        id: 'v1', code: 'TEST', title: 'Test reward',
        discountType: type, discountValue: value, minimumOrder: minimum,
        maxRedemptions: max, redeemedCount: redeemed, validUntil: until,
        isActive: active,
      );

  group('US15 — working out the discount', () {
    test('TC_UV_001 a percentage comes off the subtotal, not the fees', () {
      final d = v(value: 10).discountOn(subtotal: 200, deliveryFee: 15);
      expect(d, 20, reason: '10% of 200, ignoring the delivery fee');
    });

    test('TC_UV_002 a fixed amount comes off as stated', () {
      expect(v(type: DiscountType.fixedAmount, value: 25)
          .discountOn(subtotal: 200, deliveryFee: 15), 25);
    });

    test('TC_UV_003 free delivery is worth exactly the delivery fee', () {
      expect(v(type: DiscountType.freeDelivery)
          .discountOn(subtotal: 200, deliveryFee: 15), 15);
      expect(v(type: DiscountType.freeDelivery)
          .discountOn(subtotal: 200, deliveryFee: 0), 0,
          reason: 'nothing to give away when delivery is already free');
    });

    test('TC_UV_004 a discount can never exceed the bill', () {
      // 50 off a 30 SAR order must take off 30, not 50 - a bill may reach
      // zero but must never go below it.
      final d = v(type: DiscountType.fixedAmount, value: 50)
          .discountOn(subtotal: 30, deliveryFee: 10);
      expect(d, 30);
    });

    test('TC_UV_005 below the minimum order it is worth nothing', () {
      expect(v(value: 50, minimum: 100).discountOn(subtotal: 99, deliveryFee: 10), 0);
      expect(v(value: 50, minimum: 100).discountOn(subtotal: 100, deliveryFee: 10), 50,
          reason: 'exactly the minimum must qualify');
    });

    test('TC_UV_006 100 per cent clears the items but not the fees', () {
      expect(v(value: 100).discountOn(subtotal: 80, deliveryFee: 12), 80);
    });
  });

  group('US15 — whether it can be used at all', () {
    final past = DateTime.now().subtract(const Duration(days: 1));
    final future = DateTime.now().add(const Duration(days: 30));

    test('TC_UV_007 an expired reward is not offered', () {
      expect(v(until: past).hasExpired, isTrue);
      expect(v(until: past).isOffered, isFalse);
      expect(v(until: future).isOffered, isTrue);
    });

    test('TC_UV_008 a reward with no expiry never expires', () {
      expect(v().hasExpired, isFalse);
    });

    test('TC_UV_009 a fully claimed reward is not offered', () {
      expect(v(max: 10, redeemed: 10).isExhausted, isTrue);
      expect(v(max: 10, redeemed: 9).isExhausted, isFalse);
      expect(v(max: 0, redeemed: 999).isExhausted, isFalse,
          reason: 'zero means unlimited');
    });

    test('TC_UV_010 a hidden reward is not offered', () {
      expect(v(active: false).isOffered, isFalse);
    });
  });

  group('US15 — a reward somebody holds', () {
    test('TC_UV_011 the terms are copied when it is granted', () {
      // Changing the campaign afterwards must not change what was promised.
      final held = UserVoucher.fromVoucher(
          v(type: DiscountType.fixedAmount, value: 30, minimum: 100), id: 'h1');
      expect(held.discountValue, 30);
      expect(held.minimumOrder, 100);
      expect(held.code, 'TEST');
      expect(held.status, VoucherStatus.available);
    });

    test('TC_UV_012 a used reward is worth nothing', () {
      const used = UserVoucher(
          id: 'h1', voucherId: 'v1', code: 'TEST', title: 'x',
          discountValue: 50, status: VoucherStatus.used);
      expect(used.isUsable, isFalse);
      expect(used.discountOn(subtotal: 200, deliveryFee: 10), 0);
    });

    test('TC_UV_013 an expired reward is worth nothing', () {
      final expired = UserVoucher(
          id: 'h1', voucherId: 'v1', code: 'TEST', title: 'x',
          discountValue: 50,
          expiresAt: DateTime.now().subtract(const Duration(days: 1)));
      expect(expired.isUsable, isFalse);
      expect(expired.discountOn(subtotal: 200, deliveryFee: 10), 0);
    });

    test('TC_UV_014 the summary says what it is worth', () {
      expect(v(value: 15).summary, '15% off');
      expect(v(type: DiscountType.fixedAmount, value: 20).summary, '20 SAR off');
      expect(v(type: DiscountType.freeDelivery).summary, 'Free delivery');
    });
  });
}
