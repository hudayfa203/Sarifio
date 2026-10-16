import 'models.dart';

/// One interface, two implementations:
///  * [SandboxApi] — on-device TEST MODE engine (no server, no real money).
///  * [HttpApi]    — the SARIFIO staging/production API (docs/API.md).
abstract class SarifioApi {
  /// True for the on-device sandbox.
  bool get isOnDevice;

  /// Human label for the environment banner.
  String get environmentLabel;

  Future<AppConfigData> getConfig();

  Future<OtpTicket> requestOtp({
    required String phone,
    String? name,
    required String purpose, // register | login
    String channel = 'sms',
  });

  Future<AppUser> verifyOtp({
    required String requestId,
    required String code,
    required String deviceName,
  });

  /// Returns the signed-in user if a saved session is still valid.
  Future<AppUser?> restoreSession();

  Future<void> logout();

  Future<AppUser> getMe();

  Future<AppUser> updateMe({String? name, String? email, String? language});

  Future<Quote> createQuote({
    required String from,
    required String to,
    required int amountCents,
  });

  Future<Transaction> createExchange({
    required Quote quote,
    required String recipientAccount,
    String? recipientName,
    required String idempotencyKey,
  });

  Future<List<Transaction>> listExchanges();

  Future<Transaction> getExchange(String id);

  Future<SupportTicket> createTicket({
    required String subject,
    required String message,
    String? transactionId,
  });

  Future<List<SupportTicket>> listTickets();

  /// Test Mode only: what happens to the next exchange.
  Future<void> setNextOutcome(String outcome);

  /// Test Mode only: wipe test data on this device / account.
  Future<void> resetTestData();
}
