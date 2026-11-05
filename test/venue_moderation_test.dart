import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';
import 'package:sport_venue_app/src/models/sport_venue_models.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/screens/moderator_dashboard_screen.dart';
import 'package:sport_venue_app/src/screens/venue_screen.dart';
import 'package:sport_venue_app/src/screens/venue_submissions_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  late _Fixture fixture;
  late AppController controller;
  setUp(() {
    fixture = _Fixture();
    controller = AppController(api: fixture.api, session: fixture.store);
  });
  tearDown(() {
    controller.dispose();
    fixture.api.close();
  });

  test(
    'moderator credentials persist a distinct role without loading player data',
    () async {
      await controller.loginModerator('  moderator  ', ' password ');
      expect(controller.isModeratorAccount, isTrue);
      expect(controller.isSignedIn, isTrue);
      expect(controller.needsProfileName, isFalse);
      expect(controller.needsClubName, isFalse);
      expect(controller.venues, isEmpty);
      expect(controller.bookings, isEmpty);
      expect(fixture.store.tokens?.accessToken, 'moderator-access');
      expect(jsonDecode(fixture.requests.first.body), {
        'login': 'moderator',
        'password': ' password ',
      });
      expect(
        fixture.requests.any(
          (r) => ['/venues', '/bookings', '/games'].any(r.url.path.endsWith),
        ),
        isFalse,
      );
    },
  );

  test('wrong credentials never establish a moderator session', () async {
    fixture.loginStatus = 401;
    await expectLater(
      controller.loginModerator('moderator', 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(controller.isSignedIn, isFalse);
    expect(fixture.api.tokens, isNull);
    expect(fixture.store.tokens, isNull);
  });

  test('logout discards a late moderator login response', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    fixture.beforeLogin = () async {
      started.complete();
      await finish.future;
    };
    final login = controller.loginModerator('moderator', 'password');
    await started.future;
    controller.logout();
    finish.complete();
    await login;
    expect(controller.isSignedIn, isFalse);
    expect(fixture.api.tokens, isNull);
    expect(fixture.store.tokens, isNull);
  });

  testWidgets(
    'separate moderator entry opens only the request queue and enforces routing',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(SportVenueApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('moderator-sign-in')));
      expect(find.text('Вход для модераторов'), findsOneWidget);
      expect(find.byKey(const ValueKey('phone-field')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('moderator-login-field')),
        'moderator',
      );
      await tester.enterText(
        find.byKey(const ValueKey('moderator-password-field')),
        'password',
      );
      await _tap(tester, find.byKey(const ValueKey('moderator-login-submit')));
      expect(find.byKey(const ValueKey('moderator-dashboard')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-first-name')), findsNothing);
      expect(find.byKey(const ValueKey('club-name-field')), findsNothing);
      expect(find.byKey(const ValueKey('home-screen')), findsNothing);
      final context = tester.element(
        find.byKey(const ValueKey('moderator-dashboard')),
      );
      GoRouter.of(context).go('/');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('moderator-dashboard')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('moderator-logout')));
      expect(controller.isSignedIn, isFalse);
      expect(
        find.byKey(const ValueKey('moderator-login-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a restored moderator goes directly to moderation without onboarding',
    (tester) async {
      _phone(tester);
      fixture.store.tokens = ApiTokenPair.fromJson(_tokens);
      await tester.pumpWidget(SportVenueApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 2700));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('moderator-dashboard')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-first-name')), findsNothing);
      expect(find.byKey(const ValueKey('club-name-field')), findsNothing);
      expect(
        fixture.requests.where((r) => r.url.path.endsWith('/login')),
        isEmpty,
      );
    },
  );

  for (final approve in [true, false]) {
    testWidgets(
      '${approve ? 'approval' : 'rejection'} removes a reviewed request and leaves the other',
      (tester) async {
        await _pump(
          tester,
          ModeratorDashboardScreen(
            api: fixture.api,
            sports: controller.sports,
            onLogout: () {},
          ),
        );
        expect(find.text('Площадка в парке'), findsOneWidget);
        expect(find.text('Дворовая площадка'), findsOneWidget);
        await _tap(
          tester,
          find.byKey(ValueKey('${approve ? 'approve' : 'reject'}-first')),
        );
        expect(find.text('Площадка в парке'), findsNothing);
        expect(find.text('Дворовая площадка'), findsOneWidget);
        expect(
          fixture.requests.last.url.path.endsWith(
            approve ? '/approve' : '/reject',
          ),
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'moderation prevents double decisions while a request is in flight',
    (tester) async {
      final gate = Completer<void>();
      fixture.beforeReview = () => gate.future;
      await _pump(
        tester,
        ModeratorDashboardScreen(
          api: fixture.api,
          sports: controller.sports,
          onLogout: () {},
        ),
      );
      final approve = find.byKey(const ValueKey('approve-first'));
      await tester.ensureVisible(approve);
      await tester.tap(approve);
      await tester.pump();
      final reject = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('reject-second')),
      );
      expect(reject.onPressed, isNull);
      expect(fixture.requests.where((r) => r.method == 'POST'), hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Площадка в парке'), findsNothing);
    },
  );

  testWidgets(
    'failed review preserves the request and permits retry; a conflict removes it',
    (tester) async {
      fixture.reviewStatus = 503;
      await _pump(
        tester,
        ModeratorDashboardScreen(
          api: fixture.api,
          sports: controller.sports,
          onLogout: () {},
        ),
      );
      await _tap(tester, find.byKey(const ValueKey('approve-first')));
      expect(find.text('Площадка в парке'), findsOneWidget);
      expect(
        find.text('Не удалось сохранить решение. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      fixture.reviewStatus = 409;
      await _tap(tester, find.byKey(const ValueKey('approve-first')));
      expect(find.text('Площадка в парке'), findsNothing);
      expect(
        find.text('Заявка уже рассмотрена другим модератором.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty queue and failed queue have distinct states with retry', (
    tester,
  ) async {
    fixture.loadFails = true;
    await _pump(
      tester,
      ModeratorDashboardScreen(
        api: fixture.api,
        sports: controller.sports,
        onLogout: () {},
      ),
    );
    expect(find.text('Нет заявок на модерацию'), findsNothing);
    expect(
      find.text('Не удалось загрузить заявки. Попробуйте ещё раз.'),
      findsOneWidget,
    );
    fixture.loadFails = false;
    fixture.rows.clear();
    await _tap(tester, find.text('Обновить заявки'));
    expect(find.text('Нет заявок на модерацию'), findsOneWidget);
  });

  testWidgets(
    'public submission validates required fields, sports, location and public confirmation',
    (tester) async {
      await _pump(
        tester,
        PublicVenueSubmissionScreen(
          api: fixture.api,
          sports: controller.sports,
        ),
      );
      await _tap(tester, find.byKey(const ValueKey('submit-public-venue')));
      expect(find.text('Отметьте площадку на карте.'), findsOneWidget);
      expect(find.text('Выберите хотя бы один вид спорта.'), findsOneWidget);
      expect(
        find.text('Подтвердите, что площадка общественная и бесплатная.'),
        findsOneWidget,
      );
      expect(find.text('Выберите покрытие'), findsOneWidget);
      expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
      expect(find.text('Цена за час'), findsNothing);
      expect(find.text('Название клуба'), findsNothing);
    },
  );

  testWidgets('author sees the statuses of their own submissions', (
    tester,
  ) async {
    fixture.rows[0]['status'] = 'approved';
    fixture.rows[1]['status'] = 'rejected';
    await _pump(tester, VenueSubmissionsScreen(controller: controller));
    expect(find.text('Одобрено · На карте'), findsOneWidget);
    expect(find.text('Отклонено'), findsOneWidget);
    expect(
      fixture.requests.last.url.path.endsWith('/venue-submissions'),
      isTrue,
    );
    expect(fixture.requests.last.url.path.contains('/moderator/'), isFalse);
  });

  testWidgets('public venue details have no paid booking or slot requests', (
    tester,
  ) async {
    final venue = Venue.fromJson(_publicVenue);
    controller.venues = [venue];
    await _pump(tester, VenueScreen(controller: controller, venue: venue));
    expect(find.text('Общественная площадка · Бесплатно'), findsOneWidget);
    expect(find.text('Свободный доступ без бронирования'), findsOneWidget);
    expect(find.byKey(const ValueKey('venue-book')), findsNothing);
    expect(fixture.requests, isEmpty);
    expect(controller.bookableVenues, isEmpty);
  });

  testWidgets('unified creation opens public submissions on a small screen', (
    tester,
  ) async {
    final demo = AppController.demo()..signInDemo();
    addTearDown(demo.dispose);
    final boot = AppBoot()
      ..ready = true
      ..onboarded = true;
    final router = buildRouter(
      controller: demo,
      boot: boot,
      restoring: Future.value(true),
    );
    addTearDown(router.dispose);
    _phone(tester);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light(),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('create-fab')));
    expect(find.text('Добавить площадку'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('add-public-venue')));
    expect(find.byType(VenueSubmissionsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'submission transport preserves all form fields and authentication',
    () async {
      fixture.api.setTokens(ApiTokenPair.fromJson(_tokens));
      final payload = <String, dynamic>{
        'name': 'Площадка',
        'address': 'Москва, Парковая, 1',
        'city_id': 'moscow',
        'geo_lat': 55.75,
        'geo_lng': 37.62,
        'sport_ids': ['football'],
        'surface': 'rubber',
        'has_lighting': true,
        'description': 'У входа в парк',
        'is_public': true,
      };
      await fixture.api.submitPublicVenue(payload);
      expect(jsonDecode(fixture.requests.single.body), payload);
      expect(
        fixture.requests.single.headers['Authorization'],
        'Bearer moderator-access',
      );
    },
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget widget) async {
  _phone(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: widget,
    ),
  );
  await tester.pumpAndSettle();
}

const _tokens = {
  'access_token': 'moderator-access',
  'refresh_token': 'moderator-refresh',
  'token_type': 'bearer',
  'expires_at': '2099-01-01T00:00:00Z',
};

final _publicVenue = <String, dynamic>{
  'id': 'public-first',
  'name': 'Площадка в парке',
  'address': 'Москва, Парковая, 1',
  'geo_lat': 55.75,
  'geo_lng': 37.62,
  'sport_ids': ['football'],
  'base_price_per_hour': 0,
  'capacity_min': 1,
  'capacity_max': 30,
  'rating': 0,
  'description': 'В парке',
  'venue_kind': 'public',
  'surface': 'rubber',
  'has_lighting': true,
};

class _MemoryStore implements SessionStore {
  ApiTokenPair? tokens;
  @override
  Future<ApiTokenPair?> read() async => tokens;
  @override
  Future<void> write(ApiTokenPair value) async {
    tokens = value;
  }

  @override
  Future<void> clear() async {
    tokens = null;
  }
}

class _Fixture {
  final store = _MemoryStore();
  final requests = <http.Request>[];
  final rows = <Map<String, dynamic>>[
    for (final (id, name) in [
      ('first', 'Площадка в парке'),
      ('second', 'Дворовая площадка'),
    ])
      {
        'id': id,
        'name': name,
        'address': 'Москва, Парковая, 1',
        'city_id': 'moscow',
        'geo_lat': 55.75,
        'geo_lng': 37.62,
        'sport_ids': ['football'],
        'surface': 'rubber',
        'has_lighting': true,
        'description': 'В парке',
        'status': 'pending',
        'created_at': '2026-11-04T10:00:00Z',
      },
  ];
  int loginStatus = 200;
  int reviewStatus = 200;
  bool loadFails = false;
  Future<void> Function()? beforeLogin;
  Future<void> Function()? beforeReview;
  late final api = SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    initialTokens: ApiTokenPair.fromJson(_tokens),
    onTokensChanged: (tokens) =>
        tokens == null ? store.clear() : store.write(tokens),
    httpClient: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.contains('/venue-submissions') &&
          request.headers['Authorization'] != 'Bearer moderator-access') {
        return _json({'detail': 'Authentication required'}, 401);
      }
      if (path.endsWith('/auth/moderator/login')) {
        await beforeLogin?.call();
        return _json(
          loginStatus == 200 ? _tokens : {'detail': 'Invalid credentials'},
          loginStatus,
        );
      }
      if (path.endsWith('/me')) {
        return _json({
          'id': 'moderator-id',
          'account_type': 'moderator',
          'preferred_sports': [],
        });
      }
      if (path.endsWith('/sports')) {
        return _json([
          {'id': 'football', 'name': 'Футбол', 'icon': '⚽', 'color': '#00C853'},
        ]);
      }
      if (request.method == 'POST' &&
          (path.endsWith('/approve') || path.endsWith('/reject'))) {
        await beforeReview?.call();
        return _json(
          reviewStatus == 200 ? rows.first : {'detail': 'Error'},
          reviewStatus,
        );
      }
      if (request.method == 'POST' && path.endsWith('/venue-submissions')) {
        return _json(rows.first, 201);
      }
      if (path.endsWith('/venue-submissions')) {
        return _json(
          loadFails ? {'detail': 'Error'} : rows,
          loadFails ? 503 : 200,
        );
      }
      throw StateError('Unexpected request: $request');
    }),
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
