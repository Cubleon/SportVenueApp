import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's colours, in the shape of a menu app: a tinted page with cards
/// floating on it, one indigo accent for actions, and neutrals with a blue
/// bias so nothing reads as dirty grey.
///
/// The tint matters more than it looks. Cards the same colour as the page
/// need borders or shadows to separate, and those are exactly what this
/// design does without; tinting the page does the same job with no ink at
/// all. That holds in both themes — the card is always a step towards the
/// reader, lighter on a light page and lighter again on a dark one.
///
/// This is a [ThemeExtension] rather than a bag of constants so the second
/// theme is the same code with different numbers. Widgets read it through
/// `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.bgAlt,
    required this.surface,
    required this.surfaceRaised,
    required this.accent,
    required this.accentPressed,
    required this.accentSoft,
    required this.commit,
    required this.onAccent,
    required this.onCommit,
    required this.ink,
    required this.muted,
    required this.dim,
    required this.faint,
    required this.border,
    required this.success,
    required this.error,
    required this.danger,
    required this.onDanger,
    required this.warning,
  });

  final Brightness brightness;

  /// The page itself.
  final Color bg;
  final Color bgAlt;

  /// Cards, sheets and anything that floats on the page.
  final Color surface;

  /// A step away from [surface], for controls that sit *on* a card — icon
  /// buttons, steppers, inputs — where card-on-card would vanish.
  final Color surfaceRaised;

  final Color accent;
  final Color accentPressed;
  final Color accentSoft;

  /// The step you cannot take back: paying, or holding a slot. It is the
  /// highest-contrast thing on the page in either theme — near-black on the
  /// light one, near-white on the dark one — so it outranks the accent
  /// without competing with it, and an accent button never sits beside it
  /// looking equally final.
  final Color commit;

  /// Text and icons on top of [accent] and [commit]. They differ: the light
  /// theme fills with a deep indigo and writes on it in white, the dark one
  /// fills with a pale indigo and writes in near-black, which is the only
  /// way either fill clears AA against its own label.
  final Color onAccent;
  final Color onCommit;

  final Color ink;
  final Color muted;
  final Color dim;

  /// Hairlines and disabled marks only — it fails as text.
  final Color faint;
  final Color border;

  final Color success;

  /// Text and hairlines that report a problem: a rejected field, a message
  /// that something failed. It has to read *on* the page.
  final Color error;

  /// The fill under a button that destroys something, with [onDanger] on
  /// top of it. A fill carries a label, which is a different job from
  /// being legible as text, so in the light theme it is a deeper red than
  /// [error] — the lighter one cannot hold white.
  final Color danger;
  final Color onDanger;

  final Color warning;

  /// Contrast, measured against both grounds this palette uses — cards and
  /// the tinted page: ink 17.9:1 / 15.9:1, muted 5.3:1 / 4.7:1, both clear
  /// AA for body text. dim clears 3:1 only, so it is for icons, hints and
  /// disabled marks, never for a sentence.
  static const light = AppColors(
    brightness: Brightness.light,
    bg: Color(0xFFEBF2F7),
    bgAlt: Color(0xFFF5F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F5F9),
    accent: Color(0xFF3D48F5),
    accentPressed: Color(0xFF2E38D4),
    accentSoft: Color(0xFFE8EAFE),
    commit: Color(0xFF1E1A4D),
    onAccent: Color(0xFFFFFFFF),
    onCommit: Color(0xFFFFFFFF),
    ink: Color(0xFF15171C),
    muted: Color(0xFF616C7A),
    dim: Color(0xFF7E8A99),
    faint: Color(0xFFD5DDE5),
    border: Color(0xFFE3EAF0),
    success: Color(0xFF12A150),
    error: Color(0xFFE5484D),
    danger: Color(0xFFCE2C31),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFFE8A317),
  );

  /// The same palette read in the dark: ink 16.4:1 on the page and 14.4:1 on
  /// a card, muted 7.6 / 6.7, dim 5.2 / 4.5. The accent had to move — the
  /// light theme's indigo cannot both carry white text and be legible as
  /// text on a dark page, so the dark theme lightens the fill and writes on
  /// it in near-black: 5.7:1 on the button, 5.9:1 as a link on the page.
  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: Color(0xFF0F131A),
    bgAlt: Color(0xFF151A23),
    surface: Color(0xFF1A202B),
    surfaceRaised: Color(0xFF232A37),
    accent: Color(0xFF7A86FF),
    accentPressed: Color(0xFF9AA3FF),
    accentSoft: Color(0xFF1E2440),
    commit: Color(0xFFE9ECFF),
    onAccent: Color(0xFF121627),
    onCommit: Color(0xFF12141F),
    ink: Color(0xFFEDF1F7),
    muted: Color(0xFF9BA7B8),
    dim: Color(0xFF7C8899),
    faint: Color(0xFF333C4A),
    border: Color(0xFF262E3B),
    success: Color(0xFF2ECC71),
    error: Color(0xFFFF6B6B),
    // On a dark page the same red carries a label at 6.5:1, so the two
    // jobs need only one colour here.
    danger: Color(0xFFFF6B6B),
    onDanger: Color(0xFF121627),
    warning: Color(0xFFF0B429),
  );

  bool get isDark => brightness == Brightness.dark;

  @override
  AppColors copyWith() => this;

  /// The two palettes are not interpolated: a theme switch swaps them at the
  /// halfway point rather than dragging every colour through mud.
  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

class AppTheme {
  const AppTheme._();

  static SystemUiOverlayStyle overlayStyle(AppColors colors) {
    final iconsOnDark = colors.isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconsOnDark,
      statusBarBrightness: colors.brightness,
      systemNavigationBarColor: colors.bg,
      systemNavigationBarIconBrightness: iconsOnDark,
    );
  }

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

  /// The floating tab bar at its unscaled height. Screens that scroll under
  /// it read this through [ScaledMetricsX.bottomBarInset].
  static const tabBarHeight = 64.0;

  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors colors) {
    final base = colors.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );

    return base.copyWith(
      extensions: [colors],
      scaffoldBackgroundColor: colors.bg,
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.accent,
        onSecondary: colors.onAccent,
        surface: colors.bg,
        onSurface: colors.ink,
        error: colors.error,
        onError: colors.onAccent,
      ),
      textTheme: textTheme,
      splashColor: colors.accent.withValues(alpha: 0.10),
      highlightColor: colors.ink.withValues(alpha: 0.03),
      dividerColor: colors.border,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: colors.ink,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
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
        fillColor: colors.surface,
        hintStyle: textTheme.bodyLarge?.copyWith(color: colors.dim),
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
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
    );
  }
}

extension TextThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;

  /// The palette for the theme in force here. Falls back to the light one
  /// rather than throwing, so a widget pumped without the app's theme — a
  /// test harness, a preview — still paints.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

extension ScaledMetricsX on BuildContext {
  /// Grows a height that cannot wrap with the reader's text size.
  ///
  /// A row of chips, a date block or a button has to be given a height, and
  /// a fixed one cuts the text off as soon as the system font is enlarged.
  /// Scaling the box by the same rule as the text inside it keeps the two in
  /// step. The result is capped, because past double the box already holds
  /// two lines and growing it further only eats the screen.
  double scaled(double height, {double max = 2}) =>
      MediaQuery.textScalerOf(this).scale(height).clamp(height, height * max);

  /// Room to leave at the bottom of a scrolling screen for the floating tab
  /// bar, which sits over the content rather than beside it. It follows the
  /// bar's own scaling, so enlarging the system font does not park the last
  /// card underneath it.
  double get bottomBarInset => scaled(AppTheme.tabBarHeight, max: 1.3) + 54;

  /// Whether the reader has set the system font large enough that a row of
  /// text and a button beside it can no longer share a line. Rows this
  /// affects stack instead of breaking words.
  bool get textIsLarge => MediaQuery.textScalerOf(this).scale(14) > 19;
}
