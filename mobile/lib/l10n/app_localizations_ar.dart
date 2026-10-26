// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'سايرنز';

  @override
  String get chooseLanguage => 'اختر لغتك';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get welcomeTitle => 'أبلغ عن الخطر. ابقَ بأمان.';

  @override
  String get welcomeBody => 'بإدارة الجيش اللبناني.';

  @override
  String get iAmCivilian => 'أنا مدني';

  @override
  String get iAmCivilianHint => 'أبلغ عن جسم مشبوه واحصل على تحذيرات لمنطقتك';

  @override
  String get iAmStaff => 'عسكري / مسؤول';

  @override
  String get iAmStaffHint => 'سجّل الدخول بحسابك في الجيش. يجب تشغيل شبكة VPN الخاصة بالجيش.';

  @override
  String get emergencyBanner => 'في خطر الآن؟ ابتعد عن الجسم واتصل بالخط الساخن.';

  @override
  String get phoneLabel => 'رقم الهاتف الخلوي';

  @override
  String get phoneHint => '03 123 456';

  @override
  String get phoneInvalid => 'أدخل رقم هاتف صحيحاً.';

  @override
  String get phonePrivacy =>
      'يُستخدم رقمك فقط لتسجيل دخولك ولكي يتمكن الجيش من التواصل معك بشأن بلاغاتك.';

  @override
  String get sendCode => 'أرسل الرمز برسالة نصية';

  @override
  String get codeLabel => 'الرمز المؤلف من 6 أرقام';

  @override
  String codeSentTo(String phone) {
    return 'أرسلنا رمزاً إلى $phone.';
  }

  @override
  String get codeInvalid => 'أدخل الأرقام الستة الواردة في الرسالة.';

  @override
  String get verify => 'تأكيد';

  @override
  String get changeNumber => 'تغيير الرقم';

  @override
  String get resendCode => 'أرسل رمزاً جديداً';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get errorNetwork => 'تعذّر الوصول إلى الخادم. تحقّق من الاتصال وحاول مجدداً.';

  @override
  String get errorNetworkStaff => 'تعذّر الوصول إلى خادم الجيش. تأكّد من تشغيل VPN.';

  @override
  String get errorTooMany => 'محاولات كثيرة. انتظر بضع دقائق وحاول مجدداً.';

  @override
  String get errorWrongCode => 'الرمز خاطئ أو منتهي الصلاحية.';

  @override
  String get errorWrongLogin => 'اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get errorAccountLocked => 'الحساب مقفل مؤقتاً بعد محاولات كثيرة.';

  @override
  String get errorAccountDisabled => 'هذا الحساب معطّل. تواصل مع المسؤول.';

  @override
  String get errorGeneric => 'حدث خطأ. حاول مجدداً.';

  @override
  String get sessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول مجدداً.';

  @override
  String get reportObject => 'الإبلاغ عن جسم مشبوه';

  @override
  String get reportObjectHint => 'صورة والمكان ووصف قصير';

  @override
  String get myReports => 'بلاغاتي';

  @override
  String get myReportsHint => 'تحقّق من استلام بلاغاتك';

  @override
  String get warnings => 'تحذيرات المناطق';

  @override
  String get warningsHint => 'أماكن يجب تجنّبها، ينشرها الجيش';

  @override
  String get safety => 'السلامة والخطوط الساخنة';

  @override
  String get safetyHint => 'ماذا تفعل ومن تتصل به';

  @override
  String staffGreeting(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get roleAdmin => 'مسؤول';

  @override
  String get levelField => 'ميداني';

  @override
  String get levelAnalyst => 'محلّل';

  @override
  String get levelCommander => 'قائد';

  @override
  String get regionsLabel => 'المناطق';

  @override
  String get allRegions => 'كل المناطق';

  @override
  String get menuNewReport => 'بلاغ جديد';

  @override
  String get menuIncidents => 'الحوادث';

  @override
  String get menuBrief => 'إحاطة قبل الوصول';

  @override
  String get menuMap => 'الخريطة وMGRS';

  @override
  String get menuReview => 'مراجعة الروابط';

  @override
  String get menuDashboard => 'لوحة المعلومات';

  @override
  String get menuCivilReports => 'بلاغات المدنيين';

  @override
  String get menuWarnings => 'نشر التحذيرات';

  @override
  String get menuUsers => 'إدارة الحسابات';

  @override
  String get menuAudit => 'سجل التدقيق';

  @override
  String get comingSoon => 'هذا القسم سيتوفر في الإصدار القادم من التطبيق.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get account => 'الحساب';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String passwordTooShort(int min) {
    return '$min أحرف على الأقل.';
  }

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get deleteAccount => 'حذف حسابي';

  @override
  String get deleteAccountBody =>
      'سيُحذف حسابك ورقم هاتفك من هذا التطبيق. البلاغات التي استلمها الجيش تبقى لدى الجيش.';

  @override
  String get delete => 'حذف';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String signedInAs(String who) {
    return 'مسجّل الدخول باسم $who';
  }
}
