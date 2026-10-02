import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/startup/startup_background.dart';
import '../../../shared/widgets/flow_components.dart';
import '../../welcome/presentation/welcome_avatar.dart';
import '../auth_controller.dart';
import 'auth_components.dart';
import 'onboarding_components.dart';

class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});
  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool get _valid =>
      _password.text.length >= 12 &&
      _password.text.length <= 128 &&
      _password.text == _confirmation.text;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || ref.read(authControllerProvider).busy) return;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .setPassword(_password.text);
    if (!mounted || !success) return;
    finishAuthAutofill();
    context.go(ref.read(authControllerProvider).user!.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'Create your password',
      description: const Text('Choose a password with 12 to 128 characters.'),
      children: [
        AuthField(
          key: const ValueKey('signup-password'),
          controller: _password,
          hint: 'Password',
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() {}),
          suffix: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? LucideIcons.eye : LucideIcons.eye_off,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AuthField(
          key: const ValueKey('signup-confirm-password'),
          controller: _confirmation,
          hint: 'Confirm password',
          obscureText: _obscure,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        if (_confirmation.text.isNotEmpty &&
            _confirmation.text != _password.text)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Passwords do not match.',
              style: TextStyle(color: authErrorColor),
            ),
          ),
        AuthError(auth.error),
        const SizedBox(height: 20),
        AuthButton(
          label: auth.busy ? 'Saving...' : 'Continue',
          onPressed: _valid && !auth.busy ? _save : null,
        ),
      ],
    );
  }
}

const interestChoices = <(String, IconData)>[
  ('Technology', LucideIcons.laptop),
  ('AI', LucideIcons.sparkles),
  ('Design', LucideIcons.pen_tool),
  ('Business', LucideIcons.briefcase),
  ('Productivity', LucideIcons.circle_check),
  ('Education', LucideIcons.graduation_cap),
  ('Science', LucideIcons.flask_conical),
  ('Health', LucideIcons.heart),
  ('Fitness', LucideIcons.dumbbell),
  ('Food', LucideIcons.utensils),
  ('Travel', LucideIcons.plane),
  ('Music', LucideIcons.music),
  ('Art', LucideIcons.palette),
  ('Gaming', LucideIcons.gamepad_2),
  ('Books', LucideIcons.book_open),
  ('Other', LucideIcons.plus),
];

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  String? _source;
  final _selected = <String>{};
  final _other = TextEditingController();
  bool _interestsStep = false;
  static const _sources = <(String, String?)>[
    ('Instagram', 'Platform=Instagram, Color=Original.png'),
    ('TikTok', 'tiktok.svg'),
    ('YouTube', 'youtub.svg'),
    ('Facebook', 'Platform=Facebook, Color=Original.png'),
    ('X', 'x.png'),
    ('LinkedIn', 'linkdin.svg'),
    ('Telegram', 'Platform=Telegram, Color=Original.png'),
    ('WhatsApp', 'Platform=WhatsApp, Color=Original.png'),
    ('Discord', 'Platform=Discord, Color=Original.png'),
    ('Threads', 'Platform=Threads, Color=Original.png'),
    ('GitHub', 'Platform=Github, Color=Original.png'),
    ('Spotify', 'Platform=Spotify, Color=Original.png'),
    ('OpenAI', 'brands/openai.png'),
    ('Claude', 'brands/claude.png'),
    ('Lovable', 'brands/lovable.png'),
    ('Gemini', 'brands/gemini.png'),
    ('Perplexity', 'brands/perplexity.png'),
    ('DeepSeek', 'brands/deepseek.png'),
    ('Friend', null),
    ('Other', null),
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _source = user?.discoverySource;
    _selected.addAll(user?.interests ?? []);
    _other.text = user?.otherInterest ?? '';
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_interestsStep) {
      setState(() => _interestsStep = true);
      return;
    }
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .saveOnboarding(
          _source!,
          _selected.toList(),
          _selected.contains('Other') ? _other.text.trim() : null,
        );
    if (mounted && success) context.go('/auth/introduction');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_interestsStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !auth.busy) setState(() => _interestsStep = false);
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const OnboardingBackdrop(),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Back',
                              icon: const Icon(LucideIcons.chevron_left),
                              onPressed: auth.busy
                                  ? null
                                  : () {
                                      if (_interestsStep) {
                                        setState(() => _interestsStep = false);
                                      } else {
                                        context.go('/auth/profile');
                                      }
                                    },
                            ),
                            const Spacer(),
                            Text(
                              _interestsStep ? '2 of 2' : '1 of 2',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedSwitcher(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 420),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: Offset(
                                            _interestsStep ? .18 : -.18,
                                            0,
                                          ),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: SingleChildScrollView(
                                  key: ValueKey(_interestsStep),
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    12,
                                    24,
                                    24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _interestsStep
                                            ? 'What catches your interest?'
                                            : 'How did you find us?',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          height: 1.2,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _interestsStep
                                            ? 'Which topics do you explore on social media?'
                                            : 'Where did you first hear about Flow?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          height: 1.5,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          final count =
                                              constraints.maxWidth >= 480
                                              ? 3
                                              : 2;
                                          final choices = _interestsStep
                                              ? interestChoices.length
                                              : _sources.length;
                                          return Wrap(
                                            spacing: 12,
                                            runSpacing: 12,
                                            children: [
                                              for (var i = 0; i < choices; i++)
                                                SizedBox(
                                                  width:
                                                      (constraints.maxWidth -
                                                          (count - 1) * 12) /
                                                      count,
                                                  height:
                                                      MediaQuery.textScalerOf(
                                                            context,
                                                          ).scale(14) >
                                                          20
                                                      ? 152
                                                      : 124,
                                                  child: OnboardingChoice(
                                                    label: _interestsStep
                                                        ? interestChoices[i].$1
                                                        : _sources[i].$1,
                                                    selected: _interestsStep
                                                        ? _selected.contains(
                                                            interestChoices[i]
                                                                .$1,
                                                          )
                                                        : _source ==
                                                              _sources[i].$1,
                                                    onTap: auth.busy
                                                        ? null
                                                        : () => setState(() {
                                                            if (_interestsStep) {
                                                              final name =
                                                                  interestChoices[i]
                                                                      .$1;
                                                              if (!_selected
                                                                  .remove(
                                                                    name,
                                                                  )) {
                                                                _selected.add(
                                                                  name,
                                                                );
                                                              }
                                                            } else {
                                                              _source =
                                                                  _sources[i]
                                                                      .$1;
                                                            }
                                                          }),
                                                    icon: _interestsStep
                                                        ? Image.asset(
                                                            'assets/onboarding/interests/${interestChoices[i].$1 == 'Fitness' ? 'health' : interestChoices[i].$1.toLowerCase()}.png',
                                                            fit: BoxFit.contain,
                                                          )
                                                        : _socialIcon(
                                                            _sources[i],
                                                          ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                                      if (_interestsStep &&
                                          _selected.contains('Other')) ...[
                                        const SizedBox(height: 20),
                                        TextField(
                                          key: const ValueKey('other-interest'),
                                          controller: _other,
                                          maxLength: 120,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Other interest (optional)',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const FlowPageSoftEdges(
                              topHeight: 18,
                              bottomHeight: 32,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                        child: Column(
                          children: [
                            AuthError(auth.error),
                            AuthButton(
                              label: auth.busy ? 'Saving...' : 'Continue',
                              onPressed:
                                  !auth.busy &&
                                      (_interestsStep
                                          ? _selected.isNotEmpty
                                          : _source != null)
                                  ? _continue
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialIcon((String, String?) source) {
    final file = source.$2;
    if (file == null) {
      return Icon(
        source.$1 == 'Friend' ? LucideIcons.users : LucideIcons.ellipsis,
        size: 28,
      );
    }
    return SizedBox(
      width: 40,
      height: 40,
      child: file.endsWith('.svg')
          ? SvgPicture.asset('assets/social/$file')
          : Image.asset(
              file.startsWith('brands/')
                  ? 'assets/onboarding/$file'
                  : 'assets/social/$file',
              fit: BoxFit.contain,
            ),
    );
  }
}

class IntroductionPage extends ConsumerStatefulWidget {
  const IntroductionPage({super.key});
  @override
  ConsumerState<IntroductionPage> createState() => _IntroductionPageState();
}

class _IntroductionPageState extends ConsumerState<IntroductionPage> {
  bool _second = false;
  bool _textComplete = false;
  Timer? _next;

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  void _written() {
    if (!mounted) return;
    if (_second) {
      setState(() => _textComplete = true);
    } else {
      _next = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _second = true);
      });
    }
  }

  Future<void> _start() async {
    final user = ref.read(authControllerProvider).user!;
    final success = await ref
        .read(authControllerProvider.notifier)
        .saveOnboarding(
          user.discoverySource!,
          user.interests,
          user.otherInterest,
          completed: true,
        );
    if (mounted && success) context.go('/auth/getting-ready');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = auth.user?.displayName ?? '';
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Opacity(opacity: .22, child: StartupBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, bounds) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: bounds.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: bounds.maxHeight > 700 ? 60 : 12),
                            const SizedBox(
                              width: 210,
                              height: 210,
                              child: WelcomeAvatar(),
                            ),
                            const SizedBox(height: 64),
                            AnimatedSwitcher(
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 650),
                              child: WordReveal(
                                key: ValueKey(_second),
                                text: _second
                                    ? "Let's make room for what matters. Together, we'll turn your plans into progress."
                                    : "Hi${name.isEmpty ? '' : ', $name'}! I'm your personal AI companion, here to help you plan your day and get things done.",
                                onComplete: _written,
                              ),
                            ),
                            const SizedBox(height: 64),
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 450),
                                opacity: _second && _textComplete ? 1 : 0,
                                child: IgnorePointer(
                                  ignoring: !_second || !_textComplete,
                                  child: ExcludeSemantics(
                                    excluding: !_second || !_textComplete,
                                    child: FlowPressFeedback(
                                      enabled: !auth.busy,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF229DEB),
                                              Color(0xFF245CEC),
                                            ],
                                          ),
                                        ),
                                        child: FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            disabledBackgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            minimumSize: const Size.fromHeight(
                                              56,
                                            ),
                                          ),
                                          onPressed: auth.busy ? null : _start,
                                          child: Text(
                                            auth.busy
                                                ? 'Getting ready...'
                                                : "Let's get started",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AuthError(auth.error),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WordReveal extends StatefulWidget {
  const WordReveal({required this.text, required this.onComplete, super.key});
  final String text;
  final VoidCallback onComplete;
  @override
  State<WordReveal> createState() => _WordRevealState();
}

class _WordRevealState extends State<WordReveal>
    with SingleTickerProviderStateMixin {
  late final _words = widget.text.split(' ');
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _words.length * 160 + 500),
  );
  bool _started = false;
  bool _completed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onComplete();
        });
      }
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.text,
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Text.rich(
          TextSpan(
            children: [
              for (var i = 0; i < _words.length; i++)
                TextSpan(
                  text: '${_words[i]}${i == _words.length - 1 ? '' : ' '}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(
                      alpha:
                          ((_controller.value * (_words.length * 160 + 500) -
                                      i * 160) /
                                  500)
                              .clamp(0.0, 1.0),
                    ),
                  ),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w300,
            height: 1.55,
            letterSpacing: 0,
          ),
        ),
      ),
    ),
  );
}
