import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/flow_tokens.dart';
import 'welcome_brand_mark.dart';

class WelcomeHeadline extends StatefulWidget {
  const WelcomeHeadline({super.key});

  @override
  State<WelcomeHeadline> createState() => _WelcomeHeadlineState();
}

class _WelcomeHeadlineState extends State<WelcomeHeadline>
    with WidgetsBindingObserver {
  static const _phrases = [
    'plans your day',
    'organizes your tasks',
    'keeps you focused',
    'gets things done',
  ];

  static const _icons = [
    'plans-your-day.png',
    'organizes-your-tasks.png',
    'keeps-you-focused.png',
    'gets-things-done.png',
  ];

  Timer? _timer;
  int _phrase = 0;
  bool _motionEnabled = false;
  bool _foreground = true;

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
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    if (_motionEnabled && _foreground) {
      _timer = Timer.periodic(const Duration(milliseconds: 3000), (_) {
        setState(() => _phrase = (_phrase + 1) % _phrases.length);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    // A stable description avoids repeated announcements as the line rotates.
    label: 'Flow, AI that plans your day and helps you get things done.',
    child: ExcludeSemantics(
      child: DefaultTextStyle(
        style: const TextStyle(
          color: FlowColors.ink,
          fontSize: 32,
          height: 1.22,
          letterSpacing: -1.2,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),
        textAlign: TextAlign.center,
        child: Column(
          children: [
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Flow '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: WelcomeBrandMark(width: 30),
                  ),
                  TextSpan(text: ', AI that'),
                ],
              ),
            ),
            const SizedBox(height: 3),
            // Reserve the tallest phrase even with larger accessibility text.
            // The avatar and button stay still while the words change.
            Stack(
              alignment: Alignment.center,
              children: [
                for (var index = 0; index < _phrases.length; index++)
                  Visibility(
                    visible: false,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: _phraseWithIcon(index),
                  ),
                ClipRect(
                  child: AnimatedSwitcher(
                    duration: _motionEnabled
                        ? const Duration(milliseconds: 420)
                        : Duration.zero,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, .3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _phraseWithIcon(_phrase, key: ValueKey(_phrase)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _phraseWithIcon(int index, {Key? key}) => Row(
    key: key,
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: Text(_phrases[index])),
      const SizedBox(width: 8),
      Image.asset(
        'assets/welcome/icons/${_icons[index]}',
        width: 38,
        height: 42,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    ],
  );
}
