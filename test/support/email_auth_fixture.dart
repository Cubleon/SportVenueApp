import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/data/api_client.dart';

class EmailAuthFixture {
  EmailAuthFixture({ApiTokensChanged? onTokensChanged}) {
    client = SportVenueApiClient(
      baseUrl: 'https://api.example.test/api/v1',
      httpClient: MockClient(_respond),
      onTokensChanged: onTokensChanged,
    );
  }

  late final SportVenueApiClient client;
  final requests = <http.Request>[];
  bool catalogFails = false;
  bool startFails = false;
  int starts = 0;
  int verifications = 0;
  int verifyStatus = 200;
  String verifyError = 'email code is invalid';
  Future<void> Function()? beforeVerify;
  Future<void> Function()? beforeCatalog;

  Future<http.Response> _respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/email/start')) {
      if (startFails) return _json({'detail': 'email delivery failed'}, 503);
      starts++;
      return _json({
        'challenge_id': 'email-challenge-$starts',
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'resend_available_at': DateTime.now()
            .add(const Duration(seconds: 60))
            .toIso8601String(),
      }, 201);
    }
    if (path.endsWith('/email/verify')) {
      verifications++;
      await beforeVerify?.call();
      if (verifyStatus != 200) {
        return _json({'detail': verifyError}, verifyStatus);
      }
      return _json({
        'access_token': 'email-access',
        'refresh_token': 'email-refresh',
        'token_type': 'bearer',
        'expires_at': '2030-01-01T00:00:00Z',
      });
    }
    if (path.endsWith('/sports')) {
      await beforeCatalog?.call();
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
    if (path.endsWith('/me')) {
      return _json({
        'id': 'email-user',
        'phone': null,
        'email': 'sportvenue@gmail.com',
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
