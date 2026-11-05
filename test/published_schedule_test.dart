import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/screens/booking_screens.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';
import 'package:sport_venue_app/src/widgets/shared_widgets.dart';
import 'package:sport_venue_app/src/widgets/venue_slot_picker.dart';

void main() {
  test('published starts preserve half-hours and Moscow wall-clock time', () {
    final row = _slot(15, 30);
    final managed = TimeSlot.fromJson(row, useMoscowTime: true);
    final legacy = TimeSlot.fromJson(row);

    expect(managed.label, '18:30');
    expect(managed.startsAt, DateTime.utc(2026, 10, 18, 15, 30));
    expect(legacy.label, '15:30');
    expect(Venue.fromJson(_venueJson).scheduleManaged, isTrue);
    expect(
      Venue.fromJson(
        {..._venueJson}..remove('managed_schedule'),
      ).scheduleManaged,
      isFalse,
    );
  });

  test('booking summaries retain minutes across confirmation and reload', () {
    final instant = DateTime.utc(2026, 10, 18, 15, 30);
    final draft = BookingDraft(
      venue: _venue,
      date: DateTime(2026, 10, 18),
      durationMinutes: 90,
      startHour: 18,
      startMinute: 30,
      apiStartsAt: instant,
      players: 4,
      mode: PaymentMode.split,
    );
    expect(draft.timeRange, '18:30–20:00');
    expect(draft.copyWith(mode: PaymentMode.full).apiStartsAt, instant);
    expect(draft.copyWith(startMinute: 0).apiStartsAt, isNull);
    expect(draft.copyWith(startHour: 23).timeRange, '23:30–01:00');

    final booking = Booking.fromJson({
      'id': 'booking-1',
      'time_slot': {..._slot(21, 30), 'duration_minutes': 90},
      'players_count': 4,
      'status': 'confirmed',
      'payment_mode': 'full',
      'total_price': 1500,
      'share_price': 375,
      'organizer_id': 'player-1',
      'created_at': '2026-10-18T10:00:00Z',
    }, venue: _venue);
    expect(booking.draft.date, DateTime(2026, 10, 19));
    expect(booking.draft.timeRange, '00:30–02:00');
    expect(
      booking.startsAt.isAtSameMomentAs(DateTime.utc(2026, 10, 18, 21, 30)),
      isTrue,
    );
  });

  test('games retain a published start when participants change', () {
    final game = Game.fromJson(
      {
        'id': 'game-1',
        'sport_id': 'football',
        'time_slot': {..._slot(15, 30), 'duration_minutes': 90},
        'capacity': 4,
        'price_per_person': 375,
        'type': 'open',
        'gender_filter': 'any',
        'participants': <Object?>[],
        'organizer_id': 'player-1',
      },
      venue: _venue,
      currentUserId: null,
    );
    expect(game.timeRange, '18:30–20:00');
    expect(game.copyWith(participants: []).startMinute, 30);
    expect(game.copyWith(participants: []).apiStartsAt, game.apiStartsAt);
    expect(
      game.startsAt.isAtSameMomentAs(DateTime.utc(2026, 10, 18, 15, 30)),
      isTrue,
    );
  });

  testWidgets(
    'picker distinguishes minutes and follows duration availability',
    (tester) async {
      final api = _api((request) async {
        final duration = request.url.queryParameters['duration_minutes'];
        return switch (duration) {
          '60' => [_slot(15, 0), _slot(15, 30)],
          '120' => [_slot(16, 30)],
          _ => <Map<String, dynamic>>[],
        };
      });
      final controller = AppController(api: api);
      addTearDown(controller.dispose);
      addTearDown(api.close);
      var duration = 60;
      int? hour = 18;
      var minute = 30;
      var ready = false;
      TimeSlot? selected;
      late StateSetter rebuild;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return VenueSlotPicker(
                controller: controller,
                venue: _venue,
                date: DateTime(2026, 10, 18),
                durationMinutes: duration,
                selectedHour: hour,
                selectedMinute: minute,
                onHourChanged: (value) => setState(() => hour = value),
                onSlotChanged: (slot) => setState(() {
                  selected = slot;
                  hour = slot.hour;
                  minute = slot.minute;
                }),
                onReadyChanged: (value) => ready = value,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(ready, isTrue);
      expect(selected?.label, '18:30');
      final tiles = tester.widgetList<TimeTile>(find.byType(TimeTile));
      expect(tiles.where((tile) => tile.selected).single.label, '18:30');

      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();
      expect(selected?.minute, 0);
      expect(selected?.startsAt, DateTime.utc(2026, 10, 18, 15));

      rebuild(() => duration = 120);
      await tester.pumpAndSettle();
      expect(ready, isFalse);
      expect(hour, isNull);
      await tester.tap(find.text('19:30'));
      await tester.pumpAndSettle();
      expect(ready, isTrue);
      expect(selected?.label, '19:30');
      expect(find.text('18:00'), findsNothing);

      rebuild(() => duration = 180);
      await tester.pumpAndSettle();
      expect(ready, isFalse);
      expect(find.text('На эту дату свободных слотов нет'), findsOneWidget);
    },
  );

  testWidgets('late availability cannot overwrite a newer duration request', (
    tester,
  ) async {
    final responses = <int, Completer<List<Map<String, dynamic>>>>{};
    final api = _api((request) {
      final duration = int.parse(
        request.url.queryParameters['duration_minutes']!,
      );
      final response = Completer<List<Map<String, dynamic>>>();
      responses[duration] = response;
      return response.future;
    });
    final controller = AppController(api: api);
    addTearDown(controller.dispose);
    addTearDown(api.close);
    var duration = 60;
    TimeSlot? selected;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return VenueSlotPicker(
              controller: controller,
              venue: _venue,
              date: DateTime(2026, 10, 18),
              durationMinutes: duration,
              selectedHour: 18,
              onHourChanged: (_) {},
              onSlotChanged: (slot) => selected = slot,
              onReadyChanged: (_) {},
            );
          },
        ),
      ),
    );
    await tester.pump();
    rebuild(() => duration = 120);
    await tester.pump();
    responses[120]!.complete([_slot(16, 30)]);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('19:30'));
    await tester.pumpAndSettle();
    expect(selected?.label, '19:30');
    responses[60]!.complete([_slot(15, 0)]);
    await tester.pumpAndSettle();
    expect(selected?.label, '19:30');
    expect(find.text('18:00'), findsNothing);
  });

  testWidgets('booking confirmation carries the exact published start', (
    tester,
  ) async {
    final api = _api(
      (_) async => [
        {..._slot(15, 30), 'price': 1700},
      ],
    );
    final controller = AppController(api: api);
    addTearDown(controller.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(
        BookingScreen(
          controller: controller,
          venue: Venue.fromJson({
            ..._venueJson,
            'capacity_min': 6,
            'capacity_max': 8,
          }),
          date: DateTime(2026, 10, 18),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-full')), findsNothing);
    await _pickSlot(tester, '18:30');
    await tester.tap(find.byKey(const ValueKey('pay-full')));
    await tester.pumpAndSettle();
    final screen = tester.widget<BookingConfirmationScreen>(
      find.byType(BookingConfirmationScreen),
    );
    expect(screen.draft.timeRange, '18:30–19:30');
    expect(screen.draft.totalPrice, 1700);
    expect(screen.draft.players, 6);
    expect(screen.draft.apiStartsAt, DateTime.utc(2026, 10, 18, 15, 30));
  });

  testWidgets('game share summary uses the published slot price', (
    tester,
  ) async {
    final api = _api(
      (_) async => [
        {..._slot(15, 30), 'price': 1700},
      ],
    );
    final controller = AppController(api: api)..venues = [_venue];
    addTearDown(controller.dispose);
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(
        BookingScreen(
          controller: controller,
          venue: _venue,
          date: DateTime(2026, 10, 18),
          findPlayers: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _pickSlot(tester, '18:30');
    final summary = tester.widget<BookingSummaryRows>(
      find.byType(BookingSummaryRows),
    );
    expect(summary.draft.sharePrice, 425);
    expect(summary.draft.apiStartsAt, DateTime.utc(2026, 10, 18, 15, 30));
    expect(find.byKey(const ValueKey('create-game-submit')), findsOneWidget);
  });
}

Future<void> _pickSlot(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(body: child),
);

SportVenueApiClient _api(
  Future<List<Map<String, dynamic>>> Function(http.Request) slots,
) => SportVenueApiClient(
  baseUrl: 'https://api.example.test/api/v1',
  httpClient: MockClient(
    (request) async => http.Response(
      jsonEncode(await slots(request)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

final _venue = Venue.fromJson(_venueJson);

const _venueJson = {
  'id': 'club-court',
  'name': 'Клуб',
  'address': 'Москва, Спортивная, 1',
  'geo_lat': 55.75,
  'geo_lng': 37.61,
  'sport_ids': ['football'],
  'capacity_min': 2,
  'capacity_max': 10,
  'base_price_per_hour': 1000,
  'rating': 0,
  'description': 'Площадка клуба',
  'managed_schedule': true,
};

Map<String, dynamic> _slot(int utcHour, int minute) => {
  'starts_at': DateTime.utc(2026, 10, 18, utcHour, minute).toIso8601String(),
  'ends_at': DateTime.utc(2026, 10, 18, utcHour + 1, minute).toIso8601String(),
  'is_available': true,
  'price': 1000,
  'status': 'available',
};
