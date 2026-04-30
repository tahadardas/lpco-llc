# Google Play Release Checklist (LPCO)

## الحالة الحالية بعد التهيئة
- اسم الحزمة (Package Name): `com.lpco.app`
- ملف الدخول Android: `com.lpco.app.MainActivity`
- إذن الكاميرا موجود فعليًا في الـ release manifest لأن التطبيق يستخدم ميزة المسح (`mobile_scanner`)
- أذونات الإعلانات `AD_ID` و `ACCESS_ADSERVICES_*` تمت إزالتها من الـ manifest النهائي

## لماذا تظهر رسالة سياسة الخصوصية؟
Google Play يطلب **رابط سياسة خصوصية** عندما يكون التطبيق يصرّح أذونات حساسة مثل:
- `android.permission.CAMERA`

بما أن التطبيق يستخدم المسح بالكاميرا، لا يجب حذف الإذن حتى لا تتعطل الميزة.

## ما يجب ضبطه في Play Console قبل النشر
1. App content > Privacy policy:
   - ضع رابط HTTPS عام لسياسة الخصوصية.
2. Data safety:
   - صرّح استخدام الكاميرا لغرض المسح داخل التطبيق.
   - صرّح أي جمع بيانات فعلي (إن وجد) بدقة.
3. App access:
   - إذا كانت بعض الشاشات تتطلب تسجيل دخول، أضف بيانات اختبار لمراجعة Google.
4. Ads:
   - بما أن `AD_ID` محذوف، اختر أن التطبيق لا يستخدم معرّف الإعلانات إن كان ذلك مطابقًا لسلوك التطبيق.
5. Target audience / Content rating:
   - أكمل الاستبيانات الإلزامية.

## التحقق المحلي قبل الرفع
من جذر المشروع:

```powershell
cd android
.\gradlew.bat :app:processReleaseManifestForPackage
cd ..
flutter build appbundle --release
```

بعد البناء، تحقق من الحزمة داخل الـ manifest النهائي:
- `build/app/intermediates/packaged_manifests/release/processReleaseManifestForPackage/AndroidManifest.xml`
- يجب أن ترى:
  - `package="com.lpco.app"`
  - `android:name="com.lpco.app.MainActivity"`

## ملاحظة Firebase مهمة
تمت مواءمة `android/app/google-services.json` مع `com.lpco.app` كي يطابق اسم الحزمة الجديد.
للنشر الإنتاجي النهائي، الأفضل توليد ملف `google-services.json` رسمي من Firebase لنفس الحزمة `com.lpco.app` ونفس شهادة التوقيع.
