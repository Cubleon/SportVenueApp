import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

/// Every tap target says what it is to a screen reader and is big enough
/// for a thumb. Checked on the screens a player goes through, in both
/// themes. Text contrast is not checked here: test fonts draw boxes, and the
/// guideline then measures the wrong pixels.
void main() {
  final now = DateTime(2026, 5, 24, 12);

  final screens = <String, String>{
    'booking': Routes.booking('booking-demo'),
    'game': Routes.game('game-1'),
    'venue': Routes.venue('luzhniki'),
    'pay': Routes.pay('booking-demo'),
    'history': Routes.history,
  };

  for (final dark in [false, true]) {
    for (final entry in screens.entries) {
      testWidgets(
        '${entry.key} (${dark ? 'dark' : 'light'}) labels its tap targets and sizes them',
        (tester) async {
          tester.view.physicalSize = const Size(430, 932);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final app = AppController(now: now);
          addTearDown(app.dispose);
          final router = GoRouter(
            initialLocation: entry.value,
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Scaffold(),
                routes: shellRoutes(app),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              localizationsDelegates: L.localizationsDelegates,
              supportedLocales: L.supportedLocales,
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          semantics.dispose();
        },
      );
    }
  }
}
