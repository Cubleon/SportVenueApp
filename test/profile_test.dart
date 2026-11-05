import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';
import 'package:sport_venue_app/src/screens/profile_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

import 'support/profile_fixture.dart';

void main() {
  late ProfileFixture fixture;
  late AppController controller;
  setUp(() async {
    fixture = ProfileFixture();
    controller = AppController(api: fixture.client);
    await controller.refresh();
  });
  tearDown(() {
    controller.dispose();
    fixture.client.close();
  });

  test(
    'saved name is restored in a new session and cleared on logout',
    () async {
      await controller.updateProfileName(
        firstName: '  Леонид ',
        lastName: ' Кубинский ',
        middleName: ' Александрович ',
      );
      expect(jsonDecode(fixture.updates.single.body), {
        'name': 'Леонид',
        'last_name': 'Кубинский',
        'middle_name': 'Александрович',
      });
      expect(
        fixture.updates.single.headers['authorization'],
        'Bearer profile-access',
      );
      final restored = AppController(
        api: fixture.client,
        session: _SavedSession(fixture.client.tokens!),
      );
      addTearDown(restored.dispose);
      expect(await restored.restoreSession(), isTrue);
      expect(restored.fullName, 'Кубинский Леонид Александрович');
      expect(restored.email, 'profile@example.test');
      expect(restored.selectedSportIds, {'football'});
      restored.logout();
      expect(restored.firstName, isNull);
      expect(restored.lastName, isNull);
      expect(restored.middleName, isNull);
      expect(restored.fullName, isNull);
    },
  );

  test(
    'a pending profile save cannot repopulate a logged-out account',
    () async {
      final started = Completer<void>();
      final gate = Completer<void>();
      fixture.beforeUpdate = () {
        started.complete();
        return gate.future;
      };
      final saving = controller.updateProfileName(
        firstName: 'Леонид',
        lastName: 'Кубинский',
      );
      await started.future;
      controller.logout();
      gate.complete();
      await saving;
      expect(controller.fullName, isNull);
      expect(controller.isSignedIn, isFalse);
    },
  );

  testWidgets('profile form saves full name and can remove patronymic', (
    tester,
  ) async {
    await _pump(tester, controller);
    await _open(tester);
    await _enter(tester, 'profile-last-name', 'Кубинский');
    await _enter(tester, 'profile-first-name', 'Леонид');
    await _enter(tester, 'profile-middle-name', 'Александрович');
    await _save(tester);
    expect(find.text('Кубинский Леонид Александрович'), findsOneWidget);
    expect(find.text('ФИО сохранено'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-first-name')), findsNothing);

    await _open(tester);
    expect(_value(tester, 'profile-first-name'), 'Леонид');
    expect(_value(tester, 'profile-last-name'), 'Кубинский');
    expect(_value(tester, 'profile-middle-name'), 'Александрович');
    await _enter(tester, 'profile-middle-name', '');
    await _save(tester);
    expect(find.text('Кубинский Леонид'), findsOneWidget);
    expect(controller.middleName, isNull);
    expect((jsonDecode(fixture.updates.last.body) as Map)['middle_name'], '');
  });

  testWidgets('invalid fields and leaving without saving do not change data', (
    tester,
  ) async {
    await _pump(tester, controller);
    await _open(tester);
    await _save(tester);
    expect(find.text('Введите фамилию'), findsOneWidget);
    expect(find.text('Введите имя'), findsOneWidget);
    expect(fixture.updates, isEmpty);
    await _enter(tester, 'profile-last-name', 'Я' * 81);
    await _enter(tester, 'profile-first-name', 'Леонид');
    await _save(tester);
    expect(find.text('Не больше 80 символов'), findsOneWidget);
    expect(fixture.updates, isEmpty);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(controller.fullName, isNull);
  });

  testWidgets('a failed save retains the form and can be retried', (
    tester,
  ) async {
    fixture.updateStatus = 503;
    await _pump(tester, controller);
    await _open(tester);
    await _enter(tester, 'profile-last-name', 'Кубинский');
    await _enter(tester, 'profile-first-name', 'Леонид');
    await _save(tester);
    expect(find.byKey(const ValueKey('profile-save-error')), findsOneWidget);
    expect(_value(tester, 'profile-last-name'), 'Кубинский');
    expect(controller.fullName, isNull);
    fixture.updateStatus = 200;
    await _save(tester);
    expect(find.text('Кубинский Леонид'), findsOneWidget);
    expect(fixture.updates.length, 2);
  });

  testWidgets('repeated taps while saving send one update', (tester) async {
    final gate = Completer<void>();
    fixture.beforeUpdate = () => gate.future;
    await _pump(tester, controller);
    await _open(tester);
    await _enter(tester, 'profile-last-name', 'Кубинский');
    await _enter(tester, 'profile-first-name', 'Леонид');
    await tester.tap(find.byKey(const ValueKey('save-profile-name')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-profile-name')));
    await tester.pump();
    expect(fixture.updates.length, 1);
    expect(find.text('Сохраняем…'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(controller.fullName, 'Кубинский Леонид');
  });
}

Future<void> _pump(WidgetTester tester, AppController controller) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: ProfileScreen(controller: controller, onLogout: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('edit-profile-name')));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('save-profile-name')));
  await tester.pumpAndSettle();
}

String _value(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(key))).controller!.text;

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
