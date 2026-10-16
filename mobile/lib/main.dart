import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(SarifioApp(state: AppState(prefs)));
}

class SarifioApp extends StatelessWidget {
  const SarifioApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: Builder(builder: (context) {
        final app = AppScope.of(context);
        return MaterialApp(
          title: 'SARIFIO',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: app.themeMode,
          locale: Locale(app.language),
          supportedLocales: const [Locale('en'), Locale('so')],
          localizationsDelegates: const [
            _MaterialLoc(),
            _WidgetsLoc(),
            _CupertinoLoc(),
          ],
          home: const SplashScreen(),
        );
      }),
    );
  }
}

// Flutter ships no Material strings for Somali, so the few framework strings
// (tooltips, date pickers) fall back to English while all SARIFIO copy comes
// from lib/l10n/strings.dart in English or Somali.
class _MaterialLoc extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialLoc();
  @override
  bool isSupported(Locale locale) => ['en', 'so'].contains(locale.languageCode);
  @override
  Future<MaterialLocalizations> load(Locale locale) => DefaultMaterialLocalizations.load(locale);
  @override
  bool shouldReload(_MaterialLoc old) => false;
}

class _WidgetsLoc extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsLoc();
  @override
  bool isSupported(Locale locale) => ['en', 'so'].contains(locale.languageCode);
  @override
  Future<WidgetsLocalizations> load(Locale locale) => DefaultWidgetsLocalizations.load(locale);
  @override
  bool shouldReload(_WidgetsLoc old) => false;
}

class _CupertinoLoc extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoLoc();
  @override
  bool isSupported(Locale locale) => ['en', 'so'].contains(locale.languageCode);
  @override
  Future<CupertinoLocalizations> load(Locale locale) => DefaultCupertinoLocalizations.load(locale);
  @override
  bool shouldReload(_CupertinoLoc old) => false;
}
