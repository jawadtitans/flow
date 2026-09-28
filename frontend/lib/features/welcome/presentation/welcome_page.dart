import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/flow_tokens.dart';
import '../welcome_controller.dart';
import 'welcome_avatar.dart';
import 'welcome_brand_mark.dart';
import 'welcome_headline.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _opening = false;
  bool _saveFailed = false;

  Future<void> _getStarted() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _saveFailed = false;
    });
    try {
      await ref.read(welcomeControllerProvider.notifier).complete();
      if (mounted) context.go('/auth');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Scaffold(
      backgroundColor: FlowColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 480,
                    minHeight: constraints.maxHeight,
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: 'Flow',
                            excludeSemantics: true,
                            child: const Row(
                              children: [
                                WelcomeBrandMark(width: 25),
                                SizedBox(width: 8),
                                Text(
                                  'Flow',
                                  style: TextStyle(
                                    color: FlowColors.blue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: (constraints.maxHeight * .085).clamp(
                              24,
                              72,
                            ),
                          ),
                          const Center(
                            child: SizedBox.square(
                              dimension: 164,
                              child: WelcomeAvatar(),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const WelcomeHeadline(),
                          const SizedBox(height: 56),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_saveFailed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Semantics(
                                liveRegion: true,
                                child: const Text(
                                  'Couldn’t save your progress. Try again.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: FlowColors.ink),
                                ),
                              ),
                            ),
                          FilledButton(
                            onPressed: _opening ? null : _getStarted,
                            style: FilledButton.styleFrom(
                              backgroundColor: FlowColors.blue,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: FlowColors.blue,
                              disabledForegroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(56),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: const StadiumBorder(),
                              textStyle: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _opening
                                ? const SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                      semanticsLabel: 'Opening Flow',
                                    ),
                                  )
                                : const Text('Get started'),
                          ),
                        ],
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
  );
}
