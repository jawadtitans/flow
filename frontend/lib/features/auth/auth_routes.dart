import 'package:go_router/go_router.dart';

import 'presentation/auth_pages.dart';
import 'presentation/profile_page.dart';

final authRoute = GoRoute(
  path: '/auth',
  builder: (context, state) => const SignInPage(),
  routes: [
    GoRoute(
      path: 'code',
      builder: (context, state) => const VerificationPage(),
    ),
    GoRoute(
      path: 'password',
      builder: (context, state) => const PasswordPage(),
    ),
    GoRoute(
      path: 'reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: 'reset-sent',
      builder: (context, state) => const ResetCodePage(),
    ),
    GoRoute(path: 'profile', builder: (context, state) => const ProfilePage()),
    GoRoute(
      path: 'getting-ready',
      builder: (context, state) => const GettingReadyPage(),
    ),
  ],
);
