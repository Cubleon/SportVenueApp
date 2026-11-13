import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';

void main() {
  late _ClubAuthFixture fixture;
  late AppController controller;
  setUp(() {
    fixture = _ClubAuthFixture();
    controller = AppController(api: fixture.api, session: fixture.store);
  });
  tearDown(() {
    controller.dispose();
    fixture.api.close();
  });

  test(
    'club credentials establish a separate session without personal names',
    () async {
      await controller.loginClub('  club  ', ' password ');
      expect(jsonDecode(fixture.requests.first.body), {
        'login': 'club',
        'password': ' password ',
      });
      expect(controller.isSignedIn, isTrue);
      expect(controller.isClubAccount, isTrue);
      expect(controller.userId, 'club-account');
      expect(controller.needsClubName, isTrue);
      expect(controller.needsProfileName, isFalse);
      expect(fixture.store.tokens?.accessToken, 'club-access');
      expect(
        fixture.requests.any(
          (request) =>
              request.url.path.endsWith('/bookings') ||
              request.url.path.endsWith('/games'),
        ),
        isFalse,
      );
    },
  );

  test(
    'club name is normalized, persisted and reused on session restore',
    () async {
      await controller.loginClub('club', 'password');
      await controller.updateClubName('  Арена \n   Север  ');
      expect(controller.clubName, 'Арена Север');
      expect(controller.needsClubName, isFalse);
      expect(controller.needsProfileName, isFalse);
      final update = fixture.requests.singleWhere(
        (request) =>
            request.method == 'PATCH' &&
            request.url.path.endsWith('/club/account'),
      );
      expect(jsonDecode(update.body), {'club_name': 'Арена Север'});

      final nextFixture = _ClubAuthFixture(
        store: fixture.store,
        profile: fixture.profile,
      );
      final restored = AppController(
        api: nextFixture.api,
        session: fixture.store,
      );
      addTearDown(restored.dispose);
      addTearDown(nextFixture.api.close);
      expect(await restored.restoreSession(), isTrue);
      expect(restored.clubName, 'Арена Север');
      expect(restored.needsClubName, isFalse);
      expect(restored.needsProfileName, isFalse);
      expect(
        nextFixture.requests.any(
          (request) => request.url.path.endsWith('/login'),
        ),
        isFalse,
      );
    },
  );

  test('wrong credentials leave no authenticated or stored session', () async {
    fixture.loginStatus = 401;
    await expectLater(
      controller.loginClub('club', 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(controller.isSignedIn, isFalse);
    expect(fixture.api.tokens, isNull);
    expect(fixture.store.tokens, isNull);
    expect(fixture.requests, hasLength(1));
  });

  test(
    'club name cannot be blank and failed saving retains onboarding',
    () async {
      await controller.loginClub('club', 'password');
      await expectLater(
        controller.updateClubName('  \n  '),
        throwsArgumentError,
      );
      expect(
        fixture.requests.where((request) => request.method == 'PATCH'),
        isEmpty,
      );
      fixture.nameStatus = 503;
      await expectLater(
        controller.updateClubName('Арена'),
        throwsA(isA<ApiException>()),
      );
      expect(controller.needsClubName, isTrue);
      expect(controller.clubName, isNull);
    },
  );

  test('logout ignores a late successful credentials response', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    fixture.beforeLogin = () async {
      started.complete();
      await finish.future;
    };
    final login = controller.loginClub('club', 'password');
    await started.future;
    controller.logout();
    finish.complete();
    await login;
    expect(controller.isSignedIn, isFalse);
    expect(fixture.api.tokens, isNull);
    expect(fixture.store.tokens, isNull);
    expect(
      fixture.requests.where((request) => request.url.path.endsWith('/me')),
      isEmpty,
    );
  });

  test('logout during profile loading cannot restore a club session', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    fixture.beforeProfile = () async {
      started.complete();
      await finish.future;
    };
    final login = controller.loginClub('club', 'password');
    await started.future;
    controller.logout();
    finish.complete();
    await login;
    expect(controller.isSignedIn, isFalse);
    expect(controller.userId, isNull);
    expect(controller.clubName, isNull);
    expect(fixture.api.tokens, isNull);
    expect(fixture.store.tokens, isNull);
  });

  test('logout ignores a late club name response', () async {
    await controller.loginClub('club', 'password');
    final started = Completer<void>();
    final finish = Completer<void>();
    fixture.beforeName = () async {
      started.complete();
      await finish.future;
    };
    final save = controller.updateClubName('Арена');
    await started.future;
    controller.logout();
    finish.complete();
    await save;
    expect(controller.isSignedIn, isFalse);
    expect(controller.clubName, isNull);
    expect(fixture.api.tokens, isNull);
  });

  for (final method in ['phone', 'email']) {
    test(
      'club login supersedes a pending player $method verification',
      () async {
        if (method == 'phone') {
          await controller.startPhoneVerification('+79000000000');
        } else {
          await controller.startEmailVerification('player@example.test');
        }
        final started = Completer<void>();
        final finish = Completer<void>();
        fixture.beforeLegacyVerification = () async {
          started.complete();
          await finish.future;
        };
        final pending = method == 'phone'
            ? controller.checkPhoneVerification()
            : controller.verifyEmailCode('012345');
        await started.future;
        await controller.loginClub('club', 'password');
        finish.complete();
        await pending;
        expect(controller.isSignedIn, isTrue);
        expect(controller.isClubAccount, isTrue);
        expect(controller.phoneChallenge, isNull);
        expect(controller.emailChallenge, isNull);
        expect(fixture.api.tokens?.accessToken, 'club-access');
        expect(fixture.store.tokens?.accessToken, 'club-access');
      },
    );
  }

  test(
    'starting player auth supersedes a pending club credentials request',
    () async {
      final started = Completer<void>();
      final finish = Completer<void>();
      fixture.beforeLogin = () async {
        started.complete();
        await finish.future;
      };
      final pending = controller.loginClub('club', 'password');
      await started.future;
      await controller.startPhoneVerification('+79000000000');
      finish.complete();
      await pending;
      expect(controller.isSignedIn, isFalse);
      expect(controller.phoneChallenge, isNotNull);
      expect(fixture.api.tokens, isNull);
      expect(fixture.store.tokens, isNull);
    },
  );

  testWidgets('first club login asks for club name and opens owner dashboard', (
    tester,
  ) async {
    _phone(tester);
    await _launch(tester, controller);
    await _openClubLogin(tester);
    expect(find.byKey(const ValueKey('phone-field')), findsNothing);
    expect(find.byKey(const ValueKey('email-sign-in')), findsNothing);
    await _enterCredentials(tester);
    expect(controller.isSignedIn, isTrue);
    expect(find.byKey(const ValueKey('club-name-field')), findsOneWidget);
    _expectNoPlayerOnboarding();
    await tester.enterText(
      find.byKey(const ValueKey('club-name-field')),
      '  Арена   Север  ',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-club-name')));
    await tester.tap(find.byKey(const ValueKey('save-club-name')));
    await tester.pumpAndSettle();
    expect(controller.clubName, 'Арена Север');
    expect(find.byKey(const ValueKey('club-dashboard')), findsOneWidget);
    _expectNoPlayerOnboarding();
    await tester.tap(find.byKey(const ValueKey('club-logout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('club-login-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-screen')), findsNothing);
    expect(fixture.store.tokens, isNull);
  });

  testWidgets('wrong credentials keep the club login form without a session', (
    tester,
  ) async {
    _phone(tester);
    fixture.loginStatus = 401;
    await _launch(tester, controller);
    await _openClubLogin(tester);
    await _enterCredentials(tester, password: 'wrong');
    expect(controller.isSignedIn, isFalse);
    expect(fixture.store.tokens, isNull);
    expect(find.byKey(const ValueKey('club-login-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-name-field')), findsNothing);
    expect(find.byKey(const ValueKey('club-dashboard')), findsNothing);
  });

  for (final named in [false, true]) {
    testWidgets(
      'restored ${named ? 'named' : 'unnamed'} club never asks for FIO or sports',
      (tester) async {
        _phone(tester);
        fixture.store.tokens = ApiTokenPair.fromJson(_tokens);
        fixture.profile['club_name'] = named ? 'Сохранённый клуб' : '  ';
        await _launch(tester, controller);
        expect(controller.isClubAccount, isTrue);
        expect(controller.needsProfileName, isFalse);
        _expectNoPlayerOnboarding();
        expect(
          find.byKey(ValueKey(named ? 'club-dashboard' : 'club-name-field')),
          findsOneWidget,
        );
        if (!named) {
          await tester.tap(find.byKey(const ValueKey('club-name-logout')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('club-login-field')),
            findsOneWidget,
          );
        }
      },
    );
  }
}

void _expectNoPlayerOnboarding() {
  expect(find.byKey(const ValueKey('profile-first-name')), findsNothing);
  expect(find.byKey(const ValueKey('profile-last-name')), findsNothing);
  expect(find.byKey(const ValueKey('sports-continue')), findsNothing);
  expect(find.text('Давайте познакомимся'), findsNothing);
}

Future<void> _openClubLogin(WidgetTester tester) async {
  await tester.tap(find.text('Я клуб'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('club-login-field')), findsOneWidget);
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String password = 'password',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('club-login-field')),
    'club',
  );
  await tester.enterText(
    find.byKey(const ValueKey('club-password-field')),
    password,
  );
  await tester.ensureVisible(find.byKey(const ValueKey('club-login-submit')));
  await tester.tap(find.byKey(const ValueKey('club-login-submit')));
  await tester.pumpAndSettle();
}

Future<void> _launch(WidgetTester tester, AppController controller) async {
  await tester.pumpWidget(SportVenueApp(controller: controller));
  await tester.pump(const Duration(milliseconds: 2700));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _ClubAuthFixture {
  _ClubAuthFixture({_MemoryStore? store, Map<String, dynamic>? profile})
    : store = store ?? _MemoryStore(),
      profile =
          profile ??
          {
            'id': 'club-account',
            'account_type': 'club',
            'club_name': null,
            'name': null,
            'last_name': null,
            'middle_name': null,
            'phone': null,
            'email': null,
            'preferred_sports': [],
          };

  final _MemoryStore store;
  final Map<String, dynamic> profile;
  final requests = <http.Request>[];
  int loginStatus = 200;
  int nameStatus = 200;
  Future<void> Function()? beforeLogin;
  Future<void> Function()? beforeProfile;
  Future<void> Function()? beforeName;
  Future<void> Function()? beforeLegacyVerification;
  late final api = SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    onTokensChanged: (tokens) =>
        tokens == null ? store.clear() : store.write(tokens),
    httpClient: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/auth/call/start') ||
          path.endsWith('/auth/email/start')) {
        return _json({
          'challenge_id': 'player-challenge',
          'expires_at': '2030-01-01T00:00:00Z',
          'resend_available_at': '2030-01-01T00:00:00Z',
          'call_phone': '+78005008275',
          'call_phone_pretty': '+7 (800) 500-8275',
        }, 201);
      }
      if (path.endsWith('/auth/call/status') ||
          path.endsWith('/auth/email/verify')) {
        await beforeLegacyVerification?.call();
        final playerTokens = {..._tokens, 'access_token': 'old-player-access'};
        return path.endsWith('/status')
            ? _json({'status': 'confirmed', 'tokens': playerTokens})
            : _json(playerTokens);
      }
      if (path.endsWith('/auth/club/login')) {
        await beforeLogin?.call();
        return loginStatus == 200
            ? _json(_tokens)
            : _json({'detail': 'invalid login or password'}, loginStatus);
      }
      if (path.endsWith('/club/account')) {
        expect(request.method, 'PATCH');
        await beforeName?.call();
        if (nameStatus != 200) {
          return _json({'detail': 'Unavailable'}, nameStatus);
        }
        final name = jsonDecode(request.body)['club_name'] as String;
        profile['club_name'] = name.trim().replaceAll(RegExp(r'\s+'), ' ');
        return _json(profile);
      }
      if (path.endsWith('/me')) {
        expect(
          request.method,
          'GET',
          reason: 'Club onboarding must not update personal FIO',
        );
        await beforeProfile?.call();
        return _json(profile);
      }
      if (path.endsWith('/sports') ||
          path.endsWith('/venues') ||
          path.endsWith('/bookings') ||
          path.endsWith('/games') ||
          path.endsWith('/club/clubs')) {
        return _json([]);
      }
      throw StateError('Unexpected request: $request');
    }),
  );
}

class _MemoryStore implements SessionStore {
  ApiTokenPair? tokens;
  @override
  Future<ApiTokenPair?> read() async => tokens;
  @override
  Future<void> write(ApiTokenPair value) async => tokens = value;
  @override
  Future<void> clear() async => tokens = null;
}

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
