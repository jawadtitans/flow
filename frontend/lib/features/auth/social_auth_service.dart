import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';

const googleAuthRedirect = 'com.flow.app://login-callback/';

final socialAuthServiceProvider = Provider<SocialAuthService>((ref) {
  final service = SupabaseSocialAuthService(Supabase.instance.client);
  ref.onDispose(service.dispose);
  return service;
});

abstract interface class SocialAuthService {
  Future<String?> authenticateWithGoogle();
  Future<void> signOut();
  void dispose();
}

/// Supabase is only an identity broker; Flow owns the application session.
class SupabaseSocialAuthService
    with WidgetsBindingObserver
    implements SocialAuthService {
  SupabaseSocialAuthService(
    this._supabase, {
    this.timeout = const Duration(minutes: 3),
    this.resumeGracePeriod = const Duration(seconds: 10),
  });

  final SupabaseClient _supabase;
  final Duration timeout;
  final Duration resumeGracePeriod;
  Completer<String?>? _pending;
  Timer? _resumeTimer;
  bool _leftApp = false;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<void> continueWithGoogle() async {
    final launched = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: googleAuthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
    if (!launched) {
      throw const AuthFailure('Unable to connect to Google. Please try again.');
    }
  }

  /// Listen before launching so a fast callback cannot be missed. Only an
  /// explicit attempt accepts events; restored and late sessions never log in.
  @override
  Future<String?> authenticateWithGoogle() async {
    if (_pending != null) return null;
    final pending = _pending = Completer<String?>();
    _leftApp = false;
    WidgetsBinding.instance.addObserver(this);
    final subscription = authStateChanges.listen(
      (event) {
        if (pending.isCompleted || event.event != AuthChangeEvent.signedIn) {
          return;
        }
        final token = event.session?.accessToken;
        if (token == null || token.isEmpty) {
          pending.completeError(
            const AuthFailure(
              "We couldn't complete your sign-in. Please try again.",
            ),
          );
        } else {
          pending.complete(token);
        }
      },
      onError: (Object error) {
        if (pending.isCompleted) return;
        if (error is AuthException &&
            (error.code == 'access_denied' || error.code == 'user_cancelled')) {
          pending.complete(null);
        } else {
          pending.completeError(
            const AuthFailure('Unable to connect to Google. Please try again.'),
          );
        }
      },
    );
    final timer = Timer(timeout, () {
      if (!pending.isCompleted) {
        pending.completeError(
          const AuthFailure('Google sign-in timed out. Please try again.'),
        );
      }
    });
    // Attach error handling before launch, which itself may be asynchronous.
    final result = pending.future;
    unawaited(result.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    try {
      await continueWithGoogle();
      return await result;
    } finally {
      timer.cancel();
      _resumeTimer?.cancel();
      await subscription.cancel();
      WidgetsBinding.instance.removeObserver(this);
      _pending = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftApp = true;
      _resumeTimer?.cancel();
    }
    if (state == AppLifecycleState.resumed && _leftApp) {
      _resumeTimer?.cancel();
      // External browsers don't report closing. Allow PKCE callback processing
      // to finish before treating a return without a session as cancellation.
      _resumeTimer = Timer(resumeGracePeriod, cancelGoogle);
    }
  }

  void cancelGoogle() {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(null);
  }

  @override
  Future<void> signOut() async {
    cancelGoogle();
    // Supabase clears its local session before attempting remote revocation.
    // Remote downtime must not prevent a completed Flow logout.
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Never log exceptions that may contain an OAuth token or callback URI.
    }
  }

  @override
  void dispose() {
    cancelGoogle();
    _resumeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
