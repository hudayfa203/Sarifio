import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'sarifio_mark.dart';

/// Mark coloured for the current theme.
Widget themedMark(BuildContext context, {double size = 32}) =>
    Theme.of(context).brightness == Brightness.dark
        ? SarifioMark.reversed(size: size)
        : SarifioMark(size: size);

/// Persistent strip shown on every screen while running against test data.
class TestModeBanner extends StatelessWidget {
  const TestModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.config.testMode) return const SizedBox.shrink();
    final s = app.s;
    return Material(
      color: SC.amberBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, size: 16, color: SC.amberText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${s.t('test_mode')} · ${app.api.isOnDevice ? s.t('env_device') : s.t('env_staging')} · ${s.t('no_real_money')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: SC.amberText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scaffold with the Test Mode strip pinned on top.
class SarifioScaffold extends StatelessWidget {
  const SarifioScaffold({
    super.key,
    required this.body,
    this.title,
    this.bottomBar,
    this.showBack = true,
    this.actions,
  });

  final Widget body;
  final String? title;
  final Widget? bottomBar;
  final bool showBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      bottomNavigationBar: bottomBar,
      body: Column(
        children: [
          const TestModeBanner(),
          if (title != null)
            SafeArea(
              bottom: false,
              top: !AppScope.of(context).config.testMode,
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    if (showBack && Navigator.of(context).canPop())
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(Icons.arrow_back_rounded, color: p.text),
                      )
                    else
                      const SizedBox(width: 20),
                    Expanded(
                      child: Text(title!,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.text)),
                    ),
                    ...?actions,
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            )
          else if (!AppScope.of(context).config.testMode)
            const SafeArea(bottom: false, child: SizedBox.shrink()),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.onTap});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? p.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: color == null ? Border.all(color: p.border) : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({super.key, required this.code, required this.label, this.size = 38});
  final String code;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    switch (code) {
      case 'sahal':
      case 'evc_plus':
        bg = dark ? const Color(0xFF1C3360) : const Color(0xFFE7EEFF);
        fg = dark ? const Color(0xFF9DB7FF) : SC.blue;
        break;
      case 'ebirr':
      case 'mpesa':
        bg = dark ? const Color(0xFF2A2340) : const Color(0xFFF1ECFB);
        fg = dark ? const Color(0xFFC9B8F5) : const Color(0xFF5B3FA8);
        break;
      case 'edahab':
        bg = dark ? const Color(0xFF0E3B35) : const Color(0xFFE5F6F2);
        fg = dark ? const Color(0xFF5FD9C4) : SC.tealDark;
        break;
      default:
        bg = dark ? const Color(0xFF1E2D47) : const Color(0xFFEEF0F4);
        fg = dark ? Colors.white : SC.ink;
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.32)),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final TxStatus status;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    Color bg;
    Color fg;
    switch (status) {
      case TxStatus.settled:
        bg = const Color(0xFFE7F7F3);
        fg = SC.tealDark;
        break;
      case TxStatus.failed:
      case TxStatus.cancelled:
        bg = const Color(0xFFFBE7E8);
        fg = const Color(0xFFA82E33);
        break;
      case TxStatus.refunded:
        bg = const Color(0xFFEEF0F4);
        fg = SC.text3;
        break;
      default:
        bg = SC.amberBg;
        fg = SC.amberText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(s.status(status),
          style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class KV extends StatelessWidget {
  const KV(this.label, this.value, {super.key, this.bold = false, this.valueColor, this.mono = false});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: bold ? p.text : p.text2,
                    fontSize: bold ? 15.5 : 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? p.text,
                fontSize: bold ? 15.5 : 14,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                fontFamily: mono ? 'monospace' : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
              child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.text))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: p.text2, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: p.text)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: p.text2, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Primary button with a built-in busy state.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (icon != null) ...[const SizedBox(width: 10), Icon(icon, size: 20, color: SC.teal)],
              ],
            ),
    );
  }
}

void showError(BuildContext context, Object e) {
  final s = AppScope.read(context).s;
  final msg = e is ApiException ? s.error(e) : s.t('err_generic');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

String fmtDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year} · ${two(d.hour)}:${two(d.minute)}';
}

S strings(BuildContext context) => AppScope.of(context).s;
