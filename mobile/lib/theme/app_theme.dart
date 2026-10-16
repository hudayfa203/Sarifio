import 'package:flutter/material.dart';

/// SARIFIO brand tokens (see the brand guidelines board).
class SC {
  SC._();
  static const ink = Color(0xFF0B1B33);
  static const blue = Color(0xFF2458F2);
  static const teal = Color(0xFF14B8A0);
  static const tealDark = Color(0xFF0C6B5C);
  static const mist = Color(0xFFF4F6F9);
  static const surface = Color(0xFFFFFFFF);
  static const text2 = Color(0xFF55657E);
  static const text3 = Color(0xFF3E4C63);
  static const border = Color(0xFFDFE5EE);
  static const night = Color(0xFF070F1E);
  static const nightSurface = Color(0xFF0F1C31);
  static const nightBorder = Color(0xFF1E2D47);
  static const nightText2 = Color(0xFF9FB0C8);
  static const success = Color(0xFF138A5B);
  static const warning = Color(0xFFB7791F);
  static const danger = Color(0xFFD64045);
  static const amberBg = Color(0xFFFBF1E2);
  static const amberText = Color(0xFF8A5A12);
}

/// Colours that change with light/dark mode.
class Palette {
  const Palette({
    required this.bg,
    required this.card,
    required this.border,
    required this.text,
    required this.text2,
    required this.chip,
    required this.hero,
  });
  final Color bg;
  final Color card;
  final Color border;
  final Color text;
  final Color text2;
  final Color chip;
  final Color hero;

  static const light = Palette(
    bg: SC.mist,
    card: SC.surface,
    border: SC.border,
    text: SC.ink,
    text2: SC.text2,
    chip: Color(0xFFEEF2F7),
    hero: SC.ink,
  );
  static const dark = Palette(
    bg: SC.night,
    card: SC.nightSurface,
    border: SC.nightBorder,
    text: Color(0xFFF2F5FA),
    text2: SC.nightText2,
    chip: Color(0xFF16253D),
    hero: Color(0xFF12295A),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

const kDisplay = 'Sora';
const kBody = 'Manrope';

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final p = dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme(
    brightness: b,
    primary: dark ? const Color(0xFF5B85FF) : SC.blue,
    onPrimary: Colors.white,
    secondary: SC.teal,
    onSecondary: SC.ink,
    error: SC.danger,
    onError: Colors.white,
    surface: p.card,
    onSurface: p.text,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: kBody,
    scaffoldBackgroundColor: p.bg,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    dividerColor: p.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: p.text2, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: p.text2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SC.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: SC.danger, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Colors.white : SC.ink,
        foregroundColor: dark ? SC.ink : Colors.white,
        disabledBackgroundColor: p.chip,
        disabledForegroundColor: p.text2,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: kBody, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: p.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: kBody, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontFamily: kBody, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      indicatorColor: dark ? const Color(0xFF1C3360) : const Color(0xFFE7EEFF),
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: kBody,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? p.text : p.text2,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.text : p.text2,
            size: 24,
          )),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w600}) => TextStyle(
      fontFamily: kDisplay,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.02 * size,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
