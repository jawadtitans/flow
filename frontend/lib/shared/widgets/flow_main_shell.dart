import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'flow_components.dart';

/// Keeps the primary navigation chrome mounted while the route body changes.
class FlowMainShell extends StatelessWidget {
  const FlowMainShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  String get _activeDestination => switch (location) {
    '/inbox' => 'Inbox',
    '/today' => 'My tasks',
    '/favorites' => 'Favorites',
    '/search' => 'Search',
    _ => '',
  };

  @override
  Widget build(BuildContext context) => ColoredBox(
    // Keep the app canvas behind the nested navigator during route changes.
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Stack(
      fit: StackFit.expand,
      children: [
        // The router owns this navigator. Keep its identity stable across
        // destination changes and when another route is pushed above it.
        child,
        ValueListenableBuilder<bool>(
          valueListenable: flowBottomNavigationExpanded,
          builder: (context, expanded, child) => IgnorePointer(
            ignoring: !expanded,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => flowBottomNavigationExpanded.value = false,
              child: child,
            ),
          ),
          child: const SizedBox.expand(),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ValueListenableBuilder<bool>(
            valueListenable: flowNavigationVisible,
            builder: (context, visible, child) => IgnorePointer(
              ignoring: !visible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: visible ? Offset.zero : const Offset(0, 1.15),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: visible ? 1 : 0,
                  child: child,
                ),
              ),
            ),
            child: FlowBottomNavigation(
              activeDestination: _activeDestination,
              onSelect: (index) => _navigate(context, index),
              onMoreDestination: (destination) =>
                  _navigateDestination(context, destination),
              onOpenAgent: () => context.push('/ai-layer'),
            ),
          ),
        ),
      ],
    ),
  );

  void _navigate(BuildContext context, int index) => context.go(switch (index) {
    0 => '/inbox',
    1 => '/today',
    _ => '/today',
  });

  void _navigateDestination(BuildContext context, String destination) =>
      switch (destination) {
        'Inbox' => context.go('/inbox'),
        'My tasks' => context.go('/today'),
        'Favorites' => context.go('/favorites'),
        'Search' => context.go('/search'),
        'Settings' => context.push('/settings'),
        _ => showFlowNotification(
          context,
          message: '$destination is coming soon',
        ),
      };
}
