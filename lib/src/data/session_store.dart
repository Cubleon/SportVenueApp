import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

/// Where the signed-in session lives between launches.
///
/// Without one of these the app forgets who is using it the moment it is
/// closed, and asks for the phone number and the call code again — which is
/// a long way to walk to look at tomorrow's free courts.
abstract class SessionStore {
  Future<ApiTokenPair?> read();

  Future<void> write(ApiTokenPair tokens);

  Future<void> clear();
}

/// The device's own protected store: the Keychain on iOS and macOS,
/// EncryptedSharedPreferences on Android, WebCrypto-wrapped local storage on
/// the web.
///
/// A refresh token is a password with a long life, so it does not belong in
/// plain preferences, where a backup or a rooted device hands it over.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore({
    // The defaults are already AES-GCM under an RSA-wrapped KeyStore key on
    // Android, which needs API 23 and up.
    this._storage = const FlutterSecureStorage(),
  });

  static const _key = 'sportvenue.session';

  final FlutterSecureStorage _storage;

  @override
  Future<ApiTokenPair?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) {
        return null;
      }
      return ApiTokenPair.fromJson(json);
    } catch (_) {
      // A session that cannot be read is a session that does not exist. The
      // app asks for the phone number again rather than refusing to start.
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(ApiTokenPair tokens) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
    } catch (_) {
      // Storage the platform will not give us costs the reader nothing now;
      // they are signed in for this run either way.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Nothing to do about it, and nothing depends on it having worked.
    }
  }
}

/// Keeps nothing. The demo build and the tests sign in every time.
class NoSessionStore implements SessionStore {
  const NoSessionStore();

  @override
  Future<ApiTokenPair?> read() async => null;

  @override
  Future<void> write(ApiTokenPair tokens) async {}

  @override
  Future<void> clear() async {}
}
