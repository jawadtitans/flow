import 'dart:io';
import 'dart:ui' as ui;
import 'package:flow_app/app/app.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/features/settings/domain/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Test-only catalog for inspecting the layout. It is never production data.
  const catalog = SubscriptionState(
    features: [
      PlanFeature('Flow assistant', {
        SubscriptionTier.free,
        SubscriptionTier.pro,
        SubscriptionTier.max,
      }),
      PlanFeature('Higher usage limits', {
        SubscriptionTier.pro,
        SubscriptionTier.max,
      }),
      PlanFeature('Task automations', {
        SubscriptionTier.pro,
        SubscriptionTier.max,
      }),
      PlanFeature('Document context', {
        SubscriptionTier.pro,
        SubscriptionTier.max,
      }),
      PlanFeature('Priority processing', {SubscriptionTier.max}),
    ],
  );
  for (final entry in [('/settings', 'settings'), ('/settings/pro', 'pro')]) {
    testWidgets('${entry.$2} renders an exportable phone preview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader(
            'Roboto',
          )..addFont(rootBundle.load('assets/fonts/roboto/Roboto-Regular.ttf')))
          .load();
      await (FontLoader(
            'FlowEditorial',
          )..addFont(rootBundle.load('assets/fonts/editorial/DejaVuSerif.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/flutter_lucide/lucide')..addFont(
            rootBundle.load('packages/flutter_lucide/lib/fonts/lucide.ttf'),
          ))
          .load();
      final router = createAppRouter(initialLocation: entry.$1);
      addTearDown(router.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionProvider.overrideWith((ref) async => catalog),
          ],
          child: RepaintBoundary(
            key: key,
            child: FlowApp(router: router),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), null);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('build/settings-previews')
          ..createSync(recursive: true);
        await File(
          '${directory.path}/flow-${entry.$2}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
