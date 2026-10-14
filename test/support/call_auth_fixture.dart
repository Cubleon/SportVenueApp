import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

class CallAuthFixture {
  CallAuthFixture() {
    client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient(_respond),
    );
  }

  late final SportVenueApiClient client;
  String status = 'pending';
  bool catalogFails = false;
  int starts = 0;
  int checks = 0;
  Future<void> Function()? beforeStatus;

  Future<http.Response> _respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/call/start')) {
      starts++;
      return _json({
        'challenge_id': 'challenge-$starts',
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'call_phone': '+78005008275',
        'call_phone_pretty': '+7 (800) 500-8275',
      }, 201);
    }
    if (path.endsWith('/call/status')) {
      checks++;
      await beforeStatus?.call();
      return _json({
        'status': status,
        'tokens': status == 'confirmed'
            ? {
                'access_token': 'access-token',
                'refresh_token': 'refresh-token',
                'token_type': 'bearer',
                'expires_at': '2030-01-01T00:00:00Z',
              }
            : null,
      });
    }
    if (path.endsWith('/sports')) {
      if (catalogFails) return _json({'detail': 'Unavailable'}, 503);
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
    if (path.endsWith('/me') || path.endsWith('/me/preferences')) {
      return _json({
        'id': 'user-1',
        'phone': '+79000000000',
        'preferred_sports': [],
      });
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
    headers: {'content-type': 'application/json'},
  );
}
