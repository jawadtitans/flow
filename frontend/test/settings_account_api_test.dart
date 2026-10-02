import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flow_app/core/network/api_client.dart';
import 'package:flow_app/core/storage/session_storage.dart';
import 'package:flow_app/features/auth/auth_controller.dart';
import 'package:flow_app/features/settings/domain/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_auth_api.dart';

class SettingsApiFixture extends FakeAuthApi {
  SettingsApiFixture() : super(hasPassword: true, profileCompleted: true);
  bool mfaRequired = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data as Map? ?? {};
    ResponseBody reply(Map<String, dynamic> body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
    switch (options.path) {
      case 'auth/login-password':
        if (mfaRequired) {
          return reply({
            'mfa_required': true,
            'challenge_id': 'server-challenge',
          });
        }
        return super.fetch(options, requestStream, cancelFuture);
      case 'auth/mfa/verify':
        if (data['code'] != '123456') {
          return reply({'detail': 'Invalid authenticator code'}, 400);
        }
        mfaRequired = false;
        return reply({
          'access_token': 'access-test',
          'refresh_token': 'refresh-test',
        });
      case 'me/phone/request':
        return reply({'verification_id': 'server-phone-challenge'});
      case 'me/phone/verify':
        if (data['verification_id'] != 'server-phone-challenge' ||
            data['code'] != '123456') {
          return reply({'detail': 'Invalid phone code'}, 400);
        }
        user['phone_number'] = '+93701234567';
        user['phone_verified'] = true;
        return reply({});
      case 'me/security/password':
        if (data['current_password'] != 'current-secret') {
          return reply({'detail': 'Current password is incorrect'}, 400);
        }
        return reply({});
      case 'auth/passkeys/register/verify':
        return reply({'detail': 'The challenge has expired'}, 410);
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

void main() {
  test('MFA login establishes no session before server verification', () async {
    final api = SettingsApiFixture()..mfaRequired = true;
    final storage = MemorySessionStorage();
    final client = ApiClient(
      baseUrl: 'http://test/api/v1/',
      storage: storage,
      transport: Dio()..httpClientAdapter = api,
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    final controller = container.read(authControllerProvider.notifier);
    await controller.requestAccess('hello@flow.example');
    expect(await controller.loginPassword('current-secret'), false);
    expect(
      container.read(authControllerProvider).mfaChallenge,
      'server-challenge',
    );
    expect(storage.token, null);
    expect(container.read(authControllerProvider).user, null);
    expect(await controller.verifyMfaLogin('000000'), false);
    expect(storage.token, null);
    expect(await controller.verifyMfaLogin('123456'), true);
    expect(storage.token, 'refresh-test');
    expect(container.read(authControllerProvider).mfaChallenge, null);
    expect(
      container.read(authControllerProvider).user?.email,
      'hello@flow.example',
    );
  });
  test(
    'phone verification updates global user only after server success and refresh',
    () async {
      final api = SettingsApiFixture();
      final client = api.client();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final auth = container.read(authControllerProvider.notifier);
      await auth.requestAccess('hello@flow.example');
      await auth.verifyOtp('123456');
      final repo = container.read(accountSettingsRepositoryProvider);
      final id = await repo.requestPhone('+93701234567');
      expect(container.read(authControllerProvider).user?.phoneVerified, false);
      await expectLater(
        repo.verifyPhone(id, '000000'),
        throwsA(isA<DioException>()),
      );
      expect(container.read(authControllerProvider).user?.phoneVerified, false);
      await repo.verifyPhone(id, '123456');
      await auth.refreshUser();
      expect(container.read(authControllerProvider).user?.phoneVerified, true);
      expect(
        container.read(authControllerProvider).user?.phoneNumber,
        '+93701234567',
      );
    },
  );
  test(
    'password and passkey server rejection never produce local success',
    () async {
      final api = SettingsApiFixture();
      final client = api.client();
      addTearDown(client.close);
      final repository = AccountSettingsRepository(client);
      await expectLater(
        repository.changePassword('wrong-current', 'new-secret'),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        repository.verifyRegistration({
          'challenge_id': 'expired',
          'credential': {},
        }),
        throwsA(isA<DioException>()),
      );
    },
  );
}
