import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_controller.dart';
import '../../auth/presentation/auth_components.dart';

import '../../../shared/widgets/flow_dialog.dart';

import 'settings_components.dart';
import '../../../l10n/app_localizations.dart';
import 'account_actions.dart';

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
            (LucideIcons.layout_grid, 'Widget', 'widget'),
            (LucideIcons.shield, 'Permissions', 'permissions'),
            (LucideIcons.globe, 'Language', 'language'),
            (LucideIcons.circle_question_mark, 'Help & support', 'help'),
            (LucideIcons.lock_keyhole, 'Data & privacy', 'privacy'),
            (LucideIcons.info, 'App info', 'info'),
            (LucideIcons.shield_check, 'Legal & safety', 'legal'),
          ])
            SettingsRow(
              icon: option.$1,
              title: switch (option.$3) {
                'widget' => AppLocalizations.of(context)!.widget,
                'permissions' => AppLocalizations.of(context)!.permissions,
                'language' => AppLocalizations.of(context)!.language,
                _ => option.$2,
              },
              trailing: option.$3 == 'language'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.english,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        const Icon(LucideIcons.chevron_right, size: 20),
                      ],
                    )
                  : null,
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
                if (!await confirmLogout(context) || !context.mounted) return;
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
      if (ref.watch(authControllerProvider).user != null) ...[
        const SizedBox(height: 12),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: LucideIcons.trash,
              title: 'Delete account',
              destructive: true,
              onTap: () => confirmAccountDeletion(context, ref),
            ),
          ],
        ),
      ],
    ],
  );
}
