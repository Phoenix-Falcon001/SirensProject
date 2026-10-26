// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sirens';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get continueLabel => 'Continue';

  @override
  String get welcomeTitle => 'Report danger. Stay safe.';

  @override
  String get welcomeBody => 'Run by the Lebanese Army.';

  @override
  String get iAmCivilian => 'I am a civilian';

  @override
  String get iAmCivilianHint => 'Report a suspicious object and get warnings for your area';

  @override
  String get iAmStaff => 'Military / Admin';

  @override
  String get iAmStaffHint => 'Sign in with your Army account. The Army VPN must be on.';

  @override
  String get emergencyBanner => 'In danger now? Move away from the object and call the hotline.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHint => '03 123 456';

  @override
  String get phoneInvalid => 'Enter a valid mobile number.';

  @override
  String get phonePrivacy =>
      'Your number is used only to sign you in and so the Army can contact you about your reports.';

  @override
  String get sendCode => 'Send code by SMS';

  @override
  String get codeLabel => '6-digit code';

  @override
  String codeSentTo(String phone) {
    return 'We sent a code to $phone.';
  }

  @override
  String get codeInvalid => 'Enter the 6 digits from the SMS.';

  @override
  String get verify => 'Confirm';

  @override
  String get changeNumber => 'Change number';

  @override
  String get resendCode => 'Send a new code';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get fieldRequired => 'Required';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get errorNetwork => 'Cannot reach the server. Check your connection and try again.';

  @override
  String get errorNetworkStaff => 'Cannot reach the Army server. Check that the VPN is on.';

  @override
  String get errorTooMany => 'Too many attempts. Wait a few minutes and try again.';

  @override
  String get errorWrongCode => 'Wrong or expired code.';

  @override
  String get errorWrongLogin => 'Wrong username or password.';

  @override
  String get errorAccountLocked => 'Account locked for a while after too many attempts.';

  @override
  String get errorAccountDisabled => 'This account is disabled. Contact your admin.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';

  @override
  String get sessionExpired => 'Your session ended. Please sign in again.';

  @override
  String get reportObject => 'Report a suspicious object';

  @override
  String get reportObjectHint => 'Photo, place and a short description';

  @override
  String get myReports => 'My reports';

  @override
  String get myReportsHint => 'See whether your reports were received';

  @override
  String get warnings => 'Area warnings';

  @override
  String get warningsHint => 'Places to avoid, published by the Army';

  @override
  String get safety => 'Safety and hotlines';

  @override
  String get safetyHint => 'What to do, and who to call';

  @override
  String staffGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get levelField => 'Field';

  @override
  String get levelAnalyst => 'Analyst';

  @override
  String get levelCommander => 'Commander';

  @override
  String get regionsLabel => 'Regions';

  @override
  String get allRegions => 'All regions';

  @override
  String get menuNewReport => 'New report';

  @override
  String get menuIncidents => 'Incidents';

  @override
  String get menuBrief => 'Pre-arrival brief';

  @override
  String get menuMap => 'Map and MGRS';

  @override
  String get menuReview => 'Review links';

  @override
  String get menuDashboard => 'Dashboard';

  @override
  String get menuCivilReports => 'Civilian reports';

  @override
  String get menuWarnings => 'Publish warnings';

  @override
  String get menuUsers => 'Manage accounts';

  @override
  String get menuAudit => 'Audit log';

  @override
  String get comingSoon => 'This part arrives in the next version of the app.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get account => 'Account';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String passwordTooShort(int min) {
    return 'At least $min characters.';
  }

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountBody =>
      'Your account and phone number will be deleted from this app. Reports already received by the Army stay with the Army.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String signedInAs(String who) {
    return 'Signed in as $who';
  }

  @override
  String get catSuspiciousObject => 'Suspicious object';

  @override
  String get catUnexplodedOrdnance => 'Unexploded shell, rocket or bomb';

  @override
  String get catSuspiciousVehicle => 'Suspicious vehicle';

  @override
  String get catSuspiciousActivity => 'Suspicious activity';

  @override
  String get catOther => 'Other';

  @override
  String get reportSafeDistance => 'I am at a safe distance from the object';

  @override
  String get reportSafeDistanceRequired =>
      'Move away first. Only send the report from a safe distance.';

  @override
  String get reportWhat => 'What did you see?';

  @override
  String get reportDescription => 'Description';

  @override
  String get reportDescriptionHint =>
      'What it looks like and exactly where it is (street, landmark)';

  @override
  String get reportPhoto => 'Photo (optional)';

  @override
  String get reportPhotoWarning => 'Never go closer to take a photo.';

  @override
  String get reportTakePhoto => 'Take photo';

  @override
  String get reportChoosePhoto => 'From gallery';

  @override
  String get reportRemovePhoto => 'Remove photo';

  @override
  String get photoUnsupported => 'This photo format is not supported. Use JPEG or PNG.';

  @override
  String get photoTooLarge => 'This photo is too large (over 5 MB).';

  @override
  String get reportLocation => 'Location';

  @override
  String get reportUseLocation => 'Use my current location';

  @override
  String reportLocationFix(int meters) {
    return 'Location added (within about $meters m)';
  }

  @override
  String get reportLocationNone => 'No location. Describe the place as precisely as you can.';

  @override
  String get locationServiceOff => 'Location is turned off on this phone.';

  @override
  String get locationDenied => 'Location permission was refused.';

  @override
  String get locationTimeout => 'Could not get a location. Try again in the open.';

  @override
  String get locationOutside => 'That position is outside Lebanon.';

  @override
  String get reportNeedsContent => 'Add a description or a photo.';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSentTitle => 'Report received';

  @override
  String reportSentBody(String id) {
    return 'Reference $id. The Army will review it. Stay away from the object.';
  }

  @override
  String get reportQueuedTitle => 'Saved on this phone';

  @override
  String get reportQueuedBody =>
      'There is no connection. The report will be sent automatically when you are back online. If there is immediate danger, call the hotline.';

  @override
  String get reportDailyLimit =>
      'You have sent many reports today. Please call the hotline instead.';

  @override
  String get ok => 'OK';

  @override
  String get myReportsEmpty => 'You have not sent any reports yet.';

  @override
  String get pendingSection => 'Waiting to send';

  @override
  String get sentSection => 'Sent';

  @override
  String get sendNow => 'Send now';

  @override
  String get discard => 'Discard';

  @override
  String notSentReason(String reason) {
    return 'Not accepted: $reason';
  }

  @override
  String get statusReceived => 'Received';

  @override
  String get statusUnderReview => 'Under review';

  @override
  String get statusClosed => 'Closed';

  @override
  String get statusRejected => 'Not followed up';

  @override
  String get statusWaiting => 'Waiting to send';

  @override
  String get deliveredToArmy => 'Delivered to the Army';

  @override
  String sentOn(String date) {
    return 'Sent $date';
  }

  @override
  String savedOn(String date) {
    return 'Saved $date';
  }

  @override
  String showingSaved(String date) {
    return 'Offline. Showing the copy from $date.';
  }

  @override
  String get warningsEmpty => 'No active warnings.';

  @override
  String get warningsAllAreas => 'All areas';

  @override
  String warningsUntil(String date) {
    return 'Until $date';
  }

  @override
  String get warningsPullHint => 'Pull down to check for new warnings.';

  @override
  String get severityInfo => 'Information';

  @override
  String get severityCaution => 'Caution';

  @override
  String get severityDanger => 'Danger';

  @override
  String get safetyPlaceholder =>
      'Sample text. The official instructions and numbers from the Lebanese Army will replace it.';

  @override
  String get safetySteps => 'If you see a suspicious object';

  @override
  String get safetyHotlines => 'Hotlines';

  @override
  String get call => 'Call';

  @override
  String get numberToBeConfirmed => 'Number to be confirmed';

  @override
  String callFailed(String number) {
    return 'Could not start the call. Dial $number yourself.';
  }
}
