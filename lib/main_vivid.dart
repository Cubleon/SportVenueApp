import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'src/data/app_controller.dart';
import 'src/screens/home_vivid_screen.dart';
import 'src/theme/app_theme.dart';

/// Runs the loud home on its own, so it can be looked at next to the
/// shipping one rather than instead of it.
///
/// Not part of the app: `flutter build web -t lib/main_vivid.dart`.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      builder: (context, child) => ColoredBox(
        color: AppColors.light.bg,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child,
          ),
        ),
      ),
      home: HomeVividScreen(controller: AppController()),
    ),
  );
}
