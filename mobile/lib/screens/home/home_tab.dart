import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sarifio_mark.dart';
import '../activity/receipt_screen.dart';
import 'home_shell.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  String _greeting(AppState app) {
    final h = DateTime.now().hour;
    final key = h < 12 ? 'good_morning' : (h < 17 ? 'good_afternoon' : 'good_evening');
    return app.s.t(key);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final user = app.user;
    final recent = app.transactions.take(3).toList();
    final fee = FeeEngine.percentLabel(app.config.feeBps);

    return RefreshIndicator(
      onRefresh: () async {
        await app.refreshConfig();
        await app.loadTransactions();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.chip, shape: BoxShape.circle),
                child: Text(
                  _initials(user?.name ?? ''),
                  style: TextStyle(fontWeight: FontWeight.w800, color: p.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(app), style: TextStyle(color: p.text2, fontSize: 13)),
                    Text(user?.firstName ?? '',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: p.text)),
                  ],
                ),
              ),
              themedMark(context, size: 28),
            ],
          ),
          const SizedBox(height: 18),

          // Quick exchange hero
          Container(
            decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(26)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                const Positioned(
                  right: -60,
                  top: -50,
                  child: Opacity(opacity: 0.22, child: SarifioMark(size: 220, a: SC.blue, b: SC.teal)),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('quick_exchange'),
                          style: const TextStyle(color: SC.nightText2, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(s.t('hero_line'), style: display(26, color: Colors.white)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: SC.teal,
                              foregroundColor: const Color(0xFF04231E),
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            onPressed: () => HomeShell.of(context)?.go(1),
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: Text(s.t('exchange_now')),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(s.t('fee_flat', {'fee': fee}),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (app.configError != null) ...[
            const SizedBox(height: 14),
            AppCard(
              color: const Color(0xFFFBE7E8),
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, color: Color(0xFFA82E33)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(app.configError!,
                        style: const TextStyle(color: Color(0xFFA82E33), fontWeight: FontWeight.w700))),
                TextButton(onPressed: app.refreshConfig, child: Text(s.t('retry'))),
              ]),
            ),
          ],

          for (final a in app.config.announcements) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: SC.amberBg, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.campaign_outlined, color: SC.amberText, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.titleFor(app.language),
                            style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
                        const SizedBox(height: 3),
                        Text(a.bodyFor(app.language), style: TextStyle(color: p.text2, height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (user != null && user.kycStatus != 'verified') ...[
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.verified_user_outlined, color: p.text, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.t('kyc_title'), style: TextStyle(fontWeight: FontWeight.w800, color: p.text)),
                        const SizedBox(height: 3),
                        Text(s.t('kyc_body', {'limit': formatUsd(user.perTxLimitCents)}),
                            style: TextStyle(color: p.text2, height: 1.45, fontSize: 13.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          SectionHeader(s.t('payment_methods')),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: app.config.providers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final pr = app.config.providers[i];
                return Container(
                  width: 128,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProviderBadge(code: pr.code, label: pr.initials, size: 30),
                      const Spacer(),
                      Text(pr.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: p.text)),
                      Text(s.providerStatus(pr.status, app.config.testMode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: pr.usable ? SC.tealDark : p.text2, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          SectionHeader(
            s.t('recent_activity'),
            action: recent.isEmpty ? null : s.t('see_all'),
            onAction: () => HomeShell.of(context)?.go(2),
          ),
          if (app.txLoading && !app.txLoadedOnce)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (recent.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.swap_horiz_rounded,
                title: s.t('no_tx_title'),
                body: s.t('no_tx_body'),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    TxTile(tx: recent[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '•';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

/// One transaction row, used on Home and Activity.
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx});
  final Transaction tx;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(txId: tx.id, initial: tx))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            ProviderBadge(code: tx.from.code, label: _initialsFor(tx.from.code, tx.from.name), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tx.from.name} → ${tx.to.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: p.text)),
                  const SizedBox(height: 3),
                  Text(fmtDateTime(tx.createdAt), style: TextStyle(fontSize: 12.5, color: p.text2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoney(tx.amountCents, tx.currency),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: p.text,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 4),
                StatusChip(tx.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _initialsFor(String code, String name) => PaymentProvider(
          code: code, name: name, status: 'sandbox', canCollect: true, canPayout: true)
      .initials;
}
