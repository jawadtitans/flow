import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class FlowUser {
  const FlowUser({
    required this.email,
    required this.profileCompleted,
    this.firstName = '',
    this.lastName = '',
    this.birthDate,
  });
  final String email;
  final bool profileCompleted;
  final String firstName;
  final String lastName;
  final DateTime? birthDate;
  String get displayName => '$firstName $lastName'.trim();

  factory FlowUser.fromJson(Map<String, dynamic> data) => FlowUser(
    email: data['email'] as String,
    profileCompleted: data['profile_completed'] as bool,
    firstName: data['first_name'] as String? ?? '',
    lastName: data['last_name'] as String? ?? '',
    birthDate: data['birth_date'] == null
        ? null
        : DateTime.parse(data['birth_date'] as String),
  );
}

class AccessInfo {
  const AccessInfo({
    required this.email,
    required this.accountExists,
    required this.hasPassword,
  });
  final String email;
  final bool accountExists;
  final bool hasPassword;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

class AuthRepository {
  AuthRepository(this.client);
  final ApiClient client;

  Future<AccessInfo> requestAccess(String email) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      'auth/request-access',
      data: {'email': email.trim().toLowerCase()},
    );
    final data = response.data!;
    return AccessInfo(
      email: data['email'] as String,
      accountExists: data['account_exists'] as bool,
      hasPassword: data['has_password'] as bool,
    );
  }

  Future<FlowUser> verifyOtp(String email, String code) =>
      _signIn('auth/verify-otp', {'email': email, 'code': code});
  Future<FlowUser> loginPassword(String email, String password) =>
      _signIn('auth/login-password', {'email': email, 'password': password});

  Future<FlowUser> _signIn(String path, Map<String, dynamic> data) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      path,
      data: data,
    );
    await client.establish(response.data!);
    try {
      return await me();
    } on DioException catch (error) {
      if ([401, 403].contains(error.response?.statusCode)) rethrow;
    }
    // The auth response is sufficient to route if this optional read is offline.
    return FlowUser(
      email: data['email'] as String,
      profileCompleted: response.data!['profile_completed'] as bool,
    );
  }

  Future<FlowUser> me() async {
    final response = await client.dio.get<Map<String, dynamic>>(
      'me',
      options: ApiClient.authenticated,
    );
    return FlowUser.fromJson(response.data!);
  }

  Future<FlowUser?> restore() async {
    try {
      return await client.restore() ? await me() : null;
    } on DioException catch (error) {
      if ([401, 403].contains(error.response?.statusCode)) return null;
      rethrow;
    }
  }

  Future<void> forgotPassword(String email) async {
    await client.dio.post<void>('auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    await client.dio.post<void>(
      'auth/reset-password',
      data: {'email': email, 'code': code, 'new_password': newPassword},
    );
    await client.clear();
  }

  Future<FlowUser> completeProfile(
    String firstName,
    String lastName,
    DateTime birthday,
  ) async {
    final date =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
    final response = await client.dio.patch<Map<String, dynamic>>(
      'auth/complete-profile',
      data: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'birth_date': date,
      },
      options: ApiClient.authenticated,
    );
    return FlowUser.fromJson(response.data!);
  }

  Future<void> logout() async {
    // Keep the session if revocation cannot be confirmed; the UI offers retry.
    try {
      await client.dio.post<void>(
        'auth/logout',
        options: ApiClient.authenticated,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
    }
    await client.clear();
  }
}
