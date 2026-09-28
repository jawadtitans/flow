import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../settings_controller.dart';
import 'settings_components.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      settingsControllerProvider.select((s) => s.themeMode),
    );
    return SettingsScaffold(
      title: 'App appearance',
      centerTitle: false,
      children: [
        SettingsGroup(
          children: [
            for (final choice in const [
              ('Automatic', ThemeMode.system),
              ('Light', ThemeMode.light),
              ('Dark', ThemeMode.dark),
            ])
              _ChoiceRow(
                title: choice.$1,
                selected: mode == choice.$2,
                onTap: () => saveSettings(
                  context,
                  () => ref
                      .read(settingsControllerProvider.notifier)
                      .setThemeMode(choice.$2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = ref.watch(
      settingsControllerProvider.select((s) => s.pauseNotifications),
    );
    void update(bool value) => saveSettings(
      context,
      () => ref
          .read(settingsControllerProvider.notifier)
          .setPauseNotifications(value),
    );
    return SettingsScaffold(
      title: 'Notifications',
      children: [
        SettingsGroup(
          children: [
            MergeSemantics(
              child: SettingsRow(
                title: 'Pause all',
                onTap: () => update(!paused),
                trailing: SizedBox(
                  height: 28,
                  child: CupertinoSwitch(
                    value: paused,
                    onChanged: update,
                    activeTrackColor: const Color(0xFF087CC1),
                    inactiveTrackColor: const Color(0xFF73767B),
                    inactiveThumbColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Data & privacy',
    children: [
      SettingsGroup(
        children: [
          SettingsRow(
            title: 'Manage your information',
            onTap: () => context.push('/settings/privacy/information'),
          ),
          SettingsRow(
            title: 'Mentions',
            onTap: () => context.push('/settings/privacy/mentions'),
          ),
        ],
      ),
    ],
  );
}

class MentionSettingsPage extends ConsumerWidget {
  const MentionSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audience = ref.watch(
      settingsControllerProvider.select((s) => s.mentions),
    );
    return SettingsScaffold(
      title: 'Mentions',
      fallback: '/settings/privacy',
      children: [
        const SettingsSectionLabel('Who can mention you'),
        SettingsGroup(
          children: [
            for (final choice in const [
              ('Everyone', MentionAudience.everyone),
              ('People in my workspace', MentionAudience.teammates),
              ('No one', MentionAudience.nobody),
            ])
              _ChoiceRow(
                title: choice.$1,
                selected: audience == choice.$2,
                onTap: () => saveSettings(
                  context,
                  () => ref
                      .read(settingsControllerProvider.notifier)
                      .setMentions(choice.$2),
                ),
              ),
          ],
        ),
        const SettingsNote(
          'Saved on this device. Account-wide mention controls aren’t available yet.',
        ),
      ],
    );
  }
}

class InformationSettingsPage extends StatelessWidget {
  const InformationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'Your information',
    fallback: '/settings/privacy',
    children: [
      const SettingsSectionLabel('On this device'),
      const SettingsGroup(
        children: [
          SettingsRow(
            icon: LucideIcons.smartphone,
            title: 'App preferences',
            subtitle:
                'Your appearance, notification and mention preferences are stored on this device.',
          ),
        ],
      ),
      const SizedBox(height: 28),
      const SettingsSectionLabel('Your account'),
      SettingsGroup(
        children: [
          SettingsRow(
            title: 'Account information',
            icon: LucideIcons.circle_user_round,
            onTap: () => context.push('/settings/accounts'),
          ),
        ],
      ),
      const SettingsNote(
        'No account is connected. Account data export and deletion aren’t available in this version of Flow.',
      ),
    ],
  );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    inMutuallyExclusiveGroup: true,
    child: SettingsRow(
      title: title,
      onTap: onTap,
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 21,
        height: 21,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? const Color(0xFF087CC1)
                : Theme.of(context).colorScheme.onSurface,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFF087CC1) : Colors.transparent,
          ),
        ),
      ),
    ),
  );
}
