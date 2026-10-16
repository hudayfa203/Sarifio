import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import 'api.dart';
import 'models.dart';

/// On-device TEST MODE engine.
///
/// Mirrors the staging API closely enough to exercise every screen without a
/// server: OTP with a fresh random code per request (shown on screen, never a
/// shared code), quotes that expire, the full transaction state machine,
/// simulated failures and refunds. Nothing here can move real money.
class SandboxApi implements SarifioApi {
  SandboxApi(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'sarifio_sandbox_v1';
  final Random _rng = Random.secure();

  final Map<String, _OtpState> _otps = {};
  final Map<String, Quote> _quotes = {};

  @override
  bool get isOnDevice => true;

  @override
  String get environmentLabel => 'TEST MODE · on-device sandbox';

  // ---------- persistence ----------

  Map<String, dynamic> _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      return {
        'users': <String, dynamic>{},
        'session': null,
        'tx': <String, dynamic>{},
        'tickets': <String, dynamic>{},
        'outcome': 'success',
        'idem': <String, dynamic>{},
        'seq': 10020,
      };
    }
    return (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  Future<void> _save(Map<String, dynamic> db) => _prefs.setString(_key, jsonEncode(db));

  String _id(String prefix) {
    const chars = 'ABCDEFGHJKMNPQRSTVWXYZ0123456789';
    return prefix + List.generate(10, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Future<T> _latency<T>(T Function() f) async {
    await Future<void>.delayed(Duration(milliseconds: 350 + _rng.nextInt(400)));
    return f();
  }

  String? _sessionPhone(Map<String, dynamic> db) => db['session'] as String?;

  AppUser _requireUser(Map<String, dynamic> db) {
    final phone = _sessionPhone(db);
    final u = phone == null ? null : (db['users'] as Map)[phone];
    if (u == null) {
      throw ApiException('unauthenticated', 'Please sign in again.', status: 401);
    }
    return AppUser.fromJson((u as Map).cast<String, dynamic>());
  }

  // ---------- config ----------

  static AppConfigData buildConfig() {
    PaymentProvider p(String code, String name, String? group, String status,
            {bool collect = true, bool payout = true, String country = 'SO', String currency = 'USD'}) =>
        PaymentProvider(
            code: code,
            name: name,
            group: group,
            status: status,
            canCollect: collect,
            canPayout: payout,
            country: country,
            currency: currency);
    // Somali USD wallets exchange with each other; eBirr (ETB) and M-Pesa (KES)
    // exchange with every Somali wallet and with each other.
    const somali = ['sahal', 'evc_plus', 'edahab', 'premier_wallet'];
    final pairs = <List<String>>[
      ['sahal', 'edahab'],
      ['sahal', 'premier_wallet'],
      ['edahab', 'sahal'],
      ['premier_wallet', 'sahal'],
      ['evc_plus', 'edahab'],
      ['evc_plus', 'premier_wallet'],
      ['edahab', 'evc_plus'],
      ['premier_wallet', 'evc_plus'],
      ['edahab', 'premier_wallet'],
      ['premier_wallet', 'edahab'],
      for (final w in somali) ...[
        [w, 'ebirr'],
        ['ebirr', w],
        [w, 'mpesa'],
        ['mpesa', w],
      ],
      ['ebirr', 'mpesa'],
      ['mpesa', 'ebirr'],
    ];
    // SANDBOX TEST RATES — illustrative only, not market rates. Real rates
    // are set by administrators in the Exchange Management dashboard.
    FxRate r(String a, String b, String rate, {int spread = 50}) {
      final parts = rate.split('.');
      final micro = int.parse(parts[0]) * 1000000 + int.parse(parts[1].padRight(6, '0').substring(0, 6));
      return FxRate(a, b, micro, spread);
    }

    return AppConfigData(
      environment: 'sandbox',
      testMode: true,
      company: CompanyInfo.defaults,
      feeBps: FeeEngine.defaultFeeBps,
      providers: [
        p('sahal', 'Sahal', 'WaafiPay', 'sandbox'),
        p('evc_plus', 'EVC Plus', 'WaafiPay', 'sandbox'),
        p('edahab', 'eDahab', null, 'sandbox'),
        p('premier_wallet', 'Premier Wallet', null, 'sandbox'),
        p('ebirr', 'eBirr', null, 'sandbox', country: 'ET', currency: 'ETB'),
        p('mpesa', 'M-Pesa', null, 'sandbox', country: 'KE', currency: 'KES'),
        p('binance', 'Binance', null, 'not_configured', collect: false, payout: false, country: 'XX'),
        p('visa', 'Visa', 'Card processor', 'not_configured', payout: false, country: 'XX'),
      ],
      routes: pairs
          .map((e) => ExchangeRoute(e[0], e[1], true, providerFeeBps: e[1] == 'mpesa' ? 50 : 0))
          .toList(),
      rates: [
        r('USD', 'ETB', '125.000000'),
        r('ETB', 'USD', '0.008000'),
        r('USD', 'KES', '129.000000'),
        r('KES', 'USD', '0.007750'),
        r('ETB', 'KES', '1.032000'),
        r('KES', 'ETB', '0.969000'),
      ],
      announcements: [
        Announcement('welcome', {
          'en': 'You are in Test Mode',
          'so': 'Waxaad ku jirtaa Habka Tijaabada',
        }, {
          'en': 'Exchanges, exchange rates and provider charges here are simulated. No real money moves.',
          'so': 'Sarrifyada, sicirrada iyo khidmadaha bixiyeyaasha halkan waa tijaabo. Lacag dhab ah ma dhaqaaqdo.',
        }),
      ],
      otpChannels: const ['sms', 'whatsapp'],
    );
  }

  @override
  Future<AppConfigData> getConfig() => _latency(buildConfig);

  // ---------- auth ----------

  @override
  Future<OtpTicket> requestOtp({
    required String phone,
    String? name,
    required String purpose,
    String channel = 'sms',
  }) async {
    final db = _load();
    final users = (db['users'] as Map).cast<String, dynamic>();
    if (purpose == 'login' && !users.containsKey(phone)) {
      throw ApiException('not_found', 'No SARIFIO account uses this number yet. Create one instead.',
          status: 404);
    }
    if (purpose == 'register' && (name == null || name.trim().length < 2)) {
      throw ApiException('validation_failed', 'Please enter your full name.', status: 422);
    }
    final now = DateTime.now();
    for (final o in _otps.values) {
      if (o.phone == phone && now.difference(o.createdAt).inSeconds < 60) {
        throw ApiException('otp_resend_too_soon',
            'Please wait ${60 - now.difference(o.createdAt).inSeconds}s before requesting a new code.',
            status: 429);
      }
    }
    final code = (_rng.nextInt(900000) + 100000).toString();
    final id = _id('otp_');
    _otps.removeWhere((_, o) => o.phone == phone);
    _otps[id] = _OtpState(phone: phone, name: name?.trim(), purpose: purpose, code: code, createdAt: now);
    return _latency(() => OtpTicket(
        requestId: id, channel: channel, expiresIn: 300, resendIn: 60, testCode: code));
  }

  @override
  Future<AppUser> verifyOtp({
    required String requestId,
    required String code,
    required String deviceName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final o = _otps[requestId];
    if (o == null) {
      throw ApiException('otp_expired', 'This code has expired. Request a new one.', status: 410);
    }
    if (DateTime.now().difference(o.createdAt).inMinutes >= 5) {
      _otps.remove(requestId);
      throw ApiException('otp_expired', 'This code has expired. Request a new one.', status: 410);
    }
    if (o.code != code.trim()) {
      o.attempts++;
      if (o.attempts >= 5) {
        _otps.remove(requestId);
        throw ApiException('otp_attempts_exceeded', 'Too many wrong attempts. Request a new code.',
            status: 429);
      }
      throw ApiException('otp_invalid', 'That code is not correct. ${5 - o.attempts} attempts left.',
          status: 422);
    }
    _otps.remove(requestId);
    final db = _load();
    final users = (db['users'] as Map).cast<String, dynamic>();
    AppUser user;
    if (users.containsKey(o.phone)) {
      user = AppUser.fromJson((users[o.phone] as Map).cast<String, dynamic>());
    } else {
      user = AppUser(
        id: _id('usr_'),
        name: o.name ?? 'SARIFIO customer',
        phone: o.phone,
        createdAt: DateTime.now(),
      );
      users[o.phone] = user.toJson();
      db['users'] = users;
      db['session'] = o.phone;
      _seedDemoInto(db, user);
    }
    db['users'] = users;
    db['session'] = o.phone;
    await _save(db);
    return user;
  }

  @override
  Future<AppUser?> restoreSession() async {
    final db = _load();
    try {
      return _requireUser(db);
    } on ApiException {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final db = _load();
    db['session'] = null;
    await _save(db);
  }

  @override
  Future<AppUser> getMe() async => _requireUser(_load());

  @override
  Future<AppUser> updateMe({String? name, String? email, String? language}) async {
    final db = _load();
    final u = _requireUser(db);
    if (name != null && name.trim().length < 2) {
      throw ApiException('validation_failed', 'Please enter your full name.', status: 422);
    }
    if (email != null && email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ApiException('validation_failed', 'Please enter a valid email address.', status: 422);
    }
    final updated = u.copyWith(name: name?.trim(), email: email, language: language);
    (db['users'] as Map)[u.phone] = updated.toJson();
    await _save(db);
    return _latency(() => updated);
  }

  // ---------- quotes & exchanges ----------

  @override
  Future<Quote> createQuote({required String from, required String to, required int amountCents}) async {
    final db = _load();
    final user = _requireUser(db);
    final cfg = buildConfig();
    if (!cfg.routeAvailable(from, to)) {
      throw ApiException('route_disabled', 'This exchange route is not available yet.', status: 403);
    }
    final sendCur = cfg.provider(from)!.currency;
    final toUsd = cfg.rate(sendCur, 'USD');
    final usdEquivalent = toUsd == null ? amountCents : FeeEngine.convert(amountCents, toUsd.midRateMicro);
    if (usdEquivalent < 100) {
      throw ApiException('amount_out_of_range', 'The minimum exchange is the equivalent of \$1.00.', status: 422);
    }
    if (usdEquivalent > user.perTxLimitCents) {
      throw ApiException('limit_exceeded',
          'Test accounts can exchange up to ${formatUsd(user.perTxLimitCents)} at a time.',
          status: 403);
    }
    final fromP = cfg.provider(from)!;
    final toP = cfg.provider(to)!;
    final fx = cfg.rate(fromP.currency, toP.currency)!;
    final route = cfg.route(from, to)!;
    final providerFee = FeeEngine.feeMinor(amountCents, route.providerFeeBps);
    final m = FeeEngine.quote(
      amountMinor: amountCents,
      feeBps: cfg.feeBps,
      providerFeeMinor: providerFee,
      midRateMicro: fx.midRateMicro,
      spreadBps: fx.spreadBps,
    );
    final q = Quote(
      id: _id('qt_'),
      from: from,
      to: to,
      currency: fromP.currency,
      receiveCurrency: toP.currency,
      amountCents: amountCents,
      feeBps: cfg.feeBps,
      feeCents: m.feeMinor,
      providerFeeCents: m.providerFeeMinor,
      midRateMicro: fx.midRateMicro,
      rateMicro: m.appliedRateMicro,
      rateDifferenceMinor: m.rateDifferenceMinor,
      receiveCents: m.receiveMinor,
      expiresAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    _quotes[q.id] = q;
    return _latency(() => q);
  }

  @override
  Future<Transaction> createExchange({
    required Quote quote,
    required String recipientAccount,
    String? recipientName,
    required String idempotencyKey,
  }) async {
    final db = _load();
    final user = _requireUser(db);
    final idem = (db['idem'] as Map).cast<String, dynamic>();
    if (idem.containsKey(idempotencyKey)) {
      final existing = (db['tx'] as Map)[idem[idempotencyKey]];
      if (existing != null) {
        return _advance(Transaction.fromJson((existing as Map).cast<String, dynamic>()), db);
      }
    }
    final q = _quotes[quote.id];
    if (q == null) {
      throw ApiException('quote_already_used', 'This quote was already used. Please get a new quote.',
          status: 409);
    }
    if (q.expired) {
      throw ApiException('quote_expired', 'This quote has expired. Please refresh it.', status: 410);
    }
    final digits = recipientAccount.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      throw ApiException('validation_failed', 'Please enter the receiving account number.', status: 422);
    }
    _quotes.remove(q.id);
    final cfg = buildConfig();
    final fromP = cfg.provider(q.from)!;
    final toP = cfg.provider(q.to)!;
    final now = DateTime.now();
    final seq = (db['seq'] as num).toInt() + 1;
    db['seq'] = seq;
    final ref = 'SRF-T${seq.toString().padLeft(5, '0')}-${_id('').substring(0, 4)}';
    final masked = '•••• ${digits.substring(digits.length - 4)}';
    final tx = Transaction(
      id: _id('tx_'),
      reference: ref,
      status: TxStatus.awaitingPayment,
      test: true,
      from: ProviderRef(fromP.code, fromP.name, fromP.group),
      to: ProviderRef(toP.code, toP.name, toP.group),
      currency: q.currency,
      receiveCurrency: q.receiveCurrency,
      amountCents: q.amountCents,
      feeBps: q.feeBps,
      feeCents: q.feeCents,
      providerFeeCents: q.providerFeeCents,
      rateMicro: q.rateMicro,
      rateDifferenceMinor: q.rateDifferenceMinor,
      receiveCents: q.receiveCents,
      recipientAccount: masked,
      recipientName: (recipientName == null || recipientName.trim().isEmpty) ? null : recipientName.trim(),
      events: [
        TxEvent(TxStatus.created, now),
        TxEvent(TxStatus.quoted, now),
        TxEvent(TxStatus.awaitingPayment, now),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final txMap = (db['tx'] as Map).cast<String, dynamic>();
    final stored = tx.toJson()
      ..['owner'] = user.phone
      ..['outcome'] = db['outcome'] ?? 'success';
    txMap[tx.id] = stored;
    idem[idempotencyKey] = tx.id;
    db['tx'] = txMap;
    db['idem'] = idem;
    db['outcome'] = 'success'; // outcome applies to the next exchange only
    await _save(db);
    return _latency(() => tx);
  }

  /// Advances a sandbox transaction along the state machine based on elapsed
  /// time, so progress survives app restarts without background timers.
  Transaction _advance(Transaction tx, Map<String, dynamic> db) {
    final raw = ((db['tx'] as Map)[tx.id] as Map).cast<String, dynamic>();
    final outcome = raw['outcome'] as String? ?? 'success';
    final t0 = tx.createdAt;
    final elapsed = DateTime.now().difference(t0).inMilliseconds;
    final plan = <(int, TxStatus)>[];
    String? reason;
    switch (outcome) {
      case 'fail_payment':
        plan.add((4000, TxStatus.failed));
        reason = 'The sending provider declined the payment (simulated).';
        break;
      case 'fail_payout':
        plan
          ..add((3000, TxStatus.paymentVerified))
          ..add((5500, TxStatus.payoutProcessing))
          ..add((8500, TxStatus.failed))
          ..add((12000, TxStatus.refunded));
        reason = 'The receiving provider rejected the payout. Your money was returned (simulated).';
        break;
      case 'manual_review':
        plan
          ..add((3000, TxStatus.paymentVerified))
          ..add((5500, TxStatus.manualReview));
        reason = 'This exchange is being reviewed by our team (simulated).';
        break;
      default:
        plan
          ..add((3000, TxStatus.paymentVerified))
          ..add((5500, TxStatus.payoutProcessing))
          ..add((8500, TxStatus.settled));
    }
    final events = List<TxEvent>.from(tx.events);
    var status = tx.status;
    for (final step in plan) {
      if (elapsed >= step.$1 && !events.any((e) => e.status == step.$2)) {
        events.add(TxEvent(step.$2, t0.add(Duration(milliseconds: step.$1))));
        status = step.$2;
      }
    }
    if (status == tx.status) return tx;
    final updated = tx.copyWith(
      status: status,
      events: events,
      failureReason: status.isProblem ? reason : null,
      updatedAt: events.last.at,
    );
    (db['tx'] as Map)[tx.id] = updated.toJson()
      ..['owner'] = raw['owner']
      ..['outcome'] = outcome;
    return updated;
  }

  @override
  Future<List<Transaction>> listExchanges() async {
    final db = _load();
    final user = _requireUser(db);
    final all = (db['tx'] as Map).values
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((e) => e['owner'] == user.phone)
        .map((e) => _advance(Transaction.fromJson(e), db))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _save(db);
    return _latency(() => all);
  }

  @override
  Future<Transaction> getExchange(String id) async {
    final db = _load();
    final user = _requireUser(db);
    final raw = (db['tx'] as Map)[id];
    if (raw == null || (raw as Map)['owner'] != user.phone) {
      throw ApiException('not_found', 'Transaction not found.', status: 404);
    }
    final tx = _advance(Transaction.fromJson(raw.cast<String, dynamic>()), db);
    await _save(db);
    return tx;
  }

  // ---------- support ----------

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    String? transactionId,
  }) async {
    final db = _load();
    final user = _requireUser(db);
    if (subject.trim().length < 3 || message.trim().length < 5) {
      throw ApiException('validation_failed', 'Please add a subject and describe the issue.', status: 422);
    }
    final seq = (db['seq'] as num).toInt() + 1;
    db['seq'] = seq;
    final t = SupportTicket(
      id: _id('tkt_'),
      number: 'T-$seq',
      subject: subject.trim(),
      status: 'open',
      createdAt: DateTime.now(),
    );
    final tickets = (db['tickets'] as Map).cast<String, dynamic>();
    tickets[t.id] = t.toJson()
      ..['owner'] = user.phone
      ..['message'] = message.trim()
      ..['transaction_id'] = transactionId;
    db['tickets'] = tickets;
    await _save(db);
    return _latency(() => t);
  }

  @override
  Future<List<SupportTicket>> listTickets() async {
    final db = _load();
    final user = _requireUser(db);
    final list = (db['tickets'] as Map).values
        .map((e) => (e as Map).cast<String, dynamic>())
        .where((e) => e['owner'] == user.phone)
        .map(SupportTicket.fromJson)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _latency(() => list);
  }

  // ---------- test controls ----------

  @override
  Future<void> setNextOutcome(String outcome) async {
    final db = _load();
    db['outcome'] = outcome;
    await _save(db);
  }

  String get nextOutcome => (_load()['outcome'] as String?) ?? 'success';


  // ---------- demo data ----------

  /// Adds realistic, clearly-test exchanges to the signed-in account so every
  /// screen can be seen "in use". Returns how many were added.
  Future<int> seedDemo() async {
    final db = _load();
    final user = _requireUser(db);
    final n = _seedDemoInto(db, user);
    await _save(db);
    return n;
  }

  int _seedDemoInto(Map<String, dynamic> db, AppUser user) {
    final cfg = buildConfig();
    final now = DateTime.now();
    // from, to, amount (minor units of the sending wallet), age, outcome, receiver
    final specs = <(String, String, int, Duration, String, String?)>[
      ('sahal', 'edahab', 10000, const Duration(hours: 2), 'success', 'Amina Yusuf'),
      ('evc_plus', 'mpesa', 25000, const Duration(hours: 20), 'success', 'John Kamau'),
      ('sahal', 'premier_wallet', 50000, const Duration(hours: 26), 'manual_review', null),
      ('sahal', 'ebirr', 8000, const Duration(days: 2, hours: 3), 'success', 'Abebe Tesfaye'),
      ('premier_wallet', 'sahal', 4550, const Duration(days: 3, hours: 5), 'success', 'Hodan Ali'),
      ('edahab', 'premier_wallet', 30000, const Duration(days: 4, hours: 1), 'fail_payout', 'Farah Warsame'),
      ('mpesa', 'sahal', 500000, const Duration(days: 5, hours: 7), 'success', null),
      ('ebirr', 'evc_plus', 600000, const Duration(days: 6, hours: 2), 'success', 'Ayaan Mohamed'),
      ('evc_plus', 'edahab', 2000, const Duration(days: 7, hours: 4), 'fail_payment', null),
      ('edahab', 'sahal', 15000, const Duration(days: 9), 'success', 'Ismail Nur'),
    ];
    final txMap = (db['tx'] as Map).cast<String, dynamic>();
    var seq = (db['seq'] as num).toInt();
    var added = 0;
    for (final sp in specs) {
      final fromP = cfg.provider(sp.$1)!;
      final toP = cfg.provider(sp.$2)!;
      final fx = cfg.rate(fromP.currency, toP.currency)!;
      final route = cfg.route(sp.$1, sp.$2)!;
      final m = FeeEngine.quote(
        amountMinor: sp.$3,
        feeBps: cfg.feeBps,
        providerFeeMinor: FeeEngine.feeMinor(sp.$3, route.providerFeeBps),
        midRateMicro: fx.midRateMicro,
        spreadBps: fx.spreadBps,
      );
      final t0 = now.subtract(sp.$4);
      DateTime at(int s) => t0.add(Duration(seconds: s));
      final events = [TxEvent(TxStatus.created, t0), TxEvent(TxStatus.quoted, t0), TxEvent(TxStatus.awaitingPayment, t0)];
      TxStatus status;
      String? reason;
      switch (sp.$5) {
        case 'fail_payment':
          events.add(TxEvent(TxStatus.failed, at(120)));
          status = TxStatus.failed;
          reason = 'The sending provider declined the payment (simulated).';
          break;
        case 'fail_payout':
          events
            ..add(TxEvent(TxStatus.paymentVerified, at(40)))
            ..add(TxEvent(TxStatus.payoutProcessing, at(55)))
            ..add(TxEvent(TxStatus.failed, at(90)))
            ..add(TxEvent(TxStatus.refunded, at(150)));
          status = TxStatus.refunded;
          reason = 'The receiving provider rejected the payout. Your money was returned (simulated).';
          break;
        case 'manual_review':
          events
            ..add(TxEvent(TxStatus.paymentVerified, at(40)))
            ..add(TxEvent(TxStatus.manualReview, at(60)));
          status = TxStatus.manualReview;
          reason = 'This exchange is being reviewed by our team (simulated).';
          break;
        default:
          events
            ..add(TxEvent(TxStatus.paymentVerified, at(40)))
            ..add(TxEvent(TxStatus.payoutProcessing, at(55)))
            ..add(TxEvent(TxStatus.settled, at(80)));
          status = TxStatus.settled;
      }
      seq++;
      final digits = '${2520000000 + _rng.nextInt(99999999)}';
      final tx = Transaction(
        id: _id('tx_'),
        reference: 'SRF-T${seq.toString().padLeft(5, '0')}-${_id('').substring(0, 4)}',
        status: status,
        test: true,
        from: ProviderRef(fromP.code, fromP.name, fromP.group),
        to: ProviderRef(toP.code, toP.name, toP.group),
        currency: fromP.currency,
        receiveCurrency: toP.currency,
        amountCents: sp.$3,
        feeBps: cfg.feeBps,
        feeCents: m.feeMinor,
        providerFeeCents: m.providerFeeMinor,
        rateMicro: m.appliedRateMicro,
        rateDifferenceMinor: m.rateDifferenceMinor,
        receiveCents: m.receiveMinor,
        recipientAccount: '•••• ${digits.substring(digits.length - 4)}',
        recipientName: sp.$6,
        events: events,
        failureReason: reason,
        createdAt: t0,
        updatedAt: events.last.at,
      );
      txMap[tx.id] = tx.toJson()
        ..['owner'] = user.phone
        ..['outcome'] = sp.$5
        ..['demo'] = true;
      added++;
    }
    db['tx'] = txMap;
    db['seq'] = seq;
    return added;
  }

  @override
  Future<void> resetTestData() async {
    final db = _load();
    final session = db['session'];
    final users = db['users'];
    await _prefs.remove(_key);
    final fresh = _load();
    fresh['session'] = session;
    fresh['users'] = users;
    await _save(fresh);
  }
}

class _OtpState {
  _OtpState({
    required this.phone,
    required this.name,
    required this.purpose,
    required this.code,
    required this.createdAt,
  });
  final String phone;
  final String? name;
  final String purpose;
  final String code;
  final DateTime createdAt;
  int attempts = 0;
}
