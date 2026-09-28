import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai_layer/presentation/ai_layer_page.dart';
import '../../features/auth/auth_routes.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/favorites/presentation/favorites_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/inbox/presentation/inbox_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/settings/settings_routes.dart';
import '../../features/welcome/presentation/welcome_page.dart';
import '../../shared/widgets/flow_main_shell.dart';
import '../startup/startup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final changes = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => changes.value++);
  final router = createAppRouter(
    refreshListenable: changes,
    redirect: (context, route) =>
        authRedirect(ref.read(authControllerProvider), route.uri.path),
  );
  ref.onDispose(() {
    router.dispose();
    changes.dispose();
  });
  return router;
});

String? authRedirect(AuthState auth, String path) {
  if (!auth.initialized && path != '/') return '/';
  final protected = [
    '/today',
    '/inbox',
    '/favorites',
    '/search',
    '/ai-layer',
  ].contains(path);
  if (protected && auth.user == null) return '/auth';
  if (protected && !auth.user!.profileCompleted) return '/auth/profile';
  if ([
        '/auth/profile',
        '/auth/getting-ready',
        '/settings/accounts/details',
      ].contains(path) &&
      auth.user == null)
    return '/auth';
  if (['/auth/code', '/auth/password'].contains(path) && auth.email.isEmpty)
    return '/auth';
  if (path == '/auth/password' && !auth.hasPassword) return '/auth/code';
  if (path == '/auth/reset-sent' && auth.resetEmail.isEmpty)
    return '/auth/reset-password';
  return null;
}

GoRouter createAppRouter({
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
  String initialLocation = '/',
}) => GoRouter(
  initialLocation: initialLocation,
  redirect: redirect,
  refreshListenable: refreshListenable,
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartupScreen()),
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomePage()),
    ShellRoute(
      builder: (context, state, child) =>
          FlowMainShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/today',
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const HomePage()),
        ),
        GoRoute(
          path: '/inbox',
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const InboxPage()),
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const FavoritesPage(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const SearchPage()),
        ),
      ],
    ),
    // A focused page above the shell: popping it reveals the same dock and
    // destination, without relying on a page's dispose timing to restore them.
    GoRoute(
      path: '/ai-layer',
      builder: (context, state) => const AiLayerPage(),
    ),
    authRoute,
    settingsRoute,
  ],
);
