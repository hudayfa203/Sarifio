import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/sarifio_mark.dart';
import 'auth/register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(bool login) {
    AppScope.read(context).markOnboardingSeen();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RegisterScreen(login: login)));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final pages = [
      _Slide(visual: const _WalletsVisual(), title: s.t('ob1_title'), body: s.t('ob1_body')),
      _Slide(visual: const _FeeVisual(), title: s.t('ob2_title'), body: s.t('ob2_body')),
      _Slide(visual: const _TrackVisual(), title: s.t('ob3_title'), body: s.t('ob3_body')),
    ];
    return SarifioScaffold(
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            children: [
              Row(
                children: [
                  themedMark(context, size: 30),
                  const Spacer(),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('EN')),
                      ButtonSegment(value: 'so', label: Text('SO')),
                    ],
                    selected: {app.language},
                    onSelectionChanged: (v) => app.setLanguage(v.first),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView(
                  controller: _pc,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: pages,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 24 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? p.text : p.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (_page < pages.length - 1) {
                    _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
                  } else {
                    _go(false);
                  }
                },
                child: Text(_page < pages.length - 1 ? s.t('next') : s.t('create_account')),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => _go(true), child: Text(s.t('have_account'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.visual, required this.title, required this.body});
  final Widget visual;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: visual),
        const SizedBox(height: 28),
        Text(title, style: display(30, color: p.text)),
        const SizedBox(height: 12),
        Text(body, style: TextStyle(fontSize: 15.5, height: 1.55, color: p.text2)),
      ],
    );
  }
}

class _VisualFrame extends StatelessWidget {
  const _VisualFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12295A), SC.ink],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned(
            left: -40,
            top: -10,
            child: Opacity(opacity: 0.16, child: SarifioMark(size: 300, a: SC.blue, b: SC.teal)),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.label, required this.amount, this.teal = false});
  final String label;
  final String amount;
  final bool teal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: teal ? SC.teal : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: teal ? const Color(0xFF04231E) : SC.text2)),
          const SizedBox(height: 4),
          Text(amount, style: display(22, color: teal ? const Color(0xFF04231E) : SC.ink)),
        ],
      ),
    );
  }
}

class _WalletsVisual extends StatelessWidget {
  const _WalletsVisual();
  @override
  Widget build(BuildContext context) => const _VisualFrame(
        child: Stack(
          children: [
            Positioned(left: 20, top: 30, child: _MiniCard(label: 'Sahal', amount: '\$100.00')),
            Positioned(right: 20, top: 130, child: _MiniCard(label: 'eDahab', amount: '\$99.00', teal: true)),
          ],
        ),
      );
}

class _FeeVisual extends StatelessWidget {
  const _FeeVisual();
  @override
  Widget build(BuildContext context) => _VisualFrame(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1%', style: display(84, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('\$100.00  →  \$1.00',
                  style: TextStyle(color: SC.nightText2, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      );
}

class _TrackVisual extends StatelessWidget {
  const _TrackVisual();
  @override
  Widget build(BuildContext context) {
    Widget row(String t, bool done) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: done ? SC.teal : SC.nightText2, size: 22),
              const SizedBox(width: 12),
              Text(t,
                  style: TextStyle(
                      color: done ? Colors.white : SC.nightText2, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        );
    return _VisualFrame(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('Payment verified', true),
            row('Sending to eDahab', true),
            row('Completed · \$99.00', true),
            row('Receipt SRF-…', false),
          ],
        ),
      ),
    );
  }
}
