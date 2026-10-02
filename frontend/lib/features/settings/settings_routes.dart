import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'presentation/account_settings_pages.dart';
import 'presentation/security_pages.dart';
import 'presentation/app_lock_pages.dart';
import 'presentation/device_settings_pages.dart';
import 'presentation/flow_pro_page.dart';

import 'presentation/settings_information_pages.dart';
import 'presentation/settings_option_pages.dart';
import 'presentation/settings_page.dart';

final settingsRoute = GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsPage(),
  routes: [
    GoRoute(path: 'pro', builder: (context, state) => const FlowProPage()),
    GoRoute(
      path: 'widget',
      builder: (context, state) => const WidgetSettingsPage(),
    ),
    GoRoute(
      path: 'permissions',
      builder: (context, state) => const PermissionsSettingsPage(),
    ),
    GoRoute(
      path: 'language',
      builder: (context, state) => const LanguageSettingsPage(),
    ),
    GoRoute(path: 'mfa', builder: (context, state) => const MfaSettingsPage()),
    GoRoute(
      path: 'passkeys',
      builder: (context, state) => const PasskeysPage(),
    ),
    GoRoute(
      path: 'app-lock',
      builder: (context, state) => const AppLockSettingsPage(),
    ),
    GoRoute(
      path: 'password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
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
          path: 'phone',
          builder: (context, state) => const AddPhoneNumberPage(),
        ),
        GoRoute(
          path: 'verify-phone',
          builder: (context, state) => VerifyPhonePage(
            verification: state.extra is PhoneVerification
                ? state.extra as PhoneVerification
                : null,
          ),
        ),
        GoRoute(
          path: 'details',
          builder: (context, state) => const PersonalDetailsPage(),
        ),
        GoRoute(
          path: 'security',
          builder: (context, state) => const PasswordSecurityPage(),
        ),
      ],
    ),
  ],
);
