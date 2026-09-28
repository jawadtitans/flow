import 'package:flutter/material.dart';

import '../../core/theme/flow_tokens.dart';

enum FlowNotificationType { info, success, warning, error }

/// Shows one app-wide message. A new message replaces the current one.
void showFlowNotification(
  BuildContext context, {
  required String message,
  String? title,
  FlowNotificationType type = FlowNotificationType.info,
  Duration duration = const Duration(seconds: 6),
}) {
  final scope = context.getInheritedWidgetOfExactType<_FlowNotificationScope>();
  if (scope == null) {
    throw FlutterError('showFlowNotification requires a FlowNotificationHost.');
  }
  assert(duration > Duration.zero);
  scope.state.show(message, title, type, duration);
}

/// Lives above the router so messages survive navigation and cover app sheets.
class FlowNotificationHost extends StatefulWidget {
  const FlowNotificationHost({required this.child, super.key});

  final Widget child;

  @override
  State<FlowNotificationHost> createState() => _FlowNotificationHostState();
}

class _FlowNotificationHostState extends State<FlowNotificationHost> {
  _Notice? _notice;

  void show(
    String message,
    String? title,
    FlowNotificationType type,
    Duration duration,
  ) {
    setState(() => _notice = _Notice(message, title, type, duration));
  }

  void _remove(_Notice notice) {
    if (mounted && identical(_notice, notice)) {
      setState(() => _notice = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical;
    return _FlowNotificationScope(
      state: this,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (notice != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 460,
                        maxHeight: (availableHeight * .5).clamp(0, 320),
                      ),
                      child: _NotificationCard(
                        key: ObjectKey(notice),
                        notice: notice,
                        onDismiss: () => _remove(notice),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlowNotificationScope extends InheritedWidget {
  const _FlowNotificationScope({required this.state, required super.child});

  final _FlowNotificationHostState state;

  @override
  bool updateShouldNotify(_FlowNotificationScope oldWidget) => false;
}

class _Notice {
  const _Notice(this.message, this.title, this.type, this.duration);

  final String message;
  final String? title;
  final FlowNotificationType type;
  final Duration duration;
}

class _NotificationCard extends StatefulWidget {
  const _NotificationCard({
    required this.notice,
    required this.onDismiss,
    super.key,
  });

  final _Notice notice;
  final VoidCallback onDismiss;

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with TickerProviderStateMixin {
  late final AnimationController _entrance =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
        reverseDuration: const Duration(milliseconds: 200),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _syncCountdown();
      });
  late final AnimationController _lifetime =
      AnimationController(
        vsync: this,
        duration: widget.notice.duration,
        // Accessibility's reduced animation duration must not shorten reading time.
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _dismiss();
      });
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final CurvedAnimation _iconCurve = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(.15, 1, curve: Curves.easeOutBack),
  );
  bool _started = false;
  bool _closing = false;
  bool _hovered = false;
  bool _pressed = false;
  bool _reduceMotion = false;
  bool _accessibleNavigation = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    if (!_started) {
      _started = true;
      if (_reduceMotion) {
        _entrance.value = 1;
      } else {
        _entrance.forward();
      }
    } else if (_reduceMotion && !_closing) {
      _entrance.value = 1;
    }
    _syncCountdown();
  }

  void _syncCountdown() {
    if (_closing || _hovered || _pressed || _accessibleNavigation) {
      _lifetime.stop();
    } else if (_entrance.isCompleted && !_lifetime.isAnimating) {
      _lifetime.forward();
    }
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _lifetime.stop();
    if (!_reduceMotion) {
      await _entrance.reverse().orCancel.catchError((Object _) {});
    }
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _curve.dispose();
    _iconCurve.dispose();
    _entrance.dispose();
    _lifetime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (accent, icon, defaultTitle) = switch (widget.notice.type) {
      FlowNotificationType.info => (
        dark ? const Color(0xFF98B7FF) : FlowColors.blue,
        Icons.info_outline_rounded,
        'Flow',
      ),
      FlowNotificationType.success => (
        dark ? const Color(0xFF70DCB0) : const Color(0xFF16825D),
        Icons.check_rounded,
        'Done',
      ),
      FlowNotificationType.warning => (
        dark ? const Color(0xFFF5CA79) : const Color(0xFF9B650D),
        Icons.priority_high_rounded,
        'Heads up',
      ),
      FlowNotificationType.error => (
        dark ? const Color(0xFFFFA5AD) : const Color(0xFFC73D50),
        Icons.error_outline_rounded,
        'Something went wrong',
      ),
    };
    final surface = dark ? const Color(0xFF1C3948) : Colors.white;
    final foreground = dark ? const Color(0xFFF5F7FA) : FlowColors.ink;
    return MouseRegion(
      onEnter: (_) {
        _hovered = true;
        _syncCountdown();
      },
      onExit: (_) {
        _hovered = false;
        _syncCountdown();
      },
      child: Listener(
        onPointerDown: (_) {
          _pressed = true;
          _syncCountdown();
        },
        onPointerUp: (_) {
          _pressed = false;
          _syncCountdown();
        },
        onPointerCancel: (_) {
          _pressed = false;
          _syncCountdown();
        },
        child: Dismissible(
          key: ObjectKey(widget.notice),
          direction: DismissDirection.horizontal,
          resizeDuration: null,
          movementDuration: _reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          onDismissed: (_) => widget.onDismiss(),
          child: FadeTransition(
            opacity: _curve,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -.35),
                end: Offset.zero,
              ).animate(_curve),
              child: ScaleTransition(
                scale: Tween(begin: .96, end: 1.0).animate(_curve),
                alignment: Alignment.topCenter,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  onDismiss: _dismiss,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? .28 : .09,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: surface,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(color: accent.withValues(alpha: .2)),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.alphaBlend(
                                accent.withValues(alpha: dark ? .08 : .045),
                                surface,
                              ),
                              surface,
                            ],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  8,
                                  14,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ScaleTransition(
                                      scale: Tween(
                                        begin: .65,
                                        end: 1.0,
                                      ).animate(_iconCurve),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: accent,
                                          size: 23,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 1),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.notice.title ??
                                                  defaultTitle,
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                height: 1.3,
                                                color: foreground,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              widget.notice.message,
                                              style: TextStyle(
                                                fontFamily: 'Roboto',
                                                fontSize: 13,
                                                height: 1.4,
                                                color: dark
                                                    ? const Color(0xFFD0DAE0)
                                                    : const Color(0xFF535B68),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _dismiss,
                                      style: IconButton.styleFrom(
                                        minimumSize: const Size.square(48),
                                        tapTargetSize:
                                            MaterialTapTargetSize.padded,
                                        foregroundColor: foreground.withValues(
                                          alpha: .55,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        semanticLabel: 'Dismiss notification',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!_accessibleNavigation && !_reduceMotion)
                              ExcludeSemantics(
                                child: AnimatedBuilder(
                                  animation: _lifetime,
                                  builder: (context, _) =>
                                      LinearProgressIndicator(
                                        value: 1 - _lifetime.value,
                                        minHeight: 3,
                                        color: accent.withValues(alpha: .65),
                                        backgroundColor: accent.withValues(
                                          alpha: .07,
                                        ),
                                      ),
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
          ),
        ),
      ),
    );
  }
}
