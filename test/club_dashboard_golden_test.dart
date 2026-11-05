@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/screens/club_dashboard_screen.dart';
import 'package:sport_venue_app/src/screens/club_login_screen.dart';
import 'package:sport_venue_app/src/screens/club_name_setup_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

import 'support/club_dashboard_fixture.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader(AppTheme.fontFamily);
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(
        File(
          'assets/fonts/Manrope-$weight.ttf',
        ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  });

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';
    for (final view in ['empty', 'populated', 'club-form', 'venue-form']) {
      testWidgets('$theme club $view', (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = ClubDashboardFixture(empty: view == 'empty');
        addTearDown(fixture.client.close);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: ClubDashboardScreen(api: fixture.client, onLogout: () {}),
          ),
        );
        await tester.pumpAndSettle();
        if (view == 'club-form') {
          await tester.tap(find.byTooltip('Редактировать клуб'));
          await tester.pumpAndSettle();
        }
        if (view == 'venue-form') {
          await tester.tap(find.byTooltip('Редактировать площадку'));
          await tester.pumpAndSettle();
        }
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$theme-club-$view.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final view in ['login', 'name']) {
      testWidgets('$theme club $view', (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            localizationsDelegates: L.localizationsDelegates,
            supportedLocales: L.supportedLocales,
            home: view == 'login'
                ? ClubLoginScreen(onLogin: (_, _) async => null, onBack: () {})
                : ClubNameSetupScreen(
                    onContinue: (_) async => null,
                    onLogout: () {},
                  ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$theme-club-$view.png'),
        );
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
