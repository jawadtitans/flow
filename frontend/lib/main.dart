import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/settings/settings_controller.dart';
import 'features/welcome/welcome_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  if (supabasePublishableKey.isEmpty) {
    throw StateError(
      'Set SUPABASE_PUBLISHABLE_KEY with --dart-define before launching Flow.',
    );
  }
  await Supabase.initialize(
    url: 'https://lisockinsfgyqkzmshwz.supabase.co',
    publishableKey: supabasePublishableKey,
    // Flow restores its own securely stored refresh token. Supabase's broker
    // session must not introduce another persisted session in preferences.
    authOptions: const FlutterAuthClientOptions(persistSession: false),
    debug: false,
  );
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'DejaVu Serif',
    ], await rootBundle.loadString('assets/fonts/editorial/LICENSE.txt'));
  });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        settingsStorageProvider.overrideWithValue(preferences),
        welcomeStorageProvider.overrideWithValue(preferences),
      ],
      child: const FlowApp(),
    ),
  );
}
