import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';

/// A store that keeps what it is given, for the length of a test.
class _MemoryStore implements SessionStore {
  ApiTokenPair? tokens;
  int writes = 0;
  int clears = 0;

  @override
  Future<ApiTokenPair?> read() async => tokens;

  @override
  Future<void> write(ApiTokenPair value) async {
    tokens = value;
    writes++;
  }

  @override
  Future<void> clear() async {
    tokens = null;
    clears++;
  }
}

void main() {
  test('a stored session goes straight to the main screen', () async {
    final store = _MemoryStore()..tokens = _pair;
    final controller = _controllerWith(store, unauthorized: false);
    addTearDown(controller.dispose);

    expect(await controller.restoreSession(), isTrue);
    expect(controller.isSignedIn, isTrue);
    expect(controller.userId, 'user-1');
    expect(controller.venues.single.id, 'luzhniki');
  });

  test('a session the server no longer honours is dropped', () async {
    final store = _MemoryStore()..tokens = _pair;
    final controller = _controllerWith(store, unauthorized: true);
    addTearDown(controller.dispose);

    // Not an error to report: the reader signs in again, and the dead token
    // does not sit on the device waiting to fail the next launch too.
    expect(await controller.restoreSession(), isFalse);
    expect(controller.isSignedIn, isFalse);
    expect(store.tokens, isNull);
    expect(store.clears, greaterThan(0));
  });

  test('nothing stored means nothing to restore', () async {
    final store = _MemoryStore();
    final controller = _controllerWith(store, unauthorized: false);
    addTearDown(controller.dispose);

    expect(await controller.restoreSession(), isFalse);
    expect(controller.isSignedIn, isFalse);
  });

  test('signing in hands the tokens to the store', () async {
    final store = _MemoryStore();
    final controller = _controllerWith(store, unauthorized: false);
    addTearDown(controller.dispose);

    await controller.startPhoneVerification('+7 (900) 000-00-00');
    await controller.signIn('+7 (900) 000-00-00', '1234');

    expect(store.tokens?.accessToken, 'access-token');
    expect(store.writes, greaterThan(0));

    controller.logout();
    expect(store.tokens, isNull);
  });
}

AppController _controllerWith(
  SessionStore store, {
  required bool unauthorized,
}) {
  final client = SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    onTokensChanged: (tokens) =>
        tokens == null ? store.clear() : store.write(tokens),
    httpClient: MockClient((request) async {
      final path = request.url.path;
      if (unauthorized && path.endsWith('/me')) {
        return http.Response('{"detail":"expired"}', 401, headers: _json);
      }
      if (path.endsWith('/auth/call/start')) {
        return http.Response(
          '{"challenge_id":"c1","expires_at":"2030-01-01T00:00:00Z"}',
          200,
          headers: _json,
        );
      }
      if (path.endsWith('/auth/call/verify')) {
        return http.Response(_tokensJson, 200, headers: _json);
      }
      if (path.endsWith('/auth/refresh')) {
        return http.Response('{"detail":"expired"}', 401, headers: _json);
      }
      if (path.endsWith('/sports')) {
        return http.Response('[$_sportJson]', 200, headers: _json);
      }
      if (path.endsWith('/venues')) {
        return http.Response('[$_venueJson]', 200, headers: _json);
      }
      if (path.endsWith('/me')) {
        return http.Response(_userJson, 200, headers: _json);
      }
      if (path.endsWith('/bookings') || path.endsWith('/games')) {
        return http.Response('[]', 200, headers: _json);
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    }),
  );
  addTearDown(client.close);
  return AppController(now: DateTime(2026, 8, 1), api: client, session: store);
}

const _json = {'content-type': 'application/json; charset=utf-8'};

final _pair = ApiTokenPair(
  accessToken: 'stored-access',
  refreshToken: 'stored-refresh',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2030),
);

const _tokensJson =
    '{"access_token":"access-token","refresh_token":"refresh-token",'
    '"token_type":"bearer","expires_at":"2030-01-01T00:00:00Z"}';

const _sportJson =
    '{"id":"football","name":"футбол","icon":"⚽","color":"#00C853",'
    '"sort_order":10}';

const _venueJson =
    '{"id":"luzhniki","club_id":"luzhniki","club_name":"лужники",'
    '"city_id":"moscow","name":"лужники","address":"ул. Лужники, 24",'
    '"geo_lat":55.715765,"geo_lng":37.553895,"sport_ids":["football"],'
    '"capacity_min":2,"capacity_max":10,"base_price_per_hour":1600,'
    '"rating":4.8,"description":"крытые поля",'
    '"cancellation_policy":"за 24 часа"}';

const _userJson =
    '{"id":"user-1","phone":"+79000000000","name":"Миша","last_name":null,'
    '"avatar_url":null,"birth_date":null,"gender":null,"city_id":"moscow",'
    '"geo_lat":null,"geo_lng":null,"preferred_sports":[$_sportJson],'
    '"created_at":"2026-08-01T10:00:00Z"}';
