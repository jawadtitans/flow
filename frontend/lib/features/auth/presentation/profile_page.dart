import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../shared/widgets/flow_dialog.dart';
import '../auth_controller.dart';
import 'auth_components.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  final _birthdayText = TextEditingController();
  final _birthdayFocus = FocusNode();
  DateTime? _birthday;
  late final TapGestureRecognizer _birthdayHelp;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _birthdayHelp = TapGestureRecognizer()..onTap = _explainBirthday;
    final user = ref.read(authControllerProvider).user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _birthday = user?.birthDate;
    _updateBirthdayText();
  }

  void _updateBirthdayText() {
    final date = _birthday;
    _birthdayText.text = date == null
        ? ''
        : '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  void dispose() {
    _birthdayHelp.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _birthdayText.dispose();
    _birthdayFocus.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _birthday != null;

  Future<void> _pickBirthday() async {
    dismissAuthKeyboard();
    final now = DateUtils.dateOnly(DateTime.now());
    var selected = _birthday ?? DateTime(now.year - 20, 1, 1);
    final date = await showFlowDialog<DateTime>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final surface = flowDialogSurface(context);
        return FlowDialog(
          title: 'Your birthday',
          content: SizedBox(
            height: 180,
            child: Stack(
              children: [
                CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    primaryColor: FlowColors.blue,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        fontFamily: 'Roboto',
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    key: const ValueKey('birthday-picker'),
                    mode: CupertinoDatePickerMode.date,
                    itemExtent: 36,
                    selectionOverlayBuilder:
                        (
                          context, {
                          required selectedIndex,
                          required columnCount,
                        }) => const SizedBox.shrink(),
                    initialDateTime: selected,
                    minimumDate: DateTime(1900),
                    maximumDate: now,
                    minimumYear: 1900,
                    maximumYear: now.year,
                    backgroundColor: surface,
                    onDateTimeChanged: (value) => selected = value,
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            surface,
                            surface.withValues(alpha: 0),
                            surface.withValues(alpha: 0),
                            surface,
                          ],
                          stops: const [0, .34, .66, 1],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FlowDialogAction(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
            FlowDialogAction(
              label: 'Done',
              primary: true,
              onPressed: () => Navigator.pop(context, selected),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    _birthdayFocus.unfocus();
    if (date != null) {
      setState(() {
        _birthday = date;
        _updateBirthdayText();
      });
    }
  }

  Future<void> _confirm() async {
    if (!_canContinue || ref.read(authControllerProvider).busy) return;
    final editing =
        ref.read(authControllerProvider).user?.profileCompleted ?? false;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .completeProfile(_firstName.text, _lastName.text, _birthday!);
    if (mounted && success) {
      if (editing && context.canPop()) {
        context.pop();
      } else {
        context.go('/today');
      }
    }
  }

  Widget? _clearButton(TextEditingController controller, String label) =>
      controller.text.isEmpty
      ? null
      : IconButton(
          tooltip: 'Clear $label',
          icon: const Icon(Icons.cancel_outlined, size: 18),
          onPressed: () => setState(controller.clear),
        );

  void _explainBirthday() => showFlowDialog<void>(
    context: context,
    builder: (context) => FlowDialog(
      title: 'Why your birthday?',
      content: const Text(
        'Your birthday helps us provide an age-appropriate experience. '
        'It won’t appear on your public profile.',
      ),
      actions: [
        FlowDialogAction(
          label: 'Got it',
          primary: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: ref.watch(authControllerProvider).user?.profileCompleted == true
        ? 'Personal details'
        : 'Finish creating your account',
    fallback: ref.watch(authControllerProvider).user?.profileCompleted == true
        ? '/settings/accounts'
        : '/auth',
    description: Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'This information won’t be public. '),
          TextSpan(
            text: 'Why do I need to provide my birthday?',
            recognizer: _birthdayHelp,
            style: const TextStyle(
              color: FlowColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
    children: [
      AuthField(
        key: const ValueKey('profile-first-name'),
        controller: _firstName,
        hint: 'First name',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.givenName],
        onChanged: (_) => setState(() {}),
        suffix: _clearButton(_firstName, 'first name'),
      ),
      const SizedBox(height: 12),
      AuthField(
        key: const ValueKey('profile-last-name'),
        controller: _lastName,
        hint: 'Last name',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.familyName],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _pickBirthday(),
        suffix: _clearButton(_lastName, 'last name'),
      ),
      const SizedBox(height: 12),
      AuthField(
        key: const ValueKey('profile-birthday'),
        controller: _birthdayText,
        focusNode: _birthdayFocus,
        hint: 'Birthday',
        readOnly: true,
        onTap: _pickBirthday,
      ),
      const SizedBox(height: 14),
      if (ref.watch(authControllerProvider).user?.profileCompleted != true)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text:
                      'By tapping Confirm, you’ll finish setting up your Flow account and agree to these ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _LegalLink(
                    label: 'terms',
                    route: '/settings/legal/terms',
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: _LegalLink(
                    label: 'policies',
                    route: '/settings/legal/policy',
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
            style: TextStyle(
              color: authMutedColor(context),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      const SizedBox(height: 16),
      AuthError(ref.watch(authControllerProvider).error),
      AuthButton(
        label: ref.watch(authControllerProvider).busy
            ? 'Saving...'
            : ref.watch(authControllerProvider).user?.profileCompleted == true
            ? 'Save changes'
            : 'Confirm',
        onPressed: _canContinue && !ref.watch(authControllerProvider).busy
            ? _confirm
            : null,
      ),
    ],
  );
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.route});

  final String label;
  final String route;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: () => context.push(route),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        label,
        style: const TextStyle(color: FlowColors.blue, fontSize: 12),
      ),
    ),
  );
}

class GettingReadyPage extends ConsumerStatefulWidget {
  const GettingReadyPage({super.key});

  @override
  ConsumerState<GettingReadyPage> createState() => _GettingReadyPageState();
}

class _GettingReadyPageState extends ConsumerState<GettingReadyPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).user;
      context.go(
        user == null
            ? '/auth'
            : user.profileCompleted
            ? '/today'
            : '/auth/profile',
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/icons/7IId9kMtfJ.json',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                repeat: true,
                animate: !MediaQuery.disableAnimationsOf(context),
                controller: MediaQuery.disableAnimationsOf(context)
                    ? const AlwaysStoppedAnimation<double>(.5)
                    : null,
              ),
              const SizedBox(height: 38),
              const Text(
                'Getting Ready',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
