import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../auth_controller.dart';
import 'auth_components.dart';

class MfaLoginPage extends ConsumerStatefulWidget {
  const MfaLoginPage({super.key});
  @override
  ConsumerState<MfaLoginPage> createState() => _MfaLoginPageState();
}

class _MfaLoginPageState extends ConsumerState<MfaLoginPage> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: c.mfa,
      fallback: '/auth',
      children: [
        Text(c.mfaLoginInstructions),
        const SizedBox(height: 16),
        AuthField(
          controller: code,
          hint: c.verificationCode,
          autofillHints: const [AutofillHints.oneTimeCode],
          onChanged: (_) => setState(() {}),
        ),
        AuthError(auth.error),
        AuthButton(
          label: c.verify,
          onPressed: auth.busy || code.text.trim().isEmpty
              ? null
              : () async {
                  final success = await ref
                      .read(authControllerProvider.notifier)
                      .verifyMfaLogin(code.text.trim());
                  code.clear();
                  if (context.mounted && success) {
                    context.go(
                      ref.read(authControllerProvider).user!.nextRoute,
                    );
                  }
                },
        ),
      ],
    );
  }
}
