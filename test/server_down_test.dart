import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/l10n/app_localizations.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';
import 'package:sport_venue_app/src/labels.dart';
import 'package:sport_venue_app/src/screens/home_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

/// What the app does when the server is not there: no connection, an
/// error, or no answer at all. Played against a fake server that can be
/// switched between those.
enum _State { up, offline, broken, silent }

class _Server {
  _State state = _State.up;
  final cancelled = <String>[];

  late final client = SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    requestTimeout: const Duration(milliseconds: 200),
    onTokensChanged: (tokens) =>
        tokens == null ? store.clear() : store.write(tokens),
    httpClient: MockClient(_answer),
  );

  final store = _MemoryStore()..tokens = _pair;

  Future<http.Response> _answer(http.Request request) async {
    switch (state) {
      case _State.offline:
        throw http.ClientException('Connection refused', request.url);
      case _State.broken:
        return http.Response('{"detail":"Internal Server Error"}', 500);
      case _State.silent:
        return Completer<http.Response>().future;
      case _State.up:
        break;
    }
    final path = request.url.path;
    if (path.endsWith('/cancel')) {
      cancelled.add(path);
      return _json({..._booking, 'status': 'cancelled'});
    }
    if (path.endsWith('/sports')) return _json([_sport]);
    if (path.endsWith('/venues')) return _json([_venue]);
    if (path.endsWith('/me')) return _json(_user);
    if (path.endsWith('/bookings')) return _json([_booking]);
    if (path.endsWith('/games')) return _json(<Object?>[]);
    if (path.contains('/slots')) return _json(<Object?>[]);
    return http.Response('{"detail":"not found"}', 404);
  }

  AppController controller() {
    final app = AppController(
      now: DateTime(2026, 8, 1),
      api: client,
      session: store,
    );
    addTearDown(app.dispose);
    addTearDown(client.close);
    return app;
  }
}

void main() {
  final ru = lookupL(const Locale('ru'));

  group('launching with a stored session', () {
    for (final state in [_State.offline, _State.broken, _State.silent]) {
      test('keeps the session when the server is ${state.name}', () async {
        final server = _Server()..state = state;
        final app = server.controller();

        // Straight to the main screen, still signed in: a phone with no
        // signal is not a reason to confirm the number by call again.
        expect(await app.restoreSession(), isTrue);
        expect(app.isSignedIn, isTrue);
        expect(app.loadFailed, isTrue);
        expect(server.store.tokens, isNotNull);
        expect(server.store.clears, 0);
        // Nothing made up stands in for what did not arrive.
        expect(app.venues, isEmpty);
      });
    }

    test('picks everything up once the server answers again', () async {
      final server = _Server()..state = _State.offline;
      final app = server.controller();
      await app.restoreSession();

      server.state = _State.up;
      await app.refresh();

      expect(app.loadFailed, isFalse);
      expect(app.venues.single.id, 'luzhniki');
      expect(app.bookings, hasLength(1));
    });
  });

  test('a cancellation the server never heard changes nothing', () async {
    final server = _Server();
    final app = server.controller();
    await app.restoreSession();
    final booking = app.bookings.single;

    server.state = _State.offline;
    Object? error;
    try {
      await app.cancelBooking(booking);
    } catch (caught) {
      error = caught;
    }

    expect(AppController.kindOf(error!), AppErrorKind.network);
    expect(app.bookings.single.statusCode, booking.statusCode);
    expect(server.cancelled, isEmpty);
  });

  test('errors read as sentences a player understands', () {
    final offline = ApiException(
      kind: ApiExceptionKind.network,
      message: 'Connection refused',
    );
    final text = errorTextFor(ru, offline);

    expect(text, startsWith('Нет связи'));
    expect(text, isNot(contains('запущен')));
    expect(
      errorTextFor(ru, StateError('x')),
      'Не получилось. Попробуйте ещё раз.',
    );
  });

  testWidgets('the home says the data did not load, and tries again', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final server = _Server()..state = _State.offline;
    final app = server.controller();
    await tester.runAsync(app.restoreSession);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: HomeScreen(
            controller: app,
            onOpenSearch: () {},
            onOpenGames: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final notice = find.byKey(const ValueKey('home-load-failed'));
    await tester.scrollUntilVisible(
      notice,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Not «Клубов пока нет»: the clubs did not arrive, which is different.
    expect(find.text('Клубов пока нет'), findsNothing);

    server.state = _State.up;
    await tester.tap(find.text('Повторить'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    expect(notice, findsNothing);
    expect(app.loadFailed, isFalse);
  });
}

http.Response _json(Object? body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

class _MemoryStore implements SessionStore {
  ApiTokenPair? tokens;
  int clears = 0;

  @override
  Future<ApiTokenPair?> read() async => tokens;

  @override
  Future<void> write(ApiTokenPair value) async => tokens = value;

  @override
  Future<void> clear() async {
    tokens = null;
    clears++;
  }
}

final _pair = ApiTokenPair(
  accessToken: 'stored-access',
  refreshToken: 'stored-refresh',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2030),
);

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
  'club_name': 'футбольный центр Лужники',
  'city_id': 'moscow',
  'name': 'футбольный центр Лужники',
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
  'id': 'user-1',
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
  'id': 'slot-1',
  'venue_id': 'luzhniki',
  'starts_at': '2026-08-02T18:00:00Z',
  'ends_at': '2026-08-02T19:00:00Z',
  'duration_minutes': 60,
  'price': 1600,
  'status': 'booked',
  'is_available': false,
};

const _booking = {
  'id': 'booking-1',
  'organizer_id': 'user-1',
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
