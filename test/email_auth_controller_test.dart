import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_venue_app/src/data/api_client.dart';
import 'package:sport_venue_app/src/data/app_controller.dart';
import 'package:sport_venue_app/src/data/session_store.dart';

import 'support/email_auth_fixture.dart';

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

void main() {
  late EmailAuthFixture fixture;
  late AppController controller;
  setUp(() {
    fixture = EmailAuthFixture();
    controller = AppController(api: fixture.client);
  });
  tearDown(() {
    controller.dispose();
    fixture.client.close();
  });

  test(
    'sending stays signed out and verification accepts only server tokens',
    () async {
      await controller.startEmailVerification('sportvenue@gmail.com');
      expect(controller.isSignedIn, isFalse);
      expect(fixture.client.tokens, isNull);
      expect(jsonDecode(fixture.requests.first.body), {
        'email': 'sportvenue@gmail.com',
        'consent_accepted': true,
      });
      await controller.verifyEmailCode('012345');
      expect(controller.isSignedIn, isTrue);
      expect(controller.userId, 'email-user');
      expect(controller.email, 'sportvenue@gmail.com');
      expect(controller.phone, isEmpty);
      expect(fixture.client.tokens!.accessToken, 'email-access');
      expect(jsonDecode(fixture.requests[1].body), {
        'challenge_id': 'email-challenge-1',
        'code': '012345',
      });
      controller.logout();
      expect(controller.email, isEmpty);
      expect(fixture.client.tokens, isNull);
    },
  );

  test('wrong code never stores a session', () async {
    await controller.startEmailVerification('sportvenue@gmail.com');
    fixture.verifyStatus = 400;
    await expectLater(
      controller.verifyEmailCode('000000'),
      throwsA(isA<ApiException>()),
    );
    expect(controller.isSignedIn, isFalse);
    expect(fixture.client.tokens, isNull);
  });

  test(
    'catalog retry uses issued tokens without redeeming the code twice',
    () async {
      await controller.startEmailVerification('sportvenue@gmail.com');
      fixture.catalogFails = true;
      await expectLater(
        controller.verifyEmailCode('012345'),
        throwsA(isA<ApiException>()),
      );
      expect(controller.isSignedIn, isFalse);
      expect(controller.emailCodeAccepted, isTrue);
      fixture.catalogFails = false;
      await controller.verifyEmailCode('012345');
      expect(controller.isSignedIn, isTrue);
      expect(fixture.verifications, 1);
    },
  );

  test('leaving verification ignores late token responses', () async {
    await controller.startEmailVerification('sportvenue@gmail.com');
    final gate = Completer<void>();
    fixture.beforeVerify = () => gate.future;
    final verifying = controller.verifyEmailCode('012345');
    controller.cancelEmailVerification();
    gate.complete();
    await verifying;
    expect(controller.isSignedIn, isFalse);
    expect(controller.emailChallenge, isNull);
    expect(fixture.client.tokens, isNull);
  });

  test('a new email ignores confirmation of the previous email', () async {
    await controller.startEmailVerification('sportvenue@gmail.com');
    final gate = Completer<void>();
    fixture.beforeVerify = () => gate.future;
    final verifying = controller.verifyEmailCode('012345');
    await controller.startEmailVerification('another@gmail.com');
    gate.complete();
    await verifying;
    expect(controller.email, 'another@gmail.com');
    expect(controller.emailChallenge!.id, 'email-challenge-2');
    expect(controller.isSignedIn, isFalse);
    expect(fixture.client.tokens, isNull);
  });

  test(
    'canceling catalog loading clears tokens and ignores the loaded user',
    () async {
      await controller.startEmailVerification('sportvenue@gmail.com');
      final gate = Completer<void>();
      final started = Completer<void>();
      fixture.beforeCatalog = () {
        started.complete();
        return gate.future;
      };
      final verifying = controller.verifyEmailCode('012345');
      await started.future;
      controller.cancelEmailVerification();
      gate.complete();
      await verifying;
      expect(controller.isSignedIn, isFalse);
      expect(controller.userId, isNull);
      expect(fixture.client.tokens, isNull);
    },
  );

  test('a failed resend preserves the previous challenge', () async {
    await controller.startEmailVerification('sportvenue@gmail.com');
    fixture.startFails = true;
    await expectLater(
      controller.startEmailVerification('sportvenue@gmail.com'),
      throwsA(isA<ApiException>()),
    );
    expect(controller.emailChallenge!.id, 'email-challenge-1');
    await controller.verifyEmailCode('012345');
    expect(controller.isSignedIn, isTrue);
  });

  test('email tokens persist and restore an account without a phone', () async {
    final store = _MemoryStore();
    void changed(ApiTokenPair? tokens) {
      tokens == null ? store.clear() : store.write(tokens);
    }

    final loginFixture = EmailAuthFixture(onTokensChanged: changed);
    final login = AppController(api: loginFixture.client, session: store);
    addTearDown(loginFixture.client.close);
    addTearDown(login.dispose);
    await login.startEmailVerification('sportvenue@gmail.com');
    await login.verifyEmailCode('012345');
    expect(store.tokens?.accessToken, 'email-access');
    final restoreFixture = EmailAuthFixture(onTokensChanged: changed);
    final restored = AppController(api: restoreFixture.client, session: store);
    addTearDown(restoreFixture.client.close);
    addTearDown(restored.dispose);
    expect(await restored.restoreSession(), isTrue);
    expect(restored.email, 'sportvenue@gmail.com');
    expect(restored.phone, isEmpty);
    expect(restoreFixture.verifications, 0);
    restored.logout();
    expect(store.tokens, isNull);
  });

  test('offline mode cannot authenticate using an email code', () async {
    final offline = AppController();
    addTearDown(offline.dispose);
    await expectLater(
      offline.startEmailVerification('sportvenue@gmail.com'),
      throwsStateError,
    );
    expect(offline.isSignedIn, isFalse);
  });
}
