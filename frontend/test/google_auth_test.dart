import 'dart:async';

import 'package:flow_app/features/auth/auth_repository.dart';
import 'package:flow_app/features/auth/auth_controller.dart';
import 'package:flow_app/features/auth/social_auth_service.dart';
import 'package:flow_app/core/network/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_api.dart';

void main() {
  test(
    'Google exchange stores Flow refresh token and returns Flow user',
    () async {
      final api = FakeAuthApi();
      final client = api.client();
      addTearDown(client.close);

      final user = await AuthRepository(
        client,
      ).loginWithGoogle('supabase-session-access-token');

      expect(user.email, 'hello@flow.example');
      expect(await client.storage.read(), 'google-flow-refresh');
      final exchange = api.requests.singleWhere(
        (request) => request.path == 'auth/google',
      );
      expect(exchange.data, {'access_token': 'supabase-session-access-token'});
      final profile = api.requests.singleWhere(
        (request) => request.path == 'me',
      );
      expect(profile.headers['Authorization'], 'Bearer google-flow-access');
    },
  );

  test(
    'Google taps are deduplicated and Flow state waits for exchange',
    () async {
      final api = FakeAuthApi();
      final client = api.client();
      final social = FakeSocialAuthService();
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          socialAuthServiceProvider.overrideWithValue(social),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);

      final controller = container.read(authControllerProvider.notifier);
      final signIn = controller.continueWithGoogle();
      expect(container.read(authControllerProvider).busy, isTrue);
      expect(container.read(authControllerProvider).user, isNull);
      await controller.continueWithGoogle();
      expect(social.calls, 1);
      expect(api.requests, isEmpty);

      social.complete('supabase-session-access-token');
      await signIn;
      expect(
        container.read(authControllerProvider).user?.email,
        'hello@flow.example',
      );
      expect(await client.storage.read(), 'google-flow-refresh');
    },
  );

  test(
    'Google cancellation restores idle state without contacting Flow',
    () async {
      final api = FakeAuthApi();
      final client = api.client();
      final social = FakeSocialAuthService()..result = Future.value(null);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          socialAuthServiceProvider.overrideWithValue(social),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);

      await container
          .read(authControllerProvider.notifier)
          .continueWithGoogle();
      expect(container.read(authControllerProvider).busy, isFalse);
      expect(container.read(authControllerProvider).error, isNull);
      expect(container.read(authControllerProvider).user, isNull);
      expect(api.requests, isEmpty);
    },
  );

  test(
    'Google exchange failure is safe and does not establish a session',
    () async {
      final api = FakeAuthApi()..sendError = 'internal verification detail';
      final client = api.client();
      final social = FakeSocialAuthService()
        ..result = Future.value('supabase-session-access-token');
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          socialAuthServiceProvider.overrideWithValue(social),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);

      await container
          .read(authControllerProvider.notifier)
          .continueWithGoogle();
      expect(container.read(authControllerProvider).user, isNull);
      expect(await client.storage.read(), isNull);
      expect(
        container.read(authControllerProvider).error,
        'We couldn’t complete your sign-in. Please try again.',
      );
    },
  );

  test('Flow logout clears its token and signs out of Supabase', () async {
    final api = FakeAuthApi();
    final client = api.client();
    final social = FakeSocialAuthService()
      ..result = Future.value('supabase-session-access-token');
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        socialAuthServiceProvider.overrideWithValue(social),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(client.close);
    final controller = container.read(authControllerProvider.notifier);

    await controller.continueWithGoogle();
    expect(await client.storage.read(), 'google-flow-refresh');
    expect(await controller.logout(), isTrue);
    expect(await client.storage.read(), isNull);
    expect(social.signedOut, isTrue);
    expect(container.read(authControllerProvider).user, isNull);
  });
}

class FakeSocialAuthService implements SocialAuthService {
  int calls = 0;
  bool signedOut = false;
  Future<String?>? result;
  Completer<String?>? _pending;

  @override
  Future<String?> authenticateWithGoogle() {
    calls++;
    return result ?? (_pending = Completer<String?>()).future;
  }

  void complete(String? token) => _pending!.complete(token);

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  void dispose() {}
}
