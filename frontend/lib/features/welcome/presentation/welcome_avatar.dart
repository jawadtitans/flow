import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Local, silent video with a matching poster throughout loading or failure.
class WelcomeAvatar extends StatefulWidget {
  const WelcomeAvatar({super.key});

  @override
  State<WelcomeAvatar> createState() => _WelcomeAvatarState();
}

class _WelcomeAvatarState extends State<WelcomeAvatar>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _motionEnabled = false;
  bool _foreground = true;
  bool _showVideo = false;
  bool _failed = false;

  bool get _supportsVideo =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionEnabled =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (_controller == null && _motionEnabled && _supportsVideo) {
      unawaited(_initialize());
    } else {
      unawaited(_syncPlayback());
    }
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(
      'assets/welcome/flow-avatar.mp4',
      // This widget manages lifecycle so reduced motion also stays paused
      // when the app returns to the foreground.
      videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
    );
    _controller = controller;
    controller.addListener(_onVideoChanged);
    try {
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.initialize();
      if (mounted) await _syncPlayback();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onVideoChanged() {
    final value = _controller!.value;
    final show = value.isInitialized && !value.hasError;
    if (mounted && show != _showVideo) setState(() => _showVideo = show);
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      if (_motionEnabled && _foreground && !_failed) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncPlayback());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onVideoChanged);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Your Flow AI companion',
    child: ExcludeSemantics(
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/welcome/flow-avatar.jpg', fit: BoxFit.cover),
            if (_showVideo && !_failed && _motionEnabled)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
