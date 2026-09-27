import 'package:flutter/material.dart';

/// Shared visual theme so all four apps look consistent.
///
/// Colors are sampled from the real SSD Farm (Shree Shyam Dairy Farm) logo
/// (`docs/branding/logo_original.jpg`) — see `docs/DESIGN_SYSTEM.md` for the
/// full palette, spacing scale and component patterns this theme
/// implements, and PROJECT_STATUS.md's Phase 8 entry for how each color was
/// originally picked. Built in Phase 1; re-branded with the real logo's
/// palette and given a full component theme (AppBar, Card, buttons, inputs,
/// chips) in the post-launch UI polish pass.
class AppTheme {
  /// The logo's outer ring and banner text — primary brand color.
  static const Color brandNavy = Color(0xFF1F425B);

  /// The logo's wheat-sheaf gold — secondary accent.
  static const Color brandGold = Color(0xFFC79A45);

  /// The logo's field green — tertiary accent (also reused by several
  /// screens for a "delivered / approved / success" status color).
  static const Color brandGreen = Color(0xFF6B8E4E);

  /// The logo's cream background — the app's scaffold background and splash
  /// screens, so the brand's warmth carries through even plain list screens.
  static const Color brandCream = Color(0xFFFBF6E8);

  /// A slightly deeper cream than [brandCream], for surfaces that sit on top
  /// of it (cards, dialogs) and need to read as a distinct layer.
  static const Color surfaceCream = Color(0xFFFFFDF8);

  static final ColorScheme _colorScheme = ColorScheme.fromSeed(
    seedColor: brandNavy,
  ).copyWith(
    secondary: brandGold,
    onSecondary: Colors.white,
    tertiary: brandGreen,
    onTertiary: Colors.white,
    surface: surfaceCream,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: brandCream,
    visualDensity: VisualDensity.standard,

    appBarTheme: AppBarTheme(
      backgroundColor: brandNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),

    cardTheme: CardThemeData(
      color: surfaceCream,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: _colorScheme.outlineVariant.withValues(alpha: 0.6),
      thickness: 1,
      space: 24,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: brandNavy.withValues(alpha: 0.06),
      selectedColor: brandNavy,
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      side: BorderSide(color: _colorScheme.outlineVariant),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: BorderSide(color: brandNavy.withValues(alpha: 0.5)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceCream,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: brandNavy, width: 2),
      ),
    ),

    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brandNavy,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: surfaceCream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surfaceCream,
      selectedIconTheme: IconThemeData(color: brandNavy),
      selectedLabelTextStyle: TextStyle(color: brandNavy, fontWeight: FontWeight.w600),
      indicatorColor: brandGold.withValues(alpha: 0.25),
    ),
  );
}

/// A small, consistent spacing scale — used by [AppTheme] itself and by
/// screens that lay out their own padding/gaps, so spacing reads as
/// intentional rather than ad hoc. See `docs/DESIGN_SYSTEM.md`.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
