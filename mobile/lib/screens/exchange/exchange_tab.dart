import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'progress_screen.dart';

/// Send from → receive to → amount → receiving account → quote → confirm.
class ExchangeTab extends StatefulWidget {
  const ExchangeTab({super.key});

  @override
  State<ExchangeTab> createState() => _ExchangeTabState();
}

class _ExchangeTabState extends State<ExchangeTab> {
  String? _from;
  String? _to;
  final _amount = TextEditingController();
  final _account = TextEditingController();
  final _recipientName = TextEditingController();
  Quote? _quote;
  String? _idemKey;
  bool _quoting = false;
  bool _submitting = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_invalidateQuote);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _quote != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _amount.dispose();
    _account.dispose();
    _recipientName.dispose();
    super.dispose();
  }

  void _invalidateQuote() {
    setState(() => _quote = null);
  }

  int? get _amountCents => parseUsdToCents(_amount.text);

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _pick({required bool from}) async {
    final app = AppScope.read(context);
    final s = app.s;
    final cfg = app.config;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final p = Palette.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text(from ? s.t('send_from') : s.t('receive_to'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text)),
                ),
                for (final pr in cfg.providers)
                  Builder(builder: (context) {
                    final ok = from
                        ? cfg.sendable.any((x) => x.code == pr.code)
                        : (_from != null && cfg.routeAvailable(_from!, pr.code));
                    final reason = !pr.usable
                        ? s.providerStatus(pr.status, cfg.testMode)
                        : (!from && _from == pr.code)
                            ? s.t('same_provider')
                            : (!ok ? s.t('route_unavailable') : (pr.group ?? ''));
                    return ListTile(
                      enabled: ok,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Opacity(
                          opacity: ok ? 1 : 0.45, child: ProviderBadge(code: pr.code, label: pr.initials)),
                      title: Text(pr.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: reason.isEmpty ? null : Text(reason),
                      trailing: ((from ? _from : _to) == pr.code)
                          ? const Icon(Icons.check_circle_rounded, color: SC.teal)
                          : null,
                      onTap: ok ? () => Navigator.pop(context, pr.code) : null,
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
    if (chosen == null) return;
    setState(() {
      if (from) {
        _from = chosen;
        if (_to != null && !cfg.routeAvailable(chosen, _to!)) _to = null;
      } else {
        _to = chosen;
      }
      _quote = null;
    });
  }

  void _swap() {
    final cfg = AppScope.read(context).config;
    if (_from == null || _to == null) return;
    if (!cfg.routeAvailable(_to!, _from!)) {
      showError(context, ApiException('route_disabled', ''));
      return;
    }
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
      _quote = null;
    });
  }

  String? _validate() {
    final s = AppScope.read(context).s;
    if (_from == null || _to == null) return s.t('err_pick_providers');
    final c = _amountCents;
    if (c == null || c <= 0) return s.t('err_amount');
    if (_account.text.replaceAll(RegExp(r'\D'), '').length < 7) return s.t('err_account');
    return null;
  }

  Future<void> _getQuote() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _quoting = true);
    final app = AppScope.read(context);
    try {
      final q = await app.api.createQuote(from: _from!, to: _to!, amountCents: _amountCents!);
      if (!mounted) return;
      setState(() {
        _quote = q;
        _idemKey = _uuid(); // one key per accepted quote → no double submission
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _confirm() async {
    final q = _quote;
    if (q == null) return;
    if (q.expired) {
      await _getQuote();
      return;
    }
    final app = AppScope.read(context);
    final s = app.s;
    final cfg = app.config;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final p = Palette.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.t('confirm_exchange'), style: display(24, color: p.text)),
                const SizedBox(height: 14),
                KV(s.t('you_send'), '${formatMoney(q.amountCents, q.currency)} · ${cfg.provider(q.from)?.name ?? q.from}'),
                KV(s.t('to_account'), '${cfg.provider(q.to)?.name ?? q.to} · ${_account.text.trim()}'),
                if (_recipientName.text.trim().isNotEmpty) KV(s.t('recipient_name'), _recipientName.text.trim()),
                KV(s.t('service_fee_pct', {'fee': FeeEngine.percentLabel(q.feeBps)}),
                    '−${formatMoney(q.feeCents, q.currency)}'),
                if (q.providerFeeCents > 0)
                  KV(s.t('provider_charges'), '−${formatMoney(q.providerFeeCents, q.currency)}'),
                if (q.crossCurrency) ...[
                  KV(s.t('rate'), '1 ${q.currency} = ${formatRate(q.rateMicro)} ${q.receiveCurrency}'),
                  KV(s.t('rate_difference'), '−${formatMoney(q.rateDifferenceMinor, q.receiveCurrency)}'),
                ],
                Divider(color: p.border, height: 20),
                KV(s.t('they_receive'), formatMoney(q.receiveCents, q.receiveCurrency), bold: true),
                const SizedBox(height: 10),
                Text(s.t('confirm_note'), style: TextStyle(color: p.text2, fontSize: 12.5, height: 1.5)),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('exchange_now'))),
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
              ],
            ),
          ),
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final tx = await app.api.createExchange(
        quote: q,
        recipientAccount: _account.text.trim(),
        recipientName: _recipientName.text.trim(),
        idempotencyKey: _idemKey ?? _uuid(),
      );
      if (!mounted) return;
      _amount.clear();
      _account.clear();
      _recipientName.clear();
      setState(() => _quote = null);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProgressScreen(initial: tx)));
      if (mounted) app.loadTransactions();
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
      if (e is ApiException && (e.code == 'quote_expired' || e.code == 'quote_already_used')) {
        setState(() => _quote = null);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final cfg = app.config;
    final cents = _amountCents ?? 0;
    final fromP = _from == null ? null : cfg.provider(_from!);
    final toP = _to == null ? null : cfg.provider(_to!);
    final sendCur = fromP?.currency ?? 'USD';
    final recvCur = toP?.currency ?? sendCur;
    final fx = cfg.rate(sendCur, recvCur);
    final route = (_from != null && _to != null) ? cfg.route(_from!, _to!) : null;
    final preview = FeeEngine.quote(
      amountMinor: cents,
      feeBps: cfg.feeBps,
      providerFeeMinor: FeeEngine.feeMinor(cents, route?.providerFeeBps ?? 0),
      midRateMicro: fx?.midRateMicro ?? 1000000,
      spreadBps: fx?.spreadBps ?? 0,
    );
    final feeBps = _quote?.feeBps ?? cfg.feeBps;
    final fee = _quote?.feeCents ?? preview.feeMinor;
    final providerFee = _quote?.providerFeeCents ?? preview.providerFeeMinor;
    final rateMicro = _quote?.rateMicro ?? preview.appliedRateMicro;
    final rateDiff = _quote?.rateDifferenceMinor ?? preview.rateDifferenceMinor;
    final receive = _quote?.receiveCents ?? preview.receiveMinor;
    final cross = sendCur != recvCur;
    final presets = sendCur == 'USD' ? const [1000, 5000, 10000, 50000] : const [100000, 500000, 1000000, 5000000];
    final secsLeft = _quote == null ? 0 : _quote!.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999).toInt();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(s.t('nav_exchange'), style: display(28, color: p.text)),
        const SizedBox(height: 16),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                _ProviderCard(
                  label: s.t('you_send'),
                  provider: _from == null ? null : cfg.provider(_from!),
                  placeholder: s.t('choose_provider'),
                  onTap: () => _pick(from: true),
                  amountField: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    textAlign: TextAlign.right,
                    style: display(28, color: p.text),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      prefixText: currencySymbol(sendCur),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ProviderCard(
                  label: s.t('you_receive'),
                  provider: _to == null ? null : cfg.provider(_to!),
                  placeholder: s.t('choose_provider'),
                  onTap: () => _from == null
                      ? ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(s.t('pick_from_first'))))
                      : _pick(from: false),
                  amountText: formatMoney(cents > 0 ? receive : 0, recvCur),
                  amountColor: SC.tealDark,
                  note: s.t('estimated_note'),
                ),
              ],
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.02),
                child: Material(
                  color: SC.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: p.bg, width: 4),
                  ),
                  child: IconButton(
                    tooltip: s.t('swap'),
                    onPressed: _swap,
                    icon: const Icon(Icons.swap_vert_rounded, color: SC.teal),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final v in presets)
              ActionChip(
                label: Text(formatMoney(v, sendCur).replaceAll('.00', '')),
                onPressed: () {
                  _amount.text = (v / 100).toStringAsFixed(2);
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _account,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _invalidateQuote(),
          decoration: InputDecoration(
            labelText: s.t('receiving_account'),
            hintText: _to == null ? null : s.t('account_hint', {'provider': cfg.provider(_to!)?.name ?? ''}),
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _recipientName,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.t('recipient_name_optional'),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              KV(s.t('exchange_amount'), formatMoney(cents, sendCur)),
              KV(s.t('service_fee_pct', {'fee': FeeEngine.percentLabel(feeBps)}), '−${formatMoney(fee, sendCur)}'),
              KV(s.t('provider_charges'), providerFee > 0 ? '−${formatMoney(providerFee, sendCur)}' : s.t('none')),
              if (cross) ...[
                KV(s.t('rate'), '1 $sendCur = ${formatRate(rateMicro)} $recvCur'),
                KV(s.t('rate_difference'), '−${formatMoney(rateDiff, recvCur)}'),
              ] else
                KV(s.t('rate'), s.t('same_currency')),
              Divider(color: p.border, height: 18),
              KV(s.t('they_receive'), formatMoney(receive, recvCur), bold: true),
              if (_quote == null && cents > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(s.t('preview_note'), style: TextStyle(color: p.text2, fontSize: 11.5)),
                ),
              if (_quote != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        value: secsLeft / 60,
                        strokeWidth: 3,
                        backgroundColor: p.border,
                        color: SC.teal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        secsLeft > 0 ? s.t('quote_locked', {'s': '$secsLeft'}) : s.t('quote_expired'),
                        style: TextStyle(fontWeight: FontWeight.w700, color: p.text, fontSize: 13.5),
                      ),
                    ),
                    if (secsLeft == 0) TextButton(onPressed: _getQuote, child: Text(s.t('refresh'))),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF13234A) : const Color(0xFFEEF3FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.t('fee_only_on_success'),
                    style: TextStyle(fontSize: 12.5, height: 1.5, color: p.text)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_quote == null || _quote!.expired)
          BusyButton(label: s.t('get_quote'), busy: _quoting, onPressed: _getQuote)
        else
          BusyButton(
            label: s.t('exchange_now'),
            busy: _submitting,
            icon: Icons.arrow_forward_rounded,
            onPressed: _confirm,
          ),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.label,
    required this.provider,
    required this.placeholder,
    required this.onTap,
    this.amountField,
    this.amountText,
    this.amountColor,
    this.note,
  });

  final String label;
  final PaymentProvider? provider;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? amountField;
  final String? amountText;
  final Color? amountColor;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: p.text2, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 10, 6),
                  decoration: BoxDecoration(
                    color: p.chip,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (provider != null)
                        ProviderBadge(code: provider!.code, label: provider!.initials, size: 32)
                      else
                        Icon(Icons.add_circle_outline_rounded, color: p.text2),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(provider?.name ?? placeholder,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.text)),
                          if (provider?.group != null)
                            Text(provider!.group!, style: TextStyle(fontSize: 11, color: p.text2)),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded, size: 18, color: p.text2),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: amountField ??
                    Text(amountText ?? '',
                        textAlign: TextAlign.right,
                        style: display(28, color: dark ? SC.teal : (amountColor ?? p.text))),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note!, style: TextStyle(color: p.text2, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
