import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/theme/flow_tokens.dart';
import '../../features/tasks/task.dart';

/// Shared chrome state for overlays that must cover the persistent app dock.
final flowNavigationVisible = ValueNotifier(true);

/// Lets the shell receive an outside tap while the dock itself remains a
/// self-contained expandable control.
final flowBottomNavigationExpanded = ValueNotifier(false);

class FlowIconButton extends StatelessWidget {
  const FlowIconButton({
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.semanticLabel,
    this.size = 50,
    this.iconSize = 21,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;
  final String? semanticLabel;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FlowColors.darkSurface : Colors.white;
    const alpha = .5;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: alpha),
                  surface.withValues(alpha: alpha),
                ],
              ),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: .18)
                    : Colors.white.withValues(alpha: .78),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, size: iconSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FlowPill extends StatelessWidget {
  const FlowPill({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? FlowColors.darkSurface : Colors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FlowRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .22 : .10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FlowRadius.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  surface.withValues(alpha: .5),
                  surface.withValues(alpha: .5),
                ],
              ),
              borderRadius: BorderRadius.circular(FlowRadius.pill),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: .18)
                    : Colors.white.withValues(alpha: .78),
              ),
            ),
            child: Padding(
              padding:
                  padding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Theme-aware, non-blurred page edges for content that scrolls behind the
/// app's floating chrome. Place this directly inside a page-level [Stack].
class FlowPageSoftEdges extends StatelessWidget {
  const FlowPageSoftEdges({
    required this.topHeight,
    required this.bottomHeight,
    super.key,
  });

  final double topHeight;
  final double bottomHeight;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas = dark ? FlowColors.darkCanvas : FlowColors.canvas;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: double.infinity,
                height: topHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        canvas.withValues(alpha: .98),
                        canvas.withValues(alpha: .92),
                        canvas.withValues(alpha: 0),
                      ],
                      stops: const [0, .7, 1],
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                height: bottomHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        canvas.withValues(alpha: 0),
                        canvas.withValues(alpha: .92),
                        canvas.withValues(alpha: .98),
                      ],
                      stops: const [0, .3, 1],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elevates compact header actions above a soft page edge.
class FlowHeaderActionSurface extends StatelessWidget {
  const FlowHeaderActionSurface({
    required this.child,
    this.pill = false,
    super.key,
  });

  final Widget child;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: pill ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: pill ? BorderRadius.circular(FlowRadius.pill) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .42 : .24),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A plain tappable icon for use inside one shared [FlowHeaderActionSurface].
///
/// Unlike [FlowIconButton], this deliberately draws no individual circle or
/// glass layer, so adjacent actions read as one combined control.
class FlowHeaderActionIcon extends StatelessWidget {
  const FlowHeaderActionIcon({
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    this.size = 42,
    this.iconSize = 20,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Icon(icon, size: iconSize)),
        ),
      ),
    );
  }
}

class FlowBottomNavigation extends StatefulWidget {
  const FlowBottomNavigation({
    required this.activeDestination,
    required this.onSelect,
    required this.onMoreDestination,
    required this.onOpenAgent,
    super.key,
  });

  /// The route currently shown in the main shell. This keeps the expanded
  /// navigation in sync even after a destination has collapsed the dock.
  final String activeDestination;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onMoreDestination;
  final VoidCallback onOpenAgent;

  @override
  State<FlowBottomNavigation> createState() => _FlowBottomNavigationState();
}

class _FlowBottomNavigationState extends State<FlowBottomNavigation> {
  static const _destinations = [
    _FlowMoreDestination(LucideIcons.inbox, 'Inbox'),
    _FlowMoreDestination(LucideIcons.focus, 'My tasks'),
    _FlowMoreDestination(LucideIcons.star, 'Favorites'),
    _FlowMoreDestination(LucideIcons.search, 'Search'),
    _FlowMoreDestination(LucideIcons.folder_kanban, 'Projects'),
    _FlowMoreDestination(LucideIcons.layers, 'Views'),
    _FlowMoreDestination(LucideIcons.users_round, 'Teams'),
    _FlowMoreDestination(LucideIcons.settings, 'Settings'),
  ];

  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    flowBottomNavigationExpanded.addListener(_syncExpandedState);
  }

  @override
  void dispose() {
    flowBottomNavigationExpanded.removeListener(_syncExpandedState);
    flowBottomNavigationExpanded.value = false;
    super.dispose();
  }

  void _syncExpandedState() {
    if (_expanded == flowBottomNavigationExpanded.value || !mounted) return;
    setState(() => _expanded = flowBottomNavigationExpanded.value);
  }

  void _setExpanded(bool expanded) {
    if (_expanded == expanded) return;
    setState(() => _expanded = expanded);
    flowBottomNavigationExpanded.value = expanded;
  }

  void _handlePrimaryTap(int index) {
    if (index == 3) {
      _setExpanded(!_expanded);
      return;
    }
    _setExpanded(false);
    widget.onSelect(index);
  }

  void _handleMoreDestination(String destination) {
    _setExpanded(false);
    widget.onMoreDestination(destination);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const primaryItems = [
      LucideIcons.inbox,
      LucideIcons.focus,
      LucideIcons.star,
    ];
    final currentDestination = _destinations
        .cast<_FlowMoreDestination?>()
        .firstWhere(
          (destination) => destination?.label == widget.activeDestination,
          orElse: () => null,
        );
    final moreIcon = switch (currentDestination?.label) {
      'Inbox' || 'My tasks' || 'Favorites' || null => LucideIcons.ellipsis,
      _ => currentDestination!.icon,
    };
    final items = [...primaryItems, moreIcon];
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24, 0, 24, 25),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity <= -120) _setExpanded(true);
                  if (velocity >= 120) _setExpanded(false);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  height: _expanded ? 480 : 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(FlowRadius.large),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? .24 : .13),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: dark ? .18 : .10),
                        blurRadius: 24,
                        spreadRadius: 1,
                        offset: const Offset(0, 13),
                      ),
                      if (!dark)
                        const BoxShadow(
                          color: Color(0x5CFFFFFF),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: Offset(0, -1),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(FlowRadius.large),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: dark
                                ? const [Color(0x80464858), Color(0x80464858)]
                                : const [Color(0x80FFFFFF), Color(0x80FFFFFF)],
                          ),
                          borderRadius: BorderRadius.circular(FlowRadius.large),
                          border: Border.all(
                            color: dark
                                ? Colors.white.withValues(alpha: .28)
                                : Colors.white.withValues(alpha: .58),
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: IgnorePointer(
                                ignoring: !_expanded,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  opacity: _expanded ? 1 : 0,
                                  child: _FlowExpandedNavigation(
                                    dark: dark,
                                    destinations: _destinations,
                                    selectedDestination:
                                        widget.activeDestination,
                                    onCollapse: () => _setExpanded(false),
                                    onSelect: _handleMoreDestination,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 55,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: List.generate(items.length, (index) {
                                  final selected =
                                      !_expanded &&
                                      switch (index) {
                                        0 =>
                                          widget.activeDestination == 'Inbox',
                                        1 =>
                                          widget.activeDestination ==
                                              'My tasks',
                                        2 =>
                                          widget.activeDestination ==
                                              'Favorites',
                                        _ =>
                                          currentDestination != null &&
                                              currentDestination.label !=
                                                  'Inbox' &&
                                              currentDestination.label !=
                                                  'My tasks' &&
                                              currentDestination.label !=
                                                  'Favorites',
                                      };
                                  return Semantics(
                                    button: true,
                                    selected: selected,
                                    label: switch (index) {
                                      0 => 'Inbox',
                                      1 => 'My tasks',
                                      2 => 'Favorites',
                                      _ => 'More',
                                    },
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _handlePrimaryTap(index),
                                      child: SizedBox(
                                        width: 66,
                                        height: 52,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            AnimatedScale(
                                              scale: selected ? 1 : 0,
                                              duration: const Duration(
                                                milliseconds: 350,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              child: Container(
                                                width: double.infinity,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  color: dark
                                                      ? Colors.white.withValues(
                                                          alpha: .14,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: .055,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(30),
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              items[index],
                                              size: 28,
                                              color: const Color(0xFF0A0A0A),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _FlowLiquidAgentButton(dark: dark, onPressed: widget.onOpenAgent),
          ],
        ),
      ),
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
      Divider(height: 19, color: dark ? Colors.white12 : FlowColors.line),
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
                  Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: .28)
                      : Colors.white.withValues(alpha: .58),
                ),
              ),
              child: const SizedBox(
                width: 58,
                height: 58,
                child: Icon(
                  LucideIcons.bot,
                  size: 25,
                  color: Color(0xFF0A0A0A),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FlowTaskTile extends StatelessWidget {
  const FlowTaskTile({
    required this.task,
    required this.onToggle,
    this.onTap,
    super.key,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.white60
        : FlowColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: FlowMotion.quick,
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: task.completed
                        ? FlowColors.blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: task.completed
                          ? FlowColors.blue
                          : muted.withValues(alpha: .55),
                      width: 1.6,
                    ),
                  ),
                  child: task.completed
                      ? const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.completed ? muted : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          task.id,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(width: 8),
                        _PriorityDot(priority: task.priority),
                        const SizedBox(width: 5),
                        Text(
                          task.project,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.urgent => const Color(0xFFE75858),
      TaskPriority.high => const Color(0xFFEF985B),
      TaskPriority.medium => const Color(0xFF7C98DF),
      TaskPriority.low => FlowColors.muted,
    };
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

Future<T?> showFlowSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  flowNavigationVisible.value = false;
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => builder(context),
    );
  } finally {
    flowNavigationVisible.value = true;
  }
}

class FlowSheetFrame extends StatelessWidget {
  const FlowSheetFrame({required this.child, this.heightFactor, super.key});
  final Widget child;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FractionallySizedBox(
      heightFactor: heightFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF273C48) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : const Color(0xFFE2E2E4),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    const FlowPageSoftEdges(topHeight: 54, bottomHeight: 54),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
