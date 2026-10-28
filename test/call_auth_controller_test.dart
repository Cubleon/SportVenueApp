import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';

import 'support/call_auth_fixture.dart';

void main() {
  late CallAuthFixture fixture;
  late AppController controller;
  setUp(() {
    fixture = CallAuthFixture();
    controller = AppController(api: fixture.client);
  });
  tearDown(() {
    controller.dispose();
    fixture.client.close();
  });

  test('pending and expired checks leave the app signed out', () async {
    await controller.startPhoneVerification('+79000000000');
    expect(controller.phoneChallenge!.callPhone, '+78005008275');
    expect(await controller.checkPhoneVerification(), PhoneCallStatus.pending);
    fixture.status = 'expired';
    expect(await controller.checkPhoneVerification(), PhoneCallStatus.expired);
    expect(controller.isSignedIn, isFalse);
    expect(fixture.client.tokens, isNull);
  });

  test(
    'confirmed call signs in and failed catalog load retries with issued tokens',
    () async {
      await controller.startPhoneVerification('+79000000000');
      fixture.status = 'confirmed';
      fixture.catalogFails = true;
      await expectLater(
        controller.checkPhoneVerification(),
        throwsA(isA<ApiException>()),
      );
      expect(controller.isSignedIn, isFalse);
      expect(fixture.client.tokens!.accessToken, 'access-token');
      fixture.catalogFails = false;
      expect(
        await controller.checkPhoneVerification(),
        PhoneCallStatus.confirmed,
      );
      expect(controller.isSignedIn, isTrue);
      expect(controller.userId, 'user-1');
      expect(fixture.checks, 1);
    },
  );

  test('leaving verification ignores a late confirmation', () async {
    await controller.startPhoneVerification('+79000000000');
    final gate = Completer<void>();
    fixture.beforeStatus = () => gate.future;
    fixture.status = 'confirmed';
    final checking = controller.checkPhoneVerification();
    controller.cancelPhoneVerification();
    gate.complete();
    await checking;
    expect(controller.isSignedIn, isFalse);
    expect(controller.phoneChallenge, isNull);
    expect(fixture.client.tokens, isNull);
  });

  test('a new phone ignores the previous challenge response', () async {
    await controller.startPhoneVerification('+79000000000');
    final gate = Completer<void>();
    fixture.beforeStatus = () => gate.future;
    fixture.status = 'confirmed';
    final checking = controller.checkPhoneVerification();
    await controller.startPhoneVerification('+79000000001');
    gate.complete();
    await checking;
    expect(controller.phone, '+79000000001');
    expect(controller.phoneChallenge!.id, 'challenge-2');
    expect(controller.isSignedIn, isFalse);
    expect(fixture.client.tokens, isNull);
  });

  test(
    'disconnected fixture mode cannot authenticate with a demo code',
    () async {
      final offline = AppController();
      addTearDown(offline.dispose);
      await expectLater(
        offline.startPhoneVerification('+79000000000'),
        throwsStateError,
      );
      expect(offline.isSignedIn, isFalse);
    },
  );
}
