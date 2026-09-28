import 'dart:io';
import 'dart:ui' as ui;
import 'package:flow_app/app/app.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/features/settings/settings_controller.dart';
import 'package:flow_app/shared/widgets/flow_dialog.dart';
import 'package:flow_app/shared/widgets/flow_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appRouter = createAppRouter();

void main() {
  testWidgets('capture the dialog and notification designs', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.runAsync(() async {
      final font = FontLoader('Roboto');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        font.addFont(rootBundle.load('assets/fonts/roboto/Roboto-$weight.ttf'));
      }
      await font.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await Directory('/tmp/flow-ui-preview').create(recursive: true);
    });
    const captureKey = ValueKey('capture');
    Future<void> open(String route, {bool dark = false}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({
        'settings.appearance': dark ? 'dark' : 'light',
      });
      final storage = await SharedPreferences.getInstance();
      appRouter.go(route);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsStorageProvider.overrideWithValue(storage)],
          child: RepaintBoundary(
            key: captureKey,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                padding: EdgeInsets.only(top: 24, bottom: 20),
              ),
              child: FlowApp(router: appRouter),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/flow-ui-preview/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await open('/settings');
    showFlowDialog<void>(
      context: tester.element(find.text('Settings').first),
      builder: (context) => FlowDialog(
        title: 'Do you want to delete this account?',
        content: const Text('You cannot undo this action'),
        actions: [
          FlowDialogAction(
            label: 'Cancel',
            primary: true,
            onPressed: () => Navigator.pop(context),
          ),
          FlowDialogAction(
            label: 'Delete',
            destructive: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await capture('dialog-short-light');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await open('/auth/profile');
    await tester.tap(find.byKey(const ValueKey('profile-birthday')));
    await tester.pumpAndSettle();
    await capture('dialog-birthday');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await open('/auth', dark: true);
    showFlowDialog<void>(
      context: tester.element(find.text('Welcome to Flow')),
      builder: (context) => FlowDialog(
        title: 'One account for your day',
        content: Text(
          List.filled(
            9,
            'Use your email address or mobile number to get started. You can verify with a code or choose your password on the next screen.',
          ).join('\n\n'),
        ),
        actions: [
          FlowDialogAction(
            label: 'Got it',
            primary: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await capture('dialog-long-dark');
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await open('/auth/code');
    showFlowNotification(
      tester.element(find.text('Enter your code')),
      title: 'Preview mode',
      message: 'Use 123456 to preview verification. No code was sent.',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await capture('notification-light');
    await tester.pumpAndSettle();

    await open('/welcome');
    final context = tester.element(find.byKey(captureKey));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/welcome/flow-avatar.jpg'),
        context,
      );
      if (context.mounted) {
        await precacheImage(
          const AssetImage('assets/welcome/icons/plans-your-day.png'),
          context,
        );
      }
    });
    await capture('welcome-latest-avatar');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
