import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
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
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: c.dataPrivacy,
      children: [
        SettingsSectionLabel(c.security),
        SettingsGroup(
          children: [
            for (final row in [
              (c.mfa, 'mfa', LucideIcons.shield_check),
              (c.passkeys, 'passkeys', LucideIcons.key_round),
              (c.appLock, 'app-lock', LucideIcons.lock_keyhole),
            ])
              SettingsRow(
                title: row.$1,
                icon: row.$3,
                onTap: () => context.push('/settings/${row.$2}'),
              ),
          ],
        ),
      ],
    );
  }
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
