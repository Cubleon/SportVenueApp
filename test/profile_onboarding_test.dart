import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';
import 'package:sport_venue_app/src/router.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

import 'support/profile_fixture.dart';

void main() {
  late ProfileFixture fixture;
  late AppController controller;
  setUp(() {
    fixture = ProfileFixture();
    controller = AppController(
      api: fixture.client,
      session: _SavedSession(fixture.client.tokens!),
    );
  });
  tearDown(() {
    controller.dispose();
    fixture.client.close();
  });

  testWidgets(
    'incomplete restored account asks once and keeps names across launches',
    (tester) async {
      _phoneSize(tester);
      await _launch(tester, controller, 'first');
      expect(find.text('Давайте познакомимся'), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byKey(const ValueKey('home-screen')), findsNothing);
      await _fill(tester);
      await _save(tester);
      expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
      expect(controller.fullName, 'Иванова Анна');
      expect(fixture.profile['last_name'], 'Иванова');

      final restored = AppController(
        api: fixture.client,
        session: _SavedSession(fixture.client.tokens!),
      );
      addTearDown(restored.dispose);
      await _launch(tester, restored, 'second');
      expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
      expect(find.text('Давайте познакомимся'), findsNothing);
      expect(restored.fullName, 'Иванова Анна');
      expect(restored.needsProfileName, isFalse);
      expect(fixture.updates.length, 1);
    },
  );

  testWidgets('validation, failed save and repeated taps keep setup pending', (
    tester,
  ) async {
    _phoneSize(tester);
    await _launch(tester, controller, 'validation');
    await _save(tester);
    expect(find.text('Введите фамилию'), findsOneWidget);
    expect(find.text('Введите имя'), findsOneWidget);
    expect(fixture.updates, isEmpty);
    await _fill(tester);
    fixture.updateStatus = 503;
    await _save(tester);
    expect(find.byKey(const ValueKey('profile-save-error')), findsOneWidget);
    expect(controller.needsProfileName, isTrue);
    expect(find.byKey(const ValueKey('home-screen')), findsNothing);

    fixture.updateStatus = 200;
    final gate = Completer<void>();
    fixture.beforeUpdate = () => gate.future;
    await tester.tap(find.byKey(const ValueKey('save-profile-name')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-profile-name')));
    await tester.pump();
    expect(fixture.updates.length, 2);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
  });

  testWidgets(
    'route guard prevents skipping setup and preserves the requested link',
    (tester) async {
      _phoneSize(tester);
      await controller.restoreSession();
      final boot = AppBoot()
        ..ready = true
        ..onboarded = true
        ..park('/game/shared-game');
      final router = buildRouter(
        controller: controller,
        boot: boot,
        restoring: Future.value(true),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        Routes.profileSetup,
      );
      router.go('/game/shared-game');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        Routes.profileSetup,
      );
      await _fill(tester);
      await _save(tester);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/game/shared-game',
      );
      router.go(Routes.profileSetup);
      await tester.pumpAndSettle();
      expect(find.text('Давайте познакомимся'), findsNothing);
    },
  );

  testWidgets('signing out from setup returns to sign-in', (tester) async {
    _phoneSize(tester);
    await _launch(tester, controller, 'logout');
    await tester.tap(find.byKey(const ValueKey('profile-setup-logout')));
    await tester.pumpAndSettle();
    expect(controller.isSignedIn, isFalse);
    expect(fixture.client.tokens, isNull);
    expect(find.byKey(const ValueKey('phone-field')), findsOneWidget);
  });
}

Future<void> _launch(
  WidgetTester tester,
  AppController controller,
  String key,
) async {
  await tester.pumpWidget(
    SportVenueApp(key: ValueKey(key), controller: controller),
  );
  await tester.pump(const Duration(milliseconds: 2700));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('profile-last-name')),
    '  Иванова  ',
  );
  await tester.enterText(
    find.byKey(const ValueKey('profile-first-name')),
    ' Анна ',
  );
  await tester.ensureVisible(find.byKey(const ValueKey('save-profile-name')));
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('save-profile-name')));
  await tester.tap(find.byKey(const ValueKey('save-profile-name')));
  await tester.pumpAndSettle();
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _SavedSession implements SessionStore {
  _SavedSession(this.tokens);
  final ApiTokenPair tokens;
  @override
  Future<ApiTokenPair?> read() async => tokens;
  @override
  Future<void> write(ApiTokenPair tokens) async {}
  @override
  Future<void> clear() async {}
}
