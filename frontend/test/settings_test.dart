import 'package:flow_app/app/app.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/features/settings/settings_controller.dart';
import 'package:flow_app/shared/widgets/flow_components.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appRouter = createAppRouter();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    flowBottomNavigationExpanded.value = false;
    flowNavigationVisible.value = true;
  });

  Future<void> openApp(
    WidgetTester tester, {
    String location = '/settings',
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = await SharedPreferences.getInstance();
    appRouter.go(location);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStorageProvider.overrideWithValue(storage)],
        child: FlowApp(router: appRouter),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) await tester.scrollUntilVisible(finder, 120);
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
  }

  test('preferences survive a new provider container', () async {
    final storage = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );
    final controller = first.read(settingsControllerProvider.notifier);
    await controller.setThemeMode(ThemeMode.dark);
    await controller.setPauseNotifications(true);
    await controller.setMentions(MentionAudience.teammates);
    first.dispose();

    final restored = ProviderContainer(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(restored.dispose);
    final preferences = restored.read(settingsControllerProvider);
    expect(preferences.themeMode, ThemeMode.dark);
    expect(preferences.pauseNotifications, isTrue);
    expect(preferences.mentions, MentionAudience.teammates);
  });

  testWidgets('appearance updates the entire app and closing restores Inbox', (
    tester,
  ) async {
    await openApp(tester, location: '/inbox');
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await visible(tester, find.text('Settings'));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(FlowBottomNavigation), findsNothing);
    expect(find.text('App settings'), findsOneWidget);
    expect(find.textContaining('Meta'), findsNothing);
    expect(find.byType(FlowPageSoftEdges), findsOneWidget);

    await visible(tester, find.text('App appearance'));
    await tester.tap(find.text('App appearance'));
    await tester.pumpAndSettle();
    for (final choice in [
      ('Dark', ThemeMode.dark),
      ('Light', ThemeMode.light),
      ('Automatic', ThemeMode.system),
    ]) {
      await visible(tester, find.text(choice.$1));
      await tester.tap(find.text(choice.$1));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        choice.$2,
      );
      expect(tester.takeException(), isNull);
    }
    await back(tester);
    await tester.tap(find.bySemanticsLabel('Close settings'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/inbox');
    expect(find.byTooltip('More').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'notifications persist and privacy exposes security destinations',
    (tester) async {
      await openApp(tester);
      await visible(tester, find.text('Notifications'));
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('Pause all'));
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isFalse,
      );
      await visible(tester, find.text('Pause all'));
      await tester.tap(find.text('Pause all'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('Pause all'));
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isTrue,
      );
      await back(tester);

      await visible(tester, find.text('Data & privacy'));
      await tester.tap(find.text('Data & privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Multi-factor authentication'), findsOneWidget);
      expect(find.text('Passkeys'), findsOneWidget);
      expect(find.text('App lock'), findsOneWidget);
      expect(find.text('Mentions'), findsNothing);
      expect(find.text('Manage your information'), findsNothing);
      final storage = await SharedPreferences.getInstance();
      await back(tester);

      await visible(tester, find.text('Notifications'));
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      await visible(tester, find.text('Pause all'));
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
        isTrue,
      );
      expect(storage.getBool('settings.pauseNotifications'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('all remaining options open pages with working back navigation', (
    tester,
  ) async {
    await openApp(tester);
    for (final entry in [
      ('Help & support', 'Using Flow'),
      ('App info', 'Version'),
      ('Legal & safety', 'Terms of service'),
      ('Accounts Center', 'No account connected'),
    ]) {
      await visible(tester, find.text(entry.$1));
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      await visible(tester, find.text(entry.$2));
      expect(find.text(entry.$2), findsOneWidget);
      await back(tester);
      expect(appRouter.routeInformationProvider.value.uri.path, '/settings');
    }

    await visible(tester, find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('You’re not signed in'), findsOneWidget);
    await visible(tester, find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close settings'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/today');
    expect(find.byTooltip('More').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deep-linked settings pages support platform back', (
    tester,
  ) async {
    await openApp(tester, location: '/settings/privacy');
    expect(find.text('Security'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('App settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('workspace menu opens Settings and restores the dock on return', (
    tester,
  ) async {
    await openApp(tester, location: '/today');
    await tester.tap(find.bySemanticsLabel('Open workspace menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('App settings'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/today');
    expect(find.byTooltip('More').hitTestable(), findsOneWidget);
    expect(flowNavigationVisible.value, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings scroll on a narrow screen with large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openApp(tester, size: const Size(320, 568));
    await tester.scrollUntilVisible(find.text('Accounts Center'), 180);
    await visible(tester, find.text('Accounts Center'));
    await tester.tap(find.text('Accounts Center'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No account connected'), 100);
    expect(find.text('No account connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
