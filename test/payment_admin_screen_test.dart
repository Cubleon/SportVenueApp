import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/screens/payment_admin_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppController> admin(WidgetTester tester) async {
    phone(tester);
    // The demo is its own payments admin.
    final controller = AppController.demo(now: now);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: PaymentAdminScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  ShareStatus statusOf(AppController controller, String shareId) => controller
      .bookings
      .expand((booking) => booking.shares)
      .firstWhere((share) => share.id == shareId)
      .status;

  testWidgets('a found transfer makes the share paid', (tester) async {
    final controller = await admin(tester);

    // Orlov pressed «Я оплатил» in the demo booking.
    expect(
      find.byKey(const ValueKey('admin-share-share-demo-2')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('admin-found-share-demo-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-yes')));
    await tester.pumpAndSettle();

    expect(statusOf(controller, 'share-demo-2'), ShareStatus.paid);
    expect(find.byKey(const ValueKey('admin-empty')), findsOneWidget);
  });

  testWidgets('a missing transfer is sent back with a reason', (tester) async {
    final controller = await admin(tester);

    await tester.tap(
      find.byKey(const ValueKey('admin-not-found-share-demo-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-reason-0')));
    await tester.pumpAndSettle();

    final share = controller.bookings
        .expand((booking) => booking.shares)
        .firstWhere((item) => item.id == 'share-demo-2');
    expect(share.status, ShareStatus.notFound);
    expect(share.note, 'Сумма не совпадает');
  });

  testWidgets('the refunds tab starts empty in the demo', (tester) async {
    await admin(tester);

    await tester.tap(find.byKey(const ValueKey('admin-tab-refund')));
    await tester.pumpAndSettle();

    expect(find.text('Возвращать никому не нужно.'), findsOneWidget);
  });

  testWidgets('the desk is closed to everyone else', (tester) async {
    phone(tester);
    final controller = AppController(now: now);
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: Routes.adminPayments,
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

    expect(
      find.text('Этот раздел только для администратора оплат.'),
      findsOneWidget,
    );
  });
}
