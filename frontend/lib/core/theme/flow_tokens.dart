import 'package:flutter/material.dart';

abstract final class FlowColors {
  static const ink = Color(0xFF17181B);
  static const muted = Color(0xFF73757C);
  static const line = Color(0xFFE9E9EC);
  static const canvas = Color(0xFFFCFCFD);
  static const surface = Color(0xFFFFFFFF);
  static const selected = Color(0xFFF0F0F2);
  static const blue = Color(0xFF4F7DF3);
  static const darkCanvas = Color(0xFF0F3040);
  static const darkSurface = Color(0xFF464858);
}

abstract final class FlowSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
  static const page = 24.0;
}

abstract final class FlowRadius {
  static const small = 12.0;
  static const medium = 20.0;
  static const large = 30.0;
  static const pill = 999.0;
}

abstract final class FlowMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 220);
}
