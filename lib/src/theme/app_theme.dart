import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A light palette in the shape of a menu app: a cool tinted page with pure
/// white cards floating on it, one indigo accent for actions, and neutrals
/// with a blue bias so nothing reads as dirty grey.
///
/// The tint matters more than it looks: white cards on a white page need
/// borders or shadows to separate, and those are exactly what this design
/// does without. Tinting the page does the same job with no ink at all.
class AppColors {
  const AppColors._();

  /// The page itself.
  static const bg = Color(0xFFEBF2F7);
  static const bgAlt = Color(0xFFF5F9FB);

  /// Cards, sheets and anything that floats on the page.
  static const surface = Color(0xFFFFFFFF);

  /// A step up from white, for controls that sit *on* a white card —
  /// icon buttons, steppers, inputs — where white on white would vanish.
  static const surfaceRaised = Color(0xFFF1F5F9);

  static const accent = Color(0xFF3D48F5);
  static const accentPressed = Color(0xFF2E38D4);
  static const accentSoft = Color(0xFFE8EAFE);

  /// The step you cannot take back: paying, or holding a slot. Dark rather
  /// than brighter, so it outranks the accent without competing with it —
  /// and so an accent button never sits next to it looking equally final.
  static const commit = Color(0xFF1E1A4D);

  /// Text and icons on top of [accent] or [commit].
  static const onAccent = Color(0xFFFFFFFF);

  // Contrast is measured against both grounds this palette uses, white cards
  // and the tinted page: ink 17.9:1 / 15.9:1, muted 5.3:1 / 4.7:1 — both
  // clear AA for body text. dim clears 3:1 only, so it is for icons, hints
  // and disabled marks, never for a sentence.
  static const ink = Color(0xFF15171C);
  static const muted = Color(0xFF616C7A);
  static const dim = Color(0xFF7E8A99);

  /// Hairlines and disabled marks only — it fails as text.
  static const faint = Color(0xFFD5DDE5);
  static const border = Color(0xFFE3EAF0);

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

  /// Cards and sheets. Generous, because a card here is a soft tile rather
  /// than a boxed panel.
  static const radius = 22.0;

  /// Controls inside a card: a little tighter than the card holding them.
  static const radiusInner = 14.0;

  /// Buttons and chips are pills, so their radius follows their height.
  static const pill = StadiumBorder();

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
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: AppColors.ink,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
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
