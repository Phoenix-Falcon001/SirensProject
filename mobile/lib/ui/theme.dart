import 'package:flutter/material.dart';

/// The same look as the web console: navy header with an amber line under
/// it, a cool grey-green background, white panels with a thin outline, and
/// amber only where something needs attention.
abstract final class SirensColors {
  static const ink = Color(0xFF16202B);
  static const inkSoft = Color(0xFF3A4652);
  static const muted = Color(0xFF66737D);
  static const line = Color(0xFFE2E6E3);
  static const surface = Color(0xFFF4F6F3);
  static const panel = Color(0xFFFFFFFF);
  static const signal = Color(0xFFB5761F);
  static const signalSoft = Color(0xFFF3E7D3);
  static const strong = Color(0xFF1F7A4D);
  static const strongSoft = Color(0xFFE7F2EC);
  static const danger = Color(0xFFA3312A);
  static const dangerSoft = Color(0xFFFBECEB);
}

ThemeData sirensTheme() {
  const c = SirensColors.ink;
  final scheme = ColorScheme.fromSeed(seedColor: c).copyWith(
    primary: SirensColors.ink,
    onPrimary: Colors.white,
    primaryContainer: SirensColors.signalSoft,
    onPrimaryContainer: const Color(0xFF7A4E12),
    secondary: SirensColors.signal,
    onSecondary: Colors.white,
    secondaryContainer: SirensColors.strongSoft,
    onSecondaryContainer: SirensColors.strong,
    tertiaryContainer: SirensColors.signalSoft,
    onTertiaryContainer: const Color(0xFF7A4E12),
    error: SirensColors.danger,
    errorContainer: SirensColors.dangerSoft,
    onErrorContainer: const Color(0xFF6E221D),
    surface: SirensColors.panel,
    onSurface: SirensColors.ink,
    onSurfaceVariant: SirensColors.inkSoft,
    surfaceContainerHighest: SirensColors.surface,
    outline: const Color(0xFF9AA6AD),
    outlineVariant: SirensColors.line,
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SirensColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: SirensColors.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: SirensColors.signal, width: 3)),
    ),
    cardTheme: CardThemeData(
      color: SirensColors.panel,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: SirensColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        foregroundColor: SirensColors.ink,
        side: const BorderSide(color: Color(0xFFCFD6D3)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SirensColors.panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCFD6D3)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: SirensColors.panel,
      side: const BorderSide(color: SirensColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    dividerTheme: const DividerThemeData(color: SirensColors.line),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Dark variant for phones set to dark mode: the same navy and amber.
ThemeData sirensDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SirensColors.ink,
    brightness: Brightness.dark,
  ).copyWith(secondary: const Color(0xFFE0A85A));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: SirensColors.ink,
      foregroundColor: Colors.white,
      shape: Border(bottom: BorderSide(color: SirensColors.signal, width: 3)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
