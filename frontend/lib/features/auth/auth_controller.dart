import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import 'auth_repository.dart';

class AuthState {
  const AuthState({
    this.user,
    this.access,
    this.resetEmail = '',
    this.busy = false,
    this.error,
    this.initialized = true,
  });
  final FlowUser? user;
  final AccessInfo? access;
  final String resetEmail;
  final bool busy;
  final String? error;
  final bool initialized;
  String get email => access?.email ?? user?.email ?? '';
  bool get hasPassword => access?.hasPassword ?? false;

  AuthState copyWith({
    FlowUser? user,
    AccessInfo? access,
    String? resetEmail,
    bool? busy,
    String? error,
  }) => AuthState(
    user: user ?? this.user,
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
    state = state.copyWith(user: user);
  });

  Future<bool> loginPassword(String password) => _run(() async {
    final user = await _repository.loginPassword(state.email, password);
    state = state.copyWith(user: user);
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

  void clearError() => state = state.copyWith();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

bool isEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
