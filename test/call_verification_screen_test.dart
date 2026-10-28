import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/l10n/l10n.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/screens/auth_screens.dart';
import 'package:sport_venue_app/src/theme/app_theme.dart';

void main() {
  testWidgets(
    'dialing opens only the supplied number and never confirms login',
    (tester) async {
      Uri? dialed;
      var checks = 0;
      await _pumpCall(
        tester,
        onCheck: () async {
          checks++;
          return PhoneCallStatus.pending;
        },
        openDialer: (uri) async {
          dialed = uri;
          return false;
        },
      );
      await tester.tap(find.byKey(const ValueKey('call-phone')));
      await tester.pumpAndSettle();
      expect(dialed.toString(), 'tel:+78005008275');
      expect(
        find.textContaining('Наберите указанный номер вручную'),
        findsOneWidget,
      );
      expect(find.text('Ждём ваш звонок'), findsOneWidget);
      expect(checks, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'polls stop in background, resume immediately, and stop on dispose',
    (tester) async {
      var checks = 0;
      var canceled = false;
      await _pumpCall(
        tester,
        onCheck: () async {
          checks++;
          return PhoneCallStatus.pending;
        },
        onCancel: () => canceled = true,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(checks, 1);
      _background(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 1);
      _resume(tester);
      await tester.pump();
      expect(checks, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 2);
      expect(canceled, isTrue);
    },
  );

  testWidgets(
    'only one status request can be in flight and confirmation stops polling',
    (tester) async {
      var checks = 0;
      final gate = Completer<PhoneCallStatus>();
      await _pumpCall(
        tester,
        onCheck: () {
          checks++;
          return gate.future;
        },
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 12));
      expect(checks, 1);
      gate.complete(PhoneCallStatus.confirmed);
      await tester.pumpAndSettle();
      expect(find.text('Номер подтверждён'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('wall clock expiry while backgrounded offers a new challenge', (
    tester,
  ) async {
    var now = DateTime.utc(2026);
    var checks = 0;
    await _pumpCall(
      tester,
      now: () => now,
      onCheck: () async {
        checks++;
        return PhoneCallStatus.pending;
      },
      onRestart: () async => ApiPhoneChallenge(
        id: 'replacement',
        expiresAt: now.add(const Duration(minutes: 5)),
        callPhone: '+78005553535',
        callPhonePretty: '+7 (800) 555-3535',
      ),
    );
    _background(tester);
    now = now.add(const Duration(minutes: 6));
    _resume(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('call-expired')), findsOneWidget);
    expect(find.byKey(const ValueKey('call-phone')), findsNothing);
    expect(checks, 0);
    await tester.tap(find.byKey(const ValueKey('restart-call')));
    await tester.pumpAndSettle();
    expect(find.text('+7 (800) 555-3535'), findsOneWidget);
    expect(find.byKey(const ValueKey('call-phone')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(checks, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'temporary provider failure recovers and provider expiry stops polling',
    (tester) async {
      var checks = 0;
      await _pumpCall(
        tester,
        onCheck: () async {
          checks++;
          if (checks == 1) {
            throw const ApiException(
              kind: ApiExceptionKind.network,
              message: 'offline',
            );
          }
          return PhoneCallStatus.expired;
        },
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('call-expired')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('call-expired')), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(checks, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _pumpCall(
  WidgetTester tester, {
  required Future<PhoneCallStatus> Function() onCheck,
  Future<ApiPhoneChallenge> Function()? onRestart,
  Future<bool> Function(Uri)? openDialer,
  VoidCallback? onCancel,
  DateTime Function()? now,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final clock = now ?? tester.binding.clock.now;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: CallVerificationScreen(
        phone: '+7 (900) 000-00-00',
        challenge: ApiPhoneChallenge(
          id: 'challenge',
          expiresAt: clock().add(const Duration(minutes: 5)),
          callPhone: '+78005008275',
          callPhonePretty: '+7 (800) 500-8275',
        ),
        now: clock,
        onCheck: onCheck,
        onRestart:
            onRestart ?? () async => throw StateError('Unexpected restart'),
        onBack: () {},
        onCancel: onCancel ?? () {},
        openDialer: openDialer,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void _resume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}
