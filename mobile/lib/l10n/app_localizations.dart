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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en'), Locale('fr')];

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

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @notFoundOrOutside.
  ///
  /// In en, this message translates to:
  /// **'Not found, or outside your regions.'**
  String get notFoundOrOutside;

  /// No description provided for @leadsNote.
  ///
  /// In en, this message translates to:
  /// **'Every link is a lead for a human analyst, never a conclusion.'**
  String get leadsNote;

  /// No description provided for @bandStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get bandStrong;

  /// No description provided for @bandMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get bandMedium;

  /// No description provided for @bandWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get bandWeak;

  /// No description provided for @decisionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get decisionConfirm;

  /// No description provided for @decisionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get decisionReject;

  /// No description provided for @decisionUnsure.
  ///
  /// In en, this message translates to:
  /// **'Unsure'**
  String get decisionUnsure;

  /// No description provided for @decisionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get decisionUndo;

  /// No description provided for @decidedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get decidedConfirm;

  /// No description provided for @decidedReject.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get decidedReject;

  /// No description provided for @decidedUnsure.
  ///
  /// In en, this message translates to:
  /// **'Unsure'**
  String get decidedUnsure;

  /// No description provided for @decidedOpen.
  ///
  /// In en, this message translates to:
  /// **'Not reviewed'**
  String get decidedOpen;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'What you checked or decided'**
  String get noteHint;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @reviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No links to review in your regions.'**
  String get reviewEmpty;

  /// No description provided for @scoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score {score}'**
  String scoreLabel(String score);

  /// No description provided for @incidentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reports in your regions yet.'**
  String get incidentsEmpty;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by place, ID or text'**
  String get searchHint;

  /// No description provided for @allCazas.
  ///
  /// In en, this message translates to:
  /// **'All cazas'**
  String get allCazas;

  /// No description provided for @narrative.
  ///
  /// In en, this message translates to:
  /// **'Report text'**
  String get narrative;

  /// No description provided for @extractedFeatures.
  ///
  /// In en, this message translates to:
  /// **'What Sirens read in it'**
  String get extractedFeatures;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @phones.
  ///
  /// In en, this message translates to:
  /// **'Phone numbers'**
  String get phones;

  /// No description provided for @networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Likely network'**
  String get networkTitle;

  /// No description provided for @networkNone.
  ///
  /// In en, this message translates to:
  /// **'Not linked to other reports in your regions.'**
  String get networkNone;

  /// No description provided for @networkTentative.
  ///
  /// In en, this message translates to:
  /// **'Tentative: all links are weak.'**
  String get networkTentative;

  /// No description provided for @networkShares.
  ///
  /// In en, this message translates to:
  /// **'Shared features'**
  String get networkShares;

  /// No description provided for @newReportCaza.
  ///
  /// In en, this message translates to:
  /// **'Caza'**
  String get newReportCaza;

  /// No description provided for @newReportStreet.
  ///
  /// In en, this message translates to:
  /// **'Street / place'**
  String get newReportStreet;

  /// No description provided for @newReportDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get newReportDate;

  /// No description provided for @newReportType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get newReportType;

  /// No description provided for @typeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not sure (Sirens will guess from the text)'**
  String get typeUnknown;

  /// No description provided for @newReportText.
  ///
  /// In en, this message translates to:
  /// **'Report text'**
  String get newReportText;

  /// No description provided for @newReportTextHint.
  ///
  /// In en, this message translates to:
  /// **'What happened, what was found, where, and who reported it'**
  String get newReportTextHint;

  /// No description provided for @gridRef.
  ///
  /// In en, this message translates to:
  /// **'MGRS {ref}'**
  String gridRef(String ref);

  /// No description provided for @fileReport.
  ///
  /// In en, this message translates to:
  /// **'File report'**
  String get fileReport;

  /// No description provided for @reportFiled.
  ///
  /// In en, this message translates to:
  /// **'Report filed as {id}'**
  String reportFiled(String id);

  /// No description provided for @reportQueuedStaff.
  ///
  /// In en, this message translates to:
  /// **'Saved on this phone. It will be filed when the Army VPN is back.'**
  String get reportQueuedStaff;

  /// No description provided for @draftsWaiting.
  ///
  /// In en, this message translates to:
  /// **'Reports waiting for the VPN: {n}'**
  String draftsWaiting(int n);

  /// No description provided for @outsideRegions.
  ///
  /// In en, this message translates to:
  /// **'That caza is outside your regions.'**
  String get outsideRegions;

  /// No description provided for @briefLocation.
  ///
  /// In en, this message translates to:
  /// **'Location (town or street)'**
  String get briefLocation;

  /// No description provided for @briefDescribe.
  ///
  /// In en, this message translates to:
  /// **'What do you expect to find? (optional)'**
  String get briefDescribe;

  /// No description provided for @briefRun.
  ///
  /// In en, this message translates to:
  /// **'Get brief'**
  String get briefRun;

  /// No description provided for @briefInArea.
  ///
  /// In en, this message translates to:
  /// **'{n} past reports in this area'**
  String briefInArea(int n);

  /// No description provided for @briefObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects reported here'**
  String get briefObjects;

  /// No description provided for @briefSignature.
  ///
  /// In en, this message translates to:
  /// **'Common features here'**
  String get briefSignature;

  /// No description provided for @briefMatches.
  ///
  /// In en, this message translates to:
  /// **'Most similar past reports'**
  String get briefMatches;

  /// No description provided for @briefIncidents.
  ///
  /// In en, this message translates to:
  /// **'Reports in this area'**
  String get briefIncidents;

  /// No description provided for @briefNote.
  ///
  /// In en, this message translates to:
  /// **'Record-based only: what was reported here before. It does not identify any object and gives no handling guidance.'**
  String get briefNote;

  /// No description provided for @briefNone.
  ///
  /// In en, this message translates to:
  /// **'No past reports match this place in your regions.'**
  String get briefNone;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'last {date}'**
  String lastSeen(String date);

  /// No description provided for @dashTotal.
  ///
  /// In en, this message translates to:
  /// **'{n} reports'**
  String dashTotal(int n);

  /// No description provided for @dashTimeline.
  ///
  /// In en, this message translates to:
  /// **'Reports per month'**
  String get dashTimeline;

  /// No description provided for @dashUndated.
  ///
  /// In en, this message translates to:
  /// **'{n} without a date'**
  String dashUndated(int n);

  /// No description provided for @dashByCaza.
  ///
  /// In en, this message translates to:
  /// **'By caza'**
  String get dashByCaza;

  /// No description provided for @dashByInitiation.
  ///
  /// In en, this message translates to:
  /// **'By initiation method'**
  String get dashByInitiation;

  /// No description provided for @dashLinks.
  ///
  /// In en, this message translates to:
  /// **'Links and review'**
  String get dashLinks;

  /// No description provided for @dashLinksTotal.
  ///
  /// In en, this message translates to:
  /// **'{n} links'**
  String dashLinksTotal(int n);

  /// No description provided for @dashReviewed.
  ///
  /// In en, this message translates to:
  /// **'{pct}% reviewed'**
  String dashReviewed(int pct);

  /// No description provided for @dashNetworks.
  ///
  /// In en, this message translates to:
  /// **'Candidate networks'**
  String get dashNetworks;

  /// No description provided for @dashNetworkRow.
  ///
  /// In en, this message translates to:
  /// **'{n} reports'**
  String dashNetworkRow(int n);

  /// No description provided for @dashUnlinked.
  ///
  /// In en, this message translates to:
  /// **'{n} reports not linked'**
  String dashUnlinked(int n);

  /// No description provided for @dashQuality.
  ///
  /// In en, this message translates to:
  /// **'Data completeness'**
  String get dashQuality;

  /// No description provided for @dashQualityOverall.
  ///
  /// In en, this message translates to:
  /// **'{pct}% complete on average'**
  String dashQualityOverall(int pct);

  /// No description provided for @dashFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get dashFrom;

  /// No description provided for @dashTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get dashTo;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilters;

  /// No description provided for @mapCentre.
  ///
  /// In en, this message translates to:
  /// **'Centre {mgrs}'**
  String mapCentre(String mgrs);

  /// No description provided for @mapCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied {mgrs}'**
  String mapCopied(String mgrs);

  /// No description provided for @mapNoStreetMap.
  ///
  /// In en, this message translates to:
  /// **'Street map not on this phone: showing caza outlines only.'**
  String get mapNoStreetMap;

  /// No description provided for @mapDownload.
  ///
  /// In en, this message translates to:
  /// **'Download street map ({mb} MB)'**
  String mapDownload(String mb);

  /// No description provided for @mapDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {pct}%'**
  String mapDownloading(int pct);

  /// No description provided for @mapDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download stopped: {reason}. Try again to resume.'**
  String mapDownloadFailed(String reason);

  /// No description provided for @mapNotOnServer.
  ///
  /// In en, this message translates to:
  /// **'The street map is not installed on the server yet.'**
  String get mapNotOnServer;

  /// No description provided for @mapApprox.
  ///
  /// In en, this message translates to:
  /// **'Approx. — placed at caza centre'**
  String get mapApprox;

  /// No description provided for @mapExact.
  ///
  /// In en, this message translates to:
  /// **'Filed grid reference'**
  String get mapExact;

  /// No description provided for @mapZoneNote.
  ///
  /// In en, this message translates to:
  /// **'The grid jumps at 36°E, where UTM zones 36 and 37 meet.'**
  String get mapZoneNote;

  /// No description provided for @mapDeleteMap.
  ///
  /// In en, this message translates to:
  /// **'Delete street map from phone'**
  String get mapDeleteMap;

  /// No description provided for @mapGrid.
  ///
  /// In en, this message translates to:
  /// **'MGRS grid'**
  String get mapGrid;

  /// No description provided for @openReport.
  ///
  /// In en, this message translates to:
  /// **'Open report'**
  String get openReport;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @civilEmpty.
  ///
  /// In en, this message translates to:
  /// **'No civilian reports in your regions.'**
  String get civilEmpty;

  /// No description provided for @civilNoCaza.
  ///
  /// In en, this message translates to:
  /// **'Outside the known cazas (admins only)'**
  String get civilNoCaza;

  /// No description provided for @civilObserved.
  ///
  /// In en, this message translates to:
  /// **'Seen {date}'**
  String civilObserved(String date);

  /// No description provided for @civilReporter.
  ///
  /// In en, this message translates to:
  /// **'Reporter'**
  String get civilReporter;

  /// No description provided for @civilReporterDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted; no number'**
  String get civilReporterDeleted;

  /// No description provided for @civilNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No GPS position: see description'**
  String get civilNoLocation;

  /// No description provided for @civilAccuracy.
  ///
  /// In en, this message translates to:
  /// **'± {meters} m'**
  String civilAccuracy(int meters);

  /// No description provided for @civilSetStatus.
  ///
  /// In en, this message translates to:
  /// **'Set status'**
  String get civilSetStatus;

  /// No description provided for @civilStatusNote.
  ///
  /// In en, this message translates to:
  /// **'Internal note (not shown to the civilian)'**
  String get civilStatusNote;

  /// No description provided for @civilStatusSaved.
  ///
  /// In en, this message translates to:
  /// **'Status saved. The civilian sees it after the next sync.'**
  String get civilStatusSaved;

  /// No description provided for @civilLastChange.
  ///
  /// In en, this message translates to:
  /// **'{status} by {who}'**
  String civilLastChange(String status, String who);

  /// No description provided for @civilToReport.
  ///
  /// In en, this message translates to:
  /// **'File as military report'**
  String get civilToReport;

  /// No description provided for @civilPhotoFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo could not be loaded.'**
  String get civilPhotoFailed;

  /// No description provided for @civilFromCivilian.
  ///
  /// In en, this message translates to:
  /// **'From civilian report {id}'**
  String civilFromCivilian(String id);

  /// No description provided for @warnActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get warnActive;

  /// No description provided for @warnPast.
  ///
  /// In en, this message translates to:
  /// **'Expired or withdrawn'**
  String get warnPast;

  /// No description provided for @warnNew.
  ///
  /// In en, this message translates to:
  /// **'New warning'**
  String get warnNew;

  /// No description provided for @warnWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get warnWithdraw;

  /// No description provided for @warnWithdrawConfirm.
  ///
  /// In en, this message translates to:
  /// **'Withdraw this warning? Civilians stop seeing it after the next sync.'**
  String get warnWithdrawConfirm;

  /// No description provided for @warnWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get warnWithdrawn;

  /// No description provided for @warnBy.
  ///
  /// In en, this message translates to:
  /// **'By {who}'**
  String warnBy(String who);

  /// No description provided for @warnSeverity.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get warnSeverity;

  /// No description provided for @warnDuration.
  ///
  /// In en, this message translates to:
  /// **'Shown for'**
  String get warnDuration;

  /// No description provided for @warnHours.
  ///
  /// In en, this message translates to:
  /// **'{n} hours'**
  String warnHours(int n);

  /// No description provided for @warnDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String warnDays(int n);

  /// No description provided for @warnTitleIn.
  ///
  /// In en, this message translates to:
  /// **'Title ({lang})'**
  String warnTitleIn(String lang);

  /// No description provided for @warnBodyIn.
  ///
  /// In en, this message translates to:
  /// **'What civilians should do ({lang})'**
  String warnBodyIn(String lang);

  /// No description provided for @warnNeedsText.
  ///
  /// In en, this message translates to:
  /// **'Write the title and text in at least one language, the same one.'**
  String get warnNeedsText;

  /// No description provided for @warnGuidance.
  ///
  /// In en, this message translates to:
  /// **'Say only what civilians should do (avoid, keep away). No incident details.'**
  String get warnGuidance;

  /// No description provided for @warnPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get warnPublish;

  /// No description provided for @warnPublished.
  ///
  /// In en, this message translates to:
  /// **'Published. Civilians see it after the next sync.'**
  String get warnPublished;

  /// No description provided for @warnEmpty.
  ///
  /// In en, this message translates to:
  /// **'No warnings.'**
  String get warnEmpty;

  /// No description provided for @usersNew.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get usersNew;

  /// No description provided for @usersRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get usersRole;

  /// No description provided for @usersRoleMilitary.
  ///
  /// In en, this message translates to:
  /// **'Military'**
  String get usersRoleMilitary;

  /// No description provided for @usersLevel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get usersLevel;

  /// No description provided for @usersRegions.
  ///
  /// In en, this message translates to:
  /// **'Regions (at least one)'**
  String get usersRegions;

  /// No description provided for @usersDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Full name and rank'**
  String get usersDisplayName;

  /// No description provided for @usersTempPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get usersTempPassword;

  /// No description provided for @usersGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get usersGenerate;

  /// No description provided for @usersPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Give it to the person in person; they change it after signing in.'**
  String get usersPasswordHint;

  /// No description provided for @usersActive.
  ///
  /// In en, this message translates to:
  /// **'Account active'**
  String get usersActive;

  /// No description provided for @usersDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get usersDisabled;

  /// No description provided for @usersResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get usersResetPassword;

  /// No description provided for @usersResetDone.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Their sessions were ended.'**
  String get usersResetDone;

  /// No description provided for @usersSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get usersSaved;

  /// No description provided for @usersCreated.
  ///
  /// In en, this message translates to:
  /// **'Account {name} created.'**
  String usersCreated(String name);

  /// No description provided for @usersSearch.
  ///
  /// In en, this message translates to:
  /// **'Search accounts'**
  String get usersSearch;

  /// No description provided for @usersYou.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get usersYou;

  /// No description provided for @usersCannotDisableSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot disable your own account.'**
  String get usersCannotDisableSelf;

  /// No description provided for @auditEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get auditEmpty;

  /// No description provided for @serverSaid.
  ///
  /// In en, this message translates to:
  /// **'Not accepted: {reason}'**
  String serverSaid(String reason);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en', 'fr'].contains(locale.languageCode);

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
