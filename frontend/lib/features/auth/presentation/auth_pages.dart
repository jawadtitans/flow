import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/flow_dialog.dart';

import '../../../core/theme/flow_tokens.dart';
import '../auth_controller.dart';
import 'auth_components.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  late final TextEditingController _identifier;

  @override
  void initState() {
    super.initState();
    _identifier = TextEditingController(
      text: ref.read(authControllerProvider).email,
    );
  }

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!isEmail(_identifier.text) || ref.read(authControllerProvider).busy)
      return;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .requestAccess(_identifier.text);
    if (mounted && success) context.push('/auth/code');
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Welcome to Flow',
    showSettings: true,
    fallback: '/welcome',
    children: [
      AuthField(
        key: const ValueKey('sign-in-identifier'),
        controller: _identifier,
        hint: 'Email address',
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.username],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _continue(),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'We’ll help you sign in or create your Flow account. ',
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => showFlowDialog<void>(
                    context: context,
                    builder: (context) => FlowDialog(
                      title: 'One account for your day',
                      content: const Text(
                        'Use your email address to get started. '
                        'We will email you a code. If your account has a password, you can use that instead.',
                      ),
                      actions: [
                        FlowDialogAction(
                          label: 'Got it',
                          primary: true,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Learn more',
                      style: TextStyle(color: FlowColors.blue, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          style: TextStyle(
            color: authMutedColor(context),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
      const SizedBox(height: 14),
      AuthError(ref.watch(authControllerProvider).error),
      AuthButton(
        label: ref.watch(authControllerProvider).busy
            ? 'Sending code...'
            : 'Continue',
        onPressed:
            isEmail(_identifier.text) && !ref.watch(authControllerProvider).busy
            ? _continue
            : null,
      ),
    ],
  );
}

class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_code.text.length != 6 || ref.read(authControllerProvider).busy) return;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(_code.text);
    if (!mounted) return;
    if (success) {
      _code.clear();
      finishAuthAutofill();
      context.go('/auth/getting-ready');
    } else {
      setState(() => _invalid = true);
    }
  }

  Future<void> _resend() async {
    final auth = ref.read(authControllerProvider);
    if (auth.busy) return;
    final success = await ref
        .read(authControllerProvider.notifier)
        .requestAccess(auth.email);
    if (!mounted || !success) return;
    setState(() {
      _code.clear();
      _invalid = false;
    });
    _focus.requestFocus();
    showAuthMessage(
      context,
      'A new code has been requested. Check your email.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final identifier = auth.email;
    return AuthScaffold(
      title: 'Enter your code',
      description: Column(
        children: [
          Text(
            'To confirm your account, enter the 6-digit code for '
            '${identifier.isEmpty ? 'your email address' : identifier}. '
            'You may need to check your spam or social mail folder.',
          ),
          AuthLink(label: 'Resend code', onPressed: auth.busy ? null : _resend),
        ],
      ),
      children: [
        // One real input supports paste, autofill, hardware keyboards and
        // backspace across all six visual cells without moving focus manually.
        SizedBox(
          height: 58,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: TextField(
                    key: const ValueKey('verification-code'),
                    controller: _code,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: '6-digit verification code',
                      border: InputBorder.none,
                    ),
                    onChanged: (_) {
                      setState(() => _invalid = false);
                      ref.read(authControllerProvider.notifier).clearError();
                    },
                    onSubmitted: (_) => _confirm(),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var index = 0; index < 6; index++) ...[
                          if (index > 0) const SizedBox(width: 5),
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: authFieldColor(context),
                                borderRadius: BorderRadius.circular(19),
                                border: Border.all(
                                  color: _invalid
                                      ? authErrorColor
                                      : _focus.hasFocus &&
                                            index ==
                                                _code.text.length.clamp(0, 5)
                                      ? FlowColors.blue
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: index < _code.text.length
                                  ? Text(
                                      _code.text[index],
                                      style: const TextStyle(fontSize: 25),
                                    )
                                  : _focus.hasFocus &&
                                        index == _code.text.length
                                  ? Container(
                                      width: 2,
                                      height: 24,
                                      color: FlowColors.blue,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AuthError(auth.error),
        const SizedBox(height: 16),
        AuthButton(
          label: auth.busy ? 'Verifying...' : 'Confirm',
          onPressed: _code.text.length == 6 && !auth.busy ? _confirm : null,
        ),
        const SizedBox(height: 18),
        if (auth.hasPassword)
          AuthLink(
            label: 'Sign in with password instead',
            onPressed: auth.busy
                ? null
                : () {
                    dismissAuthKeyboard();
                    context.push('/auth/password');
                  },
          ),
        if (auth.hasPassword)
          AuthLink(
            label: 'Forgot password?',
            onPressed: auth.busy
                ? null
                : () => context.push('/auth/reset-password'),
          ),
      ],
    );
  }
}

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});

  @override
  ConsumerState<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends ConsumerState<PasswordPage> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_password.text.isEmpty || ref.read(authControllerProvider).busy) return;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .loginPassword(_password.text);
    if (mounted && success) {
      _password.clear();
      finishAuthAutofill();
      context.go('/auth/getting-ready');
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Enter your password',
    fallback: '/auth/code',
    children: [
      AuthField(
        key: const ValueKey('sign-in-password'),
        controller: _password,
        hint: 'Password',
        obscureText: _obscure,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _continue(),
        suffix: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
        ),
      ),
      const SizedBox(height: 18),
      AuthError(ref.watch(authControllerProvider).error),
      AuthButton(
        label: ref.watch(authControllerProvider).busy
            ? 'Signing in...'
            : 'Continue',
        onPressed:
            _password.text.isNotEmpty && !ref.watch(authControllerProvider).busy
            ? _continue
            : null,
      ),
      const SizedBox(height: 18),
      AuthLink(
        label: 'Forgot password?',
        onPressed: ref.watch(authControllerProvider).busy
            ? null
            : () {
                dismissAuthKeyboard();
                context.push('/auth/reset-password');
              },
      ),
    ],
  );
}

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final identifier = ref.read(authControllerProvider).email;
    _email = TextEditingController(text: isEmail(identifier) ? identifier : '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!isEmail(_email.text) || ref.read(authControllerProvider).busy) return;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(_email.text);
    if (mounted && success) context.push('/auth/reset-sent');
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: 'Reset your password',
    fallback: '/auth/password',
    description: const Text(
      'Enter your email address and we’ll send you a code to reset your password.',
    ),
    children: [
      AuthField(
        key: const ValueKey('reset-email'),
        controller: _email,
        hint: 'Email address',
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _send(),
      ),
      const SizedBox(height: 18),
      AuthError(ref.watch(authControllerProvider).error),
      AuthButton(
        label: ref.watch(authControllerProvider).busy
            ? 'Sending code...'
            : 'Send reset code',
        onPressed:
            isEmail(_email.text) && !ref.watch(authControllerProvider).busy
            ? _send
            : null,
      ),
      const SizedBox(height: 18),
      AuthLink(label: 'Back to sign in', onPressed: () => context.go('/auth')),
    ],
  );
}

class ResetCodePage extends ConsumerStatefulWidget {
  const ResetCodePage({super.key});
  @override
  ConsumerState<ResetCodePage> createState() => _ResetCodePageState();
}

class _ResetCodePageState extends ConsumerState<ResetCodePage> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (ref.read(authControllerProvider).busy || !_valid) return;
    dismissAuthKeyboard();
    final success = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(_code.text, _password.text);
    if (mounted && success) {
      _code.clear();
      _password.clear();
      _confirmation.clear();
      context.go('/auth');
      showAuthMessage(context, 'Password updated. Sign in again to continue.');
    }
  }

  bool get _valid =>
      RegExp(r'^[0-9]{6}$').hasMatch(_code.text) &&
      _password.text.length >= 12 &&
      _password.text.length <= 128 &&
      _password.text == _confirmation.text;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'Enter your reset code',
      fallback: '/auth/reset-password',
      description: Text(
        'Enter the code sent to ${auth.resetEmail} and choose a new password with at least 12 characters.',
      ),
      children: [
        AuthField(
          key: const ValueKey('reset-code'),
          controller: _code,
          hint: '6-digit reset code',
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AuthField(
          key: const ValueKey('new-password'),
          controller: _password,
          hint: 'New password',
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AuthField(
          key: const ValueKey('confirm-password'),
          controller: _confirmation,
          hint: 'Confirm new password',
          obscureText: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _reset(),
        ),
        AuthError(auth.error),
        const SizedBox(height: 18),
        AuthButton(
          label: auth.busy ? 'Updating password...' : 'Update password',
          onPressed: _valid && !auth.busy ? _reset : null,
        ),
        AuthLink(
          label: 'Resend code',
          onPressed: auth.busy
              ? null
              : () async {
                  final success = await ref
                      .read(authControllerProvider.notifier)
                      .forgotPassword(auth.resetEmail);
                  if (context.mounted && success)
                    showAuthMessage(
                      context,
                      'A new reset code has been requested.',
                    );
                },
        ),
      ],
    );
  }
}
