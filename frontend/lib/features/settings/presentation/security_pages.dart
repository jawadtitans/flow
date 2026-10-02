import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:passkeys/exceptions.dart';
import '../domain/passkey_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/flow_dialog.dart';
import '../../auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../domain/settings_repository.dart';
import 'settings_components.dart';

class PasswordSecurityPage extends StatelessWidget {
  const PasswordSecurityPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: c.passwordSecurity,
      children: [
        SettingsGroup(
          children: [
            for (final row in [
              (c.changePassword, 'password', Icons.key_outlined),
              (c.mfa, 'mfa', Icons.shield_outlined),
              (c.passkeys, 'passkeys', Icons.fingerprint),
              (c.appLock, 'app-lock', Icons.lock_outline),
            ])
              SettingsRow(
                title: row.$1,
                icon: row.$3,
                onTap: () => context.push('/settings/${row.$2}'),
              ),
          ],
        ),
      ],
    );
  }
}

class MfaSettingsPage extends ConsumerStatefulWidget {
  const MfaSettingsPage({super.key});
  @override
  ConsumerState<MfaSettingsPage> createState() => _MfaSettingsPageState();
}

class _MfaSettingsPageState extends ConsumerState<MfaSettingsPage> {
  final password = TextEditingController(), code = TextEditingController();
  MfaSetup? setup;
  List<String> recovery = [];
  bool busy = false, acknowledged = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    code.dispose();
    setup = null;
    recovery.clear();
    super.dispose();
  }

  Future<void> run(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = authErrorMessage(e));
    } finally {
      password.clear();
      code.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    final repository = ref.watch(accountSettingsRepositoryProvider);
    return PopScope(
      canPop: recovery.isEmpty || acknowledged,
      child: SettingsScaffold(
        title: c.mfa,
        allowBack: recovery.isEmpty || acknowledged,
        children: [
          ref
              .watch(mfaProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Column(
                  children: [
                    SettingsNote(c.securityUnavailable),
                    TextButton(
                      onPressed: () => ref.invalidate(mfaProvider),
                      child: Text(c.retry),
                    ),
                  ],
                ),
                data: (state) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsGroup(
                      children: [
                        SettingsRow(
                          title: c.status,
                          trailing: Text(state.enabled ? c.on : c.off),
                        ),
                        SettingsRow(
                          title: c.authenticatorApp,
                          subtitle: c.recommended,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (setup == null && !state.enabled) ...[
                      if (ref.watch(authControllerProvider).user?.hasPassword ==
                          true)
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: c.currentPassword,
                          ),
                        ),
                      if (ref.watch(authControllerProvider).user?.hasPassword !=
                          true)
                        SettingsNote(c.mfaRecentVerification),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final result = await repository.setupMfa(
                                  password.text,
                                );
                                if (mounted) setState(() => setup = result);
                              }),
                        child: Text(c.setupMfa),
                      ),
                    ],
                    if (setup != null) ...[
                      Center(
                        child: Container(
                          color: const Color(0xFFFFFFFF),
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(data: setup!.uri, size: 190),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(setup!.key, textAlign: TextAlign.center),
                      SettingsNote(c.mfaInstructions),
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: c.authenticatorCode,
                        ),
                      ),
                      FilledButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                if (!RegExp(r'^\d{6}$').hasMatch(code.text)) {
                                  throw AuthFailure(c.invalidCode);
                                }
                                final result = await repository.verifyMfa(
                                  setup!.id,
                                  code.text,
                                );
                                if (mounted) {
                                  setState(() {
                                    recovery = result;
                                    acknowledged = false;
                                    setup = null;
                                  });
                                }
                                ref.invalidate(mfaProvider);
                              }),
                        child: Text(c.verify),
                      ),
                    ],
                    if (state.enabled) ...[
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: c.verificationCode,
                        ),
                      ),
                      if (state.recoveryAvailable)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                  final result = await repository
                                      .regenerateRecovery(code.text);
                                  if (mounted) {
                                    setState(() {
                                      recovery = result;
                                      acknowledged = false;
                                    });
                                  }
                                }),
                          child: Text(c.regenerateRecovery),
                        ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => run(() async {
                                final confirmed = await confirmSecurityAction(
                                  context,
                                  c.disableMfa,
                                );
                                if (!confirmed) return;
                                await repository.disableMfa(code.text);
                                if (mounted) setState(() => recovery = []);
                                ref.invalidate(mfaProvider);
                              }),
                        child: Text(c.disableMfa),
                      ),
                    ],
                  ],
                ),
              ),
          if (recovery.isNotEmpty) ...[
            SettingsSectionLabel(c.recoveryCodes),
            SelectableText(recovery.join('\n')),
            CheckboxListTile(
              title: Text(c.recoverySaved),
              value: acknowledged,
              onChanged: (v) => setState(() => acknowledged = v!),
            ),
            if (acknowledged)
              TextButton(
                onPressed: () => setState(() => recovery = []),
                child: Text(c.done),
              ),
          ],
          if (busy) const Center(child: CircularProgressIndicator()),
          if (error != null) SettingsNote(error!),
        ],
      ),
    );
  }
}

Future<bool> confirmSecurityAction(BuildContext context, String title) async {
  final c = AppLocalizations.of(context)!;
  return await showFlowDialog<bool>(
        context: context,
        builder: (context) => FlowDialog(
          title: title,
          content: const SizedBox.shrink(),
          actions: [
            FlowDialogAction(
              onPressed: () => Navigator.pop(context, false),
              label: c.cancel,
            ),
            FlowDialogAction(
              primary: true,
              onPressed: () => Navigator.pop(context, true),
              label: c.confirm,
            ),
          ],
        ),
      ) ??
      false;
}

class PasskeysPage extends ConsumerStatefulWidget {
  const PasskeysPage({super.key});
  @override
  ConsumerState<PasskeysPage> createState() => _PasskeysPageState();
}

class _PasskeysPageState extends ConsumerState<PasskeysPage> {
  bool busy = false;
  String? error;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      ref.invalidate(passkeysProvider);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is DioException || e is AuthFailure
              ? authErrorMessage(e)
              : switch (e) {
                  PasskeyAuthCancelledException() => AppLocalizations.of(
                    context,
                  )!.passkeyCancelled,
                  ExcludeCredentialsCanNotBeRegisteredException() =>
                    AppLocalizations.of(context)!.passkeyDuplicate,
                  DeviceNotSupportedException() ||
                  PasskeyUnsupportedException() => AppLocalizations.of(
                    context,
                  )!.passkeyUnsupported,
                  NoCreateOptionException() ||
                  MissingGoogleSignInException() ||
                  SyncAccountNotAvailableException() => AppLocalizations.of(
                    context,
                  )!.passkeyProviderUnavailable,
                  DomainNotAssociatedException() => AppLocalizations.of(
                    context,
                  )!.passkeyDomainUnavailable,
                  _ => AppLocalizations.of(context)!.passkeyFailed,
                },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    final repo = ref.watch(accountSettingsRepositoryProvider);
    return SettingsScaffold(
      title: c.passkeys,
      children: [
        SettingsNote(c.passkeyIntro),
        FilledButton.icon(
          onPressed: busy
              ? null
              : () => run(() async {
                  await ref.read(passkeyServiceProvider).register();
                }),
          icon: const Icon(Icons.add),
          label: Text(c.createPasskey),
        ),
        const SizedBox(height: 24),
        SettingsSectionLabel(c.yourPasskeys),
        ref
            .watch(passkeysProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Column(
                children: [
                  SettingsNote(c.securityUnavailable),
                  TextButton(
                    onPressed: () => ref.invalidate(passkeysProvider),
                    child: Text(c.retry),
                  ),
                ],
              ),
              data: (keys) => keys.isEmpty
                  ? SettingsNote(c.noPasskeys)
                  : SettingsGroup(
                      children: [
                        for (final key in keys)
                          SettingsRow(
                            icon: Icons.fingerprint,
                            title: key.name,
                            subtitle:
                                '${c.created}: ${MaterialLocalizations.of(context).formatMediumDate(key.createdAt)}${key.lastUsedAt == null ? '' : '\n${c.lastUsed}: ${MaterialLocalizations.of(context).formatMediumDate(key.lastUsedAt!)}'}',
                            trailing: PopupMenuButton<String>(
                              enabled: !busy,
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(c.rename),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(c.remove),
                                ),
                              ],
                              onSelected: (value) async {
                                if (value == 'remove') {
                                  if (await confirmSecurityAction(
                                    context,
                                    c.removePasskey,
                                  )) {
                                    await run(() => repo.removePasskey(key.id));
                                  }
                                } else {
                                  final name = TextEditingController(
                                    text: key.name,
                                  );
                                  final result = await showFlowDialog<String>(
                                    context: context,
                                    builder: (context) => FlowDialog(
                                      title: c.rename,
                                      content: TextField(
                                        controller: name,
                                        maxLength: 80,
                                      ),
                                      actions: [
                                        FlowDialogAction(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          label: c.cancel,
                                        ),
                                        FlowDialogAction(
                                          primary: true,
                                          onPressed: () => Navigator.pop(
                                            context,
                                            name.text.trim(),
                                          ),
                                          label: c.save,
                                        ),
                                      ],
                                    ),
                                  );
                                  name.dispose();
                                  if (result != null && result.isNotEmpty) {
                                    await run(
                                      () => repo.renamePasskey(key.id, result),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                      ],
                    ),
            ),
        if (busy) const Center(child: CircularProgressIndicator()),
        if (error != null) SettingsNote(error!),
      ],
    );
  }
}
