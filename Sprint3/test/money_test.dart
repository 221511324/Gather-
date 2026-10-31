import 'package:flutter_test/flutter_test.dart';
import 'package:gather/core/utils/money.dart';

void main() {
  group('Money.splitEvenly', () {
    test('divides a clean amount evenly', () {
      expect(Money.splitEvenly(100, 4), [25.0, 25.0, 25.0, 25.0]);
    });

    test('never loses or invents cents on an awkward split', () {
      final shares = Money.splitEvenly(100, 3);
      expect(shares, [33.34, 33.33, 33.33]);
      expect(shares.fold<double>(0, (a, b) => a + b).toStringAsFixed(2), '100.00');
    });

    test('puts the remainder on the earliest shares', () {
      final shares = Money.splitEvenly(10.01, 2);
      expect(shares, [5.01, 5.00]);
    });

    test('handles a single member', () {
      expect(Money.splitEvenly(42.55, 1), [42.55]);
    });

    test('returns nothing for a non-positive group', () {
      expect(Money.splitEvenly(50, 0), isEmpty);
    });

    test('keeps the total exact across many awkward amounts', () {
      for (final total in [0.01, 7.77, 19.99, 123.45, 1000.03]) {
        for (final count in [2, 3, 5, 7, 11]) {
          final shares = Money.splitEvenly(total, count);
          expect(shares.length, count);
          expect(
            (shares.fold<double>(0, (a, b) => a + b) * 100).round(),
            (total * 100).round(),
            reason: 'splitting $total across $count drifted',
          );
        }
      }
    });
  });

  group('Money.round', () {
    test('rounds to two decimals', () {
      expect(Money.round(2.344), 2.34);
      expect(Money.round(2.346), 2.35);
      expect(Money.round(19.999), 20.00);
      expect(Money.round(0.004), 0.00);
    });

    test('rounding is idempotent', () {
      for (final value in [1.005, 2.675, 19.999, 123.456]) {
        final once = Money.round(value);
        expect(Money.round(once), once);
      }
    });
  });

  group('Money.format', () {
    test('includes the currency and two decimals', () {
      expect(Money.format(42.5), 'SAR 42.50');
      expect(Money.format(1234.5), 'SAR 1,234.50');
    });
  });
}
