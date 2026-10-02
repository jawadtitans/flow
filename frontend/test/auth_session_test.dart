import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/core/network/api_client.dart';
import 'package:flow_app/core/storage/session_storage.dart';
import 'package:flow_app/features/auth/auth_controller.dart';
import 'package:flow_app/features/auth/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_api.dart';

void main() {
  test('server failures explain availability without exposing internals', () {
    final request = RequestOptions(path: 'auth/request-access');
    DioException failure(int status, Object data) => DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
    expect(
      authErrorMessage(failure(500, 'Internal Server Error')),
      'Flow is having a server problem. Please try again shortly.',
    );
    expect(
      authErrorMessage(failure(500, {'detail': 'database exception'})),
      'Flow is having a server problem. Please try again shortly.',
    );
    expect(
      authErrorMessage(failure(503, {'detail': 'Could not send your code.'})),
      'Could not send your code.',
    );
  });

  test('missing password endpoint explains the server update requirement', () {
    final request = RequestOptions(
      baseUrl: 'https://flow.example/api/v1/',
      path: 'auth/set-password',
    );
    final error = DioException(
      requestOptions: request,
      response: Response(
        requestOptions: request,
        statusCode: 404,
        data: {'detail': 'Not Found'},
      ),
      type: DioExceptionType.badResponse,
    );
    expect(
      authErrorMessage(error),
      'Password setup is not available on this server yet. '
      'Please try again after Flow is updated.',
    );
    expect(
      authErrorMessage(
        error.copyWith(
          response: Response(
            requestOptions: request,
            statusCode: 409,
            data: {'detail': 'A password is already set.'},
          ),
        ),
      ),
      'A password is already set.',
    );
  });

  test('missing onboarding status never sends an account directly home', () {
    final user = FlowUser.fromJson({
      'email': 'new@example.com',
      'profile_completed': true,
    });
    expect(user.onboardingCompleted, isFalse);
    expect(user.nextRoute, '/auth/onboarding');
  });

  test(
    'new signup saves password, profile, answers and completion in order',
    () async {
      final backend = FakeAuthApi(onboardingCompleted: false);
      final client = backend.client();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final auth = container.read(authControllerProvider.notifier);
      await auth.requestAccess('new@example.com');
      await auth.verifyOtp('123456');
      expect(
        container.read(authControllerProvider).user!.nextRoute,
        '/auth/set-password',
      );
      await auth.setPassword('my-new-long-password');
      expect(
        container.read(authControllerProvider).user!.nextRoute,
        '/auth/profile',
      );
      await auth.completeProfile('Amina', 'Ahmadi', DateTime(2000, 2, 29));
      expect(
        container.read(authControllerProvider).user!.nextRoute,
        '/auth/onboarding',
      );
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        '/auth/onboarding',
      );
      await auth.saveOnboarding('Instagram', [
        'Technology',
        'Other',
      ], 'Architecture');
      expect(
        container.read(authControllerProvider).user!.nextRoute,
        '/auth/introduction',
      );
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        '/auth/introduction',
      );
      await auth.saveOnboarding(
        'Instagram',
        ['Technology', 'Other'],
        'Architecture',
        completed: true,
      );
      expect(container.read(authControllerProvider).user!.nextRoute, '/today');
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        isNull,
      );
    },
  );
  test(
    'email first, passwordless OTP, profile and logout use authenticated API requests',
    () async {
      final backend = FakeAuthApi();
      final client = backend.client();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final auth = container.read(authControllerProvider.notifier);
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        '/',
      );
      expect(await auth.restore(), isTrue);
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        '/auth',
      );
      expect(await auth.requestAccess(' New@Example.com '), isTrue);
      expect(container.read(authControllerProvider).email, 'new@example.com');
      expect(container.read(authControllerProvider).hasPassword, isFalse);
      expect(await auth.verifyOtp('000000'), isFalse);
      expect(container.read(authControllerProvider).user, isNull);
      expect(await auth.verifyOtp('123456'), isTrue);
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        '/auth/set-password',
      );
      expect(await auth.setPassword('a-new-long-password'), isTrue);
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        '/auth/profile',
      );
      expect(
        await auth.completeProfile(
          ' Amina ',
          ' Ahmadi ',
          DateTime(2000, 2, 29),
        ),
        isTrue,
      );
      expect(
        authRedirect(container.read(authControllerProvider), '/today'),
        isNull,
      );
      final profile = backend.requests.firstWhere(
        (r) => r.path == 'auth/complete-profile',
      );
      expect(profile.headers['Authorization'], 'Bearer access');
      expect(profile.data, {
        'first_name': 'Amina',
        'last_name': 'Ahmadi',
        'birth_date': '2000-02-29',
      });
      expect(await auth.logout(), isTrue);
      expect(await client.storage.read(), isNull);
      expect(container.read(authControllerProvider).user, isNull);
    },
  );

  test(
    'existing password account skips onboarding and reset submits OTP plus new password',
    () async {
      final backend = FakeAuthApi(hasPassword: true, profileCompleted: true);
      final client = backend.client();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final auth = container.read(authControllerProvider.notifier);
      await auth.requestAccess('hello@flow.example');
      expect(container.read(authControllerProvider).hasPassword, isTrue);
      expect(await auth.loginPassword('wrong'), isFalse);
      expect(container.read(authControllerProvider).user, isNull);
      expect(await auth.loginPassword('correct-password'), isTrue);
      expect(
        container.read(authControllerProvider).user!.profileCompleted,
        isTrue,
      );
      await auth.forgotPassword('hello@flow.example');
      expect(
        await auth.resetPassword('123456', 'my-new-long-password'),
        isTrue,
      );
      final reset = backend.requests.firstWhere(
        (r) => r.path == 'auth/reset-password',
      );
      expect(reset.data, {
        'email': 'hello@flow.example',
        'code': '123456',
        'new_password': 'my-new-long-password',
      });
      expect(await client.storage.read(), isNull);
      expect(container.read(authControllerProvider).user, isNull);
    },
  );

  test(
    'delivery errors do not advance state and restored sessions read the server profile',
    () async {
      final backend = FakeAuthApi(profileCompleted: true)
        ..sendError = 'Try again in 15 minutes.';
      final client = backend.client();
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      final auth = container.read(authControllerProvider.notifier);
      expect(await auth.requestAccess('hello@flow.example'), isFalse);
      expect(container.read(authControllerProvider).access, isNull);
      expect(
        container.read(authControllerProvider).error,
        'Try again in 15 minutes.',
      );
      await client.storage.write('saved-refresh');
      expect(await auth.restore(), isTrue);
      expect(
        container.read(authControllerProvider).user!.profileCompleted,
        isTrue,
      );
      expect(await client.storage.read(), 'new-refresh');
    },
  );

  test(
    'concurrent 401 responses share one refresh and retry with the new access token',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      var refreshCount = 0;
      final adapter = CallbackAdapter((request) async {
        if (request.path == 'auth/refresh') {
          refreshCount++;
          if (!started.isCompleted) started.complete();
          await release.future;
          return reply({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          });
        }
        return request.headers['Authorization'] == 'Bearer new-access'
            ? reply({'ok': true})
            : reply({'detail': 'Expired'}, 401);
      });
      final client = ApiClient(
        storage: MemorySessionStorage(),
        transport: Dio()..httpClientAdapter = adapter,
      );
      addTearDown(client.close);
      await client.establish({
        'access_token': 'old-access',
        'refresh_token': 'old-refresh',
      });
      final calls = List.generate(
        3,
        (_) => client.dio.get<dynamic>('me', options: ApiClient.authenticated),
      );
      await started.future;
      release.complete();
      final responses = await Future.wait(calls);
      expect(responses.every((r) => r.statusCode == 200), isTrue);
      expect(refreshCount, 1);
      expect(await client.storage.read(), 'new-refresh');
    },
  );

  test(
    'revoked refresh clears storage and notifies the auth controller',
    () async {
      var expired = false;
      final client = ApiClient(
        storage: MemorySessionStorage(),
        transport: Dio()
          ..httpClientAdapter = CallbackAdapter(
            (_) async => reply({'detail': 'Revoked'}, 401),
          ),
      );
      addTearDown(client.close);
      client.onSessionExpired = () => expired = true;
      await client.establish({
        'access_token': 'old-access',
        'refresh_token': 'old-refresh',
      });
      await expectLater(client.refresh(), throwsA(isA<DioException>()));
      expect(await client.storage.read(), isNull);
      expect(expired, isTrue);
    },
  );

  test(
    'a refresh finishing after logout cannot recreate the session',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      final client = ApiClient(
        storage: MemorySessionStorage(),
        transport: Dio()
          ..httpClientAdapter = CallbackAdapter((_) async {
            started.complete();
            await release.future;
            return reply({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            });
          }),
      );
      addTearDown(client.close);
      await client.establish({
        'access_token': 'old-access',
        'refresh_token': 'old-refresh',
      });
      final expectation = expectLater(
        client.refresh(),
        throwsA(isA<AuthFailure>()),
      );
      await started.future;
      await client.clear();
      release.complete();
      await expectation;
      expect(await client.storage.read(), isNull);
    },
  );
}

ResponseBody reply(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class CallbackAdapter implements HttpClientAdapter {
  CallbackAdapter(this.callback);
  final Future<ResponseBody> Function(RequestOptions) callback;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => callback(options);
  @override
  void close({bool force = false}) {}
}
