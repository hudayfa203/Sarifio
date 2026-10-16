import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'models.dart';

/// Client for the SARIFIO API (docs/API.md). The bearer token lives in the
/// Android Keystore-backed secure storage — never in plain preferences — and
/// no provider credentials ever reach the app.
class HttpApi implements SarifioApi {
  HttpApi(String baseUrl) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'sarifio_token';
  String? _token;
  String _envLabel = 'STAGING';

  @override
  bool get isOnDevice => false;

  @override
  String get environmentLabel => _envLabel;

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1$path');
    try {
      final req = await _client.openUrl(method, uri).timeout(const Duration(seconds: 20));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set('X-Client', 'sarifio-android/0.1.0');
      if (auth) {
        _token ??= await _storage.read(key: _tokenKey);
        if (_token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      headers?.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(const Duration(seconds: 25));
      final text = await res.transform(utf8.decoder).join();
      final dynamic data = text.isEmpty ? null : jsonDecode(text);
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      final err = (data is Map && data['error'] is Map) ? data['error'] as Map : const {};
      if (res.statusCode == 401) {
        _token = null;
        await _storage.delete(key: _tokenKey);
      }
      throw ApiException(
        err['code']?.toString() ?? 'http_${res.statusCode}',
        err['message']?.toString() ?? 'Something went wrong (${res.statusCode}). Please try again.',
        status: res.statusCode,
      );
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('network', 'The SARIFIO server is taking too long to respond. Check your connection and try again.');
    } on SocketException {
      throw ApiException('network', 'Can\'t reach the SARIFIO server. Check your internet connection.');
    } on HandshakeException {
      throw ApiException('network', 'Secure connection to the server failed.');
    } on FormatException {
      throw ApiException('bad_response', 'The server sent an unexpected response.');
    }
  }

  Map<String, dynamic> _map(dynamic d) => (d as Map).cast<String, dynamic>();

  @override
  Future<AppConfigData> getConfig() async {
    final cfg = AppConfigData.fromJson(_map(await _send('GET', '/config', auth: false)));
    _envLabel = cfg.testMode ? 'TEST MODE · ${cfg.environment}' : cfg.environment.toUpperCase();
    return cfg;
  }

  @override
  Future<OtpTicket> requestOtp({
    required String phone,
    String? name,
    required String purpose,
    String channel = 'sms',
  }) async =>
      OtpTicket.fromJson(_map(await _send('POST', '/auth/otp/request', auth: false, body: {
        'phone': phone,
        if (name != null) 'name': name,
        'purpose': purpose,
        'channel': channel,
      })));

  @override
  Future<AppUser> verifyOtp({
    required String requestId,
    required String code,
    required String deviceName,
  }) async {
    final d = _map(await _send('POST', '/auth/otp/verify', auth: false, body: {
      'request_id': requestId,
      'code': code,
      'device_name': deviceName,
    }));
    _token = d['token'] as String;
    await _storage.write(key: _tokenKey, value: _token);
    return AppUser.fromJson(_map(d['user']));
  }

  @override
  Future<AppUser?> restoreSession() async {
    _token = await _storage.read(key: _tokenKey);
    if (_token == null) return null;
    try {
      return await getMe();
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } catch (_) {
      // Signing out locally must always succeed.
    }
    _token = null;
    await _storage.delete(key: _tokenKey);
  }

  @override
  Future<AppUser> getMe() async => AppUser.fromJson(_map(await _send('GET', '/me')));

  @override
  Future<AppUser> updateMe({String? name, String? email, String? language}) async =>
      AppUser.fromJson(_map(await _send('PATCH', '/me', body: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (language != null) 'language': language,
      })));

  @override
  Future<Quote> createQuote({required String from, required String to, required int amountCents}) async =>
      Quote.fromJson(_map(await _send('POST', '/quotes', body: {
        'from': from,
        'to': to,
        'amount_minor': amountCents, // minor units of the sending wallet's currency
      })));

  @override
  Future<Transaction> createExchange({
    required Quote quote,
    required String recipientAccount,
    String? recipientName,
    required String idempotencyKey,
  }) async =>
      Transaction.fromJson(_map(await _send('POST', '/exchanges',
          headers: {'Idempotency-Key': idempotencyKey},
          body: {
            'quote_id': quote.id,
            'recipient_account': recipientAccount,
            if (recipientName != null && recipientName.isNotEmpty) 'recipient_name': recipientName,
          })));

  @override
  Future<List<Transaction>> listExchanges() async {
    final d = _map(await _send('GET', '/exchanges'));
    return (d['data'] as List).map((e) => Transaction.fromJson(_map(e))).toList();
  }

  @override
  Future<Transaction> getExchange(String id) async =>
      Transaction.fromJson(_map(await _send('GET', '/exchanges/$id')));

  @override
  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    String? transactionId,
  }) async =>
      SupportTicket.fromJson(_map(await _send('POST', '/support/tickets', body: {
        'subject': subject,
        'message': message,
        if (transactionId != null) 'transaction_id': transactionId,
      })));

  @override
  Future<List<SupportTicket>> listTickets() async {
    final d = _map(await _send('GET', '/support/tickets'));
    return (d['data'] as List).map((e) => SupportTicket.fromJson(_map(e))).toList();
  }

  @override
  Future<void> setNextOutcome(String outcome) async {
    await _send('POST', '/sandbox/next-outcome', body: {'outcome': outcome});
  }

  @override
  Future<void> resetTestData() async {
    throw ApiException('unsupported', 'Reset staging test data from the admin dashboard.');
  }
}
