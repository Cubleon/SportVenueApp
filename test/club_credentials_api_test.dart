import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

void main() {
  test(
    'club credentials preserve password whitespace and require acceptance',
    () async {
      late http.Request captured;
      final changes = <ApiTokenPair?>[];
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        onTokensChanged: changes.add,
        httpClient: MockClient((request) async {
          captured = request;
          return _json(_tokens);
        }),
      );
      addTearDown(client.close);

      final tokens = await client.loginClub(
        login: 'club',
        password: ' password ',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/v1/auth/club/login');
      expect(captured.headers['authorization'], isNull);
      expect(jsonDecode(captured.body), {
        'login': 'club',
        'password': ' password ',
      });
      expect(tokens.accessToken, 'club-access');
      expect(client.isAuthenticated, isFalse);
      expect(changes, isEmpty);
    },
  );

  test('invalid club credentials do not authenticate the transport', () async {
    final client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient(
        (_) async => _json({'detail': 'invalid login or password'}, 401),
      ),
    );
    addTearDown(client.close);

    await expectLater(
      client.loginClub(login: 'club', password: 'wrong'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(client.tokens, isNull);
  });

  test(
    'club account name uses authenticated dedicated PATCH endpoint',
    () async {
      late http.Request captured;
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: ApiTokenPair.fromJson(_tokens),
        httpClient: MockClient((request) async {
          captured = request;
          return _json({
            'id': 'club-account',
            'account_type': 'club',
            'club_name': 'Арена Север',
          });
        }),
      );
      addTearDown(client.close);

      final profile = await client.updateClubAccountName('Арена Север');

      expect(captured.method, 'PATCH');
      expect(captured.url.path, '/api/v1/club/account');
      expect(captured.headers['authorization'], 'Bearer club-access');
      expect(jsonDecode(captured.body), {'club_name': 'Арена Север'});
      expect(profile['club_name'], 'Арена Север');
    },
  );

  test('logout prevents a late refresh from restoring stored tokens', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    final changes = <ApiTokenPair?>[];
    final client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      initialTokens: ApiTokenPair.fromJson(_tokens),
      onTokensChanged: changes.add,
      httpClient: MockClient((_) async {
        started.complete();
        await finish.future;
        return _json({..._tokens, 'access_token': 'late-access'});
      }),
    );
    addTearDown(client.close);
    final pending = client.refreshTokens();
    final rejected = expectLater(pending, _superseded);
    await started.future;
    client.clearTokens();
    finish.complete();
    await rejected;
    expect(client.tokens, isNull);
    expect(changes, [isNull]);
  });

  test(
    'late old refresh rejection cannot clear or block a new club login',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      final requests = <http.Request>[];
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: ApiTokenPair.fromJson(_tokens),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/login')) {
            return _json({
              ..._tokens,
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            });
          }
          if (jsonDecode(request.body)['refresh_token'] == 'club-refresh') {
            started.complete();
            await finish.future;
            return _json({'detail': 'old refresh expired'}, 401);
          }
          return _json({
            ..._tokens,
            'access_token': 'new-rotated-access',
            'refresh_token': 'new-rotated-refresh',
          });
        }),
      );
      addTearDown(client.close);
      final oldRefresh = client.refreshTokens();
      final oldRejected = expectLater(oldRefresh, _superseded);
      await started.future;
      client.clearTokens();
      final loginTokens = await client.loginClub(
        login: 'club',
        password: 'password',
      );
      client.setTokens(loginTokens);
      final rotated = await client.refreshTokens();
      expect(rotated.accessToken, 'new-rotated-access');
      finish.complete();
      await oldRejected;
      expect(client.tokens?.accessToken, 'new-rotated-access');
      expect(
        requests.where((request) => request.url.path.endsWith('/refresh')),
        hasLength(2),
      );
    },
  );

  test(
    'an old authenticated 401 cannot refresh a newer club session',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      var refreshCalls = 0;
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: ApiTokenPair.fromJson(_tokens),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/login')) {
            return _json({
              ..._tokens,
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            });
          }
          if (request.url.path.endsWith('/refresh')) {
            refreshCalls++;
            return _json({'detail': 'invalid refresh'}, 401);
          }
          started.complete();
          await finish.future;
          return _json({'detail': 'old access expired'}, 401);
        }),
      );
      addTearDown(client.close);
      final oldRequest = client.getMe();
      final oldRejected = expectLater(oldRequest, _superseded);
      await started.future;
      client.clearTokens();
      final loginTokens = await client.loginClub(
        login: 'club',
        password: 'password',
      );
      client.setTokens(loginTokens);
      finish.complete();
      await oldRejected;
      expect(client.tokens?.accessToken, 'new-access');
      expect(refreshCalls, 0);
    },
  );

  test(
    'concurrent expired requests reuse the refreshed session token',
    () async {
      final requestsStarted = Completer<void>();
      final releaseSecond = Completer<void>();
      var expiredCalls = 0;
      var refreshCalls = 0;
      final client = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: ApiTokenPair.fromJson(_tokens),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            refreshCalls++;
            await requestsStarted.future;
            return _json({
              ..._tokens,
              'access_token': 'rotated-access',
              'refresh_token': 'rotated-refresh',
            });
          }
          if (request.headers['authorization'] == 'Bearer club-access') {
            expiredCalls++;
            if (expiredCalls == 2) {
              requestsStarted.complete();
              await releaseSecond.future;
            }
            return _json({'detail': 'expired access'}, 401);
          }
          expect(request.headers['authorization'], 'Bearer rotated-access');
          return _json({'id': 'club-account'});
        }),
      );
      addTearDown(client.close);
      final first = client.getMe();
      final second = client.getMe();
      expect((await first)['id'], 'club-account');
      releaseSecond.complete();
      expect((await second)['id'], 'club-account');
      expect(refreshCalls, 1);
    },
  );
}

Matcher get _superseded => throwsA(
  isA<ApiException>()
      .having((error) => error.kind, 'kind', ApiExceptionKind.authentication)
      .having((error) => error.message, 'message', contains('superseded')),
);

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _tokens = {
  'access_token': 'club-access',
  'refresh_token': 'club-refresh',
  'expires_at': '2030-01-01T00:00:00Z',
  'token_type': 'bearer',
};
