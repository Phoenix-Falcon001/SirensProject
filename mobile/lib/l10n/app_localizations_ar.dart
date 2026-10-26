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

  @override
  String get catSuspiciousObject => 'جسم مشبوه';

  @override
  String get catUnexplodedOrdnance => 'قذيفة أو صاروخ أو قنبلة غير منفجرة';

  @override
  String get catSuspiciousVehicle => 'مركبة مشبوهة';

  @override
  String get catSuspiciousActivity => 'نشاط مشبوه';

  @override
  String get catOther => 'غير ذلك';

  @override
  String get reportSafeDistance => 'أنا على مسافة آمنة من الجسم';

  @override
  String get reportSafeDistanceRequired => 'ابتعد أولاً. أرسل البلاغ فقط من مسافة آمنة.';

  @override
  String get reportWhat => 'ماذا رأيت؟';

  @override
  String get reportDescription => 'الوصف';

  @override
  String get reportDescriptionHint => 'شكله ومكانه بالتحديد (الشارع، معلم قريب)';

  @override
  String get reportPhoto => 'صورة (اختياري)';

  @override
  String get reportPhotoWarning => 'لا تقترب أبداً لالتقاط صورة.';

  @override
  String get reportTakePhoto => 'التقاط صورة';

  @override
  String get reportChoosePhoto => 'من المعرض';

  @override
  String get reportRemovePhoto => 'إزالة الصورة';

  @override
  String get photoUnsupported => 'صيغة هذه الصورة غير مدعومة. استخدم JPEG أو PNG.';

  @override
  String get photoTooLarge => 'هذه الصورة كبيرة جداً (أكثر من 5 ميغابايت).';

  @override
  String get reportLocation => 'الموقع';

  @override
  String get reportUseLocation => 'استخدم موقعي الحالي';

  @override
  String reportLocationFix(int meters) {
    return 'تمت إضافة الموقع (بدقة $meters م تقريباً)';
  }

  @override
  String get reportLocationNone => 'لا يوجد موقع. صِف المكان بأكبر دقة ممكنة.';

  @override
  String get locationServiceOff => 'خدمة الموقع متوقفة على هذا الهاتف.';

  @override
  String get locationDenied => 'تم رفض إذن الوصول إلى الموقع.';

  @override
  String get locationTimeout => 'تعذّر تحديد الموقع. حاول مجدداً في مكان مكشوف.';

  @override
  String get locationOutside => 'هذا الموقع خارج لبنان.';

  @override
  String get reportNeedsContent => 'أضف وصفاً أو صورة.';

  @override
  String get reportSend => 'إرسال البلاغ';

  @override
  String get reportSentTitle => 'تم استلام البلاغ';

  @override
  String reportSentBody(String id) {
    return 'المرجع $id. سيقوم الجيش بمراجعته. ابقَ بعيداً عن الجسم.';
  }

  @override
  String get reportQueuedTitle => 'تم الحفظ على هذا الهاتف';

  @override
  String get reportQueuedBody =>
      'لا يوجد اتصال. سيُرسل البلاغ تلقائياً عند عودة الاتصال. إذا كان هناك خطر فوري، اتصل بالخط الساخن.';

  @override
  String get reportDailyLimit =>
      'لقد أرسلت بلاغات كثيرة اليوم. يرجى الاتصال بالخط الساخن بدلاً من ذلك.';

  @override
  String get ok => 'حسناً';

  @override
  String get myReportsEmpty => 'لم ترسل أي بلاغ بعد.';

  @override
  String get pendingSection => 'بانتظار الإرسال';

  @override
  String get sentSection => 'المُرسلة';

  @override
  String get sendNow => 'أرسل الآن';

  @override
  String get discard => 'تجاهل';

  @override
  String notSentReason(String reason) {
    return 'لم يُقبل: $reason';
  }

  @override
  String get statusReceived => 'تم الاستلام';

  @override
  String get statusUnderReview => 'قيد المراجعة';

  @override
  String get statusClosed => 'مُغلق';

  @override
  String get statusRejected => 'لم تتم متابعته';

  @override
  String get statusWaiting => 'بانتظار الإرسال';

  @override
  String get deliveredToArmy => 'وصل إلى الجيش';

  @override
  String sentOn(String date) {
    return 'أُرسل في $date';
  }

  @override
  String savedOn(String date) {
    return 'حُفظ في $date';
  }

  @override
  String showingSaved(String date) {
    return 'لا يوجد اتصال. يتم عرض النسخة المحفوظة في $date.';
  }

  @override
  String get warningsEmpty => 'لا توجد تحذيرات حالية.';

  @override
  String get warningsAllAreas => 'كل المناطق';

  @override
  String warningsUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get warningsPullHint => 'اسحب للأسفل للتحقق من التحذيرات الجديدة.';

  @override
  String get severityInfo => 'معلومة';

  @override
  String get severityCaution => 'تنبيه';

  @override
  String get severityDanger => 'خطر';

  @override
  String get safetyPlaceholder =>
      'نص تجريبي. ستحلّ محله التعليمات والأرقام الرسمية من الجيش اللبناني.';

  @override
  String get safetySteps => 'إذا رأيت جسماً مشبوهاً';

  @override
  String get safetyHotlines => 'الخطوط الساخنة';

  @override
  String get call => 'اتصال';

  @override
  String get numberToBeConfirmed => 'الرقم قيد التأكيد';

  @override
  String callFailed(String number) {
    return 'تعذّر بدء الاتصال. اطلب الرقم $number بنفسك.';
  }

  @override
  String get retry => 'حاول مجدداً';

  @override
  String get notFoundOrOutside => 'غير موجود، أو خارج مناطقك.';

  @override
  String get leadsNote => 'كل رابط هو مؤشر للمحلل البشري، وليس استنتاجاً.';

  @override
  String get bandStrong => 'قوي';

  @override
  String get bandMedium => 'متوسط';

  @override
  String get bandWeak => 'ضعيف';

  @override
  String get decisionConfirm => 'تأكيد';

  @override
  String get decisionReject => 'رفض';

  @override
  String get decisionUnsure => 'غير متأكد';

  @override
  String get decisionUndo => 'تراجع';

  @override
  String get decidedConfirm => 'مؤكد';

  @override
  String get decidedReject => 'مرفوض';

  @override
  String get decidedUnsure => 'غير متأكد';

  @override
  String get decidedOpen => 'لم تتم مراجعته';

  @override
  String get filterAll => 'الكل';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get noteHint => 'ما تحققت منه أو قررته';

  @override
  String get notes => 'ملاحظات';

  @override
  String get reviewEmpty => 'لا توجد روابط للمراجعة في مناطقك.';

  @override
  String scoreLabel(String score) {
    return 'الدرجة $score';
  }

  @override
  String get incidentsEmpty => 'لا توجد بلاغات في مناطقك بعد.';

  @override
  String get searchHint => 'ابحث بالمكان أو الرقم أو النص';

  @override
  String get allCazas => 'كل الأقضية';

  @override
  String get narrative => 'نص البلاغ';

  @override
  String get extractedFeatures => 'ما استخرجه Sirens منه';

  @override
  String get people => 'أشخاص';

  @override
  String get groups => 'مجموعات';

  @override
  String get phones => 'أرقام هواتف';

  @override
  String get networkTitle => 'الشبكة المحتملة';

  @override
  String get networkNone => 'غير مرتبط ببلاغات أخرى في مناطقك.';

  @override
  String get networkTentative => 'مبدئي: كل الروابط ضعيفة.';

  @override
  String get networkShares => 'سمات مشتركة';

  @override
  String get newReportCaza => 'القضاء';

  @override
  String get newReportStreet => 'الشارع / المكان';

  @override
  String get newReportDate => 'التاريخ';

  @override
  String get newReportType => 'النوع';

  @override
  String get typeUnknown => 'غير متأكد (سيستنتج Sirens من النص)';

  @override
  String get newReportText => 'نص البلاغ';

  @override
  String get newReportTextHint => 'ماذا حدث، ماذا وُجد، أين، ومن أبلغ';

  @override
  String gridRef(String ref) {
    return 'MGRS $ref';
  }

  @override
  String get fileReport => 'تسجيل البلاغ';

  @override
  String reportFiled(String id) {
    return 'سُجّل البلاغ برقم $id';
  }

  @override
  String get reportQueuedStaff => 'حُفظ على هذا الهاتف. سيُسجَّل عند عودة اتصال VPN الخاص بالجيش.';

  @override
  String draftsWaiting(int n) {
    return 'بلاغات بانتظار VPN: $n';
  }

  @override
  String get outsideRegions => 'هذا القضاء خارج مناطقك.';

  @override
  String get briefLocation => 'الموقع (بلدة أو شارع)';

  @override
  String get briefDescribe => 'ماذا تتوقع أن تجد؟ (اختياري)';

  @override
  String get briefRun => 'عرض الإحاطة';

  @override
  String briefInArea(int n) {
    return '$n بلاغات سابقة في هذه المنطقة';
  }

  @override
  String get briefObjects => 'أجسام أُبلغ عنها هنا';

  @override
  String get briefSignature => 'سمات شائعة هنا';

  @override
  String get briefMatches => 'أكثر البلاغات السابقة تشابهاً';

  @override
  String get briefIncidents => 'بلاغات في هذه المنطقة';

  @override
  String get briefNote =>
      'مبني على السجلات فقط: ما أُبلغ عنه هنا سابقاً. لا يحدد أي جسم ولا يقدم أي إرشادات للتعامل معه.';

  @override
  String get briefNone => 'لا توجد بلاغات سابقة تطابق هذا المكان في مناطقك.';

  @override
  String lastSeen(String date) {
    return 'آخرها $date';
  }

  @override
  String dashTotal(int n) {
    return '$n بلاغات';
  }

  @override
  String get dashTimeline => 'البلاغات شهرياً';

  @override
  String dashUndated(int n) {
    return '$n بلا تاريخ';
  }

  @override
  String get dashByCaza => 'حسب القضاء';

  @override
  String get dashByInitiation => 'حسب طريقة التفجير';

  @override
  String get dashLinks => 'الروابط والمراجعة';

  @override
  String dashLinksTotal(int n) {
    return '$n روابط';
  }

  @override
  String dashReviewed(int pct) {
    return 'تمت مراجعة $pct%';
  }

  @override
  String get dashNetworks => 'شبكات محتملة';

  @override
  String dashNetworkRow(int n) {
    return '$n بلاغات';
  }

  @override
  String dashUnlinked(int n) {
    return '$n بلاغات غير مرتبطة';
  }

  @override
  String get dashQuality => 'اكتمال البيانات';

  @override
  String dashQualityOverall(int pct) {
    return 'مكتملة بنسبة $pct% في المتوسط';
  }

  @override
  String get dashFrom => 'من';

  @override
  String get dashTo => 'إلى';

  @override
  String get clearFilters => 'مسح';

  @override
  String mapCentre(String mgrs) {
    return 'المركز $mgrs';
  }

  @override
  String mapCopied(String mgrs) {
    return 'تم نسخ $mgrs';
  }

  @override
  String get mapNoStreetMap => 'خريطة الشوارع غير موجودة على الهاتف: تظهر حدود الأقضية فقط.';

  @override
  String mapDownload(String mb) {
    return 'تنزيل خريطة الشوارع ($mb ميغابايت)';
  }

  @override
  String mapDownloading(int pct) {
    return 'جارٍ التنزيل… $pct%';
  }

  @override
  String mapDownloadFailed(String reason) {
    return 'توقف التنزيل: $reason. حاول مجدداً للمتابعة.';
  }

  @override
  String get mapNotOnServer => 'خريطة الشوارع غير مثبتة على الخادم بعد.';

  @override
  String get mapApprox => 'تقريبي — موضوع في مركز القضاء';

  @override
  String get mapExact => 'إحداثيات مسجلة';

  @override
  String get mapZoneNote => 'تنقطع الشبكة عند خط 36° شرقاً حيث تلتقي منطقتا UTM 36 و37.';

  @override
  String get mapDeleteMap => 'حذف خريطة الشوارع من الهاتف';

  @override
  String get mapGrid => 'شبكة MGRS';

  @override
  String get openReport => 'فتح البلاغ';

  @override
  String get copy => 'نسخ';

  @override
  String get civilEmpty => 'لا توجد بلاغات مدنيين في مناطقك.';

  @override
  String get civilNoCaza => 'خارج الأقضية المعروفة (للمسؤولين فقط)';

  @override
  String civilObserved(String date) {
    return 'شوهد في $date';
  }

  @override
  String get civilReporter => 'المُبلِّغ';

  @override
  String get civilReporterDeleted => 'الحساب محذوف؛ لا يوجد رقم';

  @override
  String get civilNoLocation => 'لا يوجد موقع GPS: راجع الوصف';

  @override
  String civilAccuracy(int meters) {
    return '± $meters م';
  }

  @override
  String get civilSetStatus => 'تحديد الحالة';

  @override
  String get civilStatusNote => 'ملاحظة داخلية (لا تظهر للمدني)';

  @override
  String get civilStatusSaved => 'حُفظت الحالة. سيراها المدني بعد المزامنة التالية.';

  @override
  String civilLastChange(String status, String who) {
    return '$status بواسطة $who';
  }

  @override
  String get civilToReport => 'تسجيل كبلاغ عسكري';

  @override
  String get civilPhotoFailed => 'تعذّر تحميل الصورة.';

  @override
  String civilFromCivilian(String id) {
    return 'من بلاغ مدني $id';
  }

  @override
  String get warnActive => 'نشطة';

  @override
  String get warnPast => 'منتهية أو مسحوبة';

  @override
  String get warnNew => 'تحذير جديد';

  @override
  String get warnWithdraw => 'سحب';

  @override
  String get warnWithdrawConfirm => 'سحب هذا التحذير؟ لن يراه المدنيون بعد المزامنة التالية.';

  @override
  String get warnWithdrawn => 'مسحوب';

  @override
  String warnBy(String who) {
    return 'بواسطة $who';
  }

  @override
  String get warnSeverity => 'المستوى';

  @override
  String get warnDuration => 'تُعرض لمدة';

  @override
  String warnHours(int n) {
    return '$n ساعات';
  }

  @override
  String warnDays(int n) {
    return '$n أيام';
  }

  @override
  String warnTitleIn(String lang) {
    return 'العنوان ($lang)';
  }

  @override
  String warnBodyIn(String lang) {
    return 'ما يجب على المدنيين فعله ($lang)';
  }

  @override
  String get warnNeedsText => 'اكتب العنوان والنص بلغة واحدة على الأقل، وباللغة نفسها.';

  @override
  String get warnGuidance =>
      'اذكر فقط ما يجب على المدنيين فعله (تجنّب، ابتعد). لا تفاصيل عن الحوادث.';

  @override
  String get warnPublish => 'نشر';

  @override
  String get warnPublished => 'نُشر. سيراه المدنيون بعد المزامنة التالية.';

  @override
  String get warnEmpty => 'لا توجد تحذيرات.';

  @override
  String get usersNew => 'حساب جديد';

  @override
  String get usersRole => 'الدور';

  @override
  String get usersRoleMilitary => 'عسكري';

  @override
  String get usersLevel => 'المستوى';

  @override
  String get usersRegions => 'المناطق (واحدة على الأقل)';

  @override
  String get usersDisplayName => 'الاسم الكامل والرتبة';

  @override
  String get usersTempPassword => 'كلمة مرور مؤقتة';

  @override
  String get usersGenerate => 'توليد';

  @override
  String get usersPasswordHint => 'سلّمها للشخص مباشرة؛ ويغيّرها بعد تسجيل الدخول.';

  @override
  String get usersActive => 'الحساب مفعّل';

  @override
  String get usersDisabled => 'معطّل';

  @override
  String get usersResetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get usersResetDone => 'أُعيد تعيين كلمة المرور. أُنهيت جلساته.';

  @override
  String get usersSaved => 'تم الحفظ.';

  @override
  String usersCreated(String name) {
    return 'تم إنشاء الحساب $name.';
  }

  @override
  String get usersSearch => 'البحث في الحسابات';

  @override
  String get usersYou => 'أنت';

  @override
  String get usersCannotDisableSelf => 'لا يمكنك تعطيل حسابك.';

  @override
  String get auditEmpty => 'لا يوجد شيء مسجّل بعد.';

  @override
  String serverSaid(String reason) {
    return 'لم يُقبل: $reason';
  }
}
