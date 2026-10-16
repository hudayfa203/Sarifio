import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../home/home_shell.dart';
import '../home/home_tab.dart';

class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  String _filter = 'all';

  bool _match(Transaction t) {
    switch (_filter) {
      case 'done':
        return t.status == TxStatus.settled;
      case 'progress':
        return !t.status.isFinal && t.status != TxStatus.manualReview;
      case 'issues':
        return t.status.isProblem;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final list = app.transactions.where(_match).toList();
    final filters = {
      'all': s.t('f_all'),
      'done': s.t('f_completed'),
      'progress': s.t('f_progress'),
      'issues': s.t('f_issues'),
    };

    return RefreshIndicator(
      onRefresh: app.loadTransactions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(s.t('nav_activity'), style: display(28, color: p.text)),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _filter == e.key,
                      onSelected: (_) => setState(() => _filter = e.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (app.txError != null)
            AppCard(
              child: Row(children: [
                Expanded(child: Text(app.txError!, style: TextStyle(color: p.text))),
                TextButton(onPressed: app.loadTransactions, child: Text(s.t('retry'))),
              ]),
            ),
          if (app.txLoading && !app.txLoadedOnce)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (list.isEmpty)
            EmptyState(
              icon: Icons.receipt_long_outlined,
              title: s.t('no_tx_title'),
              body: s.t('no_tx_body'),
              action: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
                onPressed: () => HomeShell.of(context)?.go(1),
                child: Text(s.t('exchange_now')),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: p.border),
                    TxTile(tx: list[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
