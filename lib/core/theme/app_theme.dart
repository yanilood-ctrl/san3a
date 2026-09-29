import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // ── Light ─────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF000000);
  static const primaryDark = Color(0xFF000000); // Added primaryDark
  static const primaryLight = Color(0xFF1A1A1A);
  static const accent = Color(0xFF06C167);
  static const accentDark = Color(0xFF04A055);
  static const background = Color(0xFFF6F6F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F0F0);
  static const textPrimary = Color(0xFF000000);
  static const textSecondary = Color(0xFF767676);
  static const textHint = Color(0xFFB0B0B0);
  static const border = Color(0xFFE5E5E5);
  static const divider = Color(0xFFF0F0F0);
  static const success = Color(0xFF06C167);
  static const warning = Color(0xFFFF6D00);
  static const error = Color(0xFFE03131);
  static const cardShadow = Color(0x0F000000);
  static const cardShadowMd = Color(0x18000000);

  // ── Dark ──────────────────────────────────────────────────────────────────
  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkSurfaceVariant = Color(0xFF2A2A2A);
  static const darkPrimary = Color(0xFFFFFFFF);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF9E9E9E);
  static const darkBorder = Color(0xFF2E2E2E);
  static const darkDivider = Color(0xFF252525);
  static const darkCardShadow = Color(0x40000000);

  // ── Roles ─────────────────────────────────────────────────────────────────
  static const professional = Color(0xFF235347); // Green system primary
  static const contractor = Color(0xFF7C3AED);
  static const adminRed = Color(0xFFDC2626);
}

// ── Professional Green Palette ────────────────────────────────────────────────
class AppGreen {
  /// Darkest — headers, gradient start, deep backgrounds
  static const darkest = Color(0xFF051F20);

  /// Dark — gradient end, nav bar, primary buttons
  static const dark = Color(0xFF0B2B26);

  /// Mid-dark — card accents, focused borders
  static const midDark = Color(0xFF163832);

  /// Mid — primary action color, active states
  static const mid = Color(0xFF235347);

  /// Light — highlights, chips, soft borders, badges
  static const light = Color(0xFF8EB69B);

  /// Lightest — card backgrounds, page background tint
  static const lightest = Color(0xFFDAF1DE);

  // Convenience aliases used across Professional screens
  static const surface = Color(0xFFDAF1DE); // card bg
  static const surfaceCard =
      Color(0xFFF0FAF2); // slightly off-white with green tint
  static const border = Color(0xFF8EB69B);
  static const titleText = Color(0xFF051F20);
  static const secondaryText = Color(0xFF235347);
  static const hintText = Color(0xFF8EB69B);
}

class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final primary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final txtPri = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final txtSec =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final brd = isDark ? AppColors.darkBorder : AppColors.border;
    final onPri = isDark ? Colors.black : Colors.white;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPri,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        background: bg,
        onBackground: txtPri,
        surface: surface,
        onSurface: txtPri,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
        foregroundColor: txtPri,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: txtPri,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: txtPri),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPri,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
              fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.accent : primary,
          textStyle: const TextStyle(
              fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: brd, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: brd, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle:
            TextStyle(color: txtSec, fontSize: 15, fontFamily: 'Tajawal'),
        labelStyle: TextStyle(color: txtSec, fontFamily: 'Tajawal'),
        errorStyle: const TextStyle(
            color: AppColors.error, fontSize: 12, fontFamily: 'Tajawal'),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: brd, width: 1),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: txtSec,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
            fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
            fontFamily: 'Tajawal', fontWeight: FontWeight.w500, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : Colors.white,
          fontFamily: 'Tajawal',
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        selectedItemColor: primary,
        unselectedItemColor: txtSec,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}

// ── Admin Lilac Palette ────────────────────────────────────────────────────────
// Anchored on the brand pair: Dark Lilac #72348A / Light Lilac #F5D2EF.
// `dark` and `lightest` are the two brand colors verbatim; the rest are
// interpolated shades/tints in the same hue family so every Admin surface
// reads as one coordinated system.
class AppAdmin {
  static const darkest =
      Color(0xFF321143); // header gradient start, deepest titles
  static const dark =
      Color(0xFF72348A); // BRAND: header end, primary buttons, CTA
  static const mid = Color(0xFFA463B8); // secondary accents, mid-tone borders
  static const accent = Color(0xFF9B3FA8); // highlights, badges, action accents
  static const lightest =
      Color(0xFFF5D2EF); // BRAND: card bg tint, soft surfaces
  static const warm = Color(0xFFFBF1FA); // page background

  // Structural "ink" scale — replaces the old ad-hoc indigo/violet-gray
  // neutrals (text, borders, card backgrounds) with a Lilac-tinted scale so
  // structural chrome matches the brand instead of reading as a separate
  // grayscale theme.
  static const inkDarkest =
      Color(0xFF2B1332); // primary dark text/titles on light bg
  static const inkDark = Color(0xFF4A2B55); // secondary dark text, dense icons
  static const inkMid = Color(0xFF7C5C87); // secondary/tertiary text, icons
  static const inkLight =
      Color(0xFFAF95B8); // hint text, disabled, tertiary icons
  static const borderSoft = Color(0xFFD9C2DC); // hairline borders, dividers
  static const surfaceTint = Color(0xFFF3E6F2); // card/chip backgrounds
}
