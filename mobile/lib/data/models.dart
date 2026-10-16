// Data models mirroring docs/API.md. Every model round-trips through JSON so
// the on-device sandbox can persist the same shapes the server returns.

class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status = 0});
  final String code;
  final String message;
  final int status;

  bool get isNetwork => code == 'network';

  @override
  String toString() => message;
}

enum TxStatus {
  created,
  quoted,
  awaitingPayment,
  paymentVerified,
  payoutProcessing,
  settled,
  failed,
  cancelled,
  manualReview,
  refunded;

  static TxStatus parse(String s) {
    switch (s) {
      case 'created':
        return TxStatus.created;
      case 'quoted':
        return TxStatus.quoted;
      case 'awaiting_payment':
        return TxStatus.awaitingPayment;
      case 'payment_verified':
        return TxStatus.paymentVerified;
      case 'payout_processing':
        return TxStatus.payoutProcessing;
      case 'settled':
        return TxStatus.settled;
      case 'failed':
        return TxStatus.failed;
      case 'cancelled':
        return TxStatus.cancelled;
      case 'manual_review':
        return TxStatus.manualReview;
      case 'refunded':
        return TxStatus.refunded;
    }
    return TxStatus.created;
  }

  String get wire {
    switch (this) {
      case TxStatus.created:
        return 'created';
      case TxStatus.quoted:
        return 'quoted';
      case TxStatus.awaitingPayment:
        return 'awaiting_payment';
      case TxStatus.paymentVerified:
        return 'payment_verified';
      case TxStatus.payoutProcessing:
        return 'payout_processing';
      case TxStatus.settled:
        return 'settled';
      case TxStatus.failed:
        return 'failed';
      case TxStatus.cancelled:
        return 'cancelled';
      case TxStatus.manualReview:
        return 'manual_review';
      case TxStatus.refunded:
        return 'refunded';
    }
  }

  bool get isFinal =>
      this == TxStatus.settled ||
      this == TxStatus.failed ||
      this == TxStatus.cancelled ||
      this == TxStatus.refunded;

  bool get isProblem =>
      this == TxStatus.failed ||
      this == TxStatus.cancelled ||
      this == TxStatus.refunded ||
      this == TxStatus.manualReview;
}

class PaymentProvider {
  PaymentProvider({
    required this.code,
    required this.name,
    this.group,
    required this.status,
    required this.canCollect,
    required this.canPayout,
    this.country = 'SO',
    this.currency = 'USD',
  });

  final String code;
  final String name;
  final String? group;
  final String country; // ISO 3166-1 alpha-2
  final String currency; // ISO 4217 settlement currency of this wallet
  final String status; // not_configured | sandbox | testing | awaiting_approval | live | disabled | error
  final bool canCollect;
  final bool canPayout;

  bool get usable =>
      status == 'sandbox' || status == 'testing' || status == 'live';

  String get initials {
    switch (code) {
      case 'sahal':
        return 'SH';
      case 'evc_plus':
        return 'EV';
      case 'edahab':
        return 'eD';
      case 'premier_wallet':
        return 'PW';
      case 'binance':
        return 'BN';
      case 'visa':
        return 'VI';
      case 'ebirr':
        return 'eB';
      case 'mpesa':
        return 'MP';
    }
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  factory PaymentProvider.fromJson(Map<String, dynamic> j) => PaymentProvider(
        code: j['code'] as String,
        name: j['name'] as String,
        group: j['group'] as String?,
        status: j['status'] as String? ?? 'not_configured',
        canCollect: j['can_collect'] as bool? ?? false,
        canPayout: j['can_payout'] as bool? ?? false,
        country: j['country'] as String? ?? 'SO',
        currency: j['currency'] as String? ?? 'USD',
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'group': group,
        'status': status,
        'can_collect': canCollect,
        'can_payout': canPayout,
        'country': country,
        'currency': currency,
      };
}

class ExchangeRoute {
  ExchangeRoute(this.from, this.to, this.enabled, {this.providerFeeBps = 0});
  final String from;
  final String to;
  final bool enabled;

  /// Provider charges passed through to the customer, shown separately.
  final int providerFeeBps;

  factory ExchangeRoute.fromJson(Map<String, dynamic> j) => ExchangeRoute(
      j['from'] as String, j['to'] as String, j['enabled'] as bool? ?? false,
      providerFeeBps: (j['provider_fee_bps'] as num?)?.toInt() ?? 0);
  Map<String, dynamic> toJson() =>
      {'from': from, 'to': to, 'enabled': enabled, 'provider_fee_bps': providerFeeBps};
}

/// Admin-configured exchange rate for a currency pair (micro-units).
class FxRate {
  FxRate(this.from, this.to, this.midRateMicro, this.spreadBps);
  final String from;
  final String to;
  final int midRateMicro;
  final int spreadBps;

  static FxRate identity(String c) => FxRate(c, c, 1000000, 0);

  factory FxRate.fromJson(Map<String, dynamic> j) => FxRate(
        j['from'] as String,
        j['to'] as String,
        (j['mid_rate_micro'] as num).toInt(),
        (j['spread_bps'] as num?)?.toInt() ?? 0,
      );
}

class CompanyInfo {
  CompanyInfo({
    required this.name,
    required this.tagline,
    required this.website,
    required this.email,
    required this.supportEmail,
    required this.phone,
    required this.whatsapp,
  });

  final String name;
  final String tagline;
  final String website;
  final String email;
  final String supportEmail;
  final String phone;
  final String whatsapp;

  static CompanyInfo get defaults => CompanyInfo(
        name: 'SARIFIO',
        tagline: 'One App. Every Exchange.',
        website: 'sarifio.com',
        email: 'info@sarifio.com',
        supportEmail: 'support@sarifio.com',
        phone: '+252906793240',
        whatsapp: '+252906793240',
      );

  factory CompanyInfo.fromJson(Map<String, dynamic> j) => CompanyInfo(
        name: j['name'] as String? ?? 'SARIFIO',
        tagline: j['tagline'] as String? ?? 'One App. Every Exchange.',
        website: j['website'] as String? ?? 'sarifio.com',
        email: j['email'] as String? ?? 'info@sarifio.com',
        supportEmail: j['support_email'] as String? ?? 'support@sarifio.com',
        phone: j['phone'] as String? ?? '+252906793240',
        whatsapp: j['whatsapp'] as String? ?? '+252906793240',
      );
}

class Announcement {
  Announcement(this.id, this.title, this.body);
  final String id;
  final Map<String, String> title;
  final Map<String, String> body;

  String titleFor(String lang) => title[lang] ?? title['en'] ?? '';
  String bodyFor(String lang) => body[lang] ?? body['en'] ?? '';

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        j['id'] as String,
        Map<String, String>.from(j['title'] as Map),
        Map<String, String>.from(j['body'] as Map),
      );
}

class AppConfigData {
  AppConfigData({
    required this.environment,
    required this.testMode,
    required this.company,
    required this.feeBps,
    required this.providers,
    required this.routes,
    required this.announcements,
    required this.otpChannels,
    this.rates = const [],
  });

  final String environment;
  final bool testMode;
  final CompanyInfo company;
  final int feeBps;
  final List<PaymentProvider> providers;
  final List<ExchangeRoute> routes;
  final List<Announcement> announcements;
  final List<String> otpChannels;
  final List<FxRate> rates;

  /// Rate for a currency pair; null when the pair has no configured rate.
  FxRate? rate(String from, String to) {
    if (from == to) return FxRate.identity(from);
    for (final r in rates) {
      if (r.from == from && r.to == to) return r;
    }
    return null;
  }

  ExchangeRoute? route(String from, String to) {
    for (final r in routes) {
      if (r.from == from && r.to == to) return r;
    }
    return null;
  }

  PaymentProvider? provider(String code) {
    for (final p in providers) {
      if (p.code == code) return p;
    }
    return null;
  }

  /// A route is offered only when enabled and both sides are usable.
  bool routeAvailable(String from, String to) {
    final a = provider(from);
    final b = provider(to);
    if (a == null || b == null || !a.usable || !b.usable) return false;
    if (!a.canCollect || !b.canPayout) return false;
    if (rate(a.currency, b.currency) == null) return false;
    return routes.any((r) => r.from == from && r.to == to && r.enabled);
  }

  List<PaymentProvider> get sendable =>
      providers.where((p) => p.usable && p.canCollect && routes.any((r) => r.from == p.code && r.enabled)).toList();

  List<PaymentProvider> receivableFrom(String from) =>
      providers.where((p) => routeAvailable(from, p.code)).toList();

  factory AppConfigData.fromJson(Map<String, dynamic> j) => AppConfigData(
        environment: j['environment'] as String? ?? 'staging',
        testMode: j['test_mode'] as bool? ?? true,
        company: CompanyInfo.fromJson(
            (j['company'] as Map?)?.cast<String, dynamic>() ?? const {}),
        feeBps: ((j['fee'] as Map?)?['bps'] as num?)?.toInt() ?? 100,
        providers: ((j['providers'] as List?) ?? const [])
            .map((e) => PaymentProvider.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        routes: ((j['routes'] as List?) ?? const [])
            .map((e) => ExchangeRoute.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        announcements: ((j['announcements'] as List?) ?? const [])
            .map((e) => Announcement.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        otpChannels: ((j['otp_channels'] as List?) ?? const ['sms'])
            .map((e) => e.toString())
            .toList(),
        rates: ((j['rates'] as List?) ?? const [])
            .map((e) => FxRate.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.emailVerified = false,
    this.language = 'en',
    this.kycStatus = 'not_started',
    this.perTxLimitCents = 50000,
    this.dailyLimitCents = 100000,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final bool emailVerified;
  final String language;
  final String kycStatus;
  final int perTxLimitCents;
  final int dailyLimitCents;
  final DateTime createdAt;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  AppUser copyWith({String? name, String? email, String? language}) => AppUser(
        id: id,
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        emailVerified: email != null && email != this.email ? false : emailVerified,
        language: language ?? this.language,
        kycStatus: kycStatus,
        perTxLimitCents: perTxLimitCents,
        dailyLimitCents: dailyLimitCents,
        createdAt: createdAt,
      );

  factory AppUser.fromJson(Map<String, dynamic> j) {
    final limits = (j['limits'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppUser(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      email: j['email'] as String?,
      emailVerified: j['email_verified'] as bool? ?? false,
      language: j['language'] as String? ?? 'en',
      kycStatus: j['kyc_status'] as String? ?? 'not_started',
      perTxLimitCents: (limits['per_tx_cents'] as num?)?.toInt() ?? 50000,
      dailyLimitCents: (limits['daily_cents'] as num?)?.toInt() ?? 100000,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'email_verified': emailVerified,
        'language': language,
        'kyc_status': kycStatus,
        'limits': {'per_tx_cents': perTxLimitCents, 'daily_cents': dailyLimitCents},
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class OtpTicket {
  OtpTicket({
    required this.requestId,
    required this.channel,
    required this.expiresIn,
    required this.resendIn,
    this.testCode,
  });
  final String requestId;
  final String channel;
  final int expiresIn;
  final int resendIn;
  final String? testCode;

  factory OtpTicket.fromJson(Map<String, dynamic> j) => OtpTicket(
        requestId: j['request_id'] as String,
        channel: j['channel'] as String? ?? 'sms',
        expiresIn: (j['expires_in'] as num?)?.toInt() ?? 300,
        resendIn: (j['resend_in'] as num?)?.toInt() ?? 60,
        testCode: j['test_code'] as String?,
      );
}

class Quote {
  Quote({
    required this.id,
    required this.from,
    required this.to,
    required this.currency,
    required this.receiveCurrency,
    required this.amountCents,
    required this.feeBps,
    required this.feeCents,
    required this.providerFeeCents,
    required this.midRateMicro,
    required this.rateMicro,
    required this.rateDifferenceMinor,
    required this.receiveCents,
    required this.expiresAt,
  });

  final String id;
  final String from;
  final String to;

  /// Sending currency; amount, SARIFIO fee and provider fee are in it.
  final String currency;

  /// Receiving currency; receive amount and rate difference are in it.
  final String receiveCurrency;
  final int amountCents;
  final int feeBps;
  final int feeCents;
  final int providerFeeCents;
  final int midRateMicro;
  final int rateMicro;
  final int rateDifferenceMinor;
  final int receiveCents;
  final DateTime expiresAt;

  bool get expired => DateTime.now().isAfter(expiresAt);
  bool get crossCurrency => currency != receiveCurrency;

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: j['id'] as String,
        from: j['from'] as String,
        to: j['to'] as String,
        currency: j['currency'] as String? ?? 'USD',
        receiveCurrency: j['receive_currency'] as String? ?? j['currency'] as String? ?? 'USD',
        amountCents: (j['amount_minor'] ?? j['amount_cents'] as num).toInt(),
        feeBps: (j['fee_bps'] as num).toInt(),
        feeCents: (j['fee_minor'] ?? j['fee_cents'] as num).toInt(),
        providerFeeCents: ((j['provider_fee_minor'] ?? j['provider_fee_cents'] ?? 0) as num).toInt(),
        midRateMicro: ((j['mid_rate_micro'] ?? 1000000) as num).toInt(),
        rateMicro: ((j['rate_micro'] ?? 1000000) as num).toInt(),
        rateDifferenceMinor: ((j['rate_difference_minor'] ?? 0) as num).toInt(),
        receiveCents: (j['receive_minor'] ?? j['receive_cents'] as num).toInt(),
        expiresAt: DateTime.parse(j['expires_at'] as String).toLocal(),
      );
}

class TxEvent {
  TxEvent(this.status, this.at);
  final TxStatus status;
  final DateTime at;

  factory TxEvent.fromJson(Map<String, dynamic> j) =>
      TxEvent(TxStatus.parse(j['status'] as String), DateTime.parse(j['at'] as String).toLocal());
  Map<String, dynamic> toJson() => {'status': status.wire, 'at': at.toUtc().toIso8601String()};
}

class ProviderRef {
  ProviderRef(this.code, this.name, this.group);
  final String code;
  final String name;
  final String? group;

  factory ProviderRef.fromJson(Map<String, dynamic> j) =>
      ProviderRef(j['code'] as String, j['name'] as String? ?? '', j['group'] as String?);
  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'group': group};
}

class Transaction {
  Transaction({
    required this.id,
    required this.reference,
    required this.status,
    required this.test,
    required this.from,
    required this.to,
    required this.currency,
    required this.receiveCurrency,
    required this.amountCents,
    required this.feeBps,
    required this.feeCents,
    required this.providerFeeCents,
    required this.rateMicro,
    required this.rateDifferenceMinor,
    required this.receiveCents,
    required this.recipientAccount,
    this.recipientName,
    required this.events,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reference;
  final TxStatus status;
  final bool test;
  final ProviderRef from;
  final ProviderRef to;
  final String currency;
  final String receiveCurrency;
  final int amountCents;
  final int feeBps;
  final int feeCents;
  final int providerFeeCents;
  final int rateMicro;
  final int rateDifferenceMinor;
  final int receiveCents;
  final String recipientAccount;
  final String? recipientName;
  final List<TxEvent> events;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get crossCurrency => currency != receiveCurrency;

  /// The fee is only charged when the exchange settles.
  int get feeChargedCents => status == TxStatus.settled ? feeCents : 0;

  Transaction copyWith({
    TxStatus? status,
    List<TxEvent>? events,
    String? failureReason,
    DateTime? updatedAt,
  }) =>
      Transaction(
        id: id,
        reference: reference,
        status: status ?? this.status,
        test: test,
        from: from,
        to: to,
        currency: currency,
        receiveCurrency: receiveCurrency,
        amountCents: amountCents,
        feeBps: feeBps,
        feeCents: feeCents,
        providerFeeCents: providerFeeCents,
        rateMicro: rateMicro,
        rateDifferenceMinor: rateDifferenceMinor,
        receiveCents: receiveCents,
        recipientAccount: recipientAccount,
        recipientName: recipientName,
        events: events ?? this.events,
        failureReason: failureReason,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        reference: j['reference'] as String,
        status: TxStatus.parse(j['status'] as String),
        test: j['test'] as bool? ?? false,
        from: ProviderRef.fromJson((j['from'] as Map).cast<String, dynamic>()),
        to: ProviderRef.fromJson((j['to'] as Map).cast<String, dynamic>()),
        currency: j['currency'] as String? ?? 'USD',
        receiveCurrency: j['receive_currency'] as String? ?? j['currency'] as String? ?? 'USD',
        amountCents: (j['amount_minor'] ?? j['amount_cents'] as num).toInt(),
        feeBps: ((j['fee_bps'] ?? 100) as num).toInt(),
        feeCents: (j['fee_minor'] ?? j['fee_cents'] as num).toInt(),
        providerFeeCents: ((j['provider_fee_minor'] ?? j['provider_fee_cents'] ?? 0) as num).toInt(),
        rateMicro: ((j['rate_micro'] ?? 1000000) as num).toInt(),
        rateDifferenceMinor: ((j['rate_difference_minor'] ?? 0) as num).toInt(),
        receiveCents: (j['receive_minor'] ?? j['receive_cents'] as num).toInt(),
        recipientAccount: j['recipient_account'] as String? ?? '',
        recipientName: j['recipient_name'] as String?,
        events: ((j['events'] as List?) ?? const [])
            .map((e) => TxEvent.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        failureReason: j['failure_reason'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(j['updated_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference': reference,
        'status': status.wire,
        'test': test,
        'from': from.toJson(),
        'to': to.toJson(),
        'currency': currency,
        'receive_currency': receiveCurrency,
        'amount_minor': amountCents,
        'fee_bps': feeBps,
        'fee_minor': feeCents,
        'provider_fee_minor': providerFeeCents,
        'rate_micro': rateMicro,
        'rate_difference_minor': rateDifferenceMinor,
        'receive_minor': receiveCents,
        'recipient_account': recipientAccount,
        'recipient_name': recipientName,
        'events': events.map((e) => e.toJson()).toList(),
        'failure_reason': failureReason,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

class SupportTicket {
  SupportTicket({
    required this.id,
    required this.number,
    required this.subject,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String number;
  final String subject;
  final String status;
  final DateTime createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as String,
        number: j['number'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'subject': subject,
        'status': status,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
