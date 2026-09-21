import 'package:flutter/material.dart';

import '../../core/theme/flow_tokens.dart';

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final canvas = dark ? FlowColors.darkCanvas : FlowColors.canvas;
  final surface = dark ? FlowColors.darkSurface : FlowColors.surface;
  final onSurface = dark ? const Color(0xFFF5F7FA) : FlowColors.ink;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: FlowColors.blue,
      brightness: brightness,
      surface: surface,
    ),
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    dividerColor: dark ? Colors.white12 : FlowColors.line,
    splashFactory: InkSparkle.splashFactory,
    textTheme: Typography.material2021().black.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
      fontFamily: 'Roboto',
    ),
    iconTheme: IconThemeData(color: onSurface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FlowFadePageTransitionsBuilder(),
        TargetPlatform.iOS: _FlowFadePageTransitionsBuilder(),
        TargetPlatform.macOS: _FlowFadePageTransitionsBuilder(),
        TargetPlatform.windows: _FlowFadePageTransitionsBuilder(),
        TargetPlatform.linux: _FlowFadePageTransitionsBuilder(),
      },
    ),
  );
}

final flowLightTheme = _theme(Brightness.light);
final flowDarkTheme = _theme(Brightness.dark);

class _FlowFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FlowFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}
