import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final welcomeStorageProvider = Provider<SharedPreferences?>((ref) => null);

/// Completing the welcome screen is separate from creating an account.
class WelcomeController extends Notifier<bool> {
  static const completedKey = 'welcome.completed';

  @override
  bool build() =>
      ref.watch(welcomeStorageProvider)?.getBool(completedKey) ?? false;

  Future<void> complete() async {
    final storage = ref.read(welcomeStorageProvider);
    if (storage != null && !await storage.setBool(completedKey, true)) {
      throw StateError('Welcome progress could not be saved');
    }
    if (ref.mounted) state = true;
  }
}

final welcomeControllerProvider = NotifierProvider<WelcomeController, bool>(
  WelcomeController.new,
);
