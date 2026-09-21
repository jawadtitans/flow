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
    // This remains visible beneath both fading pages, preventing a black frame
    // while the nested route is replaced.
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          reverseDuration: const Duration(milliseconds: 160),
          transitionBuilder: (page, animation) =>
              FadeTransition(opacity: animation, child: page),
          child: KeyedSubtree(key: ValueKey(location), child: child),
        ),
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
        ValueListenableBuilder<bool>(
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
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FlowBottomNavigation(
              activeDestination: _activeDestination,
              onSelect: (index) => _navigate(context, index),
              onMoreDestination: (destination) =>
                  _navigateDestination(context, destination),
              onOpenAgent: () => context.go('/ai-layer'),
            ),
          ),
        ),
      ],
    ),
  );

  void _navigate(BuildContext context, int index) => context.go(switch (index) {
    0 => '/inbox',
    1 => '/today',
    2 => '/favorites',
    _ => '/today',
  });

  void _navigateDestination(BuildContext context, String destination) =>
      switch (destination) {
        'Inbox' => context.go('/inbox'),
        'My tasks' => context.go('/today'),
        'Favorites' => context.go('/favorites'),
        'Search' => context.go('/search'),
        _ => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$destination is coming soon'))),
      };
}
