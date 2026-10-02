import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @proSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock smarter AI, advanced automation, and more powerful experiences with Flow.'**
  String get proSubtitle;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get learnMore;

  /// No description provided for @managePlan.
  ///
  /// In en, this message translates to:
  /// **'Manage plan'**
  String get managePlan;

  /// No description provided for @proHeadline.
  ///
  /// In en, this message translates to:
  /// **'Unlock more\nwith Flow'**
  String get proHeadline;

  /// No description provided for @getPro.
  ///
  /// In en, this message translates to:
  /// **'Get Flow Pro'**
  String get getPro;

  /// No description provided for @getMax.
  ///
  /// In en, this message translates to:
  /// **'Get Flow Max'**
  String get getMax;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @plansUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plans are unavailable. Connect to Flow to load current features and pricing.'**
  String get plansUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @feature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get feature;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @featuresUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Plan features have not been published yet.'**
  String get featuresUnavailable;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @billingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases will be available when Flow’s store billing is connected.'**
  String get billingUnavailable;

  /// No description provided for @flowAi.
  ///
  /// In en, this message translates to:
  /// **'Flow AI'**
  String get flowAi;

  /// No description provided for @smartActions.
  ///
  /// In en, this message translates to:
  /// **'Smart Actions'**
  String get smartActions;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @automations.
  ///
  /// In en, this message translates to:
  /// **'Automations'**
  String get automations;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLock;

  /// No description provided for @lockUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Secure storage is unavailable. App lock could not be loaded.'**
  String get lockUnavailable;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs must match.'**
  String get pinMismatch;

  /// No description provided for @lockFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not change app lock. Check your PIN and biometric enrollment, then retry.'**
  String get lockFailed;

  /// No description provided for @currentPin.
  ///
  /// In en, this message translates to:
  /// **'Current six-digit PIN'**
  String get currentPin;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New six-digit PIN'**
  String get newPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmPin;

  /// No description provided for @biometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get biometrics;

  /// No description provided for @biometricNote.
  ///
  /// In en, this message translates to:
  /// **'Requires enrolled fingerprint or face authentication. PIN remains available as a fallback.'**
  String get biometricNote;

  /// No description provided for @biometricPin.
  ///
  /// In en, this message translates to:
  /// **'Unlock method: biometrics and PIN'**
  String get biometricPin;

  /// No description provided for @pinOnly.
  ///
  /// In en, this message translates to:
  /// **'Unlock method: PIN'**
  String get pinOnly;

  /// No description provided for @lockFlow.
  ///
  /// In en, this message translates to:
  /// **'Lock Flow'**
  String get lockFlow;

  /// No description provided for @immediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get immediately;

  /// No description provided for @afterMinutes.
  ///
  /// In en, this message translates to:
  /// **'After {minutes} minutes'**
  String afterMinutes(int minutes);

  /// No description provided for @unlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Unlock failed. Check your PIN or biometrics. After repeated attempts, wait before trying again.'**
  String get unlockFailed;

  /// No description provided for @unlockFlow.
  ///
  /// In en, this message translates to:
  /// **'Unlock Flow'**
  String get unlockFlow;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @useBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get useBiometrics;

  /// No description provided for @pinRecovery.
  ///
  /// In en, this message translates to:
  /// **'For account recovery, enter the code sent to your verified account email in the PIN field. App lock is reset only after server verification.'**
  String get pinRecovery;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @defaultLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLanguage;

  /// No description provided for @languagesSoon.
  ///
  /// In en, this message translates to:
  /// **'Dari, Pashto, Arabic and more languages are coming soon.'**
  String get languagesSoon;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @permissionsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not read device permissions. Try again on a supported device.'**
  String get permissionsUnavailable;

  /// No description provided for @microphone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphone;

  /// No description provided for @microphoneReason.
  ///
  /// In en, this message translates to:
  /// **'Used for voice conversations with Flow.'**
  String get microphoneReason;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @locationReason.
  ///
  /// In en, this message translates to:
  /// **'Used when you ask Flow for location-aware assistance.'**
  String get locationReason;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos & files'**
  String get photos;

  /// No description provided for @photosReason.
  ///
  /// In en, this message translates to:
  /// **'Photos access is controlled by your device. Files are selected through the system picker.'**
  String get photosReason;

  /// No description provided for @granted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get granted;

  /// No description provided for @limited.
  ///
  /// In en, this message translates to:
  /// **'Selected photos only'**
  String get limited;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @notGranted.
  ///
  /// In en, this message translates to:
  /// **'Not granted'**
  String get notGranted;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @phoneNotRequired.
  ///
  /// In en, this message translates to:
  /// **'Not required by current Flow features on this device.'**
  String get phoneNotRequired;

  /// No description provided for @permissionsNote.
  ///
  /// In en, this message translates to:
  /// **'To revoke an allowed permission, open your device’s app settings. No permissions are requested at startup.'**
  String get permissionsNote;

  /// No description provided for @flowWidget.
  ///
  /// In en, this message translates to:
  /// **'Flow Widget'**
  String get flowWidget;

  /// No description provided for @widgetDescription.
  ///
  /// In en, this message translates to:
  /// **'Access Flow faster directly from your Home Screen.'**
  String get widgetDescription;

  /// No description provided for @widgetPrompt.
  ///
  /// In en, this message translates to:
  /// **'What can I help with?'**
  String get widgetPrompt;

  /// No description provided for @askFlow.
  ///
  /// In en, this message translates to:
  /// **'Ask Flow'**
  String get askFlow;

  /// No description provided for @widgetPinRequested.
  ///
  /// In en, this message translates to:
  /// **'Your launcher has received the request. Confirm placement in the system dialog.'**
  String get widgetPinRequested;

  /// No description provided for @widgetInstructions.
  ///
  /// In en, this message translates to:
  /// **'Touch and hold your Home Screen, open the widget picker, then select Flow. On iOS, tap + or Edit → Add Widget, search for Flow, and choose Add Widget.'**
  String get widgetInstructions;

  /// No description provided for @widgetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The widget could not be added. Try your launcher’s widget picker.'**
  String get widgetUnavailable;

  /// No description provided for @addWidget.
  ///
  /// In en, this message translates to:
  /// **'Add Flow Widget'**
  String get addWidget;

  /// No description provided for @passwordSecurity.
  ///
  /// In en, this message translates to:
  /// **'Password & security'**
  String get passwordSecurity;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @mfa.
  ///
  /// In en, this message translates to:
  /// **'Multi-factor authentication'**
  String get mfa;

  /// No description provided for @passkeys.
  ///
  /// In en, this message translates to:
  /// **'Passkeys'**
  String get passkeys;

  /// No description provided for @securityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account security is unavailable on this server. Retry after the service is configured.'**
  String get securityUnavailable;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @authenticatorApp.
  ///
  /// In en, this message translates to:
  /// **'Authenticator app'**
  String get authenticatorApp;

  /// No description provided for @recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended method'**
  String get recommended;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @setupMfa.
  ///
  /// In en, this message translates to:
  /// **'Set up MFA'**
  String get setupMfa;

  /// No description provided for @mfaInstructions.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code or enter the manual key in your authenticator app, then enter its current six-digit code.'**
  String get mfaInstructions;

  /// No description provided for @authenticatorCode.
  ///
  /// In en, this message translates to:
  /// **'Authenticator code'**
  String get authenticatorCode;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a six-digit code.'**
  String get invalidCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @regenerateRecovery.
  ///
  /// In en, this message translates to:
  /// **'Regenerate recovery codes'**
  String get regenerateRecovery;

  /// No description provided for @disableMfa.
  ///
  /// In en, this message translates to:
  /// **'Disable MFA'**
  String get disableMfa;

  /// No description provided for @recoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get recoveryCodes;

  /// No description provided for @recoverySaved.
  ///
  /// In en, this message translates to:
  /// **'I have stored these recovery codes safely.'**
  String get recoverySaved;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @passkeyFailed.
  ///
  /// In en, this message translates to:
  /// **'Passkey creation was not completed. Your device may not support passkeys, no provider may be available, or the request was cancelled. Try again after checking your device and domain association.'**
  String get passkeyFailed;

  /// No description provided for @passkeyIntro.
  ///
  /// In en, this message translates to:
  /// **'Passkeys let you securely access Flow using your device unlock, fingerprint, face or password manager without typing your password.'**
  String get passkeyIntro;

  /// No description provided for @createPasskey.
  ///
  /// In en, this message translates to:
  /// **'Create a passkey'**
  String get createPasskey;

  /// No description provided for @yourPasskeys.
  ///
  /// In en, this message translates to:
  /// **'Your passkeys'**
  String get yourPasskeys;

  /// No description provided for @noPasskeys.
  ///
  /// In en, this message translates to:
  /// **'No passkeys yet'**
  String get noPasskeys;

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @lastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get lastUsed;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removePasskey.
  ///
  /// In en, this message translates to:
  /// **'Remove this passkey?'**
  String get removePasskey;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @personalDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get personalDetails;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get birthDate;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @addPhone.
  ///
  /// In en, this message translates to:
  /// **'Add phone number'**
  String get addPhone;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @countryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get countryCode;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number for the selected country.'**
  String get invalidPhone;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify phone number'**
  String get verifyPhone;

  /// No description provided for @phoneSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'This verification session has expired. Add your phone number again.'**
  String get phoneSessionExpired;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPassword;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get createPassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @passwordPolicy.
  ///
  /// In en, this message translates to:
  /// **'The server validates Flow’s password requirements. After a password change, sign in again; existing sessions must be revoked by the server.'**
  String get passwordPolicy;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Enter the required passwords and ensure the new passwords match.'**
  String get passwordMismatch;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @dataPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Data & privacy'**
  String get dataPrivacy;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice conversations are not available in this build yet. You can ask Flow using text.'**
  String get voiceUnavailable;

  /// No description provided for @recoverLock.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN? Send an account recovery code'**
  String get recoverLock;

  /// No description provided for @verifyRecovery.
  ///
  /// In en, this message translates to:
  /// **'Verify emailed code and reset app lock'**
  String get verifyRecovery;

  /// No description provided for @signInPasskey.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a passkey'**
  String get signInPasskey;

  /// No description provided for @mfaLoginInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter a code from your authenticator app or one of your recovery codes.'**
  String get mfaLoginInstructions;

  /// No description provided for @widget.
  ///
  /// In en, this message translates to:
  /// **'Widget'**
  String get widget;

  /// No description provided for @pickerOnly.
  ///
  /// In en, this message translates to:
  /// **'Selected photos and files use the system picker. No broad storage permission is required on this device.'**
  String get pickerOnly;

  /// No description provided for @purchasePending.
  ///
  /// In en, this message translates to:
  /// **'Your purchase is pending. Flow will update your plan after the store and server confirm it.'**
  String get purchasePending;

  /// No description provided for @restoreRequired.
  ///
  /// In en, this message translates to:
  /// **'Restore your purchases to reconnect your existing plan.'**
  String get restoreRequired;

  /// No description provided for @purchaseConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Store request completed. Your plan updates after server confirmation.'**
  String get purchaseConfirmed;

  /// No description provided for @included.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get included;

  /// No description provided for @notIncluded.
  ///
  /// In en, this message translates to:
  /// **'Not included'**
  String get notIncluded;

  /// No description provided for @passkeyCancelled.
  ///
  /// In en, this message translates to:
  /// **'Passkey creation was cancelled. You can try again whenever you are ready.'**
  String get passkeyCancelled;

  /// No description provided for @passkeyDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This passkey is already registered. Use your existing passkey or choose another provider.'**
  String get passkeyDuplicate;

  /// No description provided for @passkeyUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Passkeys are not supported on this device. Use a supported device or sign in with your email.'**
  String get passkeyUnsupported;

  /// No description provided for @passkeyProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No credential provider is available. Enable a password manager or sign in to your device’s provider, then retry.'**
  String get passkeyProviderUnavailable;

  /// No description provided for @passkeyDomainUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Flow’s passkey domain association is not configured for this build yet.'**
  String get passkeyDomainUnavailable;

  /// No description provided for @mfaRecentVerification.
  ///
  /// In en, this message translates to:
  /// **'For passwordless accounts, sign in with a fresh email code or passkey before setting up MFA. Flow’s server verifies that the session is recent.'**
  String get mfaRecentVerification;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
