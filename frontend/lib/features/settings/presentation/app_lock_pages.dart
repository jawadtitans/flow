import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/app_lock.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_repository.dart';
import 'settings_components.dart';

class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});
  @override
  ConsumerState<AppLockSettingsPage> createState() =>
      _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  final pin = TextEditingController(), confirmation = TextEditingController();
  bool biometric = false, busy = false;
  String? error;
  @override
  void dispose() {
    pin.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context)!;
    final config = ref.watch(appLockProvider);
    return SettingsScaffold(
      title: copy.appLock,
      children: [
        config.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Column(
            children: [
              Text(copy.lockUnavailable),
              TextButton(
                onPressed: () => ref.invalidate(appLockProvider),
                child: Text(copy.retry),
              ),
            ],
          ),
          data: (data) => Column(
            children: [
              SettingsGroup(
                children: [
                  SettingsRow(
                    title: copy.appLock,
                    trailing: Switch(
                      value: data.enabled,
                      onChanged: busy
                          ? null
                          : (_) async {
                              if (!data.enabled &&
                                  pin.text != confirmation.text) {
                                setState(() => error = copy.pinMismatch);
                                return;
                              }
                              setState(() {
                                busy = true;
                                error = null;
                              });
                              try {
                                final controller = ref.read(
                                  appLockProvider.notifier,
                                );
                                if (data.enabled) {
                                  await controller.disable(pin.text);
                                } else {
                                  await controller.enable(pin.text, biometric);
                                }
                                pin.clear();
                                confirmation.clear();
                              } catch (_) {
                                if (mounted) {
                                  setState(() => error = copy.lockFailed);
                                }
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: data.enabled ? copy.currentPin : copy.newPin,
                ),
              ),
              if (!data.enabled) ...[
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: copy.confirmPin),
                ),
                SwitchListTile(
                  title: Text(copy.biometrics),
                  subtitle: Text(copy.biometricNote),
                  value: biometric,
                  onChanged: (v) => setState(() => biometric = v),
                ),
              ],
              if (data.enabled) ...[
                SettingsNote(
                  data.biometrics ? copy.biometricPin : copy.pinOnly,
                ),
                SettingsSectionLabel(copy.lockFlow),
                RadioGroup<int>(
                  groupValue: data.minutes,
                  onChanged: (v) => saveSettings(
                    context,
                    () => ref.read(appLockProvider.notifier).timeout(v!),
                  ),
                  child: SettingsGroup(
                    children: [
                      for (final minutes in [0, 1, 5, 15])
                        RadioListTile<int>(
                          title: Text(
                            minutes == 0
                                ? copy.immediately
                                : copy.afterMinutes(minutes),
                          ),
                          value: minutes,
                        ),
                    ],
                  ),
                ),
              ],
              if (busy) const CircularProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Removes protected content from the tree while the app is backgrounded or
/// locked. A cold start with a saved configuration always requires unlocking.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool locked = true, hidden = false, busy = false, recovering = false;
  String? recoveryChallenge;
  final elapsed = Stopwatch();
  final pin = TextEditingController();
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final configuration = ref.read(appLockProvider).asData?.value;
    if (configuration?.enabled != true) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (state != AppLifecycleState.inactive && !elapsed.isRunning) {
        elapsed.reset();
        elapsed.start();
      }
      setState(() => hidden = true);
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        locked =
            locked ||
            (elapsed.isRunning && configuration!.shouldLock(elapsed.elapsed));
        hidden = false;
      });
      elapsed.stop();
    }
  }

  Future<void> unlock(bool biometric) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final controller = ref.read(appLockProvider.notifier);
      final success = biometric
          ? await controller.biometricUnlock()
          : await controller.verify(pin.text);
      if (mounted) {
        setState(() {
          if (success) {
            locked = false;
            pin.clear();
            error = null;
          } else {
            error = AppLocalizations.of(context)!.unlockFailed;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = AppLocalizations.of(context)!.unlockFailed);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appLockProvider);
    // Unsupported previews have no persistent native secure storage.
    if (config.isLoading) {
      return const ColoredBox(
        color: Color(0xFF101E28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (config.hasError) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(appLockProvider),
            child: Text(AppLocalizations.of(context)!.retry),
          ),
        ),
      );
    }
    final value = config.requireValue;
    if (!value.enabled || (!locked && !hidden)) {
      return Stack(children: [Offstage(offstage: false, child: widget.child)]);
    }
    final copy = AppLocalizations.of(context)!;
    final lockScreen = Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 42),
                const SizedBox(height: 20),
                Text(
                  copy.unlockFlow,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (!hidden) ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: pin,
                    obscureText: true,
                    keyboardType: recoveryChallenge == null
                        ? TextInputType.number
                        : TextInputType.text,
                    maxLength: recoveryChallenge == null ? 6 : 64,
                    inputFormatters: recoveryChallenge == null
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : [],
                    decoration: InputDecoration(labelText: copy.currentPin),
                    onSubmitted: recovering ? null : (_) => unlock(false),
                  ),
                  if (error != null) Text(error!),
                  FilledButton(
                    onPressed: busy ? null : () => unlock(false),
                    child: Text(copy.unlock),
                  ),
                  if (value.biometrics)
                    TextButton(
                      onPressed: busy ? null : () => unlock(true),
                      child: Text(copy.useBiometrics),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              final email = ref
                                  .read(authControllerProvider)
                                  .user!
                                  .email;
                              await ref
                                  .read(authRepositoryProvider)
                                  .requestAccess(email);
                              if (mounted) {
                                setState(() {
                                  recovering = true;
                                  pin.clear();
                                });
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(() => error = copy.unlockFailed);
                              }
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(copy.recoverLock),
                  ),
                  if (recovering)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                final email = ref
                                    .read(authControllerProvider)
                                    .user!
                                    .email;
                                await ref
                                    .read(appLockProvider.notifier)
                                    .recover(
                                      email,
                                      pin.text,
                                      mfaChallenge: recoveryChallenge,
                                    );
                                if (mounted) {
                                  setState(() {
                                    locked = false;
                                    recovering = false;
                                    pin.clear();
                                  });
                                }
                              } on MfaChallengeRequired catch (challenge) {
                                if (mounted) {
                                  setState(() {
                                    recoveryChallenge = challenge.id;
                                    pin.clear();
                                    error = copy.mfaLoginInstructions;
                                  });
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => error = copy.unlockFailed);
                                }
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: Text(copy.verifyRecovery),
                    ),
                  Text(
                    copy.pinRecovery,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Offstage(offstage: true, child: widget.child),
        Positioned.fill(child: lockScreen),
      ],
    );
  }
}
