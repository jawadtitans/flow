// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get proSubtitle =>
      'Unlock smarter AI, advanced automation, and more powerful experiences with Flow.';

  @override
  String get learnMore => 'Learn more';

  @override
  String get managePlan => 'Manage plan';

  @override
  String get proHeadline => 'Unlock more\nwith Flow';

  @override
  String get getPro => 'Get Flow Pro';

  @override
  String get getMax => 'Get Flow Max';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get close => 'Close';

  @override
  String get active => 'Active';

  @override
  String get plansUnavailable =>
      'Plans are unavailable. Connect to Flow to load current features and pricing.';

  @override
  String get retry => 'Retry';

  @override
  String get feature => 'Feature';

  @override
  String get free => 'Free';

  @override
  String get featuresUnavailable =>
      'Plan features have not been published yet.';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get billingUnavailable =>
      'Purchases will be available when Flow’s store billing is connected.';

  @override
  String get flowAi => 'Flow AI';

  @override
  String get smartActions => 'Smart Actions';

  @override
  String get voice => 'Voice';

  @override
  String get automations => 'Automations';

  @override
  String get documents => 'Documents';

  @override
  String get appLock => 'App lock';

  @override
  String get lockUnavailable =>
      'Secure storage is unavailable. App lock could not be loaded.';

  @override
  String get pinMismatch => 'The PINs must match.';

  @override
  String get lockFailed =>
      'Could not change app lock. Check your PIN and biometric enrollment, then retry.';

  @override
  String get currentPin => 'Current six-digit PIN';

  @override
  String get newPin => 'New six-digit PIN';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get biometrics => 'Biometrics';

  @override
  String get biometricNote =>
      'Requires enrolled fingerprint or face authentication. PIN remains available as a fallback.';

  @override
  String get biometricPin => 'Unlock method: biometrics and PIN';

  @override
  String get pinOnly => 'Unlock method: PIN';

  @override
  String get lockFlow => 'Lock Flow';

  @override
  String get immediately => 'Immediately';

  @override
  String afterMinutes(int minutes) {
    return 'After $minutes minutes';
  }

  @override
  String get unlockFailed =>
      'Unlock failed. Check your PIN or biometrics. After repeated attempts, wait before trying again.';

  @override
  String get unlockFlow => 'Unlock Flow';

  @override
  String get unlock => 'Unlock';

  @override
  String get useBiometrics => 'Use biometrics';

  @override
  String get pinRecovery =>
      'For account recovery, enter the code sent to your verified account email in the PIN field. App lock is reset only after server verification.';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get defaultLanguage => 'Default';

  @override
  String get languagesSoon =>
      'Dari, Pashto, Arabic and more languages are coming soon.';

  @override
  String get permissions => 'Permissions';

  @override
  String get permissionsUnavailable =>
      'Could not read device permissions. Try again on a supported device.';

  @override
  String get microphone => 'Microphone';

  @override
  String get microphoneReason => 'Used for voice conversations with Flow.';

  @override
  String get location => 'Location';

  @override
  String get locationReason =>
      'Used when you ask Flow for location-aware assistance.';

  @override
  String get photos => 'Photos & files';

  @override
  String get photosReason =>
      'Photos access is controlled by your device. Files are selected through the system picker.';

  @override
  String get granted => 'Granted';

  @override
  String get limited => 'Selected photos only';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get checking => 'Checking…';

  @override
  String get notGranted => 'Not granted';

  @override
  String get phone => 'Phone';

  @override
  String get phoneNotRequired =>
      'Not required by current Flow features on this device.';

  @override
  String get permissionsNote =>
      'To revoke an allowed permission, open your device’s app settings. No permissions are requested at startup.';

  @override
  String get flowWidget => 'Flow Widget';

  @override
  String get widgetDescription =>
      'Access Flow faster directly from your Home Screen.';

  @override
  String get widgetPrompt => 'What can I help with?';

  @override
  String get askFlow => 'Ask Flow';

  @override
  String get widgetPinRequested =>
      'Your launcher has received the request. Confirm placement in the system dialog.';

  @override
  String get widgetInstructions =>
      'Touch and hold your Home Screen, open the widget picker, then select Flow. On iOS, tap + or Edit → Add Widget, search for Flow, and choose Add Widget.';

  @override
  String get widgetUnavailable =>
      'The widget could not be added. Try your launcher’s widget picker.';

  @override
  String get addWidget => 'Add Flow Widget';

  @override
  String get passwordSecurity => 'Password & security';

  @override
  String get changePassword => 'Change password';

  @override
  String get mfa => 'Multi-factor authentication';

  @override
  String get passkeys => 'Passkeys';

  @override
  String get securityUnavailable =>
      'Account security is unavailable on this server. Retry after the service is configured.';

  @override
  String get status => 'Status';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get authenticatorApp => 'Authenticator app';

  @override
  String get recommended => 'Recommended method';

  @override
  String get currentPassword => 'Current password';

  @override
  String get setupMfa => 'Set up MFA';

  @override
  String get mfaInstructions =>
      'Scan the QR code or enter the manual key in your authenticator app, then enter its current six-digit code.';

  @override
  String get authenticatorCode => 'Authenticator code';

  @override
  String get invalidCode => 'Enter a six-digit code.';

  @override
  String get verify => 'Verify';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get regenerateRecovery => 'Regenerate recovery codes';

  @override
  String get disableMfa => 'Disable MFA';

  @override
  String get recoveryCodes => 'Recovery codes';

  @override
  String get recoverySaved => 'I have stored these recovery codes safely.';

  @override
  String get done => 'Done';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get passkeyFailed =>
      'Passkey creation was not completed. Your device may not support passkeys, no provider may be available, or the request was cancelled. Try again after checking your device and domain association.';

  @override
  String get passkeyIntro =>
      'Passkeys let you securely access Flow using your device unlock, fingerprint, face or password manager without typing your password.';

  @override
  String get createPasskey => 'Create a passkey';

  @override
  String get yourPasskeys => 'Your passkeys';

  @override
  String get noPasskeys => 'No passkeys yet';

  @override
  String get created => 'Created';

  @override
  String get lastUsed => 'Last used';

  @override
  String get rename => 'Rename';

  @override
  String get remove => 'Remove';

  @override
  String get removePasskey => 'Remove this passkey?';

  @override
  String get save => 'Save';

  @override
  String get personalDetails => 'Personal details';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get birthDate => 'Date of birth';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get addPhone => 'Add phone number';

  @override
  String get verified => 'Verified';

  @override
  String get country => 'Country';

  @override
  String get countryCode => 'Country code';

  @override
  String get invalidPhone =>
      'Enter a valid phone number for the selected country.';

  @override
  String get sending => 'Sending…';

  @override
  String get continueLabel => 'Continue';

  @override
  String get verifyPhone => 'Verify phone number';

  @override
  String get phoneSessionExpired =>
      'This verification session has expired. Add your phone number again.';

  @override
  String get resendCode => 'Resend code';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get createPassword => 'Create password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get passwordPolicy =>
      'The server validates Flow’s password requirements. After a password change, sign in again; existing sessions must be revoked by the server.';

  @override
  String get passwordMismatch =>
      'Enter the required passwords and ensure the new passwords match.';

  @override
  String get saving => 'Saving…';

  @override
  String get dataPrivacy => 'Data & privacy';

  @override
  String get security => 'Security';

  @override
  String get voiceUnavailable =>
      'Voice conversations are not available in this build yet. You can ask Flow using text.';

  @override
  String get recoverLock => 'Forgot PIN? Send an account recovery code';

  @override
  String get verifyRecovery => 'Verify emailed code and reset app lock';

  @override
  String get signInPasskey => 'Sign in with a passkey';

  @override
  String get mfaLoginInstructions =>
      'Enter a code from your authenticator app or one of your recovery codes.';

  @override
  String get widget => 'Widget';

  @override
  String get pickerOnly =>
      'Selected photos and files use the system picker. No broad storage permission is required on this device.';

  @override
  String get purchasePending =>
      'Your purchase is pending. Flow will update your plan after the store and server confirm it.';

  @override
  String get restoreRequired =>
      'Restore your purchases to reconnect your existing plan.';

  @override
  String get purchaseConfirmed =>
      'Store request completed. Your plan updates after server confirmation.';

  @override
  String get included => 'Included';

  @override
  String get notIncluded => 'Not included';

  @override
  String get passkeyCancelled =>
      'Passkey creation was cancelled. You can try again whenever you are ready.';

  @override
  String get passkeyDuplicate =>
      'This passkey is already registered. Use your existing passkey or choose another provider.';

  @override
  String get passkeyUnsupported =>
      'Passkeys are not supported on this device. Use a supported device or sign in with your email.';

  @override
  String get passkeyProviderUnavailable =>
      'No credential provider is available. Enable a password manager or sign in to your device’s provider, then retry.';

  @override
  String get passkeyDomainUnavailable =>
      'Flow’s passkey domain association is not configured for this build yet.';

  @override
  String get mfaRecentVerification =>
      'For passwordless accounts, sign in with a fresh email code or passkey before setting up MFA. Flow’s server verifies that the session is recent.';
}
