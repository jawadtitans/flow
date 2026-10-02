import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => createSessionStorage(),
);
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(storage: ref.watch(sessionStorageProvider));
  ref.onDispose(client.close);
  return client;
});

String get defaultApiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  return 'https://flow-gxog.onrender.com/api/v1/';
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String authErrorMessage(Object error) {
  if (error is AuthFailure) return error.message;
  if (error is DioException) {
    if (error.error is AuthFailure) return (error.error as AuthFailure).message;
    if (error.response?.statusCode == 404 &&
        error.requestOptions.uri.path.endsWith('/auth/set-password')) {
      return 'Password setup is not available on this server yet. '
          'Please try again after Flow is updated.';
    }
    if ((error.response?.statusCode ?? 0) >= 500) {
      final data = error.response?.data;
      if (error.response?.statusCode == 503 &&
          data is Map &&
          data['detail'] is String) {
        return data['detail'] as String;
      }
      return 'Flow is having a server problem. Please try again shortly.';
    }
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (error.response?.statusCode == 422) {
      return 'Please check your details and try again.';
    }
    if (error.response == null) {
      return 'Could not reach Flow. Check your connection and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

class ApiClient {
  ApiClient({String? baseUrl, SessionStorage? storage, Dio? transport})
    : storage = storage ?? createSessionStorage(),
      dio = transport ?? Dio() {
    final url = baseUrl ?? defaultApiBaseUrl;
    dio.options = BaseOptions(
      baseUrl: url.endsWith('/') ? url : '$url/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.extra['authenticated'] == true) {
            options.extra['sessionGeneration'] ??= _generation;
            if (options.extra['sessionGeneration'] != _generation) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: const AuthFailure(
                    'Your session has changed. Please try again.',
                  ),
                ),
              );
              return;
            }
            if (_accessToken != null) {
              options.headers['Authorization'] = 'Bearer $_accessToken';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (kDebugMode) {
            debugPrint(
              'Flow API: ${request.method} ${request.uri.host}'
              '${request.uri.path} '
              'status=${error.response?.statusCode ?? "no response"} '
              'type=${error.type.name}',
            );
          }
          if (request.extra['authenticated'] == true &&
              request.extra['sessionGeneration'] != _generation) {
            handler.next(error);
            return;
          }
          if (error.response?.statusCode == 401 &&
              request.extra['authenticated'] == true &&
              request.extra['retried'] == true) {
            await _expireSession();
            handler.next(error);
            return;
          }
          if (error.response?.statusCode != 401 ||
              request.extra['authenticated'] != true ||
              request.extra['retried'] == true) {
            handler.next(error);
            return;
          }
          try {
            // A concurrent request may already have refreshed this token.
            if (_accessToken == null ||
                request.headers['Authorization'] == 'Bearer $_accessToken') {
              await refresh();
            }
            request.extra['retried'] = true;
            request.headers['Authorization'] = 'Bearer $_accessToken';
            handler.resolve(await dio.fetch<dynamic>(request));
          } on DioException catch (refreshError) {
            handler.reject(refreshError);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio dio;
  final SessionStorage storage;
  String? _accessToken;
  Future<void>? _refreshing;
  Future<void> _storageWork = Future<void>.value();
  int _generation = 0;
  VoidCallback? onSessionExpired;
  static Options get authenticated => Options(extra: {'authenticated': true});

  Future<void> establish(Map<String, dynamic> tokens) async {
    final generation = ++_generation;
    await _saveTokens(tokens, generation);
  }

  Future<void> _serializeStorage(Future<void> Function() operation) {
    final work = _storageWork.then((_) => operation());
    _storageWork = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return work;
  }

  Future<void> _saveTokens(Map<String, dynamic> tokens, int generation) =>
      _serializeStorage(() async {
        if (generation != _generation) {
          throw const AuthFailure(
            'Your session has changed. Please sign in again.',
          );
        }
        await storage.write(tokens['refresh_token'] as String);
        if (generation != _generation) {
          throw const AuthFailure(
            'Your session has changed. Please sign in again.',
          );
        }
        _accessToken = tokens['access_token'] as String;
      });

  Future<bool> restore() async {
    if (await storage.read() == null) return false;
    await refresh();
    return true;
  }

  Future<void> refresh() =>
      _refreshing ??= _rotate().whenComplete(() => _refreshing = null);

  Future<void> _rotate() async {
    final generation = _generation;
    final token = await storage.read();
    if (token == null) throw const AuthFailure('Please sign in again.');
    try {
      final result = await dio.post<Map<String, dynamic>>(
        'auth/refresh',
        data: {'refresh_token': token},
      );
      if (generation != _generation) {
        throw const AuthFailure(
          'Your session has changed. Please sign in again.',
        );
      }
      await _saveTokens(result.data!, generation);
    } on DioException catch (error) {
      if (generation == _generation &&
          [401, 403].contains(error.response?.statusCode)) {
        await _expireSession();
      }
      rethrow;
    }
  }

  Future<void> clear() async {
    _generation++;
    _accessToken = null;
    await _serializeStorage(storage.clear);
  }

  Future<void> _expireSession() async {
    try {
      await clear();
    } catch (_) {
      // The server has already revoked this token. A keychain failure must not
      // leave a failed request hanging or keep the UI signed in.
    }
    onSessionExpired?.call();
  }

  void close() => dio.close(force: true);
}

/// Keep provider and backend details out of the Google sign-in UI.
String googleAuthErrorMessage(Object error) {
  if (error is AuthFailure) return error.message;
  if (error is AuthException) {
    if (error.code == 'access_denied' || error.code == 'user_cancelled') {
      return 'Google sign-in was cancelled.';
    }
    return 'Unable to connect to Google. Please try again.';
  }
  if (error is DioException) {
    if (error.response?.statusCode == 401) {
      return 'This account is unavailable. Please contact Flow support.';
    }
    return 'We couldn’t complete your sign-in. Please try again.';
  }
  return 'We couldn’t complete your sign-in. Please try again.';
}
