import 'package:flow_app/app/app.dart';
import 'package:flow_app/app/router/app_router.dart';
import 'package:flow_app/shared/widgets/flow_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

final appRouter = createAppRouter();

void main() {
  final dock = find.byKey(const ValueKey('flow-navigation-container'));
  final tabs = find.byKey(const ValueKey('flow-navigation-tabs'));

  setUp(() {
    flowBottomNavigationExpanded.value = false;
    flowNavigationVisible.value = true;
  });

  Future<void> showDock(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    ValueChanged<String>? onMoreDestination,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FlowBottomNavigation(
              activeDestination: 'My tasks',
              onSelect: (_) {},
              onMoreDestination: onMoreDestination ?? (_) {},
              onOpenAgent: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('three primary tabs keep Favorites inside More', (tester) async {
    String? destination;
    await showDock(tester, onMoreDestination: (value) => destination = value);
    final collapsedHeight = tester.getSize(dock).height;
    final primaryLabels = tester
        .widgetList<Semantics>(
          find.descendant(of: tabs, matching: find.byType(Semantics)),
        )
        .where((widget) => widget.properties.button == true)
        .map((widget) => widget.properties.label);
    expect(primaryLabels, ['Inbox', 'My tasks', 'More']);
    expect(find.text('Favorites').hitTestable(), findsNothing);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Favorites').hitTestable(), findsOneWidget);
    expect(tester.getSize(dock).width, 350);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(destination, 'Favorites');
    expect(tester.getSize(dock).height, collapsedHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dock follows a held drag and settles at either end', (
    tester,
  ) async {
    await showDock(tester);
    final collapsed = tester.getRect(dock);
    final gesture = await tester.startGesture(tester.getCenter(tabs));
    // First move wins the gesture arena; subsequent moves track the finger.
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    final partial = tester.getRect(dock);
    expect(partial.height, greaterThan(collapsed.height + 90));
    expect(partial.height, lessThan(460));
    expect(partial.width, greaterThan(collapsed.width));
    expect(partial.bottom, collapsed.bottom);
    await gesture.moveBy(const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, 460);

    final handle = find.byKey(const ValueKey('flow-navigation-handle'));
    final closing = await tester.startGesture(tester.getCenter(handle));
    await closing.moveBy(const Offset(0, 24));
    await tester.pump();
    await closing.moveBy(const Offset(0, 260));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(dock).height, lessThan(220));
    await closing.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, collapsed.height);
    expect(flowBottomNavigationExpanded.value, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short drag closes and a cancelled drag does not leave it stuck',
    (tester) async {
      await showDock(tester);
      final collapsedHeight = tester.getSize(dock).height;
      final gesture = await tester.startGesture(tester.getCenter(tabs));
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, collapsedHeight);

      final cancelled = await tester.startGesture(tester.getCenter(tabs));
      await cancelled.moveBy(const Offset(0, -24));
      await tester.pump();
      await cancelled.moveBy(const Offset(0, -250));
      await tester.pump();
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, 460);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, collapsedHeight);
    },
  );

  testWidgets('expanded menu fits a small landscape viewport and scrolls', (
    tester,
  ) async {
    await showDock(tester, size: const Size(568, 320));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(tester.getRect(dock).top, greaterThanOrEqualTo(16));
    await tester.scrollUntilVisible(find.text('Settings'), 100);
    await tester.pumpAndSettle();
    expect(find.text('Settings').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('agent Automate returns to the same page with a usable dock', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appRouter.go('/today');
    await tester.pumpWidget(ProviderScope(child: FlowApp(router: appRouter)));
    await tester.pumpAndSettle();

    for (final location in ['/today', '/inbox', '/favorites', '/search']) {
      appRouter.go(location);
      await tester.pumpAndSettle();
      final collapsedHeight = tester.getSize(dock).height;
      await tester.tap(find.bySemanticsLabel('Open agent mode'));
      await tester.pumpAndSettle();
      expect(find.byType(FlowBottomNavigation), findsNothing);
      await tester.tap(find.text('Automate'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Exit AI layer'));
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, location);
      expect(find.byTooltip('More').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Flow workspace').hitTestable(), findsOneWidget);
      await tester.tapAt(const Offset(190, 180));
      await tester.pumpAndSettle();
      expect(tester.getSize(dock).height, collapsedHeight);

      // Platform back must restore the same shell as the close button does.
      await tester.tap(find.bySemanticsLabel('Open agent mode'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, location);
      expect(find.byTooltip('More').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    // Opening the agent URL directly still has a working close action.
    appRouter.go('/ai-layer');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Exit AI layer'));
    await tester.pumpAndSettle();
    expect(appRouter.routeInformationProvider.value.uri.path, '/today');
    expect(find.byTooltip('More').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'the third tab shows the active extra destination and still opens More',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      appRouter.go('/today');
      await tester.pumpWidget(ProviderScope(child: FlowApp(router: appRouter)));
      await tester.pumpAndSettle();

      Finder tabIcon(IconData icon) =>
          find.descendant(of: tabs, matching: find.byIcon(icon));
      expect(tabIcon(LucideIcons.ellipsis), findsOneWidget);
      for (final destination in [
        ('Favorites', '/favorites', LucideIcons.star),
        ('Search', '/search', LucideIcons.search),
      ]) {
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        expect(tabIcon(LucideIcons.ellipsis), findsOneWidget);
        await tester.tap(find.text(destination.$1).hitTestable());
        await tester.pumpAndSettle();
        expect(
          appRouter.routeInformationProvider.value.uri.path,
          destination.$2,
        );
        expect(tabIcon(destination.$3), findsOneWidget);
        expect(tabIcon(LucideIcons.ellipsis), findsNothing);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('${destination.$1}, more destinations'),
          ),
          matchesSemantics(
            label: '${destination.$1}, more destinations',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasTapAction: true,
          ),
        );
      }

      await tester.tap(find.byTooltip('Inbox'));
      await tester.pumpAndSettle();
      expect(tabIcon(LucideIcons.ellipsis), findsOneWidget);
      // Unavailable destinations must not impersonate an active page.
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Projects').hitTestable());
      await tester.pumpAndSettle();
      expect(appRouter.routeInformationProvider.value.uri.path, '/inbox');
      expect(tabIcon(LucideIcons.ellipsis), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'selection glides, redirects without jumping and respects reduced motion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destination = ValueNotifier('Inbox');
      final reducedMotion = ValueNotifier(false);
      addTearDown(destination.dispose);
      addTearDown(reducedMotion.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: reducedMotion,
            builder: (context, reduced, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ValueListenableBuilder<String>(
                  valueListenable: destination,
                  builder: (context, active, _) => FlowBottomNavigation(
                    activeDestination: active,
                    onSelect: (index) =>
                        destination.value = index == 0 ? 'Inbox' : 'My tasks',
                    onMoreDestination: (value) => destination.value = value,
                    onOpenAgent: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final selection = find.byKey(const ValueKey('flow-navigation-selection'));
      final start = tester.getRect(selection);
      final target = tester.getCenter(find.byTooltip('My tasks')).dx;
      await tester.tap(find.byTooltip('My tasks'));
      await tester.pump();
      expect(tester.getCenter(selection).dx, closeTo(start.center.dx, .01));
      await tester.pump(const Duration(milliseconds: 80));
      final moving = tester.getRect(selection);
      expect(moving.center.dx, greaterThan(start.center.dx));
      expect(moving.center.dx, lessThan(target));
      expect(moving.width, greaterThan(start.width));

      await tester.tap(find.byTooltip('Inbox'));
      await tester.pump();
      expect(tester.getCenter(selection).dx, closeTo(moving.center.dx, .01));
      await tester.pumpAndSettle();
      expect(tester.getCenter(selection).dx, closeTo(start.center.dx, .1));
      expect(tester.getSize(selection).width, closeTo(start.width, .1));

      destination.value = 'Favorites';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      reducedMotion.value = true;
      await tester.pump();
      expect(
        tester.getCenter(selection).dx,
        closeTo(tester.getCenter(find.byTooltip('More')).dx, .1),
      );
      await tester.tap(find.byTooltip('My tasks'));
      await tester.pump();
      expect(tester.getCenter(selection).dx, closeTo(target, .1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
