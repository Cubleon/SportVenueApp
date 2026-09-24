@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/screens/auth_screens.dart';
import 'package:sport_venue_app/src/screens/booking_screens.dart';
import 'package:sport_venue_app/src/screens/create_game_screen.dart';
import 'package:sport_venue_app/src/screens/games_screens.dart';
import 'package:sport_venue_app/src/screens/history_screen.dart';
import 'package:sport_venue_app/src/screens/main_shell.dart';
import 'package:sport_venue_app/src/screens/profile_screen.dart';
import 'package:sport_venue_app/src/screens/sport_selection_screen.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

/// Pictures of the screens, in both themes, checked pixel for pixel.
///
/// The tests next door say the app does the right thing; nothing said it
/// still *looks* right. A restyle touches every screen at once, and a
/// shifted card or a colour that stopped following the theme is exactly
/// what no assertion catches and no reviewer finds by reading a diff.
///
/// After a deliberate visual change, regenerate and look at what moved
/// before committing the new pictures:
///
///     flutter test --update-goldens test/golden_test.dart
///
/// Two things to know about reading them. Icons come out as filled boxes:
/// the icon font lives in the SDK rather than in this repo, so loading it
/// would tie the pictures to one machine's Flutter install — the box still
/// holds the icon's size and place, which is what these are here to watch.
/// And text rendering differs a little between platforms, so the pictures
/// are made and checked on one; they carry the `golden` tag, and a run
/// elsewhere can skip them with `--exclude-tags golden`.
void main() {
  final fixedNow = DateTime(2026, 5, 24);

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await _loadRubik();
  });

  for (final theme in _themes) {
    group(theme.name, () {
      _golden(
        'sign-in',
        theme,
        now: fixedNow,
        build: (_) => RegistrationScreen(onContinue: (_) async => null),
      );

      _golden(
        'sport-selection',
        theme,
        now: fixedNow,
        build: (_) => SportSelectionScreen(
          sports: MockData.sports,
          initialSelection: const {'football', 'padel'},
          onContinue: (_) async {},
        ),
      );

      _golden(
        'home',
        theme,
        now: fixedNow,
        build: (controller) =>
            MainShell(controller: controller, onLogout: () {}),
      );

      _golden(
        'booking',
        theme,
        now: fixedNow,
        build: (controller) =>
            BookingScreen(controller: controller, venue: MockData.venues.first),
      );

      _golden(
        'create-game',
        theme,
        now: fixedNow,
        build: (controller) => CreateGameScreen(controller: controller),
      );

      _golden(
        'games',
        theme,
        now: fixedNow,
        build: (controller) => GamesScreen(controller: controller),
      );

      _golden(
        'profile',
        theme,
        now: fixedNow,
        build: (controller) =>
            ProfileScreen(controller: controller, onLogout: () {}),
      );

      _golden(
        'history',
        theme,
        now: fixedNow,
        build: (controller) => HistoryScreen(controller: controller),
      );
    });
  }
}

typedef _Theme = ({String name, ThemeData Function() data});

const _themes = <_Theme>[
  (name: 'light', data: AppTheme.light),
  (name: 'dark', data: AppTheme.dark),
];

/// One screen, in one theme, against its picture.
void _golden(
  String name,
  _Theme theme, {
  required DateTime now,
  required Widget Function(AppController controller) build,
}) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AppController(now: now);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.data(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: build(controller),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${theme.name}-$name.png'),
    );
  });
}

/// The bundled typeface, so the pictures show the app's own letters rather
/// than the test font's boxes.
Future<void> _loadRubik() async {
  const weights = [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
    'Black',
  ];
  final loader = FontLoader('Rubik');
  for (final weight in weights) {
    final file = File('assets/fonts/Rubik-$weight.ttf');
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
}
