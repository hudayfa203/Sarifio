import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'ticket_screen.dart';

Future<void> openExternal(BuildContext context, Uri uri) async {
  final s = AppScope.read(context).s;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(s.t('cant_open'))));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(s.t('cant_open'))));
  }
}

class SupportTab extends StatefulWidget {
  const SupportTab({super.key});

  @override
  State<SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<SupportTab> {
  List<SupportTicket>? _tickets;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final t = await AppScope.read(context).api.listTickets();
      if (mounted) setState(() => _tickets = t);
    } catch (_) {
      if (mounted) setState(() => _tickets = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final c = app.config.company;
    final waDigits = c.whatsapp.replaceAll(RegExp(r'\D'), '');

    Widget channel(IconData icon, String title, String sub, Uri uri, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            onTap: () => openExternal(context, uri),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: color ?? p.chip, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color == null ? p.text : Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: p.text, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(sub, style: TextStyle(color: p.text2, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.text2),
              ],
            ),
          ),
        );

    final faqs = [
      ('faq_fee_q', 'faq_fee_a'),
      ('faq_time_q', 'faq_time_a'),
      ('faq_fail_q', 'faq_fail_a'),
      ('faq_methods_q', 'faq_methods_a'),
      ('faq_fx_q', 'faq_fx_a'),
      ('faq_safe_q', 'faq_safe_a'),
      ('faq_test_q', 'faq_test_a'),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(s.t('support_title'), style: display(28, color: p.text)),
          const SizedBox(height: 6),
          Text(s.t('support_sub'), style: TextStyle(color: p.text2, height: 1.5)),
          const SizedBox(height: 18),
          channel(Icons.chat_rounded, 'WhatsApp', c.whatsapp,
              Uri.parse('https://wa.me/$waDigits?text=${Uri.encodeComponent(s.t('wa_greeting'))}'),
              color: const Color(0xFF1FA855)),
          channel(Icons.call_rounded, s.t('call_us'), c.phone, Uri(scheme: 'tel', path: c.phone)),
          channel(Icons.mail_outline_rounded, s.t('email_us'), c.supportEmail,
              Uri(scheme: 'mailto', path: c.supportEmail, query: 'subject=SARIFIO%20support')),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TicketScreen()));
              _load();
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(s.t('new_ticket')),
          ),
          const SizedBox(height: 8),
          SectionHeader(s.t('my_tickets')),
          if (_tickets == null)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_tickets!.isEmpty)
            Text(s.t('no_tickets'), style: TextStyle(color: p.text2))
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final t in _tickets!)
                    ListTile(
                      title: Text(t.subject, style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
                      subtitle: Text('${t.number} · ${fmtDateTime(t.createdAt)}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: SC.amberBg, borderRadius: BorderRadius.circular(999)),
                        child: Text(s.t('ticket_${t.status}'),
                            style: const TextStyle(color: SC.amberText, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          SectionHeader(s.t('faq')),
          AppCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [
                  for (final f in faqs)
                    ExpansionTile(
                      title: Text(s.t(f.$1), style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 14.5)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedAlignment: Alignment.centerLeft,
                      children: [Text(s.t(f.$2), style: TextStyle(color: p.text2, height: 1.55))],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(s.t('wa_note'), style: TextStyle(color: p.text2, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}
