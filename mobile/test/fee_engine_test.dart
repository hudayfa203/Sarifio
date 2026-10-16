import 'package:flutter_test/flutter_test.dart';
import 'package:sarifio_app/core/money.dart';
import 'package:sarifio_app/data/sandbox_api.dart';

void main() {
  group('1% service fee (brief table)', () {
    const cases = {
      1000: [10, 990], // $10   → $0.10 fee, $9.90 net
      5000: [50, 4950], // $50   → $0.50, $49.50
      10000: [100, 9900], // $100  → $1.00, $99.00
      50000: [500, 49500], // $500  → $5.00, $495.00
      100000: [1000, 99000], // $1000 → $10.00, $990.00
      500000: [5000, 495000], // $5000 → $50.00, $4950.00
    };
    cases.forEach((amount, expected) {
      test('${formatUsd(amount)}', () {
        final q = FeeEngine.quote(amountMinor: amount, feeBps: 100);
        expect(q.feeMinor, expected[0]);
        expect(q.receiveMinor, expected[1]);
        expect(q.rateDifferenceMinor, 0);
      });
    });

    test('rounds half up to the cent', () {
      expect(FeeEngine.feeMinor(150, 100), 2); // $1.50 → 1.5¢ → 2¢
      expect(FeeEngine.feeMinor(149, 100), 1);
      expect(FeeEngine.feeMinor(0, 100), 0);
    });
  });

  group('cross-currency quotes', () {
    test('USD → ETB shows fee, provider charge and rate difference separately', () {
      final q = FeeEngine.quote(
        amountMinor: 10000, // $100.00
        feeBps: 100,
        providerFeeMinor: 0,
        midRateMicro: 125000000, // 1 USD = 125 ETB (test rate)
        spreadBps: 50,
      );
      expect(q.feeMinor, 100); // $1.00
      expect(q.netMinor, 9900); // $99.00
      expect(q.appliedRateMicro, 124375000); // 125 × (1 − 0.5%)
      expect(q.receiveMinor, 1231313); // Br 12,313.13 (12,313.125 rounds half up)
      expect(q.rateDifferenceMinor, 1237500 - 1231313); // Br 61.87
    });

    test('same currency has no conversion', () {
      final q = FeeEngine.quote(amountMinor: 10000, feeBps: 100);
      expect(q.appliedRateMicro, 1000000);
      expect(q.receiveMinor, 9900);
    });
  });

  group('formatting', () {
    test('money and rates', () {
      expect(formatMoney(123450, 'USD'), '\$1,234.50');
      expect(formatMoney(1231313, 'ETB'), 'Br 12,313.13');
      expect(formatMoney(129000, 'KES'), 'KSh 1,290.00');
      expect(formatRate(125000000), '125.00');
      expect(formatRate(7750), '0.00775');
      expect(parseToMinor('1,250.5'), 125050);
      expect(parseToMinor('abc'), isNull);
    });
  });

  group('sandbox configuration', () {
    final cfg = SandboxApi.buildConfig();
    test('includes eBirr and M-Pesa in their own currencies', () {
      expect(cfg.provider('ebirr')!.currency, 'ETB');
      expect(cfg.provider('mpesa')!.currency, 'KES');
    });
    test('routes need a configured rate', () {
      expect(cfg.routeAvailable('sahal', 'ebirr'), isTrue);
      expect(cfg.routeAvailable('mpesa', 'ebirr'), isTrue);
      expect(cfg.routeAvailable('sahal', 'binance'), isFalse);
      expect(cfg.routeAvailable('sahal', 'sahal'), isFalse);
    });
    test('nothing is marked live', () {
      expect(cfg.providers.where((p) => p.status == 'live'), isEmpty);
    });
  });
}
