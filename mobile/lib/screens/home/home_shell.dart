import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../widgets/common.dart';
import '../activity/activity_tab.dart';
import '../exchange/exchange_tab.dart';
import '../profile/profile_tab.dart';
import '../support/support_tab.dart';
import 'home_tab.dart';

/// Home | Exchange | Activity | Support | Profile
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();

  static HomeShellState? of(BuildContext context) => context.findAncestorStateOfType<HomeShellState>();
}

class HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).loadTransactions();
    });
  }

  void go(int i) {
    setState(() => index = i);
    if (i == 0 || i == 2) AppScope.read(context).loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return SarifioScaffold(
      bottomBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.t('nav_home')),
          NavigationDestination(
              icon: const Icon(Icons.swap_horiz_rounded),
              selectedIcon: const Icon(Icons.swap_horiz_rounded),
              label: s.t('nav_exchange')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: s.t('nav_activity')),
          NavigationDestination(
              icon: const Icon(Icons.support_agent_outlined),
              selectedIcon: const Icon(Icons.support_agent_rounded),
              label: s.t('nav_support')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: s.t('nav_profile')),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [
          HomeTab(),
          ExchangeTab(),
          ActivityTab(),
          SupportTab(),
          ProfileTab(),
        ],
      ),
    );
  }
}
