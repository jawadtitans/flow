import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Slowly drifting violet, lilac and blue clouds fading into a white canvas.
class StartupBackground extends StatefulWidget {
  const StartupBackground({super.key});

  @override
  State<StartupBackground> createState() => _StartupBackgroundState();
}

class _StartupBackgroundState extends State<StartupBackground>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _StartupCloudPainter(_motion),
      child: const SizedBox.expand(),
    ),
  );
}

class _StartupCloudPainter extends CustomPainter {
  _StartupCloudPainter(this.motion) : super(repaint: motion);

  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = motion.value * math.pi * 2;
    canvas.drawColor(const Color(0xFFFFFCFF), BlendMode.src);

    // Elliptical gradients keep the feathered edges soft at every screen size,
    // without allocating a full-screen blur layer on each animation frame.
    void cloud(Color color, double x, double y, double rx, double ry) {
      canvas.save();
      canvas.translate(size.width * x, size.height * y);
      canvas.scale(size.width * rx, size.height * ry);
      const bounds = Rect.fromLTWH(-1, -1, 2, 2);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color,
            color.withValues(alpha: color.a * .84),
            color.withValues(alpha: color.a * .36),
            color.withValues(alpha: 0),
          ],
          stops: const [0, .28, .62, 1],
        ).createShader(bounds);
      canvas.drawOval(bounds, paint);
      canvas.restore();
    }

    cloud(
      const Color(0xBFBAD9FA),
      .12 + .045 * math.sin(phase),
      .48 + .035 * math.cos(phase),
      .88,
      .37,
    );
    cloud(
      const Color(0xCCDDA1F5),
      .79 + .045 * math.cos(phase),
      .49 + .04 * math.sin(phase),
      .82,
      .42,
    );
    cloud(
      const Color(0xAFBC83EF),
      .55 + .05 * math.sin(phase + 1.8),
      .66 + .025 * math.cos(phase),
      .68,
      .27,
    );
    cloud(
      const Color(0xE37B22EE),
      .52 + .045 * math.sin(phase + .5),
      .50 + .025 * math.cos(phase + .8),
      .66 + .025 * math.sin(phase),
      .35,
    );
    cloud(
      const Color(0x78585AF1),
      .26 + .055 * math.cos(phase + .4),
      .48 + .04 * math.sin(phase),
      .56,
      .29,
    );
  }

  @override
  bool shouldRepaint(_StartupCloudPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
