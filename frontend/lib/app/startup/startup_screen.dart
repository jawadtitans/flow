import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../features/welcome/welcome_controller.dart';
import '../../features/auth/auth_controller.dart';
import 'startup_background.dart';

enum _SessionStatus { checking, ready, failed }

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  _SessionStatus _status = _SessionStatus.checking;
  bool _openingApp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreSessionAndOpen();
    });
  }

  Future<void> _restoreSessionAndOpen() async {
    final startedAt = DateTime.now();
    if (mounted) setState(() => _status = _SessionStatus.checking);
    final restored = await ref.read(authControllerProvider.notifier).restore();
    final remaining =
        const Duration(seconds: 3) - DateTime.now().difference(startedAt);
    if (!remaining.isNegative) await Future<void>.delayed(remaining);
    if (!mounted) return;

    setState(
      () => _status = restored ? _SessionStatus.ready : _SessionStatus.failed,
    );
    if (restored) _openApp();
  }

  void _openApp() {
    if (_openingApp) return;
    _openingApp = true;
    final user = ref.read(authControllerProvider).user;
    context.go(
      user != null
          ? (user.profileCompleted ? '/today' : '/auth/profile')
          : ref.read(welcomeControllerProvider)
          ? '/auth'
          : '/welcome',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_status == _SessionStatus.failed) {
      return _NoConnection(
        onRetry: _restoreSessionAndOpen,
        message: ref.watch(authControllerProvider).error,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFCFF),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const StartupBackground(),
            Center(
              child: Image.asset(
                'assets/icon-logos/light mode.png',
                width: 120,
                height: 150,
                fit: BoxFit.contain,
                color: Colors.white,
                semanticLabel: 'Flow',
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
                  const _ThinkingDots(text: 'Thinking...', isDark: false),
                  const SizedBox(height: 6),
                  Text(
                    '© Flow.ai 2026',
                    style: const TextStyle(
                      color: Color(0x99121822),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

class _NoConnection extends StatelessWidget {
  const _NoConnection({required this.onRetry, this.message});

  final Future<void> Function() onRetry;
  final String? message;

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
              'Could not restore your session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              message ?? 'Check your connection and try again.',
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
