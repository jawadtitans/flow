import 'package:flutter/material.dart';

/// Visual feedback only; the child retains its gestures and accessibility.
class FlowPressFeedback extends StatefulWidget {
  const FlowPressFeedback({
    required this.child,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final bool enabled;

  @override
  State<FlowPressFeedback> createState() => _FlowPressFeedbackState();
}

class _FlowPressFeedbackState extends State<FlowPressFeedback> {
  bool _pressed = false;
  Offset? _origin;

  void _release() {
    _origin = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (event) {
            _origin = event.position;
            setState(() => _pressed = true);
          }
        : null,
    onPointerMove: (event) {
      if (_origin != null && (event.position - _origin!).distance > 10) {
        _release();
      }
    },
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: AnimatedScale(
      scale: _pressed && widget.enabled ? .96 : 1,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: _pressed ? 100 : 220),
      curve: _pressed ? Curves.easeOutCubic : Curves.easeOutBack,
      child: widget.child,
    ),
  );
}
