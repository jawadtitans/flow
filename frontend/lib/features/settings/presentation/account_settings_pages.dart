import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_picker/country_picker.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../auth/auth_controller.dart';
import '../domain/settings_repository.dart';
import 'settings_components.dart';

String normalizePhone(String input, String iso) {
  if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(input.trim())) {
    throw const FormatException('Invalid phone number');
  }
  final phone = PhoneNumber.parse(
    input.trim(),
    callerCountry: IsoCode.values.byName(iso),
  );
  if (!phone.isValid()) throw const FormatException('Invalid phone number');
  return phone.international;
}

class PersonalDetailsPage extends ConsumerWidget {
  const PersonalDetailsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppLocalizations.of(context)!;
    final user = ref.watch(authControllerProvider).user;
    return SettingsScaffold(
      title: c.personalDetails,
      fallback: '/settings/accounts',
      children: [
        SettingsGroup(
          children: [
            for (final row in [
              (c.firstName, user?.firstName ?? ''),
              (c.lastName, user?.lastName ?? ''),
              (
                c.birthDate,
                user?.birthDate == null
                    ? ''
                    : MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(user!.birthDate!),
              ),
            ])
              SettingsRow(
                title: row.$1,
                subtitle: row.$2,
                onTap: () => context.push('/auth/profile'),
              ),
            SettingsRow(
              title: c.phoneNumber,
              subtitle: user?.phoneNumber == null
                  ? c.addPhone
                  : '${user!.phoneNumber}${user.phoneVerified ? ' · ${c.verified}' : ''}',
              onTap: () => context.push('/settings/accounts/phone'),
            ),
          ],
        ),
      ],
    );
  }
}

class AddPhoneNumberPage extends ConsumerStatefulWidget {
  const AddPhoneNumberPage({super.key});
  @override
  ConsumerState<AddPhoneNumberPage> createState() => _AddPhoneNumberPageState();
}

class _AddPhoneNumberPageState extends ConsumerState<AddPhoneNumberPage> {
  Country country = Country.parse('AF');
  final phone = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: c.addPhone,
      fallback: '/settings/accounts/details',
      children: [
        SettingsSectionLabel(c.country),
        SettingsGroup(
          children: [
            SettingsRow(
              title: '${country.flagEmoji}  ${country.name}',
              onTap: busy
                  ? null
                  : () => showCountryPicker(
                      context: context,
                      showPhoneCode: true,
                      onSelect: (v) => setState(() => country = v),
                    ),
            ),
            SettingsRow(
              title: c.countryCode,
              trailing: Text('+${country.phoneCode}'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          decoration: InputDecoration(labelText: c.phoneNumber),
        ),
        if (error != null) SettingsNote(error!),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final normalized = normalizePhone(
                      phone.text,
                      country.countryCode,
                    );
                    final id = await ref
                        .read(accountSettingsRepositoryProvider)
                        .requestPhone(normalized);
                    if (context.mounted) {
                      context.push(
                        '/settings/accounts/verify-phone',
                        extra: PhoneVerification(id, normalized),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(
                        () => error = e is FormatException
                            ? c.invalidPhone
                            : authErrorMessage(e),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? c.sending : c.continueLabel),
        ),
      ],
    );
  }
}

class PhoneVerification {
  const PhoneVerification(this.id, this.phone);
  final String id, phone;
}

class VerifyPhonePage extends ConsumerStatefulWidget {
  const VerifyPhonePage({this.verification, super.key});
  final PhoneVerification? verification;
  @override
  ConsumerState<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends ConsumerState<VerifyPhonePage> {
  bool serverVerified = false;
  final code = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    return SettingsScaffold(
      title: c.verifyPhone,
      fallback: '/settings/accounts/phone',
      children: [
        SettingsNote(widget.verification?.phone ?? c.phoneSessionExpired),
        TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofillHints: const [AutofillHints.oneTimeCode],
          decoration: InputDecoration(labelText: c.verificationCode),
        ),
        if (error != null) SettingsNote(error!),
        FilledButton(
          onPressed: busy || widget.verification == null
              ? null
              : () async {
                  if (!serverVerified &&
                      !RegExp(r'^\d{6}$').hasMatch(code.text)) {
                    setState(() => error = c.invalidCode);
                    return;
                  }
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    if (!serverVerified) {
                      await ref
                          .read(accountSettingsRepositoryProvider)
                          .verifyPhone(widget.verification!.id, code.text);
                      serverVerified = true;
                    }
                    final refreshed = await ref
                        .read(authControllerProvider.notifier)
                        .refreshUser();
                    if (!refreshed) {
                      throw AuthFailure(
                        ref.read(authControllerProvider).error ??
                            c.securityUnavailable,
                      );
                    }
                    code.clear();
                    if (context.mounted) {
                      context.go('/settings/accounts/details');
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = authErrorMessage(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(c.verify),
        ),
        TextButton(
          onPressed: busy || widget.verification == null
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final id = await ref
                        .read(accountSettingsRepositoryProvider)
                        .requestPhone(widget.verification!.phone);
                    if (context.mounted) {
                      context.replace(
                        '/settings/accounts/verify-phone',
                        extra: PhoneVerification(
                          id,
                          widget.verification!.phone,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = authErrorMessage(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(c.resendCode),
        ),
      ],
    );
  }
}

bool passwordsMatch(String password, String confirmation) =>
    password.isNotEmpty && password == confirmation;

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final fields = List.generate(3, (_) => TextEditingController());
  final hidden = [true, true, true];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppLocalizations.of(context)!;
    final hasPassword =
        ref.watch(authControllerProvider).user?.hasPassword == true;
    final labels = [c.currentPassword, c.newPassword, c.confirmPassword];
    return SettingsScaffold(
      title: hasPassword ? c.changePassword : c.createPassword,
      children: [
        for (var i = hasPassword ? 0 : 1; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: fields[i],
              obscureText: hidden[i],
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: labels[i],
                suffixIcon: IconButton(
                  tooltip: hidden[i] ? c.showPassword : c.hidePassword,
                  onPressed: () => setState(() => hidden[i] = !hidden[i]),
                  icon: Icon(
                    hidden[i]
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
          ),
        SettingsNote(c.passwordPolicy),
        if (error != null) SettingsNote(error!),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  if ((hasPassword && fields[0].text.isEmpty) ||
                      !passwordsMatch(fields[1].text, fields[2].text)) {
                    setState(() => error = c.passwordMismatch);
                    return;
                  }
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    if (hasPassword) {
                      await ref
                          .read(accountSettingsRepositoryProvider)
                          .changePassword(fields[0].text, fields[1].text);
                      await ref
                          .read(authControllerProvider.notifier)
                          .expireAfterPasswordChange();
                    } else {
                      final success = await ref
                          .read(authControllerProvider.notifier)
                          .setPassword(fields[1].text);
                      if (!success) {
                        throw AuthFailure(
                          ref.read(authControllerProvider).error ??
                              c.securityUnavailable,
                        );
                      }
                    }
                    for (final field in fields) {
                      field.clear();
                    }
                    if (context.mounted) {
                      if (hasPassword) {
                        context.go('/auth');
                      } else {
                        context.pop();
                      }
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = authErrorMessage(e));
                  } finally {
                    for (final field in fields) {
                      field.clear();
                    }
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(busy ? c.saving : c.save),
        ),
      ],
    );
  }
}
