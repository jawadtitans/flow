import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'presentation/auth_pages.dart';
import 'presentation/mfa_login_page.dart';
import 'presentation/profile_page.dart';
import 'presentation/onboarding_pages.dart';

final authRoute = GoRoute(
  path: '/auth',
  builder: (context, state) => const SignInPage(),
  routes: [
    GoRoute(path: 'mfa', builder: (context, state) => const MfaLoginPage()),
    GoRoute(
      path: 'set-password',
      pageBuilder: (context, state) =>
          _slidePage(context, state, const SetPasswordPage()),
    ),
    GoRoute(
      path: 'onboarding',
      pageBuilder: (context, state) =>
          _slidePage(context, state, const OnboardingPage()),
    ),
    GoRoute(
      path: 'introduction',
      pageBuilder: (context, state) =>
          _slidePage(context, state, const IntroductionPage()),
    ),
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
    GoRoute(
      path: 'profile',
      pageBuilder: (context, state) =>
          _slidePage(context, state, const ProfilePage()),
    ),
    GoRoute(
      path: 'getting-ready',
      pageBuilder: (context, state) =>
          _slidePage(context, state, const GettingReadyPage()),
    ),
  ],
);

CustomTransitionPage<void> _slidePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<void>(
  key: state.pageKey,
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 450),
  reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 380),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  },
);
