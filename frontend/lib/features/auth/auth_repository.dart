import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class FlowUser {
  const FlowUser({
    required this.email,
    required this.profileCompleted,
    this.phoneNumber,
    this.phoneVerified = false,
    this.firstName = '',
    this.lastName = '',
    this.socialAuth = false,
    this.birthDate,
    this.hasPassword = false,
    this.onboardingCompleted = false,
    this.discoverySource,
    this.interests = const [],
    this.otherInterest,
    this.profilePhoto,
  });
  final String? phoneNumber;
  final bool phoneVerified;
  final String email;
  final bool profileCompleted;
  final String firstName;
  final String lastName;
  final bool socialAuth;
  final DateTime? birthDate;
  final bool hasPassword;
  final bool onboardingCompleted;
  final String? discoverySource;
  final List<String> interests;
  final String? otherInterest;
  final String? profilePhoto;
  String get nextRoute {
    if (!profileCompleted && !hasPassword && !socialAuth) {
      return '/auth/set-password';
    }
    if (!profileCompleted) return '/auth/profile';
    if (!onboardingCompleted) {
      return interests.isEmpty ? '/auth/onboarding' : '/auth/introduction';
    }
    return '/today';
  }

  String get displayName => '$firstName $lastName'.trim();

  factory FlowUser.fromJson(Map<String, dynamic> data) => FlowUser(
    email: data['email'] as String,
    phoneNumber: data['phone_number'] as String?,
    phoneVerified: data['phone_verified'] == true,
    profileCompleted: data['profile_completed'] as bool,
    hasPassword: data['has_password'] as bool? ?? false,
    onboardingCompleted: data['onboarding_completed'] as bool? ?? false,
    discoverySource: data['discovery_source'] as String?,
    interests: (data['interests'] as List? ?? []).cast<String>(),
    otherInterest: data['other_interest'] as String?,
    profilePhoto: data['profile_photo'] as String?,
    firstName: data['first_name'] as String? ?? '',
    lastName: data['last_name'] as String? ?? '',
    socialAuth: data['social_auth'] as bool? ?? false,
    birthDate: data['birth_date'] == null
        ? null
        : DateTime.parse(data['birth_date'] as String),
  );
}

class MfaChallengeRequired implements Exception {
  const MfaChallengeRequired(this.id);
  final String id;
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

  Future<FlowUser> loginWithGoogle(String supabaseAccessToken) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      'auth/google',
      data: {'access_token': supabaseAccessToken},
    );
    final data = response.data;
    if (data == null ||
        data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty ||
        data['refresh_token'] is! String ||
        (data['refresh_token'] as String).isEmpty) {
      throw const AuthFailure(
        "We couldn't complete your sign-in. Please try again.",
      );
    }
    // Resolve and validate the profile before changing the stored Flow session.
    final profile = await client.dio.get<Map<String, dynamic>>(
      'me',
      options: Options(
        headers: {'Authorization': 'Bearer ${data['access_token']}'},
      ),
    );
    final user = FlowUser.fromJson(profile.data!);
    await client.establish(data);
    return user;
  }

  Future<FlowUser> setPassword(String password) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      'auth/set-password',
      data: {'password': password},
      options: ApiClient.authenticated,
    );
    return FlowUser.fromJson(response.data!);
  }

  Future<FlowUser> saveOnboarding(
    String source,
    List<String> interests,
    String? other, {
    bool completed = false,
  }) async {
    final response = await client.dio.put<Map<String, dynamic>>(
      'me/onboarding',
      data: {
        'discovery_source': source,
        'interests': interests,
        'other_interest': other,
        'completed': completed,
      },
      options: ApiClient.authenticated,
    );
    return FlowUser.fromJson(response.data!);
  }

  Future<FlowUser> updatePhoto(String? photo) async {
    final response = await client.dio.put<Map<String, dynamic>>(
      'me/photo',
      data: {'photo': photo},
      options: ApiClient.authenticated,
    );
    return FlowUser.fromJson(response.data!);
  }

  Future<void> deleteAccount() async {
    await client.dio.delete<void>(
      'me',
      data: {'confirmation': 'Delete', 'acknowledge': true},
      options: ApiClient.authenticated,
    );
    await client.clear();
  }

  Future<FlowUser> _signIn(String path, Map<String, dynamic> data) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      path,
      data: data,
    );
    if (response.data!['mfa_required'] == true) {
      throw MfaChallengeRequired(response.data!['challenge_id'] as String);
    }
    await client.establish(response.data!);
    // Routing depends on persisted password and onboarding progress.
    return me();
  }

  Future<FlowUser> verifyMfaChallenge(String challenge, String code) =>
      _signIn('auth/mfa/verify', {'challenge_id': challenge, 'code': code});

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
