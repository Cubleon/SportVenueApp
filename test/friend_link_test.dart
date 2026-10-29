import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppController> open(WidgetTester tester, String location) async {
    phone(tester);
    final controller = AppController(now: now);
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox()),
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
    return controller;
  }

  testWidgets('a friend\'s booking opens by its link and offers a place', (
    tester,
  ) async {
    final controller = await open(tester, Routes.booking('booking-friend'));

    // Not «Бронь не найдена»: the booking was fetched by its id.
    expect(find.text('Бронь не найдена'), findsNothing);
    expect(find.text('Собираем оплату'), findsOneWidget);
    expect(find.byKey(const ValueKey('take-share')), findsOneWidget);
    // Someone else's booking is not the reader's to cancel, and it does not
    // join «Мои брони» just for being looked at.
    expect(find.byKey(const ValueKey('cancel-booking')), findsNothing);
    expect(controller.bookings.any((b) => b.id == 'booking-friend'), isFalse);

    await tester.tap(find.byKey(const ValueKey('take-share')));
    await tester.pumpAndSettle();

    // The place is the reader's now, the booking is theirs, and paying for
    // it is the next screen.
    final booking = controller.bookingById('booking-friend')!;
    expect(booking.myShare, isNotNull);
    expect(booking.myShare!.status, ShareStatus.unpaid);
    expect(controller.bookings.any((b) => b.id == 'booking-friend'), isTrue);
    expect(find.byKey(const ValueKey('take-share')), findsNothing);
  });

  testWidgets('a link to a booking that does not exist says so', (
    tester,
  ) async {
    await open(tester, Routes.booking('no-such-booking'));

    expect(find.text('Бронь не найдена'), findsOneWidget);
  });

  testWidgets('the reader\'s own booking still opens by its link', (
    tester,
  ) async {
    await open(tester, Routes.booking('booking-demo'));

    expect(find.text('Бронь не найдена'), findsNothing);
    expect(find.byKey(const ValueKey('take-share')), findsNothing);
    expect(find.byKey(const ValueKey('cancel-booking')), findsOneWidget);
  });
}
