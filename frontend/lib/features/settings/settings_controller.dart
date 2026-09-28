import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsStorageProvider = Provider<SharedPreferences?>((ref) => null);

enum MentionAudience { everyone, teammates, nobody }

@immutable
class FlowSettings {
  const FlowSettings({
    this.themeMode = ThemeMode.system,
    this.pauseNotifications = false,
    this.mentions = MentionAudience.everyone,
  });

  final ThemeMode themeMode;
  final bool pauseNotifications;
  final MentionAudience mentions;

  FlowSettings copyWith({
    ThemeMode? themeMode,
    bool? pauseNotifications,
    MentionAudience? mentions,
  }) => FlowSettings(
    themeMode: themeMode ?? this.themeMode,
    pauseNotifications: pauseNotifications ?? this.pauseNotifications,
    mentions: mentions ?? this.mentions,
  );
}

class SettingsController extends Notifier<FlowSettings> {
  @override
  FlowSettings build() {
    final storage = ref.watch(settingsStorageProvider);
    return FlowSettings(
      themeMode: switch (storage?.getString('settings.appearance')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      pauseNotifications:
          storage?.getBool('settings.pauseNotifications') ?? false,
      mentions: switch (storage?.getString('settings.mentions')) {
        'teammates' => MentionAudience.teammates,
        'nobody' => MentionAudience.nobody,
        _ => MentionAudience.everyone,
      },
    );
  }

  Future<void> setThemeMode(ThemeMode value) async {
    final storage = ref.read(settingsStorageProvider);
    if (storage != null &&
        !await storage.setString('settings.appearance', value.name)) {
      throw StateError('Appearance could not be saved');
    }
    if (ref.mounted) state = state.copyWith(themeMode: value);
  }

  Future<void> setPauseNotifications(bool value) async {
    final storage = ref.read(settingsStorageProvider);
    if (storage != null &&
        !await storage.setBool('settings.pauseNotifications', value)) {
      throw StateError('Notification preference could not be saved');
    }
    if (ref.mounted) state = state.copyWith(pauseNotifications: value);
  }

  Future<void> setMentions(MentionAudience value) async {
    final storage = ref.read(settingsStorageProvider);
    if (storage != null &&
        !await storage.setString('settings.mentions', value.name)) {
      throw StateError('Mention preference could not be saved');
    }
    if (ref.mounted) state = state.copyWith(mentions: value);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, FlowSettings>(SettingsController.new);
