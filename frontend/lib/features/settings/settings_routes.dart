import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import '../auth/presentation/profile_page.dart';

import 'presentation/settings_information_pages.dart';
import 'presentation/settings_option_pages.dart';
import 'presentation/settings_page.dart';

final settingsRoute = GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsPage(),
  routes: [
    GoRoute(
      path: 'appearance',
      builder: (context, state) => const AppearanceSettingsPage(),
    ),
    GoRoute(
      path: 'notifications',
      builder: (context, state) => const NotificationSettingsPage(),
    ),
    GoRoute(
      path: 'privacy',
      builder: (context, state) => const PrivacySettingsPage(),
      routes: [
        GoRoute(
          path: 'information',
          builder: (context, state) => const InformationSettingsPage(),
        ),
        GoRoute(
          path: 'mentions',
          builder: (context, state) => const MentionSettingsPage(),
        ),
      ],
    ),
    GoRoute(
      path: 'help',
      builder: (context, state) => const HelpSettingsPage(),
    ),
    GoRoute(
      path: 'info',
      builder: (context, state) => const AppInfoSettingsPage(),
    ),
    GoRoute(
      path: 'legal',
      builder: (context, state) => const LegalSettingsPage(),
      routes: [
        GoRoute(
          path: 'terms',
          builder: (context, state) => const SettingsArticlePage(
            title: 'Terms of service',
            heading: 'Terms aren’t available yet',
            body:
                'Flow’s terms of service haven’t been published in this version of the app.',
            icon: LucideIcons.file_text,
            fallback: '/settings/legal',
          ),
        ),
        GoRoute(
          path: 'policy',
          builder: (context, state) => const SettingsArticlePage(
            title: 'Privacy policy',
            heading: 'Privacy policy',
            body:
                'A privacy policy hasn’t been published in this version of Flow. You can review the preferences stored on this device in Data & privacy.',
            icon: LucideIcons.lock_keyhole,
            fallback: '/settings/legal',
          ),
        ),
        GoRoute(
          path: 'safety',
          builder: (context, state) => const SettingsArticlePage(
            title: 'Using Flow safely',
            heading: 'Stay in control',
            body:
                'Review agent drafts before adding them to your tasks. Check recipients, dates and instructions carefully.\n\nKeep passwords, recovery codes and other sensitive account details out of task descriptions and agent requests.',
            icon: LucideIcons.shield_check,
            fallback: '/settings/legal',
          ),
        ),
      ],
    ),
    GoRoute(
      path: 'accounts',
      builder: (context, state) => const AccountsSettingsPage(),
      routes: [
        GoRoute(
          path: 'details',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: 'security',
          builder: (context, state) => const SettingsArticlePage(
            title: 'Password & security',
            heading: 'Signing in securely',
            body:
                'You can sign in with a one-time email code. New accounts do not need a password. If your account already has a password, use Forgot password on the sign-in screen to reset it. Resetting a password ends all existing sessions.',
            icon: LucideIcons.key_round,
            fallback: '/settings/accounts',
          ),
        ),
      ],
    ),
  ],
);
