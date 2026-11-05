import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';

class _DeveloperFixture {
  late final client = SportVenueApiClient(
    baseUrl: 'https://api.example.test/api/v1',
    httpClient: MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path.endsWith('/auth/dev')) {
        await beforeLogin?.call();
        if (disabled) return _json({'detail': 'Not Found'}, 404);
        return _json({
          'access_token': 'dev-access',
          'refresh_token': 'dev-refresh',
          'expires_at': '2030-01-01T00:00:00Z',
          'token_type': 'bearer',
        });
      }
      if (path.endsWith('/me') || path.endsWith('/bookings')) {
        expect(request.headers['authorization'], 'Bearer dev-access');
      }
      if (path.endsWith('/me')) {
        if (request.method == 'PATCH') {
          profile.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        }
        return _json(profile);
      }
      if (catalogFails) return _json({'detail': 'Unavailable'}, 503);
      return _json([]);
    }),
  );
  final requests = <http.Request>[];
  bool disabled = false;
  bool catalogFails = false;
  Future<void> Function()? beforeLogin;
  final profile = <String, dynamic>{
    'id': 'developer',
    'name': 'Разработчик',
    'last_name': 'Тестовый',
    'phone': null,
    'email': null,
    'preferred_sports': [],
  };
  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  late _DeveloperFixture fixture;
  late AppController controller;
  setUp(() {
    fixture = _DeveloperFixture();
    controller = AppController(api: fixture.client);
  });
  tearDown(() {
    controller.dispose();
    fixture.client.close();
  });

  testWidgets('one click without phone or consent opens home', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SportVenueApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('developer-sign-in')));
    await tester.tap(find.byKey(const ValueKey('developer-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(controller.isSignedIn, isTrue);
    expect(controller.userName, 'Разработчик Тестовый');
    expect(fixture.requests.where((r) => r.method == 'POST').length, 1);
    controller.logout();
    await tester.pumpAndSettle();
    expect(fixture.client.tokens, isNull);
    expect(find.byKey(const ValueKey('developer-sign-in')), findsOneWidget);
  });

  testWidgets('developer fills missing name once before opening home', (
    tester,
  ) async {
    fixture.profile['last_name'] = null;
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(SportVenueApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('developer-sign-in')));
    await tester.tap(find.byKey(const ValueKey('developer-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Давайте познакомимся'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('profile-first-name')),
          )
          .controller!
          .text,
      'Разработчик',
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-last-name')),
      'Тестовый',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-profile-name')));
    await tester.tap(find.byKey(const ValueKey('save-profile-name')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(find.text('Какой спорт?'), findsNothing);
    controller.logout();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('developer-sign-in')));
    await tester.tap(find.byKey(const ValueKey('developer-sign-in')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(find.text('Давайте познакомимся'), findsNothing);
  });

  test(
    'server denial and catalog failure leave no session, retry works',
    () async {
      fixture.disabled = true;
      await expectLater(
        controller.developerLogin(),
        throwsA(isA<ApiException>()),
      );
      expect(controller.isSignedIn, isFalse);
      expect(fixture.client.tokens, isNull);
      fixture.disabled = false;
      fixture.catalogFails = true;
      await expectLater(
        controller.developerLogin(),
        throwsA(isA<ApiException>()),
      );
      expect(controller.isSignedIn, isFalse);
      expect(fixture.client.tokens, isNull);
      fixture.catalogFails = false;
      await controller.developerLogin();
      expect(controller.isSignedIn, isTrue);
    },
  );

  test('logout ignores a late developer login response', () async {
    final gate = Completer<void>();
    fixture.beforeLogin = () => gate.future;
    final login = controller.developerLogin();
    controller.logout();
    gate.complete();
    await login;
    expect(controller.isSignedIn, isFalse);
    expect(fixture.client.tokens, isNull);
  });

  test('offline controller cannot use developer login', () async {
    final offline = AppController();
    addTearDown(offline.dispose);
    expect(offline.canDeveloperLogin, isFalse);
    await expectLater(offline.developerLogin(), throwsStateError);
  });
}
