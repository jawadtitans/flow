import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flow_app/core/network/api_client.dart';
import 'package:flow_app/core/storage/session_storage.dart';

class FakeAuthApi implements HttpClientAdapter {
  FakeAuthApi({
    this.hasPassword = false,
    bool profileCompleted = false,
    bool onboardingCompleted = true,
  }) {
    user['profile_completed'] = profileCompleted;
    user['has_password'] = hasPassword;
    user['onboarding_completed'] = onboardingCompleted;
  }
  bool hasPassword;
  String? sendError;
  final requests = <RequestOptions>[];
  final user = <String, dynamic>{
    'email': 'hello@flow.example',
    'first_name': null,
    'last_name': null,
    'birth_date': null,
    'profile_completed': false,
    'email_verified': true,
  };

  ApiClient client() {
    final dio = Dio()..httpClientAdapter = this;
    return ApiClient(
      baseUrl: 'http://test/api/v1/',
      storage: MemorySessionStorage(),
      transport: dio,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = options.data as Map? ?? {};
    ResponseBody reply(Object? body, [int status = 200]) =>
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
    switch (options.path) {
      case 'auth/request-access':
        if (sendError != null) return reply({'detail': sendError}, 429);
        user['email'] = data['email'];
        return reply({
          'email': data['email'],
          'account_exists': hasPassword,
          'has_password': hasPassword,
        });
      case 'auth/verify-otp':
        if (data['code'] != '123456') {
          return reply({'detail': 'Invalid code. Please try again.'}, 400);
        }
        return reply({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'profile_completed': user['profile_completed'],
        });
      case 'auth/login-password':
        if (data['password'] != 'correct-password') {
          return reply({'detail': 'Invalid email or password'}, 401);
        }
        return reply({
          'access_token': 'access',
          'refresh_token': 'refresh',
          'profile_completed': user['profile_completed'],
        });
      case 'auth/google':
        if (sendError != null) return reply({'detail': sendError}, 503);
        user['social_auth'] = true;
        return reply({
          'access_token': 'google-flow-access',
          'refresh_token': 'google-flow-refresh',
          'token_type': 'bearer',
        });
      case 'auth/refresh':
        return reply({
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
        });
      case 'me':
        if (options.method == 'DELETE') return reply(null, 204);
        return reply(user);
      case 'auth/set-password':
        hasPassword = true;
        user['has_password'] = true;
        return reply(user);
      case 'me/onboarding':
        user.addAll(Map<String, dynamic>.from(data));
        user['onboarding_completed'] = data['completed'];
        return reply(user);
      case 'me/photo':
        user['profile_photo'] = data['photo'];
        return reply(user);
      case 'auth/complete-profile':
        if (!options.headers.containsKey('Authorization')) {
          return reply({'detail': 'Not authenticated'}, 401);
        }
        user.addAll(Map<String, dynamic>.from(data));
        user['profile_completed'] = true;
        return reply(user);
      case 'auth/forgot-password':
        return reply({'detail': 'Code requested'}, 202);
      case 'auth/reset-password':
        if (data['code'] != '123456') {
          return reply({'detail': 'Invalid reset code'}, 400);
        }
        return reply(null, 204);
      case 'auth/logout':
        return reply(null, 204);
      default:
        return reply({'detail': 'Unknown endpoint'}, 404);
    }
  }

  @override
  void close({bool force = false}) {}
}
