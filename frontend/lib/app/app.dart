import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FlowApp extends StatelessWidget {
  const FlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Flow',
    theme: flowLightTheme,
    debugShowCheckedModeBanner: false,
    darkTheme: flowDarkTheme,
    themeMode: ThemeMode.system,
    routerConfig: appRouter,
    supportedLocales: const [Locale('en'), Locale('fa'), Locale('ps')],
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
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
}
