import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../../auth/presentation/auth_components.dart';

import '../../../shared/widgets/flow_dialog.dart';

import 'settings_components.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SettingsScaffold(
    title: 'Settings',
    root: true,
    centerTitle: false,
    children: [
      const SettingsSectionLabel('App settings'),
      SettingsGroup(
        children: [
          for (final option in const [
            (LucideIcons.bell, 'Notifications', 'notifications'),
            (LucideIcons.sun, 'App appearance', 'appearance'),
            (LucideIcons.circle_question_mark, 'Help & support', 'help'),
            (LucideIcons.lock_keyhole, 'Data & privacy', 'privacy'),
            (LucideIcons.info, 'App info', 'info'),
            (LucideIcons.shield_check, 'Legal & safety', 'legal'),
          ])
            SettingsRow(
              icon: option.$1,
              title: option.$2,
              onTap: () => context.push('/settings/${option.$3}'),
            ),
        ],
      ),
      const SizedBox(height: 28),
      const SettingsSectionLabel('Your account', trailing: FlowSettingsBrand()),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: LucideIcons.circle_user_round,
            title: 'Accounts Center',
            subtitle: 'Password, security and personal details',
            onTap: () => context.push('/settings/accounts'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SettingsGroup(
        children: [
          SettingsRow(
            icon: LucideIcons.log_out,
            title: 'Log out',
            destructive: true,
            onTap: () async {
              final auth = ref.read(authControllerProvider);
              if (auth.busy) return;
              if (auth.user != null) {
                final success = await ref
                    .read(authControllerProvider.notifier)
                    .logout();
                if (!context.mounted) return;
                if (success) {
                  context.go('/auth');
                } else {
                  showAuthMessage(
                    context,
                    ref.read(authControllerProvider).error ??
                        'Could not sign out. Try again.',
                  );
                }
                return;
              }
              await showFlowDialog<void>(
                context: context,
                builder: (context) => FlowDialog(
                  title: 'You’re not signed in',
                  content: const Text(
                    'There’s no connected account to log out of on this device.',
                  ),
                  actions: [
                    FlowDialogAction(
                      label: 'Done',
                      primary: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
}
