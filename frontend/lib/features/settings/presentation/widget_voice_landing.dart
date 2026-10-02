import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_components.dart';

class WidgetVoiceLandingPage extends StatelessWidget {
  const WidgetVoiceLandingPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: c.voice,
      children: [
        SettingsNote(c.voiceUnavailable),
        FilledButton(
          onPressed: () => context.go('/ai-layer'),
          child: Text(c.askFlow),
        ),
      ],
    );
  }
}
