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
import '../../features/settings/presentation/widget_voice_landing.dart';
import '../../features/welcome/presentation/welcome_page.dart';
import '../../shared/widgets/flow_main_shell.dart';
import '../startup/startup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final changes = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => changes.value++);
  String? widgetDestination;
  final router = createAppRouter(
    refreshListenable: changes,
    redirect: (context, route) {
      final path = route.uri.path;
      if (path.startsWith('/widget/') ||
          path == '/ask' ||
          (route.uri.scheme == 'flow' && route.uri.host == 'widget')) {
        widgetDestination = path.endsWith('voice') ? '/voice' : '/ai-layer';
      }
      final auth = ref.read(authControllerProvider);
      final redirect = authRedirect(auth, path);
      if (redirect != null) return redirect;
      if (auth.initialized &&
          auth.user?.nextRoute == '/today' &&
          widgetDestination != null) {
        final destination = widgetDestination!;
        widgetDestination = null;
        return path == destination ? null : destination;
      }
      return null;
    },
  );
  ref.onDispose(() {
    router.dispose();
    changes.dispose();
  });
  return router;
});

String? authRedirect(AuthState auth, String path) {
  if (!auth.initialized && path != '/') return '/';
  if (path == '/auth/mfa' && auth.mfaChallenge == null) return '/auth';
  final protected =
      path.startsWith('/widget/') ||
      [
        '/today',
        '/inbox',
        '/favorites',
        '/search',
        '/ai-layer',
        '/voice',
      ].contains(path);
  final accountProtected =
      path.startsWith('/settings/accounts/') ||
      [
        '/settings/mfa',
        '/settings/passkeys',
        '/settings/password',
      ].contains(path);
  if (accountProtected && auth.user == null) return '/auth';
  if (protected && auth.user == null) return '/auth';
  if (protected && auth.user!.nextRoute != '/today') {
    return auth.user!.nextRoute;
  }
  if (path == '/auth/profile' && auth.user?.nextRoute == '/auth/set-password') {
    return '/auth/set-password';
  }
  if ([
    '/auth/set-password',
    '/auth/onboarding',
    '/auth/introduction',
  ].contains(path)) {
    if (auth.user == null) return '/auth';
    final user = auth.user!;
    if (!user.profileCompleted && path != user.nextRoute) return user.nextRoute;
    if (path == '/auth/set-password' && user.hasPassword) return user.nextRoute;
    if (path == '/auth/introduction' && user.interests.isEmpty) {
      return '/auth/onboarding';
    }
  }
  if ([
        '/auth/profile',
        '/auth/getting-ready',
        '/settings/accounts/details',
      ].contains(path) &&
      auth.user == null) {
    return '/auth';
  }
  if (['/auth/code', '/auth/password'].contains(path) && auth.email.isEmpty) {
    return '/auth';
  }
  if (path == '/auth/password' && !auth.hasPassword) return '/auth/code';
  if (path == '/auth/reset-sent' && auth.resetEmail.isEmpty) {
    return '/auth/reset-password';
  }
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
    GoRoute(path: '/ask', redirect: (context, state) => '/ai-layer'),
    GoRoute(
      path: '/voice',
      builder: (context, state) => const WidgetVoiceLandingPage(),
    ),
    GoRoute(
      path: '/widget/:action',
      redirect: (context, state) =>
          state.pathParameters['action'] == 'voice' ? '/voice' : '/ai-layer',
    ),
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
