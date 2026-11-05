import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

void main() {
  test(
    'player game history includes archived venues through an authenticated query',
    () async {
      late http.Request captured;
      final api = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: _tokens,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);

      expect(await api.listGames(includeMyHistory: true), isEmpty);

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/v1/games');
      expect(captured.url.queryParameters['include_my_history'], 'true');
      expect(captured.url.queryParameters['available_only'], 'true');
      expect(captured.headers['authorization'], 'Bearer club-access');
    },
  );

  test('including archived game history requires a signed-in player', () async {
    var requests = 0;
    final api = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.listGames(includeMyHistory: true),
      throwsA(
        isA<ApiException>().having(
          (error) => error.kind,
          'kind',
          ApiExceptionKind.authentication,
        ),
      ),
    );
    expect(requests, 0);
  });

  test('public game list preserves its anonymous default query', () async {
    late http.Request captured;
    final api = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await api.listGames();

    expect(
      captured.url.queryParameters.containsKey('include_my_history'),
      isFalse,
    );
    expect(captured.headers['authorization'], isNull);
  });

  for (final resource in ['club', 'venue']) {
    Future<void> remove(SportVenueApiClient api, String id) =>
        resource == 'club'
        ? api.deleteManagedClub(id)
        : api.deleteManagedVenue(id);
    final path =
        '/api/v1/club/${resource == 'club' ? 'clubs' : 'venues'}/owned-id';

    test('delete $resource accepts empty 204 without parsing JSON', () async {
      late http.Request captured;
      final changes = <ApiTokenPair?>[];
      final api = SportVenueApiClient(
        baseUrl: 'https://api.example.test/api/v1',
        initialTokens: _tokens,
        onTokensChanged: changes.add,
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );
      addTearDown(api.close);

      await remove(api, 'owned-id');

      expect(captured.method, 'DELETE');
      expect(captured.url.path, path);
      expect(captured.headers['authorization'], 'Bearer club-access');
      expect(captured.body, isEmpty);
      expect(api.tokens, same(_tokens));
      expect(
        changes,
        isEmpty,
        reason: 'Removing a catalogue object preserves the club account',
      );
    });

    test(
      'delete $resource requires authentication before sending a request',
      () async {
        var requests = 0;
        final api = SportVenueApiClient(
          baseUrl: 'https://api.example.test/api/v1',
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('', 204);
          }),
        );
        addTearDown(api.close);

        await expectLater(
          remove(api, 'owned-id'),
          throwsA(
            isA<ApiException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  ApiExceptionKind.authentication,
                )
                .having((error) => error.statusCode, 'statusCode', 401),
          ),
        );
        expect(requests, 0);
        expect(api.tokens, isNull);
      },
    );

    for (final status in [409, 404]) {
      test(
        'delete $resource preserves a $status error and the signed-in account',
        () async {
          final detail = status == 409
              ? '$resource has active bookings or reservation locks'
              : '$resource not found';
          var requests = 0;
          final changes = <ApiTokenPair?>[];
          final api = SportVenueApiClient(
            baseUrl: 'https://api.example.test/api/v1',
            initialTokens: _tokens,
            onTokensChanged: changes.add,
            httpClient: MockClient((request) async {
              requests++;
              expect(request.method, 'DELETE');
              expect(request.url.path, path);
              return http.Response(
                jsonEncode({'detail': detail}),
                status,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          );
          addTearDown(api.close);

          await expectLater(
            remove(api, 'owned-id'),
            throwsA(
              isA<ApiException>()
                  .having((error) => error.kind, 'kind', ApiExceptionKind.http)
                  .having((error) => error.statusCode, 'statusCode', status)
                  .having((error) => error.message, 'message', detail),
            ),
          );
          expect(requests, 1);
          expect(api.tokens, same(_tokens));
          expect(changes, isEmpty);
        },
      );
    }
  }
}

final _tokens = ApiTokenPair(
  accessToken: 'club-access',
  refreshToken: 'club-refresh',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2030),
);
