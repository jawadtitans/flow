// Flow Liquid Bottom Navigation
//
// A portable copy of Flow's complete bottom navigation widget, including the
// expandable menu, agent shortcut, spring selection, active destination icon,
// glass highlight, dark appearance and reduced-motion support.
//
// Requirements: Flutter (verified with 3.41.7) and this pubspec.yaml dependency:
//   flutter_lucide: ^1.47.0
// No Flow project files or image assets are required.
//
// Usage: import this file and place FlowBottomNavigation inside
// Align(alignment: Alignment.bottomCenter, child: ...) in a full-screen Stack.
// Supply activeDestination from your current route ('Inbox', 'My tasks',
// 'Favorites', 'Search', etc.). onSelect receives 0 for Inbox and 1 for My tasks;
// onMoreDestination receives the expanded menu item's label. onOpenAgent opens
// your agent screen. The callbacks connect to your own pages/router.
//
// To dismiss the menu on an outside tap, place a ValueListenableBuilder<bool>
// for flowBottomNavigationExpanded between your page content and the dock.
// When expanded, use a full-screen GestureDetector whose onTap sets
// flowBottomNavigationExpanded.value = false; otherwise ignore pointer events.
// Keep the dock mounted when switching pages so its spring can animate.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Lets the shell dismiss the expanded dock with an outside tap.
final flowBottomNavigationExpanded = ValueNotifier(false);

class FlowBottomNavigation extends StatefulWidget {
  const FlowBottomNavigation({
    required this.activeDestination,
    required this.onSelect,
    required this.onMoreDestination,
    required this.onOpenAgent,
    super.key,
  });

  final String activeDestination;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onMoreDestination;
  final VoidCallback onOpenAgent;

  @override
  State<FlowBottomNavigation> createState() => _FlowBottomNavigationState();
}

class _FlowBottomNavigationState extends State<FlowBottomNavigation>
    with SingleTickerProviderStateMixin {
  static const _collapsedHeight = 59.0;
  static const _destinations = [
    _FlowMoreDestination(LucideIcons.star, 'Favorites'),
    _FlowMoreDestination(LucideIcons.search, 'Search'),
    _FlowMoreDestination(LucideIcons.folder_kanban, 'Projects'),
    _FlowMoreDestination(LucideIcons.layers, 'Views'),
    _FlowMoreDestination(LucideIcons.users_round, 'Teams'),
    _FlowMoreDestination(LucideIcons.settings, 'Settings'),
  ];

  late final _expansion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: flowBottomNavigationExpanded.value ? 1 : 0,
  );
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    flowBottomNavigationExpanded.addListener(_syncExpandedState);
  }

  @override
  void dispose() {
    flowBottomNavigationExpanded.removeListener(_syncExpandedState);
    _expansion.dispose();
    super.dispose();
  }

  void _syncExpandedState() {
    if (_dragging) return;
    _settle(flowBottomNavigationExpanded.value);
  }

  void _settle(bool expanded) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _expansion.value = expanded ? 1 : 0;
    } else {
      _expansion.animateTo(expanded ? 1 : 0, curve: Curves.easeOutCubic);
    }
  }

  void _setExpanded(bool expanded) {
    _dragging = false;
    if (flowBottomNavigationExpanded.value == expanded) {
      _settle(expanded);
    } else {
      flowBottomNavigationExpanded.value = expanded;
    }
  }

  void _endDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    _setExpanded(velocity.abs() > 250 ? velocity < 0 : _expansion.value >= .5);
  }

  void _handlePrimaryTap(int index) {
    if (index == 2) {
      _setExpanded(!flowBottomNavigationExpanded.value);
    } else {
      _setExpanded(false);
      widget.onSelect(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final expandedHeight = math.max(
              _collapsedHeight,
              math.min(
                460.0,
                constraints.maxHeight - MediaQuery.paddingOf(context).top - 16,
              ),
            );
            final travel = expandedHeight - _collapsedHeight;
            final compactWidth = math.max(0.0, constraints.maxWidth - 74);
            return AnimatedBuilder(
              animation: _expansion,
              builder: (context, _) {
                final progress = _expansion.value;
                final radius = BorderRadius.circular(32);
                final agentOpacity = (1 - progress * 4).clamp(0.0, 1.0);
                final navigationHeight = _collapsedHeight + travel * progress;
                return SizedBox(
                  width: constraints.maxWidth,
                  height: math.max(58, navigationHeight),
                  child: Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          ignoring: progress > .01,
                          child: ExcludeSemantics(
                            excluding: progress > .01,
                            child: Opacity(
                              opacity: agentOpacity,
                              child: Transform.scale(
                                scale: .85 + .15 * agentOpacity,
                                child: _FlowLiquidAgentButton(
                                  dark: dark,
                                  onPressed: () {
                                    _setExpanded(false);
                                    widget.onOpenAgent();
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        key: const ValueKey('flow-navigation-container'),
                        height: navigationHeight,
                        width: lerpDouble(
                          compactWidth,
                          constraints.maxWidth,
                          progress,
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (_) {
                            _dragging = true;
                            _expansion.stop();
                            flowBottomNavigationExpanded.value = true;
                          },
                          onVerticalDragUpdate: (details) {
                            if (travel <= 0) return;
                            _expansion.value =
                                (_expansion.value - details.delta.dy / travel)
                                    .clamp(0.0, 1.0);
                          },
                          onVerticalDragEnd: _endDrag,
                          onVerticalDragCancel: () =>
                              _setExpanded(_expansion.value >= .5),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: radius,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: dark ? .26 : .14,
                                  ),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: radius,
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 20,
                                  sigmaY: 20,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        (dark
                                                ? _FlowNavigationColors
                                                      .darkSurface
                                                : Colors.white)
                                            .withValues(
                                              alpha: .72 + .14 * progress,
                                            ),
                                    borderRadius: radius,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildExpandedMenu(
                                        dark,
                                        progress,
                                        travel,
                                      ),
                                      _buildTabs(dark, progress),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandedMenu(bool dark, double progress, double travel) =>
      Expanded(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: travel,
            maxHeight: travel,
            child: IgnorePointer(
              ignoring: progress < .99,
              child: ExcludeSemantics(
                excluding: progress < .99,
                child: Opacity(
                  opacity: progress,
                  child: Column(
                    children: [
                      SizedBox(
                        key: const ValueKey('flow-navigation-handle'),
                        height: math.min(24, travel),
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 4,
                            decoration: BoxDecoration(
                              color: dark ? Colors.white38 : Colors.black26,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _FlowExpandedNavigation(
                          dark: dark,
                          destinations: _destinations,
                          selectedDestination: widget.activeDestination,
                          onCollapse: () => _setExpanded(false),
                          onSelect: (destination) {
                            _setExpanded(false);
                            widget.onMoreDestination(destination);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildTabs(bool dark, double progress) {
    final expanded = progress > .5;
    final destination = _destinations
        .where((item) => item.label == widget.activeDestination)
        .firstOrNull;
    final activeIndex = expanded
        ? 2
        : switch (widget.activeDestination) {
            'Inbox' => 0,
            'My tasks' => 1,
            _ => destination == null ? -1 : 2,
          };
    return SizedBox(
      key: const ValueKey('flow-navigation-tabs'),
      height: _collapsedHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: .5),
        child: _FlowNavigationTabs(
          dark: dark,
          activeIndex: activeIndex,
          moreDestination: expanded ? null : destination,
          onTap: _handlePrimaryTap,
        ),
      ),
    );
  }
}

/// One shared selection surface travels between the tabs. A new tap redirects
/// the spring from its current position and velocity, even midway through a move.
class _FlowNavigationTabs extends StatefulWidget {
  const _FlowNavigationTabs({
    required this.dark,
    required this.activeIndex,
    required this.moreDestination,
    required this.onTap,
  });

  final bool dark;
  final int activeIndex;
  final _FlowMoreDestination? moreDestination;
  final ValueChanged<int> onTap;

  @override
  State<_FlowNavigationTabs> createState() => _FlowNavigationTabsState();
}

class _FlowNavigationTabsState extends State<_FlowNavigationTabs>
    with SingleTickerProviderStateMixin {
  static final _spring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
    bounce: .16,
  );
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: math.max(0, widget.activeIndex).toDouble(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = math.max(0, widget.activeIndex).toDouble();
    }
  }

  @override
  void didUpdateWidget(_FlowNavigationTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex == widget.activeIndex) return;
    final target = math.max(0, widget.activeIndex).toDouble();
    if (MediaQuery.disableAnimationsOf(context) || oldWidget.activeIndex < 0) {
      _position.value = target;
      return;
    }
    _position.animateWith(
      SpringSimulation(
        _spring,
        _position.value,
        target,
        _position.velocity,
        tolerance: const Tolerance(distance: .001, velocity: .001),
      ),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final icons = [
      LucideIcons.inbox,
      LucideIcons.focus,
      widget.moreDestination?.icon ?? LucideIcons.ellipsis,
    ];
    const labels = ['Inbox', 'My tasks', 'More'];
    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / icons.length;
        final tabWidth = math.min(97.0, slotWidth);
        final tabHeight = math.min(50.0, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (widget.activeIndex >= 0)
              AnimatedBuilder(
                animation: _position,
                builder: (context, child) {
                  // Stretch slightly while moving, then relax as the spring
                  // settles. Layout and hit areas stay fixed throughout.
                  final speed = (_position.velocity.abs() / 8).clamp(0.0, 1.0);
                  final width = tabWidth * (1 + .14 * speed);
                  final height = tabHeight * (1 - .05 * speed);
                  return Positioned(
                    left: slotWidth * _position.value + (slotWidth - width) / 2,
                    top: (constraints.maxHeight - height) / 2,
                    width: width,
                    height: height,
                    child: child!,
                  );
                },
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey('flow-navigation-selection'),
                    // Keep the original tint below the sheen: a gradient in
                    // the same BoxDecoration would override the base color.
                    decoration: BoxDecoration(
                      color: (widget.dark ? Colors.white : Colors.black)
                          .withValues(alpha: widget.dark ? .18 : .085),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: widget.dark ? .10 : .025,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(27),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(
                              alpha: widget.dark ? .10 : .07,
                            ),
                            Colors.white.withValues(alpha: .015),
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(
                              alpha: widget.dark ? .055 : .035,
                            ),
                          ],
                          stops: const [0, .22, .7, 1],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: widget.dark ? .20 : .36,
                          ),
                          width: .65,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: List.generate(icons.length, (index) {
                final label = index == 2 && widget.moreDestination != null
                    ? '${widget.moreDestination!.label}, more destinations'
                    : labels[index];
                return Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      selected: widget.activeIndex == index,
                      label: label,
                      child: Tooltip(
                        message: labels[index],
                        excludeFromSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTap(index),
                          child: SizedBox(
                            width: 97,
                            height: 50,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: reducedMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: .88,
                                          end: 1,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: Icon(
                                  icons[index],
                                  key: ValueKey(icons[index]),
                                  size: 28,
                                  color: widget.dark
                                      ? Colors.white
                                      : _FlowNavigationColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _FlowMoreDestination {
  const _FlowMoreDestination(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _FlowExpandedNavigation extends StatelessWidget {
  const _FlowExpandedNavigation({
    required this.dark,
    required this.destinations,
    required this.selectedDestination,
    required this.onCollapse,
    required this.onSelect,
  });

  final bool dark;
  final List<_FlowMoreDestination> destinations;
  final String selectedDestination;
  final VoidCallback onCollapse;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
    physics: const BouncingScrollPhysics(),
    children: [
      Row(
        children: [
          const CircleAvatar(
            radius: 15,
            backgroundColor: Color(0xFFE98977),
            child: Text(
              'F',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Flow workspace',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          Semantics(
            button: true,
            label: 'Collapse navigation',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCollapse,
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(LucideIcons.chevron_down, size: 21),
              ),
            ),
          ),
        ],
      ),
      Divider(
        height: 19,
        color: dark ? Colors.white12 : _FlowNavigationColors.line,
      ),
      ...destinations.map((destination) {
        final selected = destination.label == selectedDestination;
        return Semantics(
          button: true,
          selected: selected,
          label: destination.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(destination.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? (dark
                          ? Colors.black.withValues(alpha: .34)
                          : const Color(0xFFDCDCE0))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(width: 32, child: Icon(destination.icon, size: 21)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ],
  );
}

class _FlowLiquidAgentButton extends StatelessWidget {
  const _FlowLiquidAgentButton({required this.dark, required this.onPressed});

  final bool dark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open agent mode',
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .25 : .14),
            blurRadius: 26,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .16 : .09),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
          if (!dark)
            const BoxShadow(
              color: Color(0x66FFFFFF),
              blurRadius: 7,
              spreadRadius: 1,
              offset: Offset(0, -1),
            ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onPressed,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [Color(0x80464858), Color(0x80464858)]
                      : const [Color(0x80FFFFFF), Color(0x80FFFFFF)],
                ),
              ),
              child: SizedBox(
                width: 58,
                height: 58,
                child: Icon(
                  LucideIcons.bot,
                  size: 25,
                  color: dark ? Colors.white : _FlowNavigationColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Theme values embedded to keep this file portable.
abstract final class _FlowNavigationColors {
  static const darkSurface = Color(0xFF464858);
  static const ink = Color(0xFF17181B);
  static const line = Color(0xFFE9E9EC);
}
