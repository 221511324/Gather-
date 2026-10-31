import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/models/payment_method.dart';
import 'package:gather/core/models/payment_option.dart';
import 'package:gather/core/services/payment_service.dart';
import 'package:gather/features/checkout/checkout_widgets.dart';

/// Sprint 3 unit tests — payment rules that need no database.
///
/// US20 (an administrator manages the payment methods the platform accepts),
/// plus the card-entry rules that belong to US10 (group payment) and were
/// re-checked because the payment work touched them.
void main() {
  group('US10 — card number validation', () {
    test('TC_UP_001 accepts the real card brands', () {
      for (final (brand, number) in [
        ('Visa', '4242424242424242'),
        ('Mastercard', '5555555555554444'),
        ('Amex', '378282246310005'),
      ]) {
        expect(PaymentService.validateCardNumber(number), isNull, reason: brand);
        expect(PaymentService.brandOf(number), brand);
      }
    });

    test('TC_UP_002 rejects a number that fails the checksum', () {
      expect(PaymentService.validateCardNumber('1234567890123456'), isNotNull);
    });

    test('TC_UP_003 rejects numbers that are too short or too long', () {
      expect(PaymentService.validateCardNumber('424242'), isNotNull);
      expect(PaymentService.validateCardNumber('4' * 20), isNotNull);
    });

    test('TC_UP_004 rejects letters and an empty entry', () {
      expect(PaymentService.validateCardNumber(''), isNotNull);
      expect(PaymentService.validateCardNumber('4242abcd4242'), isNotNull);
    });
  });

  group('US10 — expiry validation', () {
    final nextYear = DateTime.now().year + 1;

    test('TC_UP_005 accepts a future date as MM/YY and MM/YYYY', () {
      expect(PaymentService.validateExpiry(12, nextYear % 100), isNull);
      expect(PaymentService.validateExpiry(12, nextYear), isNull);
    });

    test('TC_UP_006 rejects a date in the past', () {
      expect(PaymentService.validateExpiry(1, 20), isNotNull);
    });

    test('TC_UP_007 rejects an impossible month', () {
      expect(PaymentService.validateExpiry(0, nextYear % 100), isNotNull);
      expect(PaymentService.validateExpiry(13, nextYear % 100), isNotNull);
    });
  });

  group('US10 — what is shown and what is stored', () {
    test('TC_UP_008 the expiry always reads MM/YY, however it was stored', () {
      // A card written as 2029 and one written as 29 must look the same.
      const fourDigit = SavedPaymentMethod(
          id: 'a', type: PaymentMethodType.card, expiryMonth: 11, expiryYear: 2029);
      const twoDigit = SavedPaymentMethod(
          id: 'b', type: PaymentMethodType.card, expiryMonth: 11, expiryYear: 29);
      expect(fourDigit.expiryLabel, '11/29');
      expect(twoDigit.expiryLabel, '11/29');
    });

    test('TC_UP_009 a card is labelled by brand and last four only', () {
      const card = SavedPaymentMethod(
          id: 'a', type: PaymentMethodType.card, brand: 'Visa', last4: '4242');
      expect(card.label, 'Visa •••• 4242');
      expect(card.toMap().toString(), isNot(contains('4242424242424242')));
    });

    test('TC_UP_010 an administrator-added method is labelled by its name', () {
      const paypal = SavedPaymentMethod(
          id: 'a', type: PaymentMethodType.other, optionName: 'PayPal');
      expect(paypal.label, 'PayPal');
    });

    test('TC_UP_011 an expired card is reported as expired', () {
      const old = SavedPaymentMethod(
          id: 'a', type: PaymentMethodType.card, expiryMonth: 1, expiryYear: 20);
      expect(old.isExpired, isTrue);
      const wallet = SavedPaymentMethod(id: 'b', type: PaymentMethodType.other);
      expect(wallet.isExpired, isFalse, reason: 'a wallet has no expiry');
    });
  });

  group('US20 — cash is gone', () {
    test('TC_UP_012 there is no cash payment type any more', () {
      expect(PaymentMethodType.values.map((t) => t.name), isNot(contains('cash')));
      for (final t in PaymentMethodType.values) {
        expect(t.label.toLowerCase(), isNot(contains('cash')));
      }
    });
  });

  group('US20 — admin options map onto the right icon', () {
    test('TC_UP_013 a known name keeps its own type', () {
      expect(PaymentService.typeForOption('Apple Pay'), PaymentMethodType.applePay);
      expect(PaymentService.typeForOption('stc pay'), PaymentMethodType.stcPay);
      expect(PaymentService.typeForOption('Card'), PaymentMethodType.card);
    });

    test('TC_UP_014 anything the administrator invents still has a type', () {
      expect(PaymentService.typeForOption('PayPal'), PaymentMethodType.other);
      expect(PaymentService.typeForOption('Tabby'), PaymentMethodType.other);
    });
  });

  // Client issue: switching Card off in the console must stop a saved card
  // being used to pay, straight away.
  group('US20 — a disabled option cannot be used to pay', () {
    const card = PaymentOption(id: 'opt-card', name: 'Card');
    const apple = PaymentOption(id: 'opt-apple', name: 'Apple Pay');
    const paypal = PaymentOption(id: 'opt-paypal', name: 'PayPal');
    const visa = SavedPaymentMethod(
        id: 'm1', type: PaymentMethodType.card, brand: 'Visa', last4: '4242',
        expiryMonth: 12, expiryYear: 2099, isDefault: true);
    // A wallet saved before options were managed: no name, no id.
    const legacyApple = SavedPaymentMethod(id: 'm2', type: PaymentMethodType.applePay);
    const savedPaypal = SavedPaymentMethod(
        id: 'm3', type: PaymentMethodType.other, optionName: 'PayPal', optionId: 'opt-paypal');

    test('TC_UP_015 everything is usable while every option is enabled', () {
      final usable = PaymentService.usableMethods(
          [visa, legacyApple, savedPaypal], [card, apple, paypal]);
      expect(usable.map((m) => m.id), ['m1', 'm2', 'm3']);
    });

    test('TC_UP_016 switching Card off removes saved cards only', () {
      final catalog = [card.copyWith(isEnabled: false), apple, paypal];
      expect(PaymentService.isUsable(visa, catalog), isFalse);
      expect(PaymentService.usableMethods([visa, legacyApple, savedPaypal], catalog)
          .map((m) => m.id), ['m2', 'm3']);
    });

    test('TC_UP_017 a wallet follows its option by id, even after a rename', () {
      final renamed = [card, apple, paypal.copyWith(name: 'PayPal Checkout')];
      expect(PaymentService.isUsable(savedPaypal, renamed), isTrue);
      final off = [card, apple, paypal.copyWith(name: 'PayPal Checkout', isEnabled: false)];
      expect(PaymentService.isUsable(savedPaypal, off), isFalse);
    });

    test('TC_UP_018 a legacy wallet is matched by its type', () {
      expect(PaymentService.isUsable(legacyApple, [card, apple]), isTrue);
      expect(PaymentService.isUsable(legacyApple, [card, apple.copyWith(isEnabled: false)]),
          isFalse);
    });

    test('TC_UP_019 a method whose option was deleted is not usable', () {
      expect(PaymentService.isUsable(savedPaypal, [card, apple]), isFalse);
    });

    test('TC_UP_020 nothing is blocked before any option is configured', () {
      expect(PaymentService.isUsable(visa, const []), isTrue);
    });

    test('TC_UP_021 a disabled default falls back to another usable method', () {
      final catalog = [card.copyWith(isEnabled: false), apple, paypal];
      final usable = PaymentService.usableMethods([visa, legacyApple, savedPaypal], catalog);
      expect(PaymentService.defaultMethod(usable)?.id, 'm2');
      expect(PaymentService.defaultMethod(const []), isNull);
    });

    test('TC_UP_022 the add list offers cards first, then the admin order', () {
      final offered = PaymentService.offeredOptions([apple, paypal, card]);
      expect(offered.map((o) => o.name), ['Card', 'Apple Pay', 'PayPal']);
    });

    test('TC_UP_023 the option id is stored with a saved wallet', () {
      expect(savedPaypal.toMap()['optionId'], 'opt-paypal');
      expect(SavedPaymentMethod.fromMap('m3', savedPaypal.toMap()).optionId, 'opt-paypal');
      expect(visa.toMap().containsKey('optionId'), isFalse);
    });
  });

  group('US20 — a pick made before the option was switched off', () {
    const a = SavedPaymentMethod(id: 'a', type: PaymentMethodType.applePay);
    const b = SavedPaymentMethod(id: 'b', type: PaymentMethodType.stcPay);

    test('TC_UP_024 a pick still usable is kept', () {
      expect(resolvePaymentMethod(b, const [a, b], a)?.id, 'b');
    });

    test('TC_UP_025 a pick no longer usable falls back to the default', () {
      expect(resolvePaymentMethod(b, const [a], a)?.id, 'a');
      expect(resolvePaymentMethod(b, const [], null), isNull);
    });
  });
}
