import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

enum _ConnectionQuality { checking, strong, fair, weak, offline }

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _meshController;
  _ConnectionQuality _quality = _ConnectionQuality.checking;
  bool _openingApp = false;

  @override
  void initState() {
    super.initState();
    _meshController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
    _checkInternetAndOpen();
  }

  Future<void> _checkInternetAndOpen() async {
    final startedAt = DateTime.now();
    if (mounted) setState(() => _quality = _ConnectionQuality.checking);

    final connection = await Connectivity().checkConnectivity();
    final hasNetwork = connection.any(
      (result) => result != ConnectivityResult.none,
    );
    _ConnectionQuality quality = _ConnectionQuality.offline;

    if (hasNetwork) {
      final stopwatch = Stopwatch()..start();
      try {
        final response = await Dio().get<void>(
          'https://connectivitycheck.gstatic.com/generate_204',
          options: Options(
            receiveTimeout: const Duration(seconds: 4),
            sendTimeout: const Duration(seconds: 4),
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        stopwatch.stop();
        if (response.statusCode != null && response.statusCode! < 400) {
          quality = stopwatch.elapsedMilliseconds < 180
              ? _ConnectionQuality.strong
              : stopwatch.elapsedMilliseconds < 700
              ? _ConnectionQuality.fair
              : _ConnectionQuality.weak;
        }
      } on DioException {
        stopwatch.stop();
      }
    }

    final remaining =
        const Duration(seconds: 3) - DateTime.now().difference(startedAt);
    if (!remaining.isNegative) await Future<void>.delayed(remaining);
    if (!mounted) return;

    setState(() => _quality = quality);
    if (quality != _ConnectionQuality.offline) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted) _openApp();
    }
  }

  void _openApp() {
    if (_openingApp) return;
    _openingApp = true;
    context.go('/today');
  }

  @override
  void dispose() {
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_quality == _ConnectionQuality.offline) {
      return _NoConnection(onRetry: _checkInternetAndOpen);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F3040) : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AnimatedMesh(controller: _meshController, isDark: isDark),
          _ColorWash(isDark: isDark),
          Center(
            child: AnimatedBuilder(
              animation: _meshController,
              builder: (context, child) => Transform.translate(
                offset: Offset(
                  0,
                  -2 * Curves.easeInOut.transform(_meshController.value),
                ),
                child: Transform.scale(
                  scale:
                      1 +
                      .018 * Curves.easeInOut.transform(_meshController.value),
                  child: child,
                ),
              ),
              child: Image.asset(
                isDark
                    ? 'assets/icon-logos/dark mode.png'
                    : 'assets/icon-logos/light mode.png',
                width: 120,
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 32,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset(
                  'assets/icons/7IId9kMtfJ.json',
                  width: 61,
                  height: 61,
                  repeat: true,
                ),
                const SizedBox(height: 4),
                _ThinkingDots(text: _qualityLabel, isDark: isDark),
                const SizedBox(height: 6),
                Text(
                  '© Flow.ai 2026',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xCCFFFFFF)
                        : const Color(0x99121822),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _qualityLabel => switch (_quality) {
    _ConnectionQuality.checking => 'Thinking...',
    // treat strong and fair as ready to proceed — show Thinking...
    _ConnectionQuality.strong => 'Thinking...',
    _ConnectionQuality.fair => 'Thinking...',
    // weak connection shows internet slow
    _ConnectionQuality.weak => 'wellcome',
    _ConnectionQuality.offline => '',
  };
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({required this.text, required this.isDark});
  final String text;
  final bool isDark;

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: widget.isDark ? const Color(0xCCFFFFFF) : const Color(0x99121822),
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = (_controller.value * 3).floor();
        final dots = List.filled(phase + 1, '.').join();
        final display = widget.text == 'Thinking...'
            ? 'Thinking$dots'
            : widget.text;
        return Text(display, style: baseStyle);
      },
    );
  }
}

class _AnimatedMesh extends StatelessWidget {
  const _AnimatedMesh({required this.controller, required this.isDark});

  final Animation<double> controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Stack(
      children: [
        _MeshBlob(
          color: isDark ? const Color(0xFF347BFF) : const Color(0xFF3F78FF),
          alignment: Alignment.lerp(
            Alignment.topLeft,
            const Alignment(-.48, -.35),
            controller.value,
          )!,
          size: 430,
        ),
        _MeshBlob(
          color: isDark ? const Color(0xFF9A6BFF) : const Color(0xFF8D5CFF),
          alignment: Alignment.lerp(
            Alignment.topRight,
            const Alignment(.50, -.08),
            controller.value,
          )!,
          size: 430,
        ),
        _MeshBlob(
          color: isDark ? const Color(0xFFD95193) : const Color(0xFFFF6CAD),
          alignment: Alignment.lerp(
            Alignment.bottomLeft,
            const Alignment(-.52, .42),
            controller.value,
          )!,
          size: 440,
        ),
        _MeshBlob(
          color: isDark ? const Color(0xFF29AFA9) : const Color(0xFF39CFC8),
          alignment: Alignment.lerp(
            Alignment.bottomRight,
            const Alignment(.48, .45),
            controller.value,
          )!,
          size: 440,
        ),
        _MeshBlob(
          color: isDark ? const Color(0xFFE98935) : const Color(0xFFFF9B3D),
          alignment: Alignment.lerp(
            const Alignment(-.20, -.42),
            const Alignment(.18, -.10),
            controller.value,
          )!,
          size: 330,
          opacity: .52,
        ),
      ],
    ),
  );
}

class _MeshBlob extends StatelessWidget {
  const _MeshBlob({
    required this.color,
    required this.alignment,
    required this.size,
    this.opacity = .65,
  });

  final Color color;
  final Alignment alignment;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size * .78,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size),
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ColorWash extends StatelessWidget {
  const _ColorWash({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -.05),
        radius: 1.05,
        colors: isDark
            ? const [Color(0x08000000), Color(0xB30F3040)]
            : const [Color(0x0AFFFFFF), Color(0x99FFFFFF)],
      ),
    ),
  );
}

class _NoConnection extends StatelessWidget {
  const _NoConnection({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.wifi_off,
              size: 64,
              color: Color(0xFF3F78FF),
            ),
            const SizedBox(height: 20),
            Text(
              'Please connect to the internet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.rotate_cw),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    ),
  );
}
