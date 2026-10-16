import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api.dart';
import '../data/http_api.dart';
import '../data/models.dart';
import '../data/sandbox_api.dart';
import '../l10n/strings.dart';

/// App-wide state: which backend we talk to, the signed-in user, language
/// and theme. Exposed to widgets through [AppScope].
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;

  /// Optional build-time default, e.g. --dart-define=API_BASE_URL=https://staging-api.sarifio.com
  static const String buildApiUrl = String.fromEnvironment('API_BASE_URL');

  late SarifioApi api;
  AppConfigData config = SandboxApi.buildConfig();
  AppUser? user;
  String language = 'en';
  ThemeMode themeMode = ThemeMode.system;
  bool onboardingSeen = false;
  String? serverUrl; // null = on-device sandbox
  String? configError;

  S get s => S(language);
  bool get signedIn => user != null;

  Future<void> init() async {
    language = _prefs.getString('lang') ?? 'en';
    themeMode = ThemeMode.values[_prefs.getInt('theme') ?? 0];
    onboardingSeen = _prefs.getBool('onboarding_seen') ?? false;
    serverUrl = _prefs.getString('server_url') ?? (buildApiUrl.isEmpty ? null : buildApiUrl);
    _buildApi();
    await refreshConfig();
    try {
      user = await api.restoreSession();
    } catch (_) {
      user = null;
    }
    notifyListeners();
  }

  void _buildApi() {
    final url = serverUrl;
    api = (url == null || url.isEmpty) ? SandboxApi(_prefs) : HttpApi(url);
  }

  Future<void> refreshConfig() async {
    try {
      config = await api.getConfig();
      configError = null;
    } on ApiException catch (e) {
      configError = e.message;
    } catch (_) {
      configError = 'Could not load configuration.';
    }
    notifyListeners();
  }

  void setSignedIn(AppUser u) {
    user = u;
    if (u.language != language && (u.language == 'en' || u.language == 'so')) {
      language = u.language;
      _prefs.setString('lang', language);
    }
    notifyListeners();
  }

  void updateUser(AppUser u) {
    user = u;
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await _prefs.setString('lang', lang);
    notifyListeners();
    if (user != null) {
      try {
        user = await api.updateMe(language: lang);
      } catch (_) {/* language is still applied locally */}
    }
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs.setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> markOnboardingSeen() async {
    onboardingSeen = true;
    await _prefs.setBool('onboarding_seen', true);
  }

  /// Switches between the on-device sandbox (url == null) and a server.
  /// Signs the user out, because sessions don't carry across environments.
  Future<void> setServer(String? url) async {
    try {
      await api.logout();
    } catch (_) {}
    user = null;
    transactions = [];
    txLoadedOnce = false;
    serverUrl = (url == null || url.trim().isEmpty) ? null : url.trim();
    if (serverUrl == null) {
      await _prefs.remove('server_url');
    } else {
      await _prefs.setString('server_url', serverUrl!);
    }
    _buildApi();
    await refreshConfig();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    transactions = [];
    notifyListeners();
  }

  // ---------- transactions shared by Home and Activity ----------

  List<Transaction> transactions = [];
  bool txLoading = false;
  String? txError;
  bool txLoadedOnce = false;

  Future<void> loadTransactions() async {
    if (user == null) return;
    txLoading = true;
    notifyListeners();
    try {
      transactions = await api.listExchanges();
      txError = null;
      txLoadedOnce = true;
    } on ApiException catch (e) {
      txError = s.error(e);
    } catch (_) {
      txError = s.t('err_generic');
    }
    txLoading = false;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
