// Captures real screenshots of the SARIFIO app (Test Mode, on-device sandbox)
// for the investor prospectus. Runs only when SARIFIO_SHOTS=1, e.g. in the
// "App screenshots" workflow:  SARIFIO_SHOTS=1 flutter test test/screens
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sarifio_app/data/sandbox_api.dart';
import 'package:sarifio_app/main.dart';
import 'package:sarifio_app/screens/activity/receipt_screen.dart';
import 'package:sarifio_app/screens/auth/otp_screen.dart';
import 'package:sarifio_app/screens/auth/register_screen.dart';
import 'package:sarifio_app/screens/exchange/exchange_tab.dart';
import 'package:sarifio_app/screens/exchange/progress_screen.dart';
import 'package:sarifio_app/screens/home/home_shell.dart';
import 'package:sarifio_app/screens/onboarding_screen.dart';
import 'package:sarifio_app/state/app_state.dart';

final _enabled = Platform.environment['SARIFIO_SHOTS'] == '1';
final _out = Directory('shots');
final _log = <String>[];

Future<void> _fonts() async {
  const fams = {
    'Sora': ['Regular', 'SemiBold', 'Bold'],
    'Manrope': ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'],
  };
  for (final e in fams.entries) {
    final l = FontLoader(e.key);
    for (final w in e.value) {
      l.addFont(rootBundle.load('assets/fonts/${e.key}-$w.ttf'));
    }
    await l.load();
  }
  for (final path in ['/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 'test/screens/mono.ttf']) {
    final f = File(path);
    if (f.existsSync()) {
      final l = FontLoader('monospace')..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
      await l.load();
      break;
    }
  }
  final icons = File('test/screens/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await l.load();
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.state, required this.child, required this.boundary});
  final AppState state;
  final Widget child;
  final GlobalKey boundary;
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundary,
      child: SarifioApp(state: state, home: child),
    );
  }
}

Future<void> _snap(WidgetTester t, GlobalKey key, String name) async {
  try {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    await t.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${_out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
    _log.add('ok   $name');
  } catch (e) {
    _log.add('FAIL $name: $e');
  }
}

Future<void> _tapText(WidgetTester t, String text, {bool last = false}) async {
  final f = find.text(text);
  await t.tap(last ? f.last : f.first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Finder _inEx(Finder f) => find.descendant(of: find.byType(ExchangeTab), matching: f);
Finder get _exScroll => _inEx(find.byType(Scrollable)).first;

Future<void> _scrollTo(WidgetTester t, String text) async {
  await t.scrollUntilVisible(_inEx(find.text(text)), 250, scrollable: _exScroll, maxScrolls: 30);
  await t.pump(const Duration(milliseconds: 300));
}

Future<void> _scrollTap(WidgetTester t, String text) async {
  await _scrollTo(t, text);
  await t.tap(_inEx(find.text(text)), warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _settleQuote(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('capture SARIFIO app screens', (t) async {
    debugDisableShadows = false;
    _out.createSync(recursive: true);
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    await t.runAsync(_fonts);

    Future<AppState> fresh({String lang = 'en', bool signedIn = true}) async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true, 'lang': lang});
      final prefs = await SharedPreferences.getInstance();
      final st = AppState(prefs);
      await t.runAsync(() async {
        await st.init();
        if (signedIn) {
          final api = st.api as SandboxApi;
          final ticket = await api.requestOtp(phone: '+252906000123', name: 'Amina Yusuf', purpose: 'register');
          final u = await api.verifyOtp(requestId: ticket.requestId, code: ticket.testCode!, deviceName: 'Test');
          st.setSignedIn(u);
          await st.loadTransactions();
        }
      });
      return st;
    }

    Future<void> show(AppState st, Widget w, String name, {Future<void> Function()? act}) async {
      final key = GlobalKey();
      await t.pumpWidget(_Frame(state: st, boundary: key, child: w));
      await t.pump(const Duration(milliseconds: 500));
      if (act != null) {
        try {
          await act();
        } catch (e) {
          _log.add('act  $name: $e');
        }
      }
      await _snap(t, key, name);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    }

    // 1-3 onboarding, sign-up, OTP
    final anon = await fresh(signedIn: false);
    await show(anon, const OnboardingScreen(), '01-onboarding');
    await show(anon, const RegisterScreen(), '02-register', act: () async {
      await t.enterText(find.byType(TextField).first, 'Amina Yusuf');
      if (find.byType(TextField).evaluate().length > 1) {
        await t.enterText(find.byType(TextField).at(1), '906000123');
      }
      await t.pump();
    });
    final otpTicket = await t.runAsync(() => (anon.api as SandboxApi)
        .requestOtp(phone: '+252906000999', name: 'Amina Yusuf', purpose: 'register'));
    await show(anon, OtpScreen(ticket: otpTicket!, phone: '+252 906 000 999', purpose: 'register', name: 'Amina Yusuf'),
        '03-otp');

    // signed-in screens with demo history
    final st = await fresh();
    await show(st, const HomeShell(), '04-home');
    await show(st, const HomeShell(), '05-exchange-empty', act: () async {
      await _tapText(t, st.s.t('nav_exchange'), last: true);
    });
    await show(st, const HomeShell(), '06-wallet-picker', act: () async {
      await _tapText(t, st.s.t('nav_exchange'), last: true);
      await _tapText(t, st.s.t('choose_provider'));
    });
    Future<void> fill(String a, String b, String amt, String acc) async {
      await _tapText(t, st.s.t('nav_exchange'), last: true);
      await _tapText(t, st.s.t('choose_provider'));
      await _tapText(t, a, last: true);
      await _tapText(t, st.s.t('choose_provider'));
      await _tapText(t, b, last: true);
      await t.enterText(find.byType(TextField).first, amt);
      await t.enterText(find.byType(TextField).at(1), acc);
      await t.pump();
    }
    await show(st, const HomeShell(), '07-exchange-quote', act: () async {
      await fill('Sahal', 'eDahab', '100', '623456789');
      await _scrollTap(t, st.s.t('get_quote'));
      await _settleQuote(t);
      await t.drag(_exScroll, const Offset(0, 2000));
      await t.pump(const Duration(milliseconds: 400));
    });
    await show(st, const HomeShell(), '07b-quote-summary', act: () async {
      await fill('Sahal', 'eDahab', '100', '623456789');
      await _scrollTap(t, st.s.t('get_quote'));
      await _settleQuote(t);
      await _scrollTo(t, st.s.t('exchange_now'));
    });
    await show(st, const HomeShell(), '08-confirm', act: () async {
      await fill('EVC Plus', 'M-Pesa', '250', '712345678');
      await _scrollTap(t, st.s.t('get_quote'));
      await _settleQuote(t);
      await _scrollTap(t, st.s.t('exchange_now'));
      await t.pump(const Duration(milliseconds: 800));
      await t.pump(const Duration(milliseconds: 800));
    });

    // progress + receipt from API-created exchanges
    final api = st.api as SandboxApi;
    final tx = await t.runAsync(() async {
      final q = await api.createQuote(from: 'sahal', to: 'ebirr', amountCents: 10000);
      return api.createExchange(quote: q, recipientAccount: '+251911223344', recipientName: 'Abebe', idempotencyKey: 'shot-1');
    });
    await show(st, ProgressScreen(initial: tx!), '09-progress');
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 10));
      await st.loadTransactions();
    });
    final settled = st.transactions.firstWhere((x) => x.status == 'settled', orElse: () => st.transactions.first);
    await show(st, ReceiptScreen(txId: settled.id, initial: settled), '10-receipt');
    await show(st, ProgressScreen(initial: tx), '09b-progress-done');
    await show(st, const HomeShell(), '11-history', act: () async {
      await _tapText(t, st.s.t('nav_activity'), last: true);
    });
    await show(st, const HomeShell(), '12-profile', act: () async {
      await _tapText(t, st.s.t('nav_profile'), last: true);
    });
    await show(st, const HomeShell(), '13-support', act: () async {
      await _tapText(t, st.s.t('nav_support'), last: true);
    });

    // Somali
    final so = await fresh(lang: 'so');
    await t.runAsync(() => so.setLanguage('so'));
    await show(so, const HomeShell(), '14-home-somali');
    await show(so, const HomeShell(), '15-exchange-somali', act: () async {
      await _tapText(t, so.s.t('nav_exchange'), last: true);
    });
    await show(so, const HomeShell(), '16-profile-somali', act: () async {
      await _tapText(t, so.s.t('nav_profile'), last: true);
    });

    File('${_out.path}/log.txt').writeAsStringSync(_log.join('\n'));
    debugDisableShadows = true;
  }, skip: !_enabled);
}
