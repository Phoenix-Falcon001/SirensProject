import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Sirens'**
  String get appTitle;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Report danger. Stay safe.'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Run by the Lebanese Army.'**
  String get welcomeBody;

  /// No description provided for @iAmCivilian.
  ///
  /// In en, this message translates to:
  /// **'I am a civilian'**
  String get iAmCivilian;

  /// No description provided for @iAmCivilianHint.
  ///
  /// In en, this message translates to:
  /// **'Report a suspicious object and get warnings for your area'**
  String get iAmCivilianHint;

  /// No description provided for @iAmStaff.
  ///
  /// In en, this message translates to:
  /// **'Military / Admin'**
  String get iAmStaff;

  /// No description provided for @iAmStaffHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Army account. The Army VPN must be on.'**
  String get iAmStaffHint;

  /// No description provided for @emergencyBanner.
  ///
  /// In en, this message translates to:
  /// **'In danger now? Move away from the object and call the hotline.'**
  String get emergencyBanner;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'03 123 456'**
  String get phoneHint;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number.'**
  String get phoneInvalid;

  /// No description provided for @phonePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your number is used only to sign you in and so the Army can contact you about your reports.'**
  String get phonePrivacy;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code by SMS'**
  String get sendCode;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {phone}.'**
  String codeSentTo(String phone);

  /// No description provided for @codeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits from the SMS.'**
  String get codeInvalid;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get verify;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get resendCode;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorNetworkStaff.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the Army server. Check that the VPN is on.'**
  String get errorNetworkStaff;

  /// No description provided for @errorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a few minutes and try again.'**
  String get errorTooMany;

  /// No description provided for @errorWrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong or expired code.'**
  String get errorWrongCode;

  /// No description provided for @errorWrongLogin.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password.'**
  String get errorWrongLogin;

  /// No description provided for @errorAccountLocked.
  ///
  /// In en, this message translates to:
  /// **'Account locked for a while after too many attempts.'**
  String get errorAccountLocked;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account is disabled. Contact your admin.'**
  String get errorAccountDisabled;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @reportObject.
  ///
  /// In en, this message translates to:
  /// **'Report a suspicious object'**
  String get reportObject;

  /// No description provided for @reportObjectHint.
  ///
  /// In en, this message translates to:
  /// **'Photo, place and a short description'**
  String get reportObjectHint;

  /// No description provided for @myReports.
  ///
  /// In en, this message translates to:
  /// **'My reports'**
  String get myReports;

  /// No description provided for @myReportsHint.
  ///
  /// In en, this message translates to:
  /// **'See whether your reports were received'**
  String get myReportsHint;

  /// No description provided for @warnings.
  ///
  /// In en, this message translates to:
  /// **'Area warnings'**
  String get warnings;

  /// No description provided for @warningsHint.
  ///
  /// In en, this message translates to:
  /// **'Places to avoid, published by the Army'**
  String get warningsHint;

  /// No description provided for @safety.
  ///
  /// In en, this message translates to:
  /// **'Safety and hotlines'**
  String get safety;

  /// No description provided for @safetyHint.
  ///
  /// In en, this message translates to:
  /// **'What to do, and who to call'**
  String get safetyHint;

  /// No description provided for @staffGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String staffGreeting(String name);

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @levelField.
  ///
  /// In en, this message translates to:
  /// **'Field'**
  String get levelField;

  /// No description provided for @levelAnalyst.
  ///
  /// In en, this message translates to:
  /// **'Analyst'**
  String get levelAnalyst;

  /// No description provided for @levelCommander.
  ///
  /// In en, this message translates to:
  /// **'Commander'**
  String get levelCommander;

  /// No description provided for @regionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Regions'**
  String get regionsLabel;

  /// No description provided for @allRegions.
  ///
  /// In en, this message translates to:
  /// **'All regions'**
  String get allRegions;

  /// No description provided for @menuNewReport.
  ///
  /// In en, this message translates to:
  /// **'New report'**
  String get menuNewReport;

  /// No description provided for @menuIncidents.
  ///
  /// In en, this message translates to:
  /// **'Incidents'**
  String get menuIncidents;

  /// No description provided for @menuBrief.
  ///
  /// In en, this message translates to:
  /// **'Pre-arrival brief'**
  String get menuBrief;

  /// No description provided for @menuMap.
  ///
  /// In en, this message translates to:
  /// **'Map and MGRS'**
  String get menuMap;

  /// No description provided for @menuReview.
  ///
  /// In en, this message translates to:
  /// **'Review links'**
  String get menuReview;

  /// No description provided for @menuDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get menuDashboard;

  /// No description provided for @menuCivilReports.
  ///
  /// In en, this message translates to:
  /// **'Civilian reports'**
  String get menuCivilReports;

  /// No description provided for @menuWarnings.
  ///
  /// In en, this message translates to:
  /// **'Publish warnings'**
  String get menuWarnings;

  /// No description provided for @menuUsers.
  ///
  /// In en, this message translates to:
  /// **'Manage accounts'**
  String get menuUsers;

  /// No description provided for @menuAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get menuAudit;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'This part arrives in the next version of the app.'**
  String get comingSoon;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters.'**
  String passwordTooShort(int min);

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed.'**
  String get passwordChanged;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Your account and phone number will be deleted from this app. Reports already received by the Army stay with the Army.'**
  String get deleteAccountBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {who}'**
  String signedInAs(String who);

  /// No description provided for @catSuspiciousObject.
  ///
  /// In en, this message translates to:
  /// **'Suspicious object'**
  String get catSuspiciousObject;

  /// No description provided for @catUnexplodedOrdnance.
  ///
  /// In en, this message translates to:
  /// **'Unexploded shell, rocket or bomb'**
  String get catUnexplodedOrdnance;

  /// No description provided for @catSuspiciousVehicle.
  ///
  /// In en, this message translates to:
  /// **'Suspicious vehicle'**
  String get catSuspiciousVehicle;

  /// No description provided for @catSuspiciousActivity.
  ///
  /// In en, this message translates to:
  /// **'Suspicious activity'**
  String get catSuspiciousActivity;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @reportSafeDistance.
  ///
  /// In en, this message translates to:
  /// **'I am at a safe distance from the object'**
  String get reportSafeDistance;

  /// No description provided for @reportSafeDistanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Move away first. Only send the report from a safe distance.'**
  String get reportSafeDistanceRequired;

  /// No description provided for @reportWhat.
  ///
  /// In en, this message translates to:
  /// **'What did you see?'**
  String get reportWhat;

  /// No description provided for @reportDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get reportDescription;

  /// No description provided for @reportDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What it looks like and exactly where it is (street, landmark)'**
  String get reportDescriptionHint;

  /// No description provided for @reportPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo (optional)'**
  String get reportPhoto;

  /// No description provided for @reportPhotoWarning.
  ///
  /// In en, this message translates to:
  /// **'Never go closer to take a photo.'**
  String get reportPhotoWarning;

  /// No description provided for @reportTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get reportTakePhoto;

  /// No description provided for @reportChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get reportChoosePhoto;

  /// No description provided for @reportRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get reportRemovePhoto;

  /// No description provided for @photoUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This photo format is not supported. Use JPEG or PNG.'**
  String get photoUnsupported;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This photo is too large (over 5 MB).'**
  String get photoTooLarge;

  /// No description provided for @reportLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get reportLocation;

  /// No description provided for @reportUseLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get reportUseLocation;

  /// No description provided for @reportLocationFix.
  ///
  /// In en, this message translates to:
  /// **'Location added (within about {meters} m)'**
  String reportLocationFix(int meters);

  /// No description provided for @reportLocationNone.
  ///
  /// In en, this message translates to:
  /// **'No location. Describe the place as precisely as you can.'**
  String get reportLocationNone;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off on this phone.'**
  String get locationServiceOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was refused.'**
  String get locationDenied;

  /// No description provided for @locationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not get a location. Try again in the open.'**
  String get locationTimeout;

  /// No description provided for @locationOutside.
  ///
  /// In en, this message translates to:
  /// **'That position is outside Lebanon.'**
  String get locationOutside;

  /// No description provided for @reportNeedsContent.
  ///
  /// In en, this message translates to:
  /// **'Add a description or a photo.'**
  String get reportNeedsContent;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// No description provided for @reportSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Report received'**
  String get reportSentTitle;

  /// No description provided for @reportSentBody.
  ///
  /// In en, this message translates to:
  /// **'Reference {id}. The Army will review it. Stay away from the object.'**
  String reportSentBody(String id);

  /// No description provided for @reportQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone'**
  String get reportQueuedTitle;

  /// No description provided for @reportQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'There is no connection. The report will be sent automatically when you are back online. If there is immediate danger, call the hotline.'**
  String get reportQueuedBody;

  /// No description provided for @reportDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'You have sent many reports today. Please call the hotline instead.'**
  String get reportDailyLimit;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @myReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'You have not sent any reports yet.'**
  String get myReportsEmpty;

  /// No description provided for @pendingSection.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get pendingSection;

  /// No description provided for @sentSection.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentSection;

  /// No description provided for @sendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sendNow;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @notSentReason.
  ///
  /// In en, this message translates to:
  /// **'Not accepted: {reason}'**
  String notSentReason(String reason);

  /// No description provided for @statusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get statusReceived;

  /// No description provided for @statusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get statusUnderReview;

  /// No description provided for @statusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get statusClosed;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not followed up'**
  String get statusRejected;

  /// No description provided for @statusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get statusWaiting;

  /// No description provided for @deliveredToArmy.
  ///
  /// In en, this message translates to:
  /// **'Delivered to the Army'**
  String get deliveredToArmy;

  /// No description provided for @sentOn.
  ///
  /// In en, this message translates to:
  /// **'Sent {date}'**
  String sentOn(String date);

  /// No description provided for @savedOn.
  ///
  /// In en, this message translates to:
  /// **'Saved {date}'**
  String savedOn(String date);

  /// No description provided for @showingSaved.
  ///
  /// In en, this message translates to:
  /// **'Offline. Showing the copy from {date}.'**
  String showingSaved(String date);

  /// No description provided for @warningsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active warnings.'**
  String get warningsEmpty;

  /// No description provided for @warningsAllAreas.
  ///
  /// In en, this message translates to:
  /// **'All areas'**
  String get warningsAllAreas;

  /// No description provided for @warningsUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String warningsUntil(String date);

  /// No description provided for @warningsPullHint.
  ///
  /// In en, this message translates to:
  /// **'Pull down to check for new warnings.'**
  String get warningsPullHint;

  /// No description provided for @severityInfo.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get severityInfo;

  /// No description provided for @severityCaution.
  ///
  /// In en, this message translates to:
  /// **'Caution'**
  String get severityCaution;

  /// No description provided for @severityDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get severityDanger;

  /// No description provided for @safetyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Sample text. The official instructions and numbers from the Lebanese Army will replace it.'**
  String get safetyPlaceholder;

  /// No description provided for @safetySteps.
  ///
  /// In en, this message translates to:
  /// **'If you see a suspicious object'**
  String get safetySteps;

  /// No description provided for @safetyHotlines.
  ///
  /// In en, this message translates to:
  /// **'Hotlines'**
  String get safetyHotlines;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @numberToBeConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Number to be confirmed'**
  String get numberToBeConfirmed;

  /// No description provided for @callFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the call. Dial {number} yourself.'**
  String callFailed(String number);
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
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
