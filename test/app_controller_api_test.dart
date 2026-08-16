import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';

void main() {
  test(
    'controller loads server state and creates a locked full booking',
    () async {
      final requests = <http.Request>[];
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;

          if (path.endsWith('/auth/call/start')) {
            return _jsonResponse({
              'challenge_id': 'challenge-1',
              'expires_at': '2030-01-01T00:00:00Z',
            }, request);
          }
          if (path.endsWith('/auth/call/verify')) {
            return _jsonResponse(_tokens, request);
          }
          if (path.endsWith('/sports')) {
            return _jsonResponse([_sport], request);
          }
          if (path.endsWith('/venues')) {
            return _jsonResponse([_venue], request);
          }
          if (path.endsWith('/me') && request.method == 'GET') {
            return _jsonResponse(_user, request);
          }
          if (path.endsWith('/bookings') && request.method == 'GET') {
            return _jsonResponse(<Object?>[], request);
          }
          if (path.endsWith('/games') && request.method == 'GET') {
            return _jsonResponse(<Object?>[], request);
          }
          if (path.endsWith('/venues/luzhniki/locks')) {
            return _jsonResponse(
              {
                'id': '9d0dd623-296d-44ee-8989-5c2f4ad99b53',
                'time_slot': _slot,
                'expires_at': '2026-08-01T18:05:00Z',
              },
              request,
              statusCode: 201,
            );
          }
          if (path.endsWith('/bookings/${_booking['id']}/cancel')) {
            return _jsonResponse({..._booking, 'status': 'cancelled'}, request);
          }
          if (path.endsWith('/bookings') && request.method == 'POST') {
            return _jsonResponse(_booking, request, statusCode: 201);
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );
      addTearDown(client.close);
      final controller = AppController(now: DateTime(2026, 8, 1), api: client);
      addTearDown(controller.dispose);

      await controller.startPhoneVerification('+7 (900) 000-00-00');
      await controller.signIn('+7 (900) 000-00-00', '1234');

      expect(controller.isSignedIn, isTrue);
      expect(controller.userId, _user['id']);
      expect(controller.sports.single.id, 'football');
      expect(controller.venues.single.id, 'luzhniki');
      expect(controller.selectedSportIds, {'football'});
      expect(controller.bookings, isEmpty);

      final draft = BookingDraft(
        venue: controller.venues.single,
        date: DateTime(2026, 8, 1),
        durationMinutes: 60,
        startHour: 18,
        players: 4,
        mode: PaymentMode.full,
      );
      final booking = await controller.addBooking(draft);

      expect(booking.id, _booking['id']);
      expect(booking.draft.totalPrice, 1600);
      expect(booking.status, 'подтверждена');
      expect(controller.bookings.single.id, booking.id);
      expect(controller.upcomingBookings.single.id, booking.id);

      final lockRequest = requests.firstWhere(
        (request) => request.url.path.endsWith('/locks'),
      );
      final bookingRequest = requests.lastWhere(
        (request) =>
            request.url.path.endsWith('/bookings') && request.method == 'POST',
      );
      expect(lockRequest.headers['authorization'], 'Bearer access-token');
      expect(jsonDecode(lockRequest.body), {
        'starts_at': '2026-08-01T18:00:00.000Z',
        'duration_minutes': 60,
      });
      expect(jsonDecode(bookingRequest.body), {
        'venue_id': 'luzhniki',
        'starts_at': '2026-08-01T18:00:00.000Z',
        'duration_minutes': 60,
        'players': 4,
        'payment_mode': 'full',
      });

      var notifications = 0;
      controller.addListener(() => notifications++);
      final cancelled = await controller.cancelBooking(booking);

      expect(cancelled.status, 'отменена');
      expect(cancelled.statusCode, 'cancelled');
      expect(controller.bookings.single.id, booking.id);
      expect(controller.bookings.single.status, 'отменена');
      expect(controller.upcomingBookings, isEmpty);
      expect(notifications, 1);

      final cancellationRequest = requests.last;
      expect(cancellationRequest.method, 'POST');
      expect(
        cancellationRequest.url.path,
        '/api/v1/bookings/${booking.id}/cancel',
      );
      expect(
        cancellationRequest.headers['authorization'],
        'Bearer access-token',
      );
    },
  );
}

http.Response _jsonResponse(
  Object? body,
  http.Request request, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    request: request,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

const _tokens = {
  'access_token': 'access-token',
  'refresh_token': 'refresh-token',
  'token_type': 'bearer',
  'expires_at': '2026-08-01T18:15:00Z',
};

const _sport = {
  'id': 'football',
  'name': 'футбол',
  'icon': '⚽',
  'color': '#00C853',
  'sort_order': 10,
};

const _venue = {
  'id': 'luzhniki',
  'club_id': 'luzhniki',
  'club_name': 'футбольный центр лужники',
  'city_id': 'moscow',
  'name': 'футбольный центр лужники',
  'address': 'ул. Лужники, 24',
  'geo_lat': 55.715765,
  'geo_lng': 37.553895,
  'sport_ids': ['football'],
  'capacity_min': 2,
  'capacity_max': 10,
  'base_price_per_hour': 1600,
  'rating': 4.8,
  'description': 'крытые поля',
  'cancellation_policy': 'за 24 часа',
};

const _user = {
  'id': 'ceca5c96-6c23-48c6-9c52-dfe94e5df774',
  'phone': '+79000000000',
  'name': 'Леонид',
  'last_name': null,
  'avatar_url': null,
  'birth_date': null,
  'gender': null,
  'city_id': 'moscow',
  'geo_lat': null,
  'geo_lng': null,
  'preferred_sports': [_sport],
  'created_at': '2026-08-01T10:00:00Z',
};

const _slot = {
  'id': 'dd204c94-43b7-4721-955b-fdbad6d5bd70',
  'venue_id': 'luzhniki',
  'starts_at': '2026-08-01T18:00:00Z',
  'ends_at': '2026-08-01T19:00:00Z',
  'duration_minutes': 60,
  'price': 1600,
  'status': 'booked',
  'is_available': false,
};

const _booking = {
  'id': 'a3ba40d1-33fe-4fe0-8693-3b638efef8d8',
  'organizer_id': 'ceca5c96-6c23-48c6-9c52-dfe94e5df774',
  'venue': _venue,
  'time_slot': _slot,
  'total_price': 1600,
  'players_count': 4,
  'share_price': 400,
  'payment_mode': 'full',
  'status': 'confirmed',
  'invite_token': 'booking-token',
  'expires_at': null,
  'shares': <Object?>[],
  'created_at': '2026-08-01T10:00:00Z',
};
