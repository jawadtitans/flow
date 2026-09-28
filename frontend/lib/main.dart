import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/settings/settings_controller.dart';
import 'features/welcome/welcome_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
