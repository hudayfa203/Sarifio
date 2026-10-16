import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, this.transactionId, this.subject});
  final String? transactionId;
  final String? subject;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late final _subject = TextEditingController(text: widget.subject ?? '');
  final _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final t = await app.api.createTicket(
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        transactionId: widget.transactionId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(app.s.t('ticket_created', {'n': t.number}))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final p = Palette.of(context);
    return SarifioScaffold(
      title: s.t('new_ticket'),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(s.t('ticket_sub'), style: TextStyle(color: p.text2, height: 1.5)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _subject,
              decoration: InputDecoration(labelText: s.t('subject')),
              validator: (v) => (v == null || v.trim().length < 3) ? s.t('err_subject') : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _message,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(labelText: s.t('describe_issue'), alignLabelWithHint: true),
              validator: (v) => (v == null || v.trim().length < 5) ? s.t('err_message') : null,
            ),
            const SizedBox(height: 22),
            BusyButton(label: s.t('send'), busy: _busy, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
