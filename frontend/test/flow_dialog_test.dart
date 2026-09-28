import 'package:flow_app/app/theme/app_theme.dart';
import 'package:flow_app/shared/widgets/flow_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BuildContext pageContext;
  var backgroundTaps = 0;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool dark = false,
    bool reducedMotion = false,
    double keyboardInset = 0,
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
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
            padding: const EdgeInsets.only(top: 24, bottom: 20),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
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

  Future<bool?> prompt() => showFlowDialog<bool>(
    context: pageContext,
    builder: (context) => FlowDialog(
      title: 'Do you want to delete this account?',
      content: const Text('You cannot undo this action.'),
      actions: [
        FlowDialogAction(
          label: 'Cancel',
          primary: true,
          onPressed: () => Navigator.pop(context, false),
        ),
        FlowDialogAction(
          label: 'Delete',
          destructive: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  testWidgets('short prompt dims the page and returns the selected result', (
    tester,
  ) async {
    await open(tester);
    final result = prompt();
    await tester.pumpAndSettle();
    expect(find.text('You cannot undo this action.'), findsOneWidget);
    final barrier = tester.widget<AnimatedModalBarrier>(
      find.byType(AnimatedModalBarrier).last,
    );
    expect(barrier.color.value!.a, greaterThan(.5));
    expect(
      tester.getCenter(find.text('Cancel')).dy,
      tester.getCenter(find.text('Delete')).dy,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
    final confirmed = prompt();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping outside closes the dialog without activating the page', (
    tester,
  ) async {
    await open(tester, reducedMotion: true);
    final result = prompt();
    await tester.pump();
    await tester.tapAt(const Offset(195, 32));
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(backgroundTaps, 0);
    expect(find.byType(FlowDialog), findsNothing);
  });

  testWidgets(
    'long dark dialog scrolls while large text actions stay reachable',
    (tester) async {
      await open(
        tester,
        size: const Size(568, 320),
        textScale: 1.8,
        dark: true,
      );
      final result = showFlowDialog<void>(
        context: pageContext,
        builder: (context) => FlowDialog(
          title: 'About your account',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 30; i++)
                Text(
                  'Paragraph $i. Your account preferences stay in your control.',
                ),
              const Text('Final paragraph'),
            ],
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
      final buttonBefore = tester.getRect(find.text('Got it'));
      expect(find.text('Got it').hitTestable(), findsOneWidget);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -8000),
      );
      await tester.ensureVisible(find.text('Final paragraph'));
      await tester.pumpAndSettle();
      expect(find.text('Final paragraph').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.text('Got it')), buttonBefore);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      await result;
    },
  );

  testWidgets(
    'narrow dialog stacks lengthy actions and handles keyboard input',
    (tester) async {
      await open(
        tester,
        size: const Size(320, 700),
        textScale: 1.5,
        keyboardInset: 260,
      );
      final controller = TextEditingController();
      final result = showFlowDialog<String>(
        context: pageContext,
        builder: (context) => FlowDialog(
          title: 'Name your task',
          content: TextField(controller: controller, autofocus: true),
          actions: [
            FlowDialogAction(
              label: 'Keep editing',
              onPressed: () => Navigator.pop(context),
            ),
            FlowDialogAction(
              label: 'Save this task',
              primary: true,
              onPressed: () => Navigator.pop(context, controller.text),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.text('Save this task')).dy,
        greaterThan(tester.getCenter(find.text('Keep editing')).dy),
      );
      await tester.enterText(find.byType(TextField), 'Plan tomorrow');
      await tester.tap(find.text('Save this task'));
      await tester.pumpAndSettle();
      expect(await result, 'Plan tomorrow');
      expect(tester.takeException(), isNull);
      controller.dispose();
    },
  );
}
