import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

void main() {
  group('API base URL', () {
    test('uses the Android emulator host for native Android', () {
      expect(
        resolveApiBaseUrl(
          configuredUrl: '',
          isWeb: false,
          targetPlatform: TargetPlatform.android,
        ),
        'http://10.0.2.2:8000/api/v1',
      );
    });

    test('uses localhost for web and desktop', () {
      expect(
        resolveApiBaseUrl(
          configuredUrl: '',
          isWeb: true,
          targetPlatform: TargetPlatform.android,
        ),
        'http://localhost:8000/api/v1',
      );
      expect(
        resolveApiBaseUrl(
          configuredUrl: '',
          isWeb: false,
          targetPlatform: TargetPlatform.macOS,
        ),
        'http://localhost:8000/api/v1',
      );
    });

    test('honors and normalizes an explicit override', () {
      expect(
        resolveApiBaseUrl(configuredUrl: ' https://api.example.test/v2/// '),
        'https://api.example.test/v2',
      );
    });
  });

  group('authentication', () {
    test(
      'call challenge starts and verification stores the token pair',
      () async {
        late http.Request capturedRequest;
        ApiTokenPair? changedTokens;
        final client = SportVenueApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((request) async {
            capturedRequest = request;
            if (request.url.path.endsWith('/call/start')) {
              return _jsonResponse({
                'challenge_id': 'challenge-1',
                'expires_at': '2030-01-01T00:00:00Z',
              }, request);
            }
            return _jsonResponse(_tokenJson('access-1', 'refresh-1'), request);
          }),
          onTokensChanged: (tokens) => changedTokens = tokens,
        );
        addTearDown(client.close);

        final challenge = await client.startPhoneCall(
          phone: '+7 900 000-00-00',
          consentAccepted: true,
        );

        expect(challenge.id, 'challenge-1');
        expect(capturedRequest.url.path, '/api/v1/auth/call/start');
        expect(jsonDecode(capturedRequest.body), {
          'phone': '+7 900 000-00-00',
          'consent_accepted': true,
        });

        final pair = await client.verifyPhoneCall(
          challengeId: challenge.id,
          code: '1234',
        );

        expect(capturedRequest.method, 'POST');
        expect(capturedRequest.url.path, '/api/v1/auth/call/verify');
        expect(capturedRequest.headers['authorization'], isNull);
        expect(jsonDecode(capturedRequest.body), {
          'challenge_id': 'challenge-1',
          'code': '1234',
        });
        expect(pair.accessToken, 'access-1');
        expect(pair.refreshToken, 'refresh-1');
        expect(client.tokens, same(pair));
        expect(changedTokens, same(pair));
      },
    );

    test('authenticated calls attach the bearer token', () async {
      late http.Request capturedRequest;
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: _tokens('access-1', 'refresh-1'),
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse({'id': 'user-1'}, request);
        }),
      );
      addTearDown(client.close);

      final me = await client.getMe();

      expect(me['id'], 'user-1');
      expect(capturedRequest.headers['authorization'], 'Bearer access-1');
    });

    test('a 401 refreshes rotating tokens and retries once', () async {
      var meCalls = 0;
      var refreshCalls = 0;
      final changedTokens = <ApiTokenPair?>[];
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: _tokens('expired-access', 'refresh-1'),
        onTokensChanged: changedTokens.add,
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            refreshCalls++;
            expect(request.headers['authorization'], isNull);
            expect(jsonDecode(request.body), {'refresh_token': 'refresh-1'});
            return _jsonResponse(_tokenJson('access-2', 'refresh-2'), request);
          }
          if (request.url.path.endsWith('/me')) {
            meCalls++;
            if (meCalls == 1) {
              expect(request.headers['authorization'], 'Bearer expired-access');
              return _jsonResponse(
                {'detail': 'access token expired'},
                request,
                statusCode: 401,
              );
            }
            expect(request.headers['authorization'], 'Bearer access-2');
            return _jsonResponse({'id': 'user-1'}, request);
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }),
      );
      addTearDown(client.close);

      final me = await client.getMe();

      expect(me['id'], 'user-1');
      expect(meCalls, 2);
      expect(refreshCalls, 1);
      expect(client.tokens?.refreshToken, 'refresh-2');
      expect(changedTokens.single?.accessToken, 'access-2');
    });

    test('an unauthorized refresh clears local tokens', () async {
      final changes = <ApiTokenPair?>[];
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: _tokens('access-1', 'invalid-refresh'),
        onTokensChanged: changes.add,
        httpClient: MockClient(
          (request) async => _jsonResponse(
            {'detail': 'invalid refresh token'},
            request,
            statusCode: 401,
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.refreshTokens(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.kind,
                'kind',
                ApiExceptionKind.authentication,
              ),
        ),
      );
      expect(client.tokens, isNull);
      expect(changes, [isNull]);
    });
  });

  group('endpoint contracts', () {
    test('catalog filters are encoded as query parameters', () async {
      late http.Request capturedRequest;
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1/',
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return _jsonResponse(<Object?>[], request);
        }),
      );
      addTearDown(client.close);

      await client.listVenues(
        cityId: 'moscow',
        sportId: 'padel',
        query: 'центр & корт',
      );

      expect(capturedRequest.url.path, '/api/v1/venues');
      expect(capturedRequest.url.queryParameters, {
        'city_id': 'moscow',
        'sport_id': 'padel',
        'q': 'центр & корт',
      });
    });

    test('preferences use the PATCH /me request shape', () async {
      late http.Request capturedRequest;
      final client = _authenticatedClient((request) async {
        capturedRequest = request;
        return _jsonResponse({'id': 'user-1'}, request);
      });
      addTearDown(client.close);

      await client.updatePreferences(['football', 'tennis']);

      expect(capturedRequest.method, 'PATCH');
      expect(capturedRequest.url.path, '/api/v1/me');
      expect(jsonDecode(capturedRequest.body), {
        'preferred_sport_ids': ['football', 'tennis'],
      });
    });

    test('booking creation sends UTC time and payment mode', () async {
      late http.Request capturedRequest;
      final client = _authenticatedClient((request) async {
        capturedRequest = request;
        return _jsonResponse({'id': 'booking-1'}, request, statusCode: 201);
      });
      addTearDown(client.close);

      await client.createBooking(
        venueId: 'venue-1',
        startsAt: DateTime.parse('2026-08-01T19:00:00+03:00'),
        durationMinutes: 90,
        players: 4,
        paymentMode: 'split',
      );

      expect(capturedRequest.url.path, '/api/v1/bookings');
      expect(jsonDecode(capturedRequest.body), {
        'venue_id': 'venue-1',
        'starts_at': '2026-08-01T16:00:00.000Z',
        'duration_minutes': 90,
        'players': 4,
        'payment_mode': 'split',
      });
    });

    test('booking cancellation posts the booking id', () async {
      late http.Request capturedRequest;
      final client = _authenticatedClient((request) async {
        capturedRequest = request;
        return _jsonResponse({
          'id': 'booking-1',
          'status': 'cancelled',
        }, request);
      });
      addTearDown(client.close);

      await client.cancelBooking('booking-1');

      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/v1/bookings/booking-1/cancel');
      expect(capturedRequest.headers['authorization'], 'Bearer access-1');
      expect(capturedRequest.body, isEmpty);
    });

    test('game creation and joining match the FastAPI paths', () async {
      final requests = <http.Request>[];
      final client = _authenticatedClient((request) async {
        requests.add(request);
        return _jsonResponse({'id': 'game-1'}, request, statusCode: 201);
      });
      addTearDown(client.close);

      await client.createGame(
        sportId: 'padel',
        venueId: 'venue-1',
        startsAt: DateTime.utc(2026, 8, 2, 18),
        durationMinutes: 60,
        capacity: 4,
        gameType: 'closed',
        genderFilter: 'any',
      );
      await client.joinGame('game-1', inviteToken: 'invite-1');

      expect(requests[0].url.path, '/api/v1/games');
      expect(jsonDecode(requests[0].body), {
        'sport_id': 'padel',
        'venue_id': 'venue-1',
        'starts_at': '2026-08-02T18:00:00.000Z',
        'duration_minutes': 60,
        'capacity': 4,
        'type': 'closed',
        'gender_filter': 'any',
      });
      expect(requests[1].url.path, '/api/v1/games/game-1/join');
      expect(jsonDecode(requests[1].body), {'invite_token': 'invite-1'});
    });

    test(
      'optional slot lock is authenticated and serializes its window',
      () async {
        late http.Request capturedRequest;
        final client = _authenticatedClient((request) async {
          capturedRequest = request;
          return _jsonResponse({'id': 'lock-1'}, request, statusCode: 201);
        });
        addTearDown(client.close);

        await client.createSlotLock(
          'venue-1',
          startsAt: DateTime.utc(2026, 8, 3, 20),
          durationMinutes: 120,
        );

        expect(capturedRequest.url.path, '/api/v1/venues/venue-1/locks');
        expect(capturedRequest.headers['authorization'], 'Bearer access-1');
        expect(jsonDecode(capturedRequest.body), {
          'starts_at': '2026-08-03T20:00:00.000Z',
          'duration_minutes': 120,
        });
      },
    );
  });

  group('response validation', () {
    test('extracts FastAPI detail into a typed exception', () async {
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient(
          (request) async => _jsonResponse(
            {'detail': 'venue not found'},
            request,
            statusCode: 404,
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.getVenue('missing'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiExceptionKind.http)
              .having((error) => error.statusCode, 'statusCode', 404)
              .having((error) => error.message, 'message', 'venue not found'),
        ),
      );
    });

    test('rejects invalid JSON on a successful response', () async {
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient(
          (request) async =>
              http.Response('<html>not json</html>', 200, request: request),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.listSports(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiExceptionKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects an object when an endpoint promises an array', () async {
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient(
          (request) async => _jsonResponse({'sports': <Object?>[]}, request),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.listSports(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Expected a JSON array from the API',
          ),
        ),
      );
    });

    test('close prevents subsequent requests', () async {
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        httpClient: MockClient(
          (request) async => _jsonResponse(<Object?>[], request),
        ),
      );

      client.close();

      await expectLater(client.listSports(), throwsA(isA<StateError>()));
    });
  });
}

SportVenueApiClient _authenticatedClient(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    initialTokens: _tokens('access-1', 'refresh-1'),
    httpClient: MockClient(handler),
  );
}

ApiTokenPair _tokens(String accessToken, String refreshToken) {
  return ApiTokenPair(
    accessToken: accessToken,
    refreshToken: refreshToken,
    tokenType: 'bearer',
    expiresAt: DateTime.utc(2099),
  );
}

Map<String, Object?> _tokenJson(String accessToken, String refreshToken) {
  return {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': 'bearer',
    'expires_at': '2099-01-01T00:00:00Z',
  };
}

http.Response _jsonResponse(
  Object? body,
  http.Request request, {
  int statusCode = 200,
}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
    request: request,
  );
}
