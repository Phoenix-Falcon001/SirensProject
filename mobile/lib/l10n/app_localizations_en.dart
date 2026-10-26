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
}
