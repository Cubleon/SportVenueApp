import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/screens/share_payment_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<(AppController, Booking)> booked() async {
    final controller = AppController(now: now);
    addTearDown(controller.dispose);
    final booking = await controller.addBooking(
      BookingDraft(
        venue: MockData.venues.first,
        date: DateTime(2026, 5, 25),
        durationMinutes: 60,
        startHour: 20,
        players: 4,
        mode: PaymentMode.split,
      ),
    );
    return (controller, booking);
  }

  Widget app(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: child,
    );
  }

  testWidgets('the share is paid by its code, and «Я оплатил» only queues it', (
    tester,
  ) async {
    phone(tester);
    final (controller, booking) = await booked();
    final share = booking.myShare!;

    await tester.pumpWidget(
      app(SharePaymentScreen(controller: controller, bookingId: booking.id)),
    );
    await tester.pumpAndSettle();

    // What to pay, where to, and what to write in the comment.
    expect(find.text('₽${share.amount}'), findsOneWidget);
    expect(find.text(share.code!), findsOneWidget);
    // The bank button is the way to pay; the QR waits, folded.
    expect(find.byKey(const ValueKey('pay-qr')), findsNothing);
    // There is no account yet, and the screen says not to send money.
    expect(find.byKey(const ValueKey('pay-test-banner')), findsOneWidget);
    expect(find.textContaining('до пн 25 мая, 18:00'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('claim-paid')));
    await tester.pumpAndSettle();

    // Queued, not paid: the admin has not looked yet.
    expect(
      controller.bookingById(booking.id)!.myShare!.status,
      ShareStatus.pendingConfirmation,
    );
    expect(find.byKey(const ValueKey('pay-pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('claim-paid')), findsNothing);
    expect(find.byKey(const ValueKey('pay-via-bank')), findsNothing);
  });

  testWidgets('the QR unfolds for paying from another device', (tester) async {
    phone(tester);
    final (controller, booking) = await booked();

    await tester.pumpWidget(
      app(SharePaymentScreen(controller: controller, bookingId: booking.id)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-qr')), findsNothing);

    final toggle = find.byKey(const ValueKey('toggle-qr'));
    await tester.scrollUntilVisible(
      toggle,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Clear of the pinned buttons, which float over the end of the list.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-qr')), findsOneWidget);
    expect(find.text('Скрыть QR'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-qr')), findsNothing);
  });

  testWidgets('«Оплатить через банк» opens the SBP link', (tester) async {
    phone(tester);
    final (controller, booking) = await booked();
    final opened = <Uri>[];

    await tester.pumpWidget(
      app(
        SharePaymentScreen(
          controller: controller,
          bookingId: booking.id,
          openLink: (uri) async {
            opened.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-via-bank')));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse(MockData.paymentInfo.sbpLink)]);
  });

  testWidgets('a bank that will not open says what to do instead', (
    tester,
  ) async {
    phone(tester);
    final (controller, booking) = await booked();

    await tester.pumpWidget(
      app(
        SharePaymentScreen(
          controller: controller,
          bookingId: booking.id,
          openLink: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-via-bank')));
    await tester.pump();

    expect(find.textContaining('Отсканируйте QR'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('the code is copied for the transfer\'s comment', (tester) async {
    phone(tester);
    final (controller, booking) = await booked();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      app(SharePaymentScreen(controller: controller, bookingId: booking.id)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('copy-code')));
    await tester.pump();

    expect(copied, booking.myShare!.code);
    expect(find.text('Код скопирован'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a transfer not found asks again, with the admin\'s note', (
    tester,
  ) async {
    phone(tester);
    final (controller, booking) = await booked();
    controller.isPaymentAdmin = true;
    await controller.claimSharePaid(booking, booking.myShare!);
    await controller.rejectShare(
      booking.myShare!.id!,
      note: 'пришло 300 вместо 400',
    );

    await tester.pumpWidget(
      app(SharePaymentScreen(controller: controller, bookingId: booking.id)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pay-not-found')), findsOneWidget);
    expect(find.textContaining('пришло 300 вместо 400'), findsOneWidget);
    // Paying again is possible: the buttons are back.
    expect(find.byKey(const ValueKey('claim-paid')), findsOneWidget);
  });

  testWidgets('a confirmed share says so, and offers nothing to pay', (
    tester,
  ) async {
    phone(tester);
    final (controller, booking) = await booked();
    controller.isPaymentAdmin = true;
    await controller.confirmShare(booking.myShare!.id!);

    await tester.pumpWidget(
      app(SharePaymentScreen(controller: controller, bookingId: booking.id)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pay-paid')), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-qr')), findsNothing);
    expect(find.byKey(const ValueKey('claim-paid')), findsNothing);
  });

  testWidgets('right after booking, the screen says what the others owe', (
    tester,
  ) async {
    phone(tester);
    final (controller, booking) = await booked();

    await tester.pumpWidget(
      app(
        SharePaymentScreen(
          controller: controller,
          bookingId: booking.id,
          justCreated: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Бронь создана'), findsOneWidget);
    expect(find.textContaining('им осталось оплатить 3 доли'), findsOneWidget);
  });
}
