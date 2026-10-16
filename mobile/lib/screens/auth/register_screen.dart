import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'otp_screen.dart';

class Country {
  const Country(this.iso, this.name, this.dial);
  final String iso;
  final String name;
  final String dial;
}

const countries = [
  Country('SO', 'Somalia', '252'),
  Country('KE', 'Kenya', '254'),
  Country('ET', 'Ethiopia', '251'),
  Country('DJ', 'Djibouti', '253'),
  Country('UG', 'Uganda', '256'),
  Country('AE', 'United Arab Emirates', '971'),
  Country('SA', 'Saudi Arabia', '966'),
  Country('TR', 'Türkiye', '90'),
  Country('GB', 'United Kingdom', '44'),
  Country('US', 'United States', '1'),
  Country('CA', 'Canada', '1'),
  Country('SE', 'Sweden', '46'),
  Country('NO', 'Norway', '47'),
];

/// Simple sign-up: full name + phone. Sign-in: phone only. Both continue to OTP.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.login = false});
  final bool login;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late bool _login = widget.login;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Country _country = countries.first;
  String _channel = 'sms';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _e164 {
    var digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith(_country.dial) && digits.length > 10) digits = digits.substring(_country.dial.length);
    return '+${_country.dial}$digits';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final ticket = await app.api.requestOtp(
        phone: _e164,
        name: _login ? null : _name.text.trim(),
        purpose: _login ? 'login' : 'register',
        channel: _channel,
      );
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          ticket: ticket,
          phone: _e164,
          name: _login ? null : _name.text.trim(),
          purpose: _login ? 'login' : 'register',
        ),
      ));
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
      if (e.code == 'not_found' && mounted) setState(() => _login = false);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in countries)
                ListTile(
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Text('+${c.dial}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  selected: c.iso == _country.iso,
                  onTap: () => Navigator.pop(context, c),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _country = picked);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final channels = app.config.otpChannels.where((c) => c != 'email').toList();
    if (!channels.contains(_channel) && channels.isNotEmpty) _channel = channels.first;

    return SarifioScaffold(
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              Row(children: [themedMark(context, size: 34)]),
              const SizedBox(height: 28),
              Text(_login ? s.t('welcome_back') : s.t('create_account'), style: display(30, color: p.text)),
              const SizedBox(height: 8),
              Text(_login ? s.t('login_sub') : s.t('register_sub'),
                  style: TextStyle(color: p.text2, fontSize: 15.5, height: 1.5)),
              const SizedBox(height: 28),
              if (!_login) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(labelText: s.t('full_name')),
                  validator: (v) => (v == null || v.trim().length < 2) ? s.t('err_name') : null,
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 58,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 58),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _pickCountry,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_country.iso} +${_country.dial}'),
                          const Icon(Icons.expand_more_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumberNational],
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                      decoration: InputDecoration(labelText: s.t('phone'), hintText: '90 000 0000'),
                      validator: (v) {
                        final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        return (d.length < 7 || d.length > 13) ? s.t('err_phone') : null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              if (channels.length > 1) ...[
                const SizedBox(height: 20),
                Text(s.t('send_code_via'),
                    style: TextStyle(color: p.text2, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in channels)
                      ChoiceChip(
                        label: Text(c == 'whatsapp' ? 'WhatsApp' : 'SMS'),
                        selected: _channel == c,
                        onSelected: (_) => setState(() => _channel = c),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              BusyButton(label: s.t('continue'), busy: _busy, onPressed: _submit),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _login = !_login),
                child: Text(_login ? s.t('no_account') : s.t('have_account')),
              ),
              const SizedBox(height: 16),
              Text(s.t('terms_note'),
                  textAlign: TextAlign.center, style: TextStyle(color: p.text2, fontSize: 12, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}
