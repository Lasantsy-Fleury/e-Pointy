import 'package:flutter/material.dart';

/// Thème Material 3 pensé pour un usage sur le terrain :
/// texte et boutons assez grands, contraste suffisant.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00695C),
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.comfortable,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onPrimaryContainer,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 10,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    ),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(fontSize: 15),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ),
  );
}
