/// The app's strings and the shortest way to reach them.
///
/// `context.l10n.somethingOrOther` reads like `context.text` and
/// `context.colors` next to it, which is how the rest of the app asks its
/// surroundings for things.
library;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension L10nX on BuildContext {
  L get l10n => L.of(this);
}
