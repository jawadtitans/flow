import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../auth/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockConfiguration {
  const AppLockConfiguration({
    this.enabled = false,
    this.biometrics = false,
    this.minutes = 0,
  });
  final bool enabled, biometrics;
  final int minutes;
  bool shouldLock(Duration elapsed) =>
      enabled && elapsed >= Duration(minutes: minutes);
}

final appLockProvider =
    AsyncNotifierProvider<AppLockController, AppLockConfiguration>(
      AppLockController.new,
    );

class AppLockController extends AsyncNotifier<AppLockConfiguration> {
  final storage = const FlutterSecureStorage();
  final auth = LocalAuthentication();
  final derivation = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  );
  static const key = 'flow.app-lock.v1';
  Map<String, dynamic>? record;
  @override
  Future<AppLockConfiguration> build() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      return const AppLockConfiguration();
    }
    final raw = await storage.read(key: key);
    record = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    await captureProtection(record != null);
    return AppLockConfiguration(
      enabled: record != null,
      biometrics: record?['biometrics'] == true,
      minutes: record?['minutes'] as int? ?? 0,
    );
  }

  Future<bool> canUseBiometrics() async =>
      await auth.canCheckBiometrics &&
      (await auth.getAvailableBiometrics()).isNotEmpty;
  Future<bool> biometricUnlock() async => await auth.authenticate(
    localizedReason: 'Unlock Flow',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
  Future<String> digest(String pin, String salt) async => base64Encode(
    await (await derivation.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: base64Decode(salt),
    )).extractBytes(),
  );
  Future<void> enable(String pin, bool biometrics) async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        ].contains(defaultTargetPlatform)) {
      throw StateError('App lock requires a supported native device.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw StateError('Use a six-digit PIN.');
    }
    if (biometrics && (!await canUseBiometrics() || !await biometricUnlock())) {
      throw StateError('Biometric verification was not completed.');
    }
    final salt = base64Encode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    record = {
      'salt': salt,
      'digest': await digest(pin, salt),
      'biometrics': biometrics,
      'minutes': 0,
      'attempts': 0,
    };
    await persist();
  }

  Future<void> captureProtection(bool enabled) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await const MethodChannel(
        'flow/security',
      ).invokeMethod<void>('secure', enabled);
    }
  }

  Future<void> persist() async {
    await captureProtection(true);
    await storage.write(key: key, value: jsonEncode(record));
    state = AsyncData(
      AppLockConfiguration(
        enabled: true,
        biometrics: record!['biometrics'] == true,
        minutes: record!['minutes'] as int,
      ),
    );
  }

  Future<bool> verify(String pin) async {
    final r = record;
    if (r == null) return false;
    final until = r['retry_after'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < until) return false;
    final actual = base64Decode(await digest(pin, r['salt']));
    final expected = base64Decode(r['digest']);
    var difference = actual.length ^ expected.length;
    for (var i = 0; i < min(actual.length, expected.length); i++) {
      difference |= actual[i] ^ expected[i];
    }
    if (difference == 0) {
      r['attempts'] = 0;
      r['retry_after'] = 0;
      await persist();
      return true;
    }
    final attempts = (r['attempts'] as int? ?? 0) + 1;
    r['attempts'] = attempts;
    if (attempts >= 5) {
      r['retry_after'] = DateTime.now()
          .add(Duration(seconds: min(900, 30 * (attempts - 4))))
          .millisecondsSinceEpoch;
    }
    await persist();
    return false;
  }

  Future<void> timeout(int minutes) async {
    record!['minutes'] = minutes;
    await persist();
  }

  Future<void> recover(
    String email,
    String code, {
    String? mfaChallenge,
  }) async {
    // Only successful server verification can clear the device lock.
    final repository = ref.read(authRepositoryProvider);
    final user = mfaChallenge == null
        ? await repository.verifyOtp(email, code)
        : await repository.verifyMfaChallenge(mfaChallenge, code);
    if (user.email.toLowerCase() != email.toLowerCase()) {
      throw StateError('Account mismatch');
    }
    await storage.delete(key: key);
    await captureProtection(false);
    record = null;
    state = const AsyncData(AppLockConfiguration());
  }

  Future<void> disable(String pin) async {
    if (!await verify(pin)) throw StateError('PIN verification failed.');
    await storage.delete(key: key);
    await captureProtection(false);
    record = null;
    state = const AsyncData(AppLockConfiguration());
  }
}
