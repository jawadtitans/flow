import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../core/theme/flow_tokens.dart';
import '../../features/tasks/task.dart';

export 'flow_bottom_navigation.dart';
export 'flow_dialog.dart';
export 'flow_notification.dart';

/// Shared chrome state for overlays that must cover the persistent app dock.
final flowNavigationVisible = ValueNotifier(true);

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
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: selected
            ? (dark ? Colors.white12 : FlowColors.selected)
            : (dark ? Colors.white10 : FlowColors.surface),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? Colors.white12 : FlowColors.surface,
        borderRadius: BorderRadius.circular(FlowRadius.pill),

        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color.fromARGB(11, 60, 65, 77),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: child,
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
    this.canvasColor,
    super.key,
  });

  final double topHeight;
  final double bottomHeight;
  final Color? canvasColor;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canvas =
        canvasColor ?? (dark ? FlowColors.darkCanvas : FlowColors.canvas);
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
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
