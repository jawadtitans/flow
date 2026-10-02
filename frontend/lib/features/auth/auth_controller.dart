import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'auth_repository.dart';
import '../settings/domain/passkey_service.dart';

class AuthState {
  const AuthState({
    this.user,
    this.mfaChallenge,
    this.access,
    this.resetEmail = '',
    this.busy = false,
    this.error,
    this.initialized = true,
  });
  final FlowUser? user;
  final String? mfaChallenge;
  final AccessInfo? access;
  final String resetEmail;
  final bool busy;
  final String? error;
  final bool initialized;
  String get email => access?.email ?? user?.email ?? '';
  bool get hasPassword => user?.hasPassword ?? access?.hasPassword ?? false;

  AuthState copyWith({
    FlowUser? user,
    String? mfaChallenge,
    AccessInfo? access,
    String? resetEmail,
    bool? busy,
    String? error,
  }) => AuthState(
    user: user ?? this.user,
    mfaChallenge: mfaChallenge ?? this.mfaChallenge,
    access: access ?? this.access,
    resetEmail: resetEmail ?? this.resetEmail,
    busy: busy ?? this.busy,
    error: error,
    initialized: initialized,
  );
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final client = ref.watch(apiClientProvider);
    client.onSessionExpired = () {
      state = const AuthState(
        error: 'Your session has ended. Please sign in again.',
      );
    };
    ref.onDispose(() => client.onSessionExpired = null);
    return const AuthState(initialized: false);
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    try {
      await action();
      state = state.copyWith(busy: false);
      return true;
    } on MfaChallengeRequired catch (challenge) {
      state = state.copyWith(busy: false, mfaChallenge: challenge.id);
      return false;
    } catch (error) {
      state = state.copyWith(busy: false, error: authErrorMessage(error));
      return false;
    }
  }

  Future<bool> restore() => _run(() async {
    final user = await _repository.restore();
    state = AuthState(user: user, busy: true);
  });

  Future<bool> requestAccess(String email) => _run(() async {
    final access = await _repository.requestAccess(email);
    state = AuthState(access: access, busy: true);
  });

  Future<bool> verifyOtp(String code) => _run(() async {
    final user = await _repository.verifyOtp(state.email, code);
    state = AuthState(user: user, busy: true);
  });

  Future<bool> loginPassword(String password) => _run(() async {
    final user = await _repository.loginPassword(state.email, password);
    state = AuthState(user: user, busy: true);
  });

  Future<bool> verifyMfaLogin(String code) => _run(() async {
    final challenge = state.mfaChallenge;
    if (challenge == null) {
      throw const AuthFailure('Sign in again to request a new challenge.');
    }
    final user = await _repository.verifyMfaChallenge(challenge, code);
    state = AuthState(user: user, busy: true);
  });

  Future<bool> loginPasskey() => _run(() async {
    await ref.read(passkeyServiceProvider).authenticate();
    state = AuthState(user: await _repository.me(), busy: true);
  });

  Future<bool> forgotPassword(String email) => _run(() async {
    final normalized = email.trim().toLowerCase();
    await _repository.forgotPassword(normalized);
    state = state.copyWith(resetEmail: normalized);
  });

  Future<bool> resetPassword(String code, String password) => _run(() async {
    await _repository.resetPassword(state.resetEmail, code, password);
    state = const AuthState(busy: true);
  });

  Future<bool> completeProfile(String first, String last, DateTime birthday) =>
      _run(() async {
        state = state.copyWith(
          user: await _repository.completeProfile(first, last, birthday),
        );
      });

  Future<bool> logout() => _run(() async {
    await _repository.logout();
    state = const AuthState(busy: true);
  });

  Future<bool> setPassword(String password) => _run(() async {
    state = state.copyWith(user: await _repository.setPassword(password));
  });

  Future<bool> saveOnboarding(
    String source,
    List<String> interests,
    String? other, {
    bool completed = false,
  }) => _run(() async {
    state = state.copyWith(
      user: await _repository.saveOnboarding(
        source,
        interests,
        other,
        completed: completed,
      ),
    );
  });

  Future<bool> updatePhoto(String? photo) => _run(() async {
    state = state.copyWith(user: await _repository.updatePhoto(photo));
  });

  Future<bool> deleteAccount() => _run(() async {
    await _repository.deleteAccount();
    state = const AuthState(busy: true);
  });

  Future<bool> refreshUser() => _run(() async {
    state = state.copyWith(user: await _repository.me());
  });

  Future<void> expireAfterPasswordChange() async {
    await ref.read(apiClientProvider).clear();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

bool isEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
