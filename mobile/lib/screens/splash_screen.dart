import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/sarifio_mark.dart';
import 'auth/register_screen.dart';
import 'home/home_shell.dart';
import 'onboarding_screen.dart';

/// Animated "handover": the two hooks slide in and lock while the app loads.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final app = AppScope.read(context);
    try {
      await Future.wait([
        app.init().timeout(const Duration(seconds: 10)),
        Future<void>.delayed(const Duration(milliseconds: 1600)),
      ]);
    } catch (_) {
      // Never get stuck on the splash: continue with whatever state loaded.
    }
    if (!mounted) return;
    final Widget next;
    if (!app.onboardingSeen) {
      next = const OnboardingScreen();
    } else if (app.signedIn) {
      next = const HomeShell();
    } else {
      next = const RegisterScreen(login: true);
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => next,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SC.ink,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [Color(0xFF12295A), SC.ink, SC.night],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final word = Curves.easeOut.transform(((_c.value - 0.45) / 0.55).clamp(0.0, 1.0));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 5),
                  SarifioMark.reversed(size: 96, progress: _c.value),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: word,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - word)),
                      child: const Text('SARIFIO',
                          style: TextStyle(
                              fontFamily: kDisplay,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 4.8,
                              color: Colors.white)),
                    ),
                  ),
                  const Spacer(flex: 4),
                  Opacity(
                    opacity: word,
                    child: const Text('ONE APP. EVERY EXCHANGE.',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 2.2, color: SC.nightText2)),
                  ),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
