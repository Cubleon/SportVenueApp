import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);

  Future<void> openBooking(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController(now: now);
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: Routes.booking('booking-demo'),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('home'))),
          routes: shellRoutes(controller),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  final booking = find.byKey(const ValueKey('cancel-booking'));

  testWidgets('a swipe from the left edge goes back', (tester) async {
    await openBooking(tester);
    expect(booking, findsOneWidget);

    await tester.dragFrom(const Offset(4, 400), const Offset(320, 0));
    await tester.pumpAndSettle();

    expect(booking, findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a short swipe lets the screen settle back', (tester) async {
    await openBooking(tester);

    // Slowly, so it is not a flick.
    await tester.timedDragFrom(
      const Offset(4, 400),
      const Offset(80, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(booking, findsOneWidget);
  });

  testWidgets('a swipe that starts away from the edge does nothing', (
    tester,
  ) async {
    await openBooking(tester);

    await tester.dragFrom(const Offset(200, 400), const Offset(200, 0));
    await tester.pumpAndSettle();

    expect(booking, findsOneWidget);
  });
}
