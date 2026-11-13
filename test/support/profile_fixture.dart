import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

class ProfileFixture {
  ProfileFixture() {
    client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      initialTokens: ApiTokenPair(
        accessToken: 'profile-access',
        refreshToken: 'profile-refresh',
        tokenType: 'bearer',
        expiresAt: DateTime(2030),
      ),
      httpClient: MockClient(_respond),
    );
  }

  late final SportVenueApiClient client;
  final requests = <http.Request>[];
  final profile = <String, dynamic>{
    'id': 'profile-user',
    'email': 'profile@example.test',
    'phone': null,
    'name': null,
    'last_name': null,
    'middle_name': null,
    'preferred_sports': [
      {'id': 'football'},
    ],
  };
  int updateStatus = 200;
  Future<void> Function()? beforeUpdate;

  Iterable<http.Request> get updates => requests.where(
    (request) => request.method == 'PATCH' && request.url.path.endsWith('/me'),
  );

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/me')) {
      if (request.method == 'PATCH') {
        await beforeUpdate?.call();
        if (updateStatus != 200) {
          return _json({'detail': 'Unavailable'}, updateStatus);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        for (final field in ['name', 'last_name', 'middle_name']) {
          if (body.containsKey(field)) {
            profile[field] = body[field] == '' ? null : body[field];
          }
        }
      }
      return _json(profile);
    }
    if (path.endsWith('/sports')) {
      return _json([
        {
          'id': 'football',
          'name': 'Футбол',
          'icon': '⚽',
          'color': '#00C853',
          'sort_order': 10,
        },
      ]);
    }
    if (path.endsWith('/venues') ||
        path.endsWith('/bookings') ||
        path.endsWith('/games')) {
      return _json([]);
    }
    throw StateError('Unexpected request: $request');
  }

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
