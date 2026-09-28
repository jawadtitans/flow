import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/flow_tokens.dart';

Color flowDialogSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF273B47)
    : const Color(0xFFF2F2F4);

/// Presents short prompts and scrollable information with the same motion.
Future<T?> showFlowDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x99080D18),
    transitionDuration: reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 380),
    pageBuilder: (context, animation, secondaryAnimation) =>
        SafeArea(child: builder(context)),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion) return child;
      final entering = animation.status != AnimationStatus.reverse;
      final motion = animation.drive(
        CurveTween(curve: entering ? Curves.easeOutBack : Curves.easeInCubic),
      );
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
        child: SlideTransition(
          position: motion.drive(
            Tween(begin: const Offset(0, .025), end: Offset.zero),
          ),
          child: ScaleTransition(
            scale: motion.drive(Tween(begin: .9, end: 1.0)),
            child: child,
          ),
        ),
      );
    },
  );
}

/// A rounded, softly frosted card with always-visible pill actions.
class FlowDialog extends StatelessWidget {
  const FlowDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 390,
    super.key,
  }) : assert(actions.length > 0);

  final String title;
  final Widget content;
  final List<FlowDialogAction> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF6F7FA) : FlowColors.ink;
    final shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(42),
      side: BorderSide(
        color: Colors.white.withValues(alpha: dark ? .14 : .85),
        width: 1.2,
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          shadows: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .3 : .16),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                color: flowDialogSurface(context).withValues(alpha: .97),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            namesRoute: true,
                            header: true,
                            child: Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.4,
                                height: 1.25,
                                color: foreground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              height: 1.4,
                              color: foreground,
                            ),
                            child: content,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonWidth =
                            (constraints.maxWidth - 10 * (actions.length - 1)) /
                            actions.length;
                        var stack = actions.length > 2;
                        for (final action in actions) {
                          final painter = TextPainter(
                            text: TextSpan(
                              text: action.label,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          )..layout();
                          stack = stack || painter.width + 32 > buttonWidth;
                          painter.dispose();
                        }
                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                actions[i],
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (var i = 0; i < actions.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: actions[i]),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FlowDialogAction extends StatelessWidget {
  const FlowDialogAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    super.key,
  }) : assert(!primary || !destructive);

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: primary
            ? FlowColors.blue
            : (dark ? const Color(0xFF3A4D58) : const Color(0xFFE4E4E8)),
        foregroundColor: primary
            ? Colors.white
            : destructive
            ? (dark ? const Color(0xFFFF919B) : const Color(0xFFE65361))
            : (dark ? Colors.white : FlowColors.ink),
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 17,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
