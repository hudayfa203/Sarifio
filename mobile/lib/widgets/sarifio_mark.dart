import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The approved SARIFIO "Handover" mark, drawn from the master geometry
/// (64-unit grid, visual box 12..52). [progress] < 1 animates the two hooks
/// sliding in from opposite corners and locking together.
class SarifioMark extends StatelessWidget {
  const SarifioMark({
    super.key,
    this.size = 40,
    this.a = SC.ink,
    this.b = SC.blue,
    this.progress = 1,
  });

  const SarifioMark.reversed({super.key, this.size = 40, this.progress = 1})
      : a = Colors.white,
        b = SC.teal;

  final double size;
  final Color a;
  final Color b;
  final double progress;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(a, b, progress),
      );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.a, this.b, this.t);
  final Color a;
  final Color b;
  final double t;

  static Path hookA() => Path()
    ..moveTo(50, 12)
    ..lineTo(27, 12)
    ..arcToPoint(const Offset(12, 27), radius: const Radius.circular(15), clockwise: false)
    ..lineTo(12, 38)
    ..lineTo(24, 38)
    ..lineTo(24, 27)
    ..arcToPoint(const Offset(27, 24), radius: const Radius.circular(3), clockwise: true)
    ..lineTo(50, 24)
    ..close();

  static Path hookB() => Path()
    ..moveTo(14, 52)
    ..lineTo(37, 52)
    ..arcToPoint(const Offset(52, 37), radius: const Radius.circular(15), clockwise: false)
    ..lineTo(52, 26)
    ..lineTo(40, 26)
    ..lineTo(40, 37)
    ..arcToPoint(const Offset(37, 40), radius: const Radius.circular(3), clockwise: true)
    ..lineTo(14, 40)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40.0;
    final e = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final d = (1 - e) * 14; // travel in grid units
    final alpha = (255 * Curves.easeOut.transform(t.clamp(0.0, 1.0))).round();
    canvas.save();
    canvas.scale(s);
    canvas.translate(-12, -12);
    canvas.save();
    canvas.translate(-d, -d);
    canvas.drawPath(hookA(), Paint()..color = a.withAlpha(alpha));
    canvas.restore();
    canvas.save();
    canvas.translate(d, d);
    canvas.drawPath(hookB(), Paint()..color = b.withAlpha(alpha));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.t != t || old.a != a || old.b != b;
}

/// Mark + wordmark lockup.
class SarifioLockup extends StatelessWidget {
  const SarifioLockup({super.key, this.size = 28, this.reversed = false});
  final double size;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        reversed ? SarifioMark.reversed(size: size) : SarifioMark(size: size),
        SizedBox(width: size * 0.4),
        Text(
          'SARIFIO',
          style: TextStyle(
            fontFamily: kDisplay,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.62,
            letterSpacing: size * 0.62 * 0.14,
            color: reversed ? Colors.white : p.text,
          ),
        ),
      ],
    );
  }
}
