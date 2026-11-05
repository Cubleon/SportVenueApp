import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/screens/club_login_screen.dart';
import 'package:sport_venue_app/src/screens/club_name_setup_screen.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  testWidgets('club login validates credentials and has no public signup', (
    tester,
  ) async {
    var attempts = 0;
    await _pump(
      tester,
      ClubLoginScreen(
        onLogin: (_, _) async {
          attempts++;
          return null;
        },
        onBack: () {},
      ),
    );
    await _tap(tester, 'club-login-submit');
    expect(find.text('Введите логин'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
    expect(attempts, 0);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Регистрация'), findsNothing);
    expect(find.byKey(const ValueKey('developer-sign-in')), findsNothing);
    expect(find.byKey(const ValueKey('email-field')), findsNothing);
  });

  testWidgets('club login trims login, preserves password and allows retry', (
    tester,
  ) async {
    final calls = <(String, String)>[];
    await _pump(
      tester,
      ClubLoginScreen(
        onLogin: (login, password) async {
          calls.add((login, password));
          return calls.length == 1 ? 'Неверный логин или пароль.' : null;
        },
        onBack: () {},
      ),
    );
    await _enter(tester, 'club-login-field', '  club  ');
    await _enter(tester, 'club-password-field', '  password  ');
    expect(_passwordField(tester).obscureText, isTrue);
    await _tap(tester, 'club-password-visibility');
    expect(_passwordField(tester).obscureText, isFalse);
    await _tap(tester, 'club-login-submit');
    expect(calls, [('club', '  password  ')]);
    expect(find.text('Неверный логин или пароль.'), findsOneWidget);
    expect(_passwordField(tester).controller!.text, '  password  ');
    await _tap(tester, 'club-login-submit');
    expect(calls.length, 2);
    expect(find.text('Неверный логин или пароль.'), findsNothing);
  });

  testWidgets(
    'club login blocks duplicate requests and navigation while busy',
    (tester) async {
      final gate = Completer<String?>();
      var attempts = 0;
      var back = 0;
      await _pump(
        tester,
        ClubLoginScreen(
          onLogin: (_, _) {
            attempts++;
            return gate.future;
          },
          onBack: () => back++,
        ),
      );
      await _enter(tester, 'club-login-field', 'club');
      await _enter(tester, 'club-password-field', 'password');
      await tester.tap(find.byKey(const ValueKey('club-login-submit')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('club-login-submit')));
      await tester.tap(find.byTooltip('Назад'));
      await tester.pump();
      expect(attempts, 1);
      expect(back, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Назад'));
      expect(back, 1);
    },
  );

  testWidgets('club name setup requests only club name and cannot be skipped', (
    tester,
  ) async {
    var attempts = 0;
    await _pump(
      tester,
      ClubNameSetupScreen(
        onContinue: (_) async {
          attempts++;
          return null;
        },
        onLogout: () {},
      ),
    );
    expect(find.text('Как называется ваш клуб?'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Фамилия'), findsNothing);
    expect(find.text('Имя'), findsNothing);
    expect(find.text('Отчество'), findsNothing);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    await _tap(tester, 'save-club-name');
    expect(find.text('Введите название клуба'), findsOneWidget);
    await _enter(tester, 'club-name-field', ' Я ');
    await _tap(tester, 'save-club-name');
    expect(find.text('Минимум 2 символа'), findsOneWidget);
    expect(attempts, 0);
  });

  testWidgets(
    'club name normalizes spaces and preserves input after a failure',
    (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        ClubNameSetupScreen(
          initialName: 'Арена',
          onContinue: (name) async {
            calls.add(name);
            return calls.length == 1 ? 'Не удалось сохранить название.' : null;
          },
          onLogout: () {},
        ),
      );
      final finder = find.byKey(const ValueKey('club-name-field'));
      expect(tester.widget<TextFormField>(finder).controller!.text, 'Арена');
      await _enter(tester, 'club-name-field', '  Спортклуб   Арена  ');
      await _tap(tester, 'save-club-name');
      expect(calls, ['Спортклуб Арена']);
      expect(find.text('Не удалось сохранить название.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(finder).controller!.text,
        '  Спортклуб   Арена  ',
      );
      await _tap(tester, 'save-club-name');
      expect(calls.length, 2);
      expect(find.text('Не удалось сохранить название.'), findsNothing);
    },
  );

  testWidgets(
    'club name prevents duplicate saves and enables logout afterwards',
    (tester) async {
      final gate = Completer<String?>();
      var attempts = 0;
      var loggedOut = false;
      await _pump(
        tester,
        ClubNameSetupScreen(
          initialName: 'Арена',
          onContinue: (_) {
            attempts++;
            return gate.future;
          },
          onLogout: () => loggedOut = true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('save-club-name')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save-club-name')));
      await tester.tap(find.byKey(const ValueKey('club-name-logout')));
      await tester.pump();
      expect(attempts, 1);
      expect(loggedOut, isFalse);
      gate.complete('Не удалось сохранить название.');
      await tester.pumpAndSettle();
      await _tap(tester, 'club-name-logout');
      expect(loggedOut, isTrue);
    },
  );
}

TextField _passwordField(WidgetTester tester) => tester.widget<TextField>(
  find.descendant(
    of: find.byKey(const ValueKey('club-password-field')),
    matching: find.byType(TextField),
  ),
);

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}
