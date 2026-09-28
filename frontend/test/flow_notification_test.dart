import 'package:flow_app/app/theme/app_theme.dart';
import 'package:flow_app/shared/widgets/flow_notification.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BuildContext pageContext;
  var backgroundTaps = 0;

  Future<void> open(
    WidgetTester tester, {
    bool reducedMotion = false,
    bool accessibleNavigation = false,
    bool dark = false,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    backgroundTaps = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? flowDarkTheme : flowLightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 20),
            disableAnimations: reducedMotion,
            accessibleNavigation: accessibleNavigation,
            textScaler: TextScaler.linear(textScale),
          ),
          child: FlowNotificationHost(child: child!),
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => backgroundTaps++,
                  child: const Text('Background action'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> enter(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('animates above safe area, preserves page input and dismisses', (
    tester,
  ) async {
    await open(tester);
    showFlowNotification(
      pageContext,
      message: 'Your changes are saved.',
      type: FlowNotificationType.success,
      duration: const Duration(seconds: 2),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('Your changes are saved.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.getTopLeft(find.byType(Dismissible)).dy,
      greaterThanOrEqualTo(36),
    );
    await tester.tap(find.text('Background action'));
    expect(backgroundTaps, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Your changes are saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Your changes are saved.'), findsNothing);
    await close(tester);
  });

  testWidgets(
    'a replacement survives the previous message finishing dismissal',
    (tester) async {
      await open(tester);
      showFlowNotification(pageContext, message: 'Previous message');
      await enter(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump(const Duration(milliseconds: 60));
      showFlowNotification(pageContext, message: 'Latest message');
      await enter(tester);
      expect(find.text('Previous message'), findsNothing);
      expect(find.text('Latest message'), findsOneWidget);
      expect(find.byType(Dismissible), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Latest message'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets('horizontal swipe dismisses and a new message can be shown', (
    tester,
  ) async {
    await open(tester, reducedMotion: true);
    showFlowNotification(pageContext, message: 'Swipe this message');
    await tester.pump();
    await tester.drag(find.text('Swipe this message'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Swipe this message'), findsNothing);
    showFlowNotification(pageContext, message: 'Another message');
    await tester.pump();
    expect(find.text('Another message'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.text('Another message'), findsNothing);
    await close(tester);
  });

  testWidgets('hover pauses reading time and leaving resumes it', (
    tester,
  ) async {
    await open(tester);
    showFlowNotification(
      pageContext,
      message: 'Take your time reading.',
      duration: const Duration(seconds: 2),
    );
    await enter(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Take your time reading.')));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Take your time reading.'), findsOneWidget);
    await mouse.moveTo(const Offset(380, 800));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Take your time reading.'), findsNothing);
    await mouse.removePointer();
    await close(tester);
  });

  testWidgets(
    'screen reader messages persist, support dismissal and large text',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await open(
          tester,
          reducedMotion: true,
          accessibleNavigation: true,
          dark: true,
          size: const Size(320, 320),
          textScale: 1.8,
        );
        showFlowNotification(
          pageContext,
          title: 'Setting not saved',
          message: 'Couldn’t save this setting. Please try again.',
          type: FlowNotificationType.error,
          duration: const Duration(seconds: 1),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 30));
        expect(find.text('Setting not saved'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.bySemanticsLabel('Dismiss notification'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(find.text('Setting not saved'), findsNothing);
        await close(tester);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('a notification remains visible across navigation', (
    tester,
  ) async {
    await open(tester, reducedMotion: true, accessibleNavigation: true);
    showFlowNotification(pageContext, message: 'This message follows you.');
    await tester.pump();
    Navigator.of(pageContext).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Next page'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Next page'), findsOneWidget);
    expect(find.text('This message follows you.'), findsOneWidget);
    await close(tester);
  });
}
