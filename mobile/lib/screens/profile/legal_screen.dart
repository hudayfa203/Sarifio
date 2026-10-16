import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Drafts only — clearly marked for legal and regulatory review.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc; // terms | privacy

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final c = app.config.company;
    final sections = doc == 'terms' ? _terms(c.supportEmail) : _privacy(c.email, c.supportEmail);
    return SarifioScaffold(
      title: doc == 'terms' ? s.t('terms') : s.t('privacy'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SC.amberBg, borderRadius: BorderRadius.circular(12)),
            child: Text(s.t('legal_draft'),
                style: const TextStyle(color: SC.amberText, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          for (final sec in sections) ...[
            Text(sec.$1, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.text)),
            const SizedBox(height: 6),
            Text(sec.$2, style: TextStyle(color: p.text2, height: 1.6)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  static List<(String, String)> _terms(String support) => [
        ('1. About these terms',
            'These terms govern your use of the SARIFIO mobile app and website, operated by SARIFIO. By creating an account you agree to them.'),
        ('2. The service',
            'SARIFIO lets you request exchanges between supported digital payment services. A service is only available once its integration has been approved and enabled. SARIFIO does not hold a stored-value wallet for you.'),
        ('3. Your account',
            'You register with your name and phone number and confirm it with a one-time code. Keep your phone and codes private. Exchange features may require identity verification and are subject to limits.'),
        ('4. Fees',
            'SARIFIO charges a service fee of 1% of the exchange amount, shown before you confirm. It is only charged when an exchange completes. Any provider charge or exchange-rate difference is shown separately.'),
        ('5. Completing an exchange',
            'An exchange is complete only when the receiving provider confirms payment. If an exchange fails after your payment is collected, the amount is returned to the sending account and no SARIFIO fee is charged.'),
        ('6. Prohibited use',
            'You may not use SARIFIO for unlawful purposes, fraud, money laundering, terrorist financing, or on behalf of another person without authority.'),
        ('7. Contact',
            'Questions about these terms: $support.'),
      ];

  static List<(String, String)> _privacy(String info, String support) => [
        ('1. What we collect',
            'Your name, phone number, optional email, transaction details, device information needed for security, and verification documents when required.'),
        ('2. Why we use it',
            'To create and secure your account, process exchanges, meet legal and anti-money-laundering obligations, prevent fraud and provide support.'),
        ('3. Who we share it with',
            'Payment providers involved in your exchange, service providers that help us operate, and authorities where the law requires. We do not sell your data.'),
        ('4. Security',
            'Data is encrypted in transit. Payment-provider credentials are never stored on your phone. We never ask for your wallet PIN.'),
        ('5. Your choices',
            'You can update your profile in the app and ask for a copy or deletion of your data, subject to record-keeping duties.'),
        ('6. Contact', 'Privacy questions: $info · Support: $support.'),
      ];
}
