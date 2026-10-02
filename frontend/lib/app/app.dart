import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/settings/settings_controller.dart';
import '../features/settings/presentation/app_lock_pages.dart';
import '../features/auth/auth_controller.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/flow_notification.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FlowApp extends ConsumerWidget {
  const FlowApp({this.router, super.key});
  final GoRouter? router;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Flow',
    theme: flowLightTheme,
    debugShowCheckedModeBanner: false,
    darkTheme: flowDarkTheme,
    themeMode: ref.watch(settingsControllerProvider.select((s) => s.themeMode)),
    routerConfig: router ?? ref.watch(appRouterProvider),
    locale: Locale(
      ref.watch(settingsControllerProvider.select((s) => s.language)),
    ),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) {
      final dark = Theme.of(context).brightness == Brightness.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarContrastEnforced: false,
        ),
        child: FlowNotificationHost(
          child: ref.watch(authControllerProvider).user == null
              ? child ?? const SizedBox.shrink()
              : AppLockGate(child: child ?? const SizedBox.shrink()),
        ),
      );
    },
  );
}
