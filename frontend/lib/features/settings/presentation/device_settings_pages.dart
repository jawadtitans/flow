import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../l10n/app_localizations.dart';
import '../settings_controller.dart';
import 'settings_components.dart';

String permissionStatusKey(PermissionStatus status) => switch (status) {
  PermissionStatus.granted => 'granted',
  PermissionStatus.limited => 'limited',
  PermissionStatus.permanentlyDenied ||
  PermissionStatus.restricted => 'settings',
  _ => 'denied',
};

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: copy.language,
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              title: copy.english,
              subtitle: copy.defaultLanguage,
              trailing: const Icon(Icons.check),
              onTap: () => saveSettings(
                context,
                () => ref
                    .read(settingsControllerProvider.notifier)
                    .setLanguage('en'),
              ),
            ),
          ],
        ),
        SettingsNote(copy.languagesSoon),
      ],
    );
  }
}

class PermissionsSettingsPage extends StatefulWidget {
  const PermissionsSettingsPage({super.key});
  @override
  State<PermissionsSettingsPage> createState() =>
      _PermissionsSettingsPageState();
}

class _PermissionsSettingsPageState extends State<PermissionsSettingsPage>
    with WidgetsBindingObserver {
  Map<Permission, PermissionStatus> states = {};
  String? error;
  bool busy = false;
  bool photosRequired = true;
  List<Permission> get permissions => [
    Permission.microphone,
    Permission.locationWhenInUse,
    if (photosRequired) Permission.photos,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        photosRequired =
            (await widgetChannel.invokeMethod<int>('sdk') ?? 0) >= 33;
      }
      final result = <Permission, PermissionStatus>{};
      for (final p in permissions) {
        result[p] = await p.status;
      }
      if (mounted) {
        setState(() {
          states = result;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = AppLocalizations.of(context)!.permissionsUnavailable,
        );
      }
    }
  }

  Future<void> request(Permission p) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final status = await p.status;
      if (status.isGranted ||
          status.isLimited ||
          status.isPermanentlyDenied ||
          status.isRestricted) {
        await openAppSettings();
      } else {
        await p.request();
      }
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = AppLocalizations.of(context)!.permissionsUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: copy.permissions,
      children: [
        if (error != null) ...[
          SettingsNote(error!),
          TextButton(onPressed: refresh, child: Text(copy.retry)),
        ],
        SettingsGroup(
          children: [
            for (final item in [
              (
                Permission.microphone,
                Icons.mic_none,
                copy.microphone,
                copy.microphoneReason,
              ),
              (
                Permission.locationWhenInUse,
                Icons.location_on_outlined,
                copy.location,
                copy.locationReason,
              ),
              if (photosRequired)
                (
                  Permission.photos,
                  Icons.photo_outlined,
                  copy.photos,
                  copy.photosReason,
                ),
            ])
              SettingsRow(
                icon: item.$2,
                title: item.$3,
                subtitle:
                    '${item.$4}\n${switch (states[item.$1]) {
                      PermissionStatus.granted => copy.granted,
                      PermissionStatus.limited => copy.limited,
                      PermissionStatus.permanentlyDenied || PermissionStatus.restricted => copy.openSettings,
                      null => copy.checking,
                      _ => copy.notGranted,
                    }}',
                trailing: Switch(
                  value:
                      states[item.$1]?.isGranted == true ||
                      states[item.$1]?.isLimited == true,
                  onChanged: busy || states[item.$1] == null
                      ? null
                      : (_) => request(item.$1),
                ),
                onTap: states[item.$1] == null || busy
                    ? null
                    : () => request(item.$1),
              ),
            if (!photosRequired)
              SettingsRow(
                icon: Icons.photo_outlined,
                title: copy.photos,
                subtitle: copy.pickerOnly,
              ),
            SettingsRow(
              icon: Icons.phone_outlined,
              title: copy.phone,
              subtitle: copy.phoneNotRequired,
            ),
          ],
        ),
        SettingsNote(copy.permissionsNote),
      ],
    );
  }
}

const widgetChannel = MethodChannel('flow/widget');

class WidgetSettingsPage extends StatefulWidget {
  const WidgetSettingsPage({super.key});
  @override
  State<WidgetSettingsPage> createState() => _WidgetSettingsPageState();
}

class _WidgetSettingsPageState extends State<WidgetSettingsPage> {
  String? message;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: copy.flowWidget,
      children: [
        SettingsNote(copy.widgetDescription),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FlowSettingsBrand(),
                  const SizedBox(height: 24),
                  Text(
                    copy.widgetPrompt,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Text(copy.askFlow),
                      ),
                      Chip(
                        avatar: const Icon(Icons.mic_none, size: 18),
                        label: Text(copy.voice),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    message = null;
                  });
                  try {
                    if (!kIsWeb &&
                        defaultTargetPlatform == TargetPlatform.android) {
                      final supported =
                          await widgetChannel.invokeMethod<bool>(
                            'pinSupported',
                          ) ??
                          false;
                      if (supported) {
                        await widgetChannel.invokeMethod('pin');
                        if (mounted) {
                          setState(() => message = copy.widgetPinRequested);
                        }
                      } else {
                        if (mounted) {
                          setState(() => message = copy.widgetInstructions);
                        }
                      }
                    } else {
                      setState(() => message = copy.widgetInstructions);
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(() => message = copy.widgetUnavailable);
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(copy.addWidget),
        ),
        if (message != null) SettingsNote(message!),
      ],
    );
  }
}
