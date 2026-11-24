import 'package:flutter/widgets.dart';

class AppReviewStrings {
  final bool _arabic;

  const AppReviewStrings._(this._arabic);

  factory AppReviewStrings.of(BuildContext context) {
    return AppReviewStrings._(
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }

  String _pick(String arabic, String english) => _arabic ? arabic : english;

  String get allowCamera =>
      _pick('السماح باستخدام الكاميرا', 'Allow Camera Permission');
  String get openSettings => _pick('فتح الإعدادات', 'Open Settings');
  String get cameraDenied => _pick(
    'تم رفض صلاحية الكاميرا. تحتاج ميزة مسح الباركود إلى الكاميرا فقط أثناء المسح.',
    'Camera permission was denied. Barcode scanning uses the camera only while scanning.',
  );
  String get cameraPermanentlyDenied => _pick(
    'صلاحية الكاميرا مرفوضة من إعدادات الجهاز. افتح إعدادات التطبيق لتفعيلها.',
    'Camera access is disabled in device settings. Open the app settings to enable it.',
  );
  String get cameraFailure => _pick(
    'تعذر تشغيل الكاميرا. يمكنك المحاولة مجدداً أو استخدام البحث اليدوي.',
    'The camera could not be started. Try again or use manual search.',
  );
  String get cameraPurpose => _pick(
    'نحتاج إذن الكاميرا فقط لمسح باركود المنتج. لا يتم تصوير أو تخزين أو إرسال صور.',
    'Camera access is used only to scan product barcodes. No photos are captured, stored, or sent.',
  );
  String get retry => _pick('إعادة المحاولة', 'Try Again');
  String get cancel => _pick('إلغاء', 'Cancel');
  String get phoneOptional =>
      _pick('رقم الهاتف – اختياري', 'Phone number – optional');
  String get phoneContactWarning => _pick(
    'إذا لم تضف رقم هاتف فلن نتمكن من التواصل معك بخصوص حسابك أو طلبك.',
    'Without a phone number, we will not be able to contact you about your account or order.',
  );
  String get settings => _pick('الإعدادات', 'Settings');
  String get accountManagement => _pick('إدارة الحساب', 'Account Management');
  String get deleteAccount => _pick('حذف الحساب', 'Delete Account');
  String get continueDeleteAccount =>
      _pick('متابعة حذف الحساب', 'Continue Account Deletion');
  String get deleteAccountPermanently =>
      _pick('حذف الحساب نهائياً', 'Delete Account Permanently');
  String get deleteAccountFailed =>
      _pick('تعذر حذف الحساب', 'Unable to Delete Account');
  String get deleteAccountSucceeded =>
      _pick('تم حذف الحساب بنجاح', 'Account Deleted Successfully');
  String get deletionRequiresInternet => _pick(
    'يتطلب حذف الحساب اتصالاً بالإنترنت.',
    'Account deletion requires an internet connection.',
  );
  String get deletionExplanation => _pick(
    'هذه العملية نهائية. سيتم حذف حسابك وملفك الشخصي وعناوينك ورموز جلساتك وإشعاراتك وبياناتك المحفوظة، ولن تتمكن من تسجيل الدخول بهذا الحساب مرة أخرى.',
    'This action is permanent. Your account, profile, addresses, sessions, notification links, and saved account data will be deleted, and you will no longer be able to sign in to this account.',
  );
  String get deletionRetainedRecords => _pick(
    'قد نحتفظ بالطلبات والفواتير التي يلزم حفظها محاسبياً أو قانونياً بعد فصلها عن حسابك وإزالة بيانات التواصل والعنوان منها.',
    'Orders and invoices that must be retained for accounting or legal reasons may be kept after they are detached from your account and contact and address data is removed.',
  );
  String get password => _pick('كلمة المرور', 'Password');
  String get confirmIdentity => _pick(
    'أدخل كلمة المرور لتأكيد هويتك.',
    'Enter your password to confirm your identity.',
  );
  String get finalDeletionConfirmation => _pick(
    'هل أنت متأكد؟ لا يمكن التراجع عن حذف الحساب.',
    'Are you sure? Account deletion cannot be undone.',
  );
}
