import 'package:flutter/widgets.dart';

/// The app's icons: Lucide, subset to the ones actually drawn.
///
/// Material's rounded set is recognisable as a default from across a room,
/// which is half of why the app read as something nobody designed. This is a
/// line set at a single weight, and it ships as [a subset of] the Lucide
/// variable font — 5 KB for these twenty-six glyphs instead of the 2.8 MB of
/// weights the package bundles for the full 1500.
///
/// Lucide is ISC-licensed; the copy here is generated from the pub package
/// `lucide_icons_flutter` with `fontTools.subset`. To add an icon, add its
/// code point below and regenerate the font with the new list.
@staticIconProvider
class AppIcons {
  const AppIcons._();

  static const IconData bell = IconData(57433, fontFamily: 'AppIcons');

  static const IconData calendarCheck = IconData(58039, fontFamily: 'AppIcons');

  static const IconData calendarDays = IconData(58041, fontFamily: 'AppIcons');

  static const IconData check = IconData(57452, fontFamily: 'AppIcons');

  static const IconData checkCircle = IconData(57468, fontFamily: 'AppIcons');

  static const IconData chevronDown = IconData(57453, fontFamily: 'AppIcons');

  static const IconData chevronLeft = IconData(57454, fontFamily: 'AppIcons');

  static const IconData chevronRight = IconData(57455, fontFamily: 'AppIcons');

  static const IconData clock = IconData(57479, fontFamily: 'AppIcons');

  static const IconData filterX = IconData(58293, fontFamily: 'AppIcons');

  static const IconData history = IconData(57845, fontFamily: 'AppIcons');

  static const IconData home = IconData(57589, fontFamily: 'AppIcons');

  static const IconData layoutGrid = IconData(57599, fontFamily: 'AppIcons');

  static const IconData locateFixed = IconData(57819, fontFamily: 'AppIcons');

  static const IconData mapPin = IconData(57617, fontFamily: 'AppIcons');

  static const IconData mapPinOff = IconData(58022, fontFamily: 'AppIcons');

  static const IconData minus = IconData(57628, fontFamily: 'AppIcons');

  static const IconData pencil = IconData(57849, fontFamily: 'AppIcons');

  static const IconData plus = IconData(57661, fontFamily: 'AppIcons');

  static const IconData search = IconData(57681, fontFamily: 'AppIcons');

  static const IconData searchX = IconData(58541, fontFamily: 'AppIcons');

  static const IconData slidersHorizontal = IconData(
    58010,
    fontFamily: 'AppIcons',
  );

  static const IconData star = IconData(57718, fontFamily: 'AppIcons');

  static const IconData user = IconData(57759, fontFamily: 'AppIcons');

  static const IconData volleyball = IconData(58927, fontFamily: 'AppIcons');

  static const IconData x = IconData(57778, fontFamily: 'AppIcons');
}
