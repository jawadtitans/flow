import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStorage {
  Future<String?> read();
  Future<void> write(String refreshToken);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  static const _key = 'flow.auth.refresh';
  final _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String refreshToken) =>
      _storage.write(key: _key, value: refreshToken);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

/// The web preview keeps tokens in its tab, never in browser local storage.
/// Native builds persist only the refresh token in platform secure storage.
class MemorySessionStorage implements SessionStorage {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String refreshToken) async => token = refreshToken;
  @override
  Future<void> clear() async => token = null;
}

SessionStorage createSessionStorage() =>
    kIsWeb ? MemorySessionStorage() : SecureSessionStorage();
