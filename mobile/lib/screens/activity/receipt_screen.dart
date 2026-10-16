import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../support/ticket_screen.dart';

/// Digital receipt / transaction details.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.txId, this.initial});
  final String txId;
  final Transaction? initial;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Transaction? _tx;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tx = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final t = await AppScope.read(context).api.getExchange(widget.txId);
      if (mounted) setState(() => _tx = t);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final tx = _tx;

    if (tx == null) {
      return SarifioScaffold(
        title: s.t('receipt'),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Text(_error is ApiException ? s.error(_error as ApiException) : s.t('err_generic')),
        ),
      );
    }

    final ok = tx.status == TxStatus.settled;
    return SarifioScaffold(
      title: s.t('receipt'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: SC.ink, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ok ? s.t('amount_received') : s.t('exchange_amount'),
                            style: const TextStyle(color: SC.nightText2, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(ok ? formatMoney(tx.receiveCents, tx.receiveCurrency) : formatMoney(tx.amountCents, tx.currency),
                            style: display(32, color: Colors.white)),
                      ],
                    ),
                  ),
                  StatusChip(tx.status),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                children: [
                  KV(s.t('reference'), tx.reference, mono: true),
                  KV(s.t('date_time'), fmtDateTime(tx.createdAt)),
                  KV(s.t('from'), tx.from.group == null ? tx.from.name : '${tx.from.name} (${tx.from.group})'),
                  KV(s.t('to'), tx.to.name),
                  KV(s.t('receiving_account'), tx.recipientAccount),
                  if (tx.recipientName != null) KV(s.t('recipient_name'), tx.recipientName!),
                  Divider(color: p.border, height: 20),
                  KV(s.t('exchange_amount'), formatMoney(tx.amountCents, tx.currency)),
                  KV(
                    s.t('service_fee_pct', {'fee': FeeEngine.percentLabel(tx.feeBps)}),
                    ok || !tx.status.isProblem ? formatMoney(tx.feeCents, tx.currency) : s.t('not_charged'),
                  ),
                  if (tx.providerFeeCents > 0) KV(s.t('provider_charges'), formatMoney(tx.providerFeeCents, tx.currency)),
                  if (tx.crossCurrency) ...[
                    KV(s.t('rate'), '1 ${tx.currency} = ${formatRate(tx.rateMicro)} ${tx.receiveCurrency}'),
                    KV(s.t('rate_difference'), formatMoney(tx.rateDifferenceMinor, tx.receiveCurrency)),
                  ],
                  Divider(color: p.border, height: 20),
                  KV(ok ? s.t('amount_received') : s.t('they_receive'), formatMoney(tx.receiveCents, tx.receiveCurrency), bold: true),
                  if (tx.failureReason != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: SC.amberBg, borderRadius: BorderRadius.circular(12)),
                      child: Text(tx.failureReason!,
                          style: const TextStyle(color: Color(0xFF5E3D0B), height: 1.45, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.t('timeline'), style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
                  const SizedBox(height: 8),
                  for (final e in tx.events)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: e.status.isProblem ? SC.warning : SC.teal, shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(s.status(e.status), style: TextStyle(color: p.text))),
                          Text(fmtDateTime(e.at).split(' · ').last, style: TextStyle(color: p.text2, fontSize: 12.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tx.reference));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('copied'))));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(s.t('copy_ref')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TicketScreen(
                              transactionId: tx.id,
                              subject: '${s.t('issue_with')} ${tx.reference}',
                            ))),
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: Text(s.t('get_help')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                themedMark(context, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tx.test ? s.t('receipt_test_note') : s.t('receipt_note', {'email': app.config.company.supportEmail}),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.text2, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

