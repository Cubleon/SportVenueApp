import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A light palette built on one accent.
///
/// Blue carries every action and nothing else, so a blue element on screen is
/// always something you can press. Everything structural is a neutral with a
/// slight blue bias, which keeps greys from reading as dirty next to the
/// accent. Status colours exist but are reserved for actual status — never for
/// decoration.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFFFFFFFF);
  static const bgAlt = Color(0xFFF7F9FC);

  /// Flat fill for cards, inputs and chips. Carries its own weight, so
  /// surfaces need neither a border nor a shadow to separate.
  static const surface = Color(0xFFF2F5F9);
  static const surfaceRaised = Color(0xFFE6EBF3);

  static const accent = Color(0xFF2979FF);
  static const accentPressed = Color(0xFF1B5FD9);

  /// Tinted accent fill, for a selected state that should not shout.
  static const accentSoft = Color(0xFFEAF1FF);

  /// Text and icons on top of [accent].
  static const onAccent = Color(0xFFFFFFFF);

  static const ink = Color(0xFF0D1421);
  static const muted = Color(0xFF5B6B85);
  static const dim = Color(0xFF8C9AB0);
  static const faint = Color(0xFFC6D0DE);
  static const border = Color(0xFFE4E9F1);

  static const success = Color(0xFF12A150);
  static const error = Color(0xFFE5484D);
  static const warning = Color(0xFFE8A317);
}

class AppTheme {
  const AppTheme._();

  static const systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  /// Bundled with the app, so text renders identically offline and on web —
  /// and unlike DM Sans it actually carries Cyrillic.
  static const fontFamily = 'Rubik';

  /// Corner radius shared by cards, buttons and fields, so nothing looks
  /// cut from a different sheet.
  static const radius = 18.0;

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.accent,
        surface: AppColors.bg,
        onSurface: AppColors.ink,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      splashColor: AppColors.accent.withValues(alpha: 0.10),
      highlightColor: AppColors.ink.withValues(alpha: 0.03),
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
          color: AppColors.ink,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      // Fields are a flat fill with no outline; focus is shown by the accent
      // alone, so an idle form has no boxes competing with the content.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.dim),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

extension TextThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
}
