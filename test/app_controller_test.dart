import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/mock_data.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';

void main() {
  test(
    'upcoming bookings contain only active future bookings in start order',
    () {
      final now = DateTime(2026, 5, 24, 12);
      final controller = AppController(now: now);
      addTearDown(controller.dispose);

      controller.bookings = [
        _booking(id: 'tomorrow', date: DateTime(2026, 5, 25), startHour: 8),
        _booking(
          id: 'cancelled',
          date: DateTime(2026, 5, 24),
          startHour: 14,
          statusCode: 'cancelled',
        ),
        _booking(
          id: 'today',
          date: DateTime(2026, 5, 24),
          startHour: 20,
          statusCode: 'collecting_shares',
        ),
        _booking(id: 'past', date: DateTime(2026, 5, 24), startHour: 10),
        _booking(
          id: 'expired',
          date: DateTime(2026, 5, 24),
          startHour: 16,
          statusCode: 'expired',
        ),
      ];

      expect(controller.upcomingBookings.map((booking) => booking.id), [
        'today',
        'tomorrow',
      ]);
    },
  );

  group('demo build', () {
    test('opens signed in, on the fixtures', () async {
      final controller = AppController.demo(now: DateTime(2026, 5, 24));
      addTearDown(controller.dispose);

      expect(await controller.restoreSession(), isTrue);
      expect(controller.isSignedIn, isTrue);
      expect(controller.isConnected, isFalse);
      expect(controller.games, isNotEmpty);
    });

    test('signs back in after signing out, without a server', () {
      final controller = AppController.demo(now: DateTime(2026, 5, 24));
      addTearDown(controller.dispose);

      controller.signInDemo(phone: '+79000000000');
      controller.logout();
      expect(controller.isSignedIn, isFalse);

      controller.signInDemo(email: ' Demo@Example.com ');
      expect(controller.isSignedIn, isTrue);
      expect(controller.email, 'demo@example.com');
    });

    test('is not a way into the real app', () async {
      final controller = AppController(now: DateTime(2026, 5, 24));
      addTearDown(controller.dispose);

      expect(controller.isDemo, isFalse);
      expect(await controller.restoreSession(), isFalse);
      expect(
        () => controller.signInDemo(phone: '+79000000000'),
        throwsStateError,
      );
      expect(controller.isSignedIn, isFalse);
    });
  });
}

Booking _booking({
  required String id,
  required DateTime date,
  required int startHour,
  String statusCode = 'confirmed',
}) {
  return Booking(
    id: id,
    draft: BookingDraft(
      venue: MockData.venues.first,
      date: date,
      durationMinutes: 60,
      startHour: startHour,
      players: 4,
      mode: PaymentMode.full,
    ),
    statusCode: statusCode,
    createdAt: date,
  );
}
