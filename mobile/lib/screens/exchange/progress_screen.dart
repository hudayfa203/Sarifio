import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sarifio_mark.dart';
import '../activity/receipt_screen.dart';
import '../support/ticket_screen.dart';

/// Live tracking: polls the transaction until it reaches a final state.
/// Success is only shown when the backend (or sandbox engine) reports `settled`.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.initial});
  final Transaction initial;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late Transaction _tx = widget.initial;
  Timer? _poll;
  String? _pollError;
  late final AnimationController _done =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final t = await AppScope.read(context).api.getExchange(_tx.id);
      if (!mounted) return;
      setState(() {
        _tx = t;
        _pollError = null;
      });
      if (t.status.isFinal || t.status == TxStatus.manualReview) {
        _poll?.cancel();
        if (t.status == TxStatus.settled) _done.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _pollError = e is ApiException ? AppScope.read(context).s.error(e) : '$e');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _done.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final p = Palette.of(context);
    final st = _tx.status;
    final reached = _tx.events.map((e) => e.status).toSet();

    final steps = <(String, bool, bool)>[
      (s.t('step_payment_requested', {'provider': _tx.from.name}), true, st == TxStatus.awaitingPayment),
      (
        s.t('step_payment_verified'),
        reached.contains(TxStatus.paymentVerified),
        st == TxStatus.paymentVerified
      ),
      (
        s.t('step_sending', {'provider': _tx.to.name}),
        reached.contains(TxStatus.payoutProcessing),
        st == TxStatus.payoutProcessing
      ),
      (s.t('step_completed'), st == TxStatus.settled, false),
    ];

    Widget header;
    if (st == TxStatus.settled) {
      header = Column(
        children: [
          AnimatedBuilder(
            animation: _done,
            builder: (_, __) => SarifioMark.reversed(size: 76, progress: _done.value),
          ),
          const SizedBox(height: 18),
          Text(s.t('exchange_complete'), style: const TextStyle(color: SC.nightText2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(formatMoney(_tx.receiveCents, _tx.receiveCurrency), style: display(40, color: Colors.white)),
          Text(s.t('delivered_to', {'provider': _tx.to.name}),
              style: const TextStyle(color: SC.nightText2, fontSize: 14)),
        ],
      );
    } else if (st.isProblem) {
      header = Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: st == TxStatus.manualReview ? SC.amberBg : const Color(0xFFFBE7E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              st == TxStatus.manualReview ? Icons.hourglass_top_rounded : Icons.error_outline_rounded,
              color: st == TxStatus.manualReview ? SC.amberText : const Color(0xFFA82E33),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(s.status(st), style: display(26, color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            _tx.failureReason ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: SC.nightText2, height: 1.5),
          ),
        ],
      );
    } else {
      header = Column(
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4, color: SC.teal, backgroundColor: Color(0x22FFFFFF)),
          ),
          const SizedBox(height: 18),
          Text(s.t('processing'), style: display(26, color: Colors.white)),
          const SizedBox(height: 6),
          Text('${formatMoney(_tx.amountCents, _tx.currency)} · ${_tx.from.name} → ${_tx.to.name}',
              style: const TextStyle(color: SC.nightText2)),
        ],
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: SC.ink,
        body: Column(
          children: [
            const TestModeBanner(),
            Expanded(
              child: SafeArea(
                top: !AppScope.of(context).config.testMode,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 36, 22, 22),
                  children: [
                    header,
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(22)),
                      child: Column(
                        children: [
                          for (final step in steps)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  if (step.$3 && !st.isProblem)
                                    const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: SC.teal))
                                  else
                                    Icon(
                                      step.$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: step.$2 ? SC.teal : p.border,
                                      size: 22,
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(step.$1,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: step.$2 || step.$3 ? p.text : p.text2)),
                                  ),
                                ],
                              ),
                            ),
                          Divider(color: p.border, height: 24),
                          KV(s.t('reference'), _tx.reference, mono: true),
                          KV(s.t('service_fee_pct', {'fee': FeeEngine.percentLabel(_tx.feeBps)}),
                              st == TxStatus.settled || !st.isProblem ? formatMoney(_tx.feeCents, _tx.currency) : s.t('not_charged')),
                        ],
                      ),
                    ),
                    if (_pollError != null) ...[
                      const SizedBox(height: 12),
                      Text(_pollError!, textAlign: TextAlign.center, style: const TextStyle(color: SC.amberBg)),
                    ],
                    const SizedBox(height: 22),
                    if (st == TxStatus.settled || st.isProblem)
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: SC.ink),
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => ReceiptScreen(txId: _tx.id, initial: _tx)),
                        ),
                        child: Text(s.t('view_receipt')),
                      ),
                    if (st.isProblem) ...[
                      const SizedBox(height: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white, side: const BorderSide(color: Color(0x55FFFFFF))),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TicketScreen(
                                  transactionId: _tx.id,
                                  subject: '${s.t('issue_with')} ${_tx.reference}',
                                ))),
                        child: Text(s.t('contact_support')),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(st.isFinal ? s.t('done') : s.t('track_in_activity'),
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
