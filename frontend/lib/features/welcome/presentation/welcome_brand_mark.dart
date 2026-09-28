import 'package:flutter/material.dart';

import '../../../core/theme/flow_tokens.dart';

/// Vector contours traced from Flow's existing logo artwork. Painting the
/// symbol directly keeps it crisp at small sizes on every renderer.
class WelcomeBrandMark extends StatelessWidget {
  const WelcomeBrandMark({this.width = 28, super.key});
  final double width;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: width * 681 / 895,
      child: const CustomPaint(painter: _MarkPainter()),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _contours = <List<Offset>>[
    [
      Offset(61.23, 0.34),
      Offset(96.87, 0.34),
      Offset(98.32, 0.89),
      Offset(99.33, 2.01),
      Offset(99.66, 3.02),
      Offset(99.66, 20.11),
      Offset(99.22, 21.34),
      Offset(98.44, 22.23),
      Offset(96.87, 22.91),
      Offset(55.87, 22.91),
      Offset(52.29, 23.35),
      Offset(47.26, 25.03),
      Offset(43.13, 27.71),
      Offset(40.11, 30.84),
      Offset(35.64, 37.65),
      Offset(32.85, 41.23),
      Offset(29.61, 44.25),
      Offset(25.92, 46.37),
      Offset(22.46, 47.49),
      Offset(19.89, 47.82),
      Offset(3.35, 47.82),
      Offset(1.68, 47.26),
      Offset(0.89, 46.48),
      Offset(0.34, 45.14),
      Offset(0.34, 27.93),
      Offset(1.56, 25.81),
      Offset(3.80, 24.92),
      Offset(28.27, 24.92),
      Offset(32.40, 23.91),
      Offset(35.42, 22.23),
      Offset(38.55, 19.33),
      Offset(45.59, 9.16),
      Offset(49.83, 4.80),
      Offset(52.07, 3.24),
      Offset(55.53, 1.56),
    ],
    [
      Offset(58.77, 31.73),
      Offset(96.65, 31.73),
      Offset(98.32, 32.29),
      Offset(99.33, 33.41),
      Offset(99.66, 34.41),
      Offset(99.66, 50.28),
      Offset(99.33, 51.40),
      Offset(98.32, 52.51),
      Offset(96.54, 53.18),
      Offset(53.97, 53.30),
      Offset(49.72, 53.97),
      Offset(46.15, 55.20),
      Offset(41.79, 57.88),
      Offset(38.55, 61.23),
      Offset(32.63, 69.27),
      Offset(29.05, 72.40),
      Offset(25.36, 74.41),
      Offset(22.57, 75.31),
      Offset(19.55, 75.75),
      Offset(2.91, 75.75),
      Offset(1.79, 75.42),
      Offset(0.78, 74.64),
      Offset(0.11, 73.07),
      Offset(0.11, 56.98),
      Offset(0.67, 55.53),
      Offset(1.56, 54.64),
      Offset(2.68, 54.19),
      Offset(26.59, 54.19),
      Offset(28.94, 53.97),
      Offset(32.29, 52.96),
      Offset(34.86, 51.51),
      Offset(37.43, 49.27),
      Offset(39.55, 46.70),
      Offset(44.13, 39.89),
      Offset(47.93, 35.98),
      Offset(49.94, 34.53),
      Offset(53.41, 32.85),
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);
    final path = Path();
    for (final contour in _contours) {
      path.addPolygon(contour, true);
    }
    canvas.drawPath(path, Paint()..color = FlowColors.blue);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
