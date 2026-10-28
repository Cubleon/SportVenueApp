import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/app.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/screens/email_auth_screens.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

import 'support/email_auth_fixture.dart';

void main() {
  testWidgets('email code login completes onboarding and opens home', (
    tester,
  ) async {
    _phoneSize(tester);
    final fixture = EmailAuthFixture();
    final controller = AppController(api: fixture.client);
    addTearDown(controller.dispose);
    addTearDown(fixture.client.close);
    await tester.pumpWidget(SportVenueApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('email-sign-in')));
    await tester.pumpAndSettle();
    await _enter(tester, 'email-field', 'sportvenue@gmail.com');
    await tester.tap(find.byKey(const ValueKey('email-consent-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send-email-code')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Отправили код на sportvenue@gmail.com'),
      findsOneWidget,
    );
    expect(controller.isSignedIn, isFalse);
    await _enter(tester, 'email-code-field', '012345');
    await tester.tap(find.byKey(const ValueKey('verify-email-code')));
    await tester.pumpAndSettle();
    expect(find.text('Какой спорт?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sports-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-screen')), findsOneWidget);
    expect(controller.isSignedIn, isTrue);
    expect(controller.email, 'sportvenue@gmail.com');
  });

  testWidgets('email validation and consent precede sending', (tester) async {
    _phoneSize(tester);
    var sent = 0;
    await _pump(
      tester,
      EmailSignInScreen(
        onBack: () {},
        onContinue: (_) async {
          sent++;
          return null;
        },
      ),
    );
    await _enter(tester, 'email-field', 'invalid');
    await tester.tap(find.byKey(const ValueKey('send-email-code')));
    expect(sent, 0);
    await _enter(tester, 'email-field', 'user@gmail.com');
    await tester.tap(find.byKey(const ValueKey('send-email-code')));
    await tester.pumpAndSettle();
    expect(find.text('Отметьте согласие, чтобы продолжить'), findsOneWidget);
    expect(sent, 0);
    await tester.tap(find.byKey(const ValueKey('email-consent-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send-email-code')));
    await tester.pumpAndSettle();
    expect(sent, 1);
  });

  testWidgets('six digits are required and wrong codes show an error', (
    tester,
  ) async {
    var attempts = 0;
    await _pumpCode(
      tester,
      onVerify: (code) async {
        attempts++;
        expect(code, '012345');
        throw const ApiException(
          kind: ApiExceptionKind.http,
          statusCode: 400,
          message: 'email code is invalid',
        );
      },
    );
    await _enter(tester, 'email-code-field', '12345');
    await tester.tap(find.byKey(const ValueKey('verify-email-code')));
    expect(attempts, 0);
    await _enter(tester, 'email-code-field', '012345');
    await tester.tap(find.byKey(const ValueKey('verify-email-code')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.textContaining('Неверный код'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'expiry blocks verification and resend resets the field and countdown',
    (tester) async {
      var now = DateTime.utc(2026);
      var attempts = 0;
      var resends = 0;
      await _pumpCode(
        tester,
        now: () => now,
        onVerify: (_) async {
          attempts++;
        },
        onResend: () async {
          resends++;
          return ApiEmailChallenge(
            id: 'new',
            expiresAt: now.add(const Duration(minutes: 5)),
            resendAvailableAt: now.add(const Duration(seconds: 60)),
          );
        },
      );
      await _enter(tester, 'email-code-field', '012345');
      await tester.tap(find.byKey(const ValueKey('resend-email-code')));
      expect(resends, 0);
      now = now.add(const Duration(minutes: 6));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('email-code-expired')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('verify-email-code')));
      expect(attempts, 0);
      await tester.tap(find.byKey(const ValueKey('resend-email-code')));
      await tester.pumpAndSettle();
      expect(resends, 1);
      expect(find.byKey(const ValueKey('email-code-expired')), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('email-code-field')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('exhausted attempts disable entry until a new code is sent', (
    tester,
  ) async {
    await _pumpCode(
      tester,
      onVerify: (_) async {
        throw const ApiException(
          kind: ApiExceptionKind.http,
          statusCode: 429,
          message: 'email code attempts exceeded',
        );
      },
    );
    await _enter(tester, 'email-code-field', '012345');
    await tester.tap(find.byKey(const ValueKey('verify-email-code')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Слишком много неверных попыток'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('email-code-field')))
          .enabled,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpCode(
  WidgetTester tester, {
  required Future<void> Function(String) onVerify,
  DateTime Function()? now,
  Future<ApiEmailChallenge> Function()? onResend,
}) async {
  _phoneSize(tester);
  final clock = now ?? tester.binding.clock.now;
  await _pump(
    tester,
    EmailVerificationScreen(
      email: 'sportvenue@gmail.com',
      challenge: ApiEmailChallenge(
        id: 'challenge',
        expiresAt: clock().add(const Duration(minutes: 5)),
        resendAvailableAt: clock().add(const Duration(seconds: 60)),
      ),
      onVerify: onVerify,
      onResend: onResend ?? () async => throw StateError('Unexpected resend'),
      onBack: () {},
      onCancel: () {},
      now: clock,
    ),
  );
}
