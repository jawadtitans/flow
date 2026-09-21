import 'package:go_router/go_router.dart';

import '../../features/ai_layer/presentation/ai_layer_page.dart';
import '../../features/favorites/presentation/favorites_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/inbox/presentation/inbox_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../shared/widgets/flow_main_shell.dart';
import '../startup/startup_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const StartupScreen()),
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
        GoRoute(
          path: '/ai-layer',
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const AiLayerPage()),
        ),
      ],
    ),
  ],
);
