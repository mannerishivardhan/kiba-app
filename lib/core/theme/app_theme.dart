import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Kiba Brand Palette ────────────────────────────────────────────────────────
class KibaColors {
  KibaColors._();

  // Primary – deep indigo
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primarySurface = Color(0xFFEEF2FF);

  // Accent – amber
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFCD34D);
  static const Color accentSurface = Color(0xFFFFFBEB);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color successSurface = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSurface = Color(0xFFDBEAFE);

  // Neutral
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // Background
  static const Color bgLight = Color(0xFFF9FAFB);
  static const Color bgDark = Color(0xFF0F1117);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A1D27);
  static const Color cardDark = Color(0xFF242736);
}

// ── Text Styles ───────────────────────────────────────────────────────────────
class KibaTextStyles {
  KibaTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      );
}

// ── Theme ─────────────────────────────────────────────────────────────────────
class KibaTheme {
  KibaTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KibaColors.primary,
        brightness: Brightness.light,
        primary: KibaColors.primary,
        secondary: KibaColors.accent,
        surface: KibaColors.surfaceLight,
        error: KibaColors.error,
      ),
      scaffoldBackgroundColor: KibaColors.bgLight,
      textTheme: _buildTextTheme(Colors.black),
      appBarTheme: AppBarTheme(
        backgroundColor: KibaColors.surfaceLight,
        foregroundColor: KibaColors.grey900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: KibaTextStyles.headlineSmall.copyWith(
          color: KibaColors.grey900,
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
      cardTheme: CardThemeData(
        color: KibaColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KibaColors.grey200),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: KibaColors.surfaceLight,
        selectedItemColor: KibaColors.primary,
        unselectedItemColor: KibaColors.grey400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: KibaColors.grey200,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KibaColors.grey100,
        labelStyle: KibaTextStyles.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      extensions: const [KibaColorExtension.light],
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KibaColors.primary,
        brightness: Brightness.dark,
        primary: KibaColors.primaryLight,
        secondary: KibaColors.accentLight,
        surface: KibaColors.surfaceDark,
        error: KibaColors.error,
      ),
      scaffoldBackgroundColor: KibaColors.bgDark,
      textTheme: _buildTextTheme(Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: KibaColors.surfaceDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: KibaTextStyles.headlineSmall.copyWith(
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(isDark: true),
      textButtonTheme: _textButtonTheme(isDark: true),
      inputDecorationTheme: _inputDecorationTheme(isDark: true),
      cardTheme: CardThemeData(
        color: KibaColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: KibaColors.surfaceDark,
        selectedItemColor: KibaColors.primaryLight,
        unselectedItemColor: KibaColors.grey500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: KibaColors.cardDark,
        labelStyle: KibaTextStyles.labelSmall.copyWith(color: Colors.white70),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      extensions: const [KibaColorExtension.dark],
    );
  }

  // ── Field Advisor Theme — Emerald Green ────────────────────────────────────
  static ThemeData get fieldAdvisor {
    const primary = Color(0xFF059669);      // Emerald 600
    const onPrimary = Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: const Color(0xFFF59E0B),
        surface: KibaColors.surfaceLight,
        error: KibaColors.error,
        onPrimary: onPrimary,
      ),
      scaffoldBackgroundColor: KibaColors.bgLight,
      textTheme: _buildTextTheme(Colors.black),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KibaColors.surfaceLight,
        indicatorColor: primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: KibaColors.grey400);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KibaTextStyles.labelSmall.copyWith(color: primary);
          }
          return KibaTextStyles.labelSmall.copyWith(color: KibaColors.grey400);
        }),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(primary: primary),
      cardTheme: CardThemeData(
        color: KibaColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KibaColors.grey200),
        ),
        margin: EdgeInsets.zero,
      ),
      extensions: const [KibaColorExtension.light],
    );
  }

  // ── Clerk Theme — Sky Blue ─────────────────────────────────────────────────
  static ThemeData get clerk {
    const primary = Color(0xFF2563EB);      // Blue 600
    const onPrimary = Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: const Color(0xFF0EA5E9),
        surface: KibaColors.surfaceLight,
        error: KibaColors.error,
        onPrimary: onPrimary,
      ),
      scaffoldBackgroundColor: KibaColors.bgLight,
      textTheme: _buildTextTheme(Colors.black),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KibaColors.surfaceLight,
        indicatorColor: primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: KibaColors.grey400);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KibaTextStyles.labelSmall.copyWith(color: primary);
          }
          return KibaTextStyles.labelSmall.copyWith(color: KibaColors.grey400);
        }),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(primary: primary),
      cardTheme: CardThemeData(
        color: KibaColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KibaColors.grey200),
        ),
        margin: EdgeInsets.zero,
      ),
      extensions: const [KibaColorExtension.light],
    );
  }

  // ── Admin Theme — Deep Indigo / Purple ────────────────────────────────────
  static ThemeData get admin {
    const primary = Color(0xFF4F46E5);       // Indigo 600
    const onPrimary = Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: const Color(0xFF7C3AED),  // Violet
        surface: KibaColors.surfaceLight,
        error: KibaColors.error,
        onPrimary: onPrimary,
      ),
      scaffoldBackgroundColor: KibaColors.bgLight,
      textTheme: _buildTextTheme(Colors.black),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KibaColors.surfaceLight,
        indicatorColor: primary.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primary);
          }
          return IconThemeData(color: KibaColors.grey400);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KibaTextStyles.labelSmall.copyWith(color: primary);
          }
          return KibaTextStyles.labelSmall.copyWith(color: KibaColors.grey400);
        }),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(primary: primary),
      cardTheme: CardThemeData(
        color: KibaColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KibaColors.grey200),
        ),
        margin: EdgeInsets.zero,
      ),
      extensions: const [KibaColorExtension.light],
    );
  }


  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: KibaTextStyles.displayLarge.copyWith(color: color),
      displayMedium: KibaTextStyles.displayMedium.copyWith(color: color),
      headlineLarge: KibaTextStyles.headlineLarge.copyWith(color: color),
      headlineMedium: KibaTextStyles.headlineMedium.copyWith(color: color),
      headlineSmall: KibaTextStyles.headlineSmall.copyWith(color: color),
      titleLarge: KibaTextStyles.titleLarge.copyWith(color: color),
      titleMedium: KibaTextStyles.titleMedium.copyWith(color: color),
      bodyLarge: KibaTextStyles.bodyLarge.copyWith(color: color),
      bodyMedium: KibaTextStyles.bodyMedium.copyWith(color: color),
      bodySmall: KibaTextStyles.bodySmall.copyWith(color: color),
      labelLarge: KibaTextStyles.labelLarge.copyWith(color: color),
      labelSmall: KibaTextStyles.labelSmall.copyWith(color: color),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme({Color? primary}) {
    final bg = primary ?? KibaColors.primary;
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: KibaTextStyles.labelLarge,
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme({bool isDark = false}) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white : KibaColors.primary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: isDark ? Colors.white24 : KibaColors.primary,
        ),
        textStyle: KibaTextStyles.labelLarge,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme({bool isDark = false}) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? KibaColors.primaryLight : KibaColors.primary,
        textStyle: KibaTextStyles.labelLarge,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? KibaColors.cardDark : KibaColors.grey50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : KibaColors.grey200,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white12 : KibaColors.grey200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KibaColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KibaColors.error),
      ),
      labelStyle: KibaTextStyles.bodyMedium.copyWith(
        color: isDark ? Colors.white60 : KibaColors.grey500,
      ),
      hintStyle: KibaTextStyles.bodyMedium.copyWith(
        color: isDark ? Colors.white38 : KibaColors.grey400,
      ),
    );
  }
}

// ── Theme Extension ───────────────────────────────────────────────────────────
@immutable
class KibaColorExtension extends ThemeExtension<KibaColorExtension> {
  const KibaColorExtension({
    required this.success,
    required this.successSurface,
    required this.warning,
    required this.warningSurface,
    required this.info,
    required this.infoSurface,
    required this.cardSurface,
    required this.divider,
  });

  final Color success;
  final Color successSurface;
  final Color warning;
  final Color warningSurface;
  final Color info;
  final Color infoSurface;
  final Color cardSurface;
  final Color divider;

  static const light = KibaColorExtension(
    success: KibaColors.success,
    successSurface: KibaColors.successSurface,
    warning: KibaColors.warning,
    warningSurface: KibaColors.warningSurface,
    info: KibaColors.info,
    infoSurface: KibaColors.infoSurface,
    cardSurface: KibaColors.surfaceLight,
    divider: KibaColors.grey200,
  );

  static const dark = KibaColorExtension(
    success: KibaColors.success,
    successSurface: Color(0xFF064E3B),
    warning: KibaColors.warning,
    warningSurface: Color(0xFF451A03),
    info: KibaColors.info,
    infoSurface: Color(0xFF1E3A5F),
    cardSurface: KibaColors.cardDark,
    divider: Color(0xFF2A2D3E),
  );

  @override
  KibaColorExtension copyWith({
    Color? success,
    Color? successSurface,
    Color? warning,
    Color? warningSurface,
    Color? info,
    Color? infoSurface,
    Color? cardSurface,
    Color? divider,
  }) {
    return KibaColorExtension(
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      info: info ?? this.info,
      infoSurface: infoSurface ?? this.infoSurface,
      cardSurface: cardSurface ?? this.cardSurface,
      divider: divider ?? this.divider,
    );
  }

  @override
  KibaColorExtension lerp(KibaColorExtension? other, double t) {
    if (other is! KibaColorExtension) return this;
    return KibaColorExtension(
      success: Color.lerp(success, other.success, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSurface: Color.lerp(infoSurface, other.infoSurface, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
