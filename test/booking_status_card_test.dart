import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';
import 'package:sport_venue_app/src/widgets/booking_status_card.dart';

void main() {
  final now = DateTime(2026, 5, 24, 12);

  Future<Booking> booked() async {
    final controller = AppController(now: now);
    addTearDown(controller.dispose);
    return controller.addBooking(
      BookingDraft(
        venue: MockData.venues.first,
        date: DateTime(2026, 5, 25),
        durationMinutes: 60,
        startHour: 20,
        players: 4,
        mode: PaymentMode.split,
      ),
    );
  }

  Future<void> show(WidgetTester tester, Booking booking) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(body: BookingStatusCard(booking: booking)),
      ),
    );
  }

  /// Every share in the given state, for the states a booking ends in.
  Booking withShares(Booking booking, String code, ShareStatus status) {
    return booking.copyWith(
      statusCode: code,
      shares: [
        for (final share in booking.shares) share.copyWith(status: status),
      ],
    );
  }

  testWidgets('collecting says how many paid and by when', (tester) async {
    final booking = await booked();
    await show(tester, booking);

    expect(find.text('Собираем оплату'), findsOneWidget);
    expect(
      find.text('Оплатили ${booking.paidShares} из ${booking.shares.length}'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('до пн 25 мая, 18:00'), findsOneWidget);
  });

  testWidgets('confirmed says the time is held', (tester) async {
    final booking = await booked();
    await show(tester, booking.copyWith(statusCode: 'confirmed'));

    expect(find.text('Бронь подтверждена'), findsOneWidget);
    expect(find.textContaining('Время за вами'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('expired with money owed promises the refund', (tester) async {
    final booking = await booked();
    await show(tester, withShares(booking, 'expired', ShareStatus.refundDue));

    expect(find.text('Не собрали вовремя'), findsOneWidget);
    expect(
      find.text('Деньги вернём в течение 1 рабочего дня.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelled after the refund says the money is back', (
    tester,
  ) async {
    final booking = await booked();
    await show(tester, withShares(booking, 'cancelled', ShareStatus.refunded));

    expect(find.text('Бронь отменена'), findsOneWidget);
    expect(find.text('Деньги вернули.'), findsOneWidget);
  });

  testWidgets('cancelled with nobody paid has nothing to return', (
    tester,
  ) async {
    final booking = await booked();
    await show(tester, withShares(booking, 'cancelled', ShareStatus.unpaid));

    expect(find.text('Оплат не было, возвращать нечего.'), findsOneWidget);
  });
}
