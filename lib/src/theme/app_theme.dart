import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  const AppColors._();

  static const bg = Color(0xFF0A0F1E);
  static const bgAlt = Color(0xFF0D1220);
  static const surface = Color(0xFF141C2F);
  static const surfaceRaised = Color(0xFF1A2540);
  static const accent = Color(0xFF2979FF);
  static const accentPressed = Color(0xFF1565C0);
  static const success = Color(0xFF00E676);
  static const error = Color(0xFFFF5252);
  static const warning = Color(0xFFFFD740);
  static const white = Color(0xFFFFFFFF);
  static const muted = Color(0x99FFFFFF);
  static const dim = Color(0x66FFFFFF);
  static const faint = Color(0x33FFFFFF);
  static const border = Color(0x14FFFFFF);
}

class AppTheme {
  const AppTheme._();

  static const systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  /// Bundled with the app, so text renders identically offline and on web —
  /// and unlike DM Sans it actually carries Cyrillic.
  static const fontFamily = 'Rubik';

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.white,
      displayColor: AppColors.white,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.success,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      splashColor: AppColors.accent.withValues(alpha: 0.12),
      highlightColor: AppColors.white.withValues(alpha: 0.04),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.white,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.faint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

extension TextThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
