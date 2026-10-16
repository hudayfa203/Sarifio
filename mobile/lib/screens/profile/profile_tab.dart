import 'package:flutter/material.dart';

import '../../data/sandbox_api.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/register_screen.dart';
import 'legal_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  String _outcome = 'success';

  @override
  void initState() {
    super.initState();
    final api = AppScope.read(context).api;
    if (api is SandboxApi) _outcome = api.nextOutcome;
  }

  Future<void> _editProfile() async {
    final app = AppScope.read(context);
    final s = app.s;
    final user = app.user!;
    final name = TextEditingController(text: user.name);
    final email = TextEditingController(text: user.email ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, MediaQuery.of(context).viewInsets.bottom + 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('edit_profile'), style: display(22, color: Palette.of(context).text)),
            const SizedBox(height: 16),
            TextField(controller: name, decoration: InputDecoration(labelText: s.t('full_name'))),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: s.t('email_optional')),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('save'))),
          ],
        ),
      ),
    );
    if (saved == true) {
      try {
        final u = await app.api.updateMe(name: name.text.trim(), email: email.text.trim());
        app.updateUser(u);
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    name.dispose();
    email.dispose();
  }

  Future<void> _changeServer() async {
    final app = AppScope.read(context);
    final s = app.s;
    final ctrl = TextEditingController(text: app.serverUrl ?? 'https://');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('test_server')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.t('test_server_body'), style: const TextStyle(height: 1.45)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'https://staging-api.sarifio.com'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ''), child: Text(s.t('use_on_device'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(s.t('connect')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    if (result.isNotEmpty && !result.startsWith('https://')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('https_only'))));
      }
      return;
    }
    await app.setServer(result.isEmpty ? null : result);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen(login: true)),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    final app = AppScope.read(context);
    final s = app.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('logout_q')),
        content: Text(s.t('logout_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(s.t('logout'))),
        ],
      ),
    );
    if (ok != true) return;
    await app.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen(login: true)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final p = Palette.of(context);
    final user = app.user;
    if (user == null) return const SizedBox.shrink();

    Widget row(IconData icon, String title, {String? value, VoidCallback? onTap, Widget? trailing, Color? color}) =>
        ListTile(
          onTap: onTap,
          leading: Icon(icon, color: color ?? p.text),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? p.text)),
          subtitle: value == null ? null : Text(value, style: TextStyle(color: p.text2)),
          trailing: trailing ?? (onTap == null ? null : Icon(Icons.chevron_right_rounded, color: p.text2)),
        );

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(title.toUpperCase(),
                    style: TextStyle(color: p.text2, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              AppCard(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: children)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(s.t('nav_profile'), style: display(28, color: p.text)),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: SC.ink,
                child: Text(
                  user.name.isEmpty ? '•' : user.name.trim().substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.text)),
                    const SizedBox(height: 2),
                    Text(user.phone, style: TextStyle(color: p.text2)),
                    if (user.email != null && user.email!.isNotEmpty)
                      Text(user.email!, style: TextStyle(color: p.text2, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(tooltip: s.t('edit_profile'), onPressed: _editProfile, icon: const Icon(Icons.edit_outlined)),
            ],
          ),
        ),
        group(s.t('account'), [
          row(Icons.verified_user_outlined, s.t('verification'), value: s.kyc(user.kycStatus)),
          row(Icons.speed_rounded, s.t('limits'),
              value: s.t('limits_value', {
                'tx': _usd(user.perTxLimitCents),
                'day': _usd(user.dailyLimitCents),
              })),
          row(Icons.fingerprint_rounded, s.t('biometric'), value: s.t('coming_next')),
        ]),
        group(s.t('preferences'), [
          ListTile(
            leading: Icon(Icons.translate_rounded, color: p.text),
            title: Text(s.t('language'), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'so', label: Text('SO')),
              ],
              selected: {app.language},
              onSelectionChanged: (v) => app.setLanguage(v.first),
            ),
          ),
          ListTile(
            leading: Icon(Icons.dark_mode_outlined, color: p.text),
            title: Text(s.t('appearance'), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
            trailing: DropdownButton<ThemeMode>(
              value: app.themeMode,
              underline: const SizedBox.shrink(),
              onChanged: (m) {
                if (m != null) app.setThemeMode(m);
              },
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(s.t('theme_system'))),
                DropdownMenuItem(value: ThemeMode.light, child: Text(s.t('theme_light'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(s.t('theme_dark'))),
              ],
            ),
          ),
        ]),
        if (app.config.testMode)
          group(s.t('test_env'), [
            row(Icons.dns_outlined, s.t('test_server'),
                value: app.serverUrl ?? s.t('env_device_long'), onTap: _changeServer),
            ListTile(
              leading: Icon(Icons.tune_rounded, color: p.text),
              title: Text(s.t('next_outcome'), style: TextStyle(fontWeight: FontWeight.w700, color: p.text)),
              subtitle: Text(s.t('next_outcome_sub'), style: TextStyle(color: p.text2, fontSize: 12.5)),
              trailing: DropdownButton<String>(
                value: _outcome,
                underline: const SizedBox.shrink(),
                onChanged: (v) async {
                  if (v == null) return;
                  setState(() => _outcome = v);
                  try {
                    await app.api.setNextOutcome(v);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
                items: [
                  DropdownMenuItem(value: 'success', child: Text(s.t('o_success'))),
                  DropdownMenuItem(value: 'fail_payment', child: Text(s.t('o_fail_payment'))),
                  DropdownMenuItem(value: 'fail_payout', child: Text(s.t('o_fail_payout'))),
                  DropdownMenuItem(value: 'manual_review', child: Text(s.t('o_review'))),
                ],
              ),
            ),
            if (app.api.isOnDevice)
              row(Icons.restart_alt_rounded, s.t('reset_test'), onTap: () async {
                await app.api.resetTestData();
                await app.loadTransactions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('reset_done'))));
                }
              }),
          ]),
        group(s.t('legal'), [
          row(Icons.description_outlined, s.t('terms'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'terms')))),
          row(Icons.privacy_tip_outlined, s.t('privacy'),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LegalScreen(doc: 'privacy')))),
        ]),
        const SizedBox(height: 14),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row(Icons.logout_rounded, s.t('logout'), onTap: _logout, color: SC.danger, trailing: const SizedBox()),
        ),
        const SizedBox(height: 18),
        Center(
          child: Column(
            children: [
              themedMark(context, size: 22),
              const SizedBox(height: 8),
              Text('SARIFIO 0.1.0 (test build) · ${app.config.company.website}',
                  style: TextStyle(color: p.text2, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  static String _usd(int cents) {
    final d = cents ~/ 100;
    return '\$$d';
  }
}
