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
    required this.borderStrong,
    required this.border,
    required this.success,
    required this.error,
    required this.danger,
    required this.onDanger,
    required this.warning,
    required this.skyTop,
    required this.skyLow,
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

  /// The outline of a control that has no fill to speak of — a field, a
  /// time cell, a chip. [border] is a divider and may be as quiet as it
  /// likes; this one has to clear 3:1 against the surface behind it,
  /// because it is the only thing saying where the control begins.
  final Color borderStrong;
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

  /// The field the home screen opens with: a wash from [skyTop] down to the
  /// page colour, with white on it the whole way. Both ends carry white above
  /// 4.5:1 — 7.4:1 and 4.9:1 in the light theme, 12.6:1 and 15.1:1 in the
  /// dark — so the loudest surface in the app is still one you can read.
  final Color skyTop;
  final Color skyLow;

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
    dim: Color(0xFF5F6B7A),
    faint: Color(0xFFD5DDE5),
    borderStrong: Color(0xFF7E8A99),
    border: Color(0xFFE3EAF0),
    success: Color(0xFF107F41),
    error: Color(0xFFC8272D),
    danger: Color(0xFFCE2C31),
    onDanger: Color(0xFFFFFFFF),
    warning: Color(0xFFE8A317),
    skyTop: Color(0xFF2A3CE0),
    skyLow: Color(0xFF4462F5),
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
    dim: Color(0xFF8E9BAC),
    faint: Color(0xFF333C4A),
    borderStrong: Color(0xFF6C7A8A),
    border: Color(0xFF262E3B),
    success: Color(0xFF2ECC71),
    error: Color(0xFFFF6B6B),
    // On a dark page the same red carries a label at 6.5:1, so the two
    // jobs need only one colour here.
    danger: Color(0xFFFF6B6B),
    onDanger: Color(0xFF121627),
    warning: Color(0xFFF0B429),
    skyTop: Color(0xFF1E2A7A),
    skyLow: Color(0xFF16205A),
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

  /// The outline that says where the keyboard is.
  ///
  /// Two pixels of accent, offset outwards so it never eats the content it
  /// surrounds. Everything focusable that paints its own background wraps
  /// itself in one of these; [ThemeData.focusColor] covers the rest.
  static BoxDecoration focusRing(
    BuildContext context,
    double radius, {
    Color? color,
  }) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    // The accent is the ring almost everywhere, but a control that sits on
    // the blue header — or is the blue itself, like the create button — has
    // to be ringed in white, or the indicator disappears into what it marks.
    border: Border.all(color: color ?? context.colors.accent, width: 2),
  );

  /// Bundled with the app, so text renders identically offline, on web and
  /// in the first second of a cold start — no font arrives over a network.
  ///
  /// Manrope is semi-condensed, which buys width back on a screen full of
  /// club names, and its heavy weights are hard enough that a title set in
  /// them reads as a poster. The copy here is cut from the OFL variable font
  /// into the five weights the app uses; the licence sits beside it in
  /// `assets/fonts/Manrope-OFL.txt`.
  static const fontFamily = 'Manrope';

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

  /// A name set in the register of a poster: upper case, heavy, and tracked
  /// tight enough that the letters hold together as a shape.
  ///
  /// Used for what a screen is about — the club you are looking at, the tab
  /// you are on — and nowhere else. It is the top of a range that runs down to
  /// an 11pt label; a page where every line is 14 to 22 has no hierarchy at
  /// all, and reads as something a machine laid out.
  static TextStyle display(BuildContext context) =>
      context.text.headlineMedium!.copyWith(letterSpacing: -1.4, height: 0.98);

  /// Prices, times and counts: the display face, with tabular figures so a
  /// column of them lines up and a changing number does not shift the words
  /// beside it.
  static TextStyle numeric(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: fontFamily,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// The small type that says what kind of thing follows: a date over a
  /// title, a section over a list.
  static TextStyle eyebrow(BuildContext context, Color color) => context
      .text
      .labelSmall!
      .copyWith(color: color, fontWeight: FontWeight.w800, letterSpacing: 1.4);

  static TextStyle _face(TextStyle? style) =>
      (style ?? const TextStyle()).copyWith(fontFamily: fontFamily);

  /// One family, and a wider gap between the sizes than the base theme ships
  /// than the base theme ships with: the large end goes to 40 at the heaviest
  /// weight the family has, the small end stays at 11 and light. A page where
  /// every line is 14 to 22 at one weight has no hierarchy at all, and one
  /// family can hold a range as long as the range is real.
  static TextTheme _typography(TextTheme base) {
    return base.copyWith(
      displayLarge: _face(base.displayLarge),
      displayMedium: _face(base.displayMedium),
      displaySmall: _face(base.displaySmall),
      headlineLarge: _face(
        base.headlineLarge?.copyWith(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          height: 1,
        ),
      ),
      headlineMedium: _face(
        base.headlineMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
          height: 1.02,
        ),
      ),
      headlineSmall: _face(
        base.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      titleLarge: _face(
        base.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      titleMedium: _face(base.titleMedium),
      titleSmall: _face(base.titleSmall),
      bodyLarge: _face(base.bodyLarge),
      bodyMedium: _face(base.bodyMedium),
      bodySmall: _face(base.bodySmall),
      labelLarge: _face(base.labelLarge),
      labelMedium: _face(base.labelMedium),
      labelSmall: _face(
        base.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// The colour a sport brings with it.
  ///
  /// Every card in the app used to be the same blue, so one screen looked
  /// like another with the words swapped. A pitch is green, ice is blue, clay
  /// is ochre — using that is both louder and truer than tinting everything
  /// with the brand.
  ///
  /// These are the dark ends: they carry white text and stand in for the
  /// photograph a club will have once there is one.
  static const _sportGrounds = <String, List<Color>>{
    'football': [Color(0xFF16281C), Color(0xFF3C7C48)],
    'hockey': [Color(0xFF0E2233), Color(0xFF2E6E96)],
    'tennis': [Color(0xFF2A1A08), Color(0xFF9A5A1E)],
    'padel': [Color(0xFF0D2430), Color(0xFF1F6E63)],
    'basketball': [Color(0xFF241634), Color(0xFF6B3A96)],
    'volleyball': [Color(0xFF2B2207), Color(0xFF8A6A12)],
  };

  static const _sportFallback = [Color(0xFF1B1C28), Color(0xFF4A4E6B)];

  static List<Color> sportGround(String sportId) =>
      _sportGrounds[sportId] ?? _sportFallback;

  static LinearGradient sportGradient(String sportId) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: sportGround(sportId),
  );

  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors colors) {
    final base = colors.isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final textTheme = _typography(
      base.textTheme.apply(bodyColor: colors.ink, displayColor: colors.ink),
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
      // Keyboard focus used to be a tint at 1.31:1 — on most controls,
      // nothing at all. WCAG 2.2 wants an indicator at 3:1 against what
      // surrounds it, so it is drawn in the accent, which carries 5.4:1 on
      // the page and 6.1:1 on a card.
      focusColor: colors.accent.withValues(alpha: 0.16),
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

extension MotionX on BuildContext {
  /// A duration, or none of it if the reader has asked for less movement.
  ///
  /// «Уменьшение движения» is a system setting people turn on for a reason —
  /// vestibular disorders, motion sickness, or simply preferring a still
  /// screen. Only the splash honoured it; every card flight, scale and slide
  /// in the app ran regardless. Passing durations through here makes the
  /// whole app answer the setting, and the animations arrive already
  /// finished rather than being skipped mid-flight.
  Duration motion(Duration duration) =>
      MediaQuery.disableAnimationsOf(this) ? Duration.zero : duration;
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
