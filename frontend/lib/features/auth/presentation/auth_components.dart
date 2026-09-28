import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/flow_tokens.dart';
import '../../../shared/widgets/flow_notification.dart';
import '../../welcome/presentation/welcome_brand_mark.dart';

const authErrorColor = Color(0xFFEF5350);

Color authFieldColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF243F4D)
    : const Color(0xFFF0F0F2);

Color authMutedColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFAFBCC3)
    : const Color(0xFF808185);

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.description,
    this.showSettings = false,
    this.fallback = '/auth',
    super.key,
  });

  final String title;
  final Widget? description;
  final List<Widget> children;
  final bool showSettings;
  final String fallback;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AuthCircleButton(
                      icon: Icons.chevron_left_rounded,
                      label: 'Back',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(fallback);
                        }
                      },
                    ),
                    if (showSettings)
                      AuthCircleButton(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onPressed: () => context.push('/settings'),
                      ),
                  ],
                ),
                const SizedBox(height: 34),
                const Center(child: WelcomeBrandMark(width: 54)),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: -.65,
                    ),
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 14),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      color: authMutedColor(context),
                      fontSize: 15,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    child: description!,
                  ),
                ],
                const SizedBox(height: 26),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthCircleButton extends StatelessWidget {
  const AuthCircleButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: label,
    onPressed: onPressed,
    icon: Icon(icon, size: 26),
    style: IconButton.styleFrom(
      minimumSize: const Size.square(46),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({required this.label, this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: FlowColors.blue,
      foregroundColor: Colors.white,
      disabledBackgroundColor: FlowColors.blue.withValues(alpha: .38),
      disabledForegroundColor: Colors.white.withValues(alpha: .6),
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class AuthLink extends StatelessWidget {
  const AuthLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: FlowColors.blue,
      minimumSize: const Size(48, 44),
      textStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.focusNode,
    this.autocorrect = false,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autocorrect;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    obscureText: obscureText,
    readOnly: readOnly,
    onTap: onTap,
    autocorrect: autocorrect,
    enableSuggestions: autocorrect,
    textCapitalization: textCapitalization,
    cursorColor: FlowColors.blue,
    style: const TextStyle(fontSize: 17),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: authMutedColor(context).withValues(alpha: .75),
      ),
      filled: true,
      fillColor: authFieldColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: FlowColors.blue, width: 1.4),
      ),
    ),
  );
}

void showAuthMessage(BuildContext context, String message) {
  showFlowNotification(context, title: 'Flow account', message: message);
}

void dismissAuthKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

void finishAuthAutofill() {
  TextInput.finishAutofillContext(shouldSave: false);
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: authErrorColor, fontSize: 13),
            ),
          ),
        );
}
