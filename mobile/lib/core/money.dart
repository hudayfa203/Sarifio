/// Money helpers. All amounts are integer minor units (cents / santim) —
/// never doubles — so the phone shows exactly what the server charges.
/// Exchange rates travel as integer micro-units: 1 USD = 125.50 ETB → 125500000.
class FeeEngine {
  FeeEngine._();

  /// SARIFIO default service fee: 1% = 100 basis points.
  static const int defaultFeeBps = 100;

  /// fee = round_half_up(amount × bps / 10 000), in the SENDING currency.
  static int feeMinor(int amountMinor, int feeBps) {
    if (amountMinor <= 0 || feeBps <= 0) return 0;
    return (amountMinor * feeBps + 5000) ~/ 10000;
  }

  /// Kept for USD-only call sites.
  static int feeCents(int amountCents, int feeBps) => feeMinor(amountCents, feeBps);

  /// Converts minor units with a micro-unit rate, rounding half up.
  static int convert(int minor, int rateMicro) {
    if (minor <= 0) return 0;
    return (minor * rateMicro + 500000) ~/ 1000000;
  }

  /// Full quote arithmetic, identical to the backend FeeEngine:
  ///   net         = amount − 1% fee − provider fee            (sending currency)
  ///   at mid rate = convert(net, midRate)                     (receiving currency)
  ///   receive     = convert(net, appliedRate)                 (receiving currency)
  ///   rate diff   = at mid rate − receive                     (shown separately)
  static QuoteMath quote({
    required int amountMinor,
    required int feeBps,
    int providerFeeMinor = 0,
    int midRateMicro = 1000000,
    int spreadBps = 0,
  }) {
    final fee = feeMinor(amountMinor, feeBps);
    var net = amountMinor - fee - providerFeeMinor;
    if (net < 0) net = 0;
    final applied = appliedRate(midRateMicro, spreadBps);
    final atMid = convert(net, midRateMicro);
    final receive = convert(net, applied);
    return QuoteMath(
      feeMinor: fee,
      providerFeeMinor: providerFeeMinor,
      netMinor: net,
      appliedRateMicro: applied,
      receiveMinor: receive,
      rateDifferenceMinor: atMid - receive,
    );
  }

  /// Applied rate = mid × (1 − spread). Spread is configured per route by admins.
  static int appliedRate(int midRateMicro, int spreadBps) =>
      (midRateMicro * (10000 - spreadBps) + 5000) ~/ 10000;

  static String percentLabel(int feeBps) {
    final whole = feeBps ~/ 100;
    final frac = feeBps % 100;
    if (frac == 0) return '$whole%';
    return '$whole.${frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}%';
  }
}

class QuoteMath {
  const QuoteMath({
    required this.feeMinor,
    required this.providerFeeMinor,
    required this.netMinor,
    required this.appliedRateMicro,
    required this.receiveMinor,
    required this.rateDifferenceMinor,
  });
  final int feeMinor;
  final int providerFeeMinor;
  final int netMinor;
  final int appliedRateMicro;
  final int receiveMinor;
  final int rateDifferenceMinor;
}

const _symbols = {'USD': '\$', 'ETB': 'Br ', 'KES': 'KSh '};

String currencySymbol(String currency) => _symbols[currency] ?? '$currency ';

String _group(int minor) {
  final abs = minor.abs();
  final whole = (abs ~/ 100).toString();
  final rem = (abs % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final fromEnd = whole.length - i;
    buf.write(whole[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  return '$buf.$rem';
}

/// "$1,234.50", "Br 12,550.00", "KSh 1,290.00"
String formatMoney(int minor, String currency) =>
    '${minor < 0 ? '−' : ''}${currencySymbol(currency)}${_group(minor)}';

/// USD shorthand.
String formatUsd(int cents, {bool withSymbol = true}) =>
    withSymbol ? formatMoney(cents, 'USD') : '${cents < 0 ? '−' : ''}${_group(cents)}';

/// "125.50" from 125500000 micro-units (2–4 decimals as needed).
String formatRate(int rateMicro) {
  final whole = rateMicro ~/ 1000000;
  var frac = (rateMicro % 1000000).toString().padLeft(6, '0').replaceAll(RegExp(r'0+$'), '');
  if (frac.length < 2) frac = frac.padRight(2, '0');
  final maxDp = whole == 0 ? 6 : 4;
  if (frac.length > maxDp) frac = frac.substring(0, maxDp);
  return '$whole.$frac';
}

/// Parses "100", "100.5", "1,250.00" into minor units. Returns null when invalid.
int? parseToMinor(String input) {
  final cleaned = input.replaceAll(',', '').replaceAll('\$', '').trim();
  if (cleaned.isEmpty) return null;
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{0,2}))?$').firstMatch(cleaned);
  if (m == null) return null;
  final whole = int.parse(m.group(1)!);
  final fracStr = (m.group(2) ?? '').padRight(2, '0');
  return whole * 100 + int.parse(fracStr.isEmpty ? '0' : fracStr);
}

int? parseUsdToCents(String input) => parseToMinor(input);
