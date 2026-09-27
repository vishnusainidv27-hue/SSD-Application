import 'package:flutter/material.dart';

/// Shared visual theme so all four apps look consistent.
///
/// Colors are sampled from the real SSD Farm (Shree Shyam Dairy Farm) logo
/// (`docs/branding/logo.png`) — see docs/PROJECT_STATUS.md's Phase 8 entry
/// for exactly how each value was picked. Built in Phase 1; re-branded with
/// the real logo's palette in Phase 8 (a placeholder milk-drop glyph/navy
/// used the same role until the logo was supplied).
class AppTheme {
  /// The logo's outer ring and banner text — primary brand color.
  static const Color brandNavy = Color(0xFF1F425B);

  /// The logo's wheat-sheaf gold — secondary accent.
  static const Color brandGold = Color(0xFFC79A45);

  /// The logo's field green — tertiary accent (also reused by several
  /// screens for a "delivered / approved / success" status color).
  static const Color brandGreen = Color(0xFF6B8E4E);

  /// The logo's cream background — used for splash screens and light
  /// surfaces that want to read as "branded" rather than plain white.
  static const Color brandCream = Color(0xFFFBF6E8);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: brandNavy).copyWith(
      secondary: brandGold,
      onSecondary: Colors.white,
      tertiary: brandGreen,
      onTertiary: Colors.white,
    ),
  );
}
