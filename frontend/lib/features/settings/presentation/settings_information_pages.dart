import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';

import '../../../core/theme/flow_tokens.dart';
import 'settings_components.dart';

class HelpSettingsPage extends StatelessWidget {
  const HelpSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Help & support',
    children: [
      const SettingsSectionLabel('Using Flow'),
      SettingsGroup(
        children: [
          for (final question in const [
            (
              'Where can I find my tasks?',
              'Open My tasks in the bottom bar. Switch between Assigned, Created and Subscribed to find the tasks you need.',
            ),
            (
              'How do I change the appearance?',
              'Open Settings, then App appearance. Choose Light, Dark, or Automatic to follow your device’s appearance.',
            ),
            (
              'Where are the other pages?',
              'Tap the three dots in the bottom bar. You can also drag the bar upward to open the full menu.',
            ),
            (
              'How do I return from agent mode?',
              'Use the close button at the top of agent mode, or your device’s back action, to return to the page you were using.',
            ),
          ])
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 3,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                title: Text(question.$1, style: const TextStyle(fontSize: 16)),
                children: [
                  Text(
                    question.$2,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      SettingsGroup(
        children: [
          SettingsRow(
            title: 'About Flow',
            icon: LucideIcons.info,
            onTap: () => context.push('/settings/info'),
          ),
        ],
      ),
    ],
  );
}

class AppInfoSettingsPage extends StatelessWidget {
  const AppInfoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'App info',
    children: [
      const Padding(
        padding: EdgeInsets.only(top: 18, bottom: 30),
        child: Column(
          children: [
            FlowSettingsBrand(),
            SizedBox(height: 16),
            Text(
              'A calmer place for your tasks.',
              style: TextStyle(fontSize: 17),
            ),
          ],
        ),
      ),
      SettingsGroup(
        children: [
          // Keep aligned with the package version in pubspec.yaml.
          const SettingsRow(
            title: 'Version',
            trailing: Text(
              '1.0.0 (1)',
              style: TextStyle(color: FlowColors.muted),
            ),
          ),
          SettingsRow(
            title: 'Open-source licences',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Flow',
              applicationVersion: '1.0.0',
            ),
          ),
        ],
      ),
    ],
  );
}

class LegalSettingsPage extends StatelessWidget {
  const LegalSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Legal & safety',
    children: [
      SettingsGroup(
        children: [
          SettingsRow(
            title: 'Terms of service',
            onTap: () => context.push('/settings/legal/terms'),
          ),
          SettingsRow(
            title: 'Privacy policy',
            onTap: () => context.push('/settings/legal/policy'),
          ),
          SettingsRow(
            title: 'Using Flow safely',
            onTap: () => context.push('/settings/legal/safety'),
          ),
          SettingsRow(
            title: 'Open-source licences',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Flow',
              applicationVersion: '1.0.0',
            ),
          ),
        ],
      ),
    ],
  );
}

class AccountsSettingsPage extends ConsumerWidget {
  const AccountsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return SettingsScaffold(
      title: 'Accounts Center',
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 14),
          child: FlowSettingsBrand(),
        ),
        SettingsGroup(
          children: [
            SettingsRow(
              title: user == null
                  ? 'No account connected'
                  : user.displayName.isEmpty
                  ? user.email
                  : user.displayName,
              subtitle:
                  user?.email ??
                  'Your app preferences are available on this device.',
              icon: LucideIcons.circle_user_round,
            ),
          ],
        ),
        const SizedBox(height: 28),
        if (user == null)
          SettingsGroup(
            children: [
              SettingsRow(
                title: 'Sign in or create an account',
                subtitle: 'Connect securely with your email address.',
                icon: LucideIcons.log_in,
                onTap: () => context.push('/auth'),
              ),
            ],
          ),
        const SizedBox(height: 28),
        const SettingsSectionLabel('Account settings'),
        SettingsGroup(
          children: [
            SettingsRow(
              title: 'Personal details',
              icon: LucideIcons.user_round,
              onTap: () =>
                  context.push(user == null ? '/auth' : '/auth/profile'),
            ),
            SettingsRow(
              title: 'Password & security',
              icon: LucideIcons.key_round,
              onTap: () => context.push('/settings/accounts/security'),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsArticlePage extends StatelessWidget {
  const SettingsArticlePage({
    required this.title,
    required this.heading,
    required this.body,
    required this.icon,
    required this.fallback,
    super.key,
  });

  final String title;
  final String heading;
  final String body;
  final IconData icon;
  final String fallback;

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: title,
    fallback: fallback,
    children: [
      SettingsGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: FlowColors.blue),
                const SizedBox(height: 18),
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(body, style: const TextStyle(fontSize: 15, height: 1.65)),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
