import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../home/home_shell.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.ticket,
    required this.phone,
    required this.purpose,
    this.name,
  });

  final OtpTicket ticket;
  final String phone;
  final String purpose;
  final String? name;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late OtpTicket _ticket = widget.ticket;
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer(_ticket.resendIn);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    _resendIn = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final user = await app.api.verifyOtp(
        requestId: _ticket.requestId,
        code: _code.text,
        deviceName: 'SARIFIO ${Platform.operatingSystem}',
      );
      app.setSignedIn(user);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      _code.clear();
      setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final app = AppScope.read(context);
    try {
      final t = await app.api.requestOtp(
        phone: widget.phone,
        name: widget.name,
        purpose: widget.purpose,
        channel: _ticket.channel,
      );
      if (!mounted) return;
      setState(() => _ticket = t);
      _startTimer(t.resendIn);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.s.t('code_resent'))));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final p = Palette.of(context);
    final via = _ticket.channel == 'whatsapp' ? 'WhatsApp' : 'SMS';
    return SarifioScaffold(
      title: s.t('verify_title'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(s.t('otp_sent', {'via': via, 'phone': widget.phone}),
                style: TextStyle(color: p.text2, fontSize: 15.5, height: 1.5)),
            if (_ticket.testCode != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: SC.amberBg, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined, color: SC.amberText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.t('test_code_title'),
                              style: const TextStyle(
                                  color: SC.amberText, fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(_ticket.testCode!,
                              style: display(22, color: const Color(0xFF5E3D0B))),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _code.text = _ticket.testCode!;
                        _verify();
                      },
                      child: Text(s.t('use_code')),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            TextField(
              controller: _code,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: display(30, color: p.text).copyWith(letterSpacing: 14),
              decoration: InputDecoration(counterText: '', hintText: '••••••', labelText: s.t('six_digit_code')),
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
            ),
            const SizedBox(height: 24),
            BusyButton(label: s.t('verify'), busy: _busy, onPressed: _verify),
            const SizedBox(height: 12),
            Center(
              child: _resendIn > 0
                  ? Text(s.t('resend_in', {'s': '$_resendIn'}), style: TextStyle(color: p.text2))
                  : TextButton(onPressed: _resend, child: Text(s.t('resend_code'))),
            ),
            const SizedBox(height: 18),
            Text(s.t('never_share_code'),
                textAlign: TextAlign.center, style: TextStyle(color: p.text2, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
