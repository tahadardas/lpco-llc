# إعداد توقيع Android (Release Signing)

تم إعداد بنية التوقيع لتطبيق Android بحيث يقرأ معلومات التوقيع من ملف `android/key.properties`.

## الملفات المستخدمة
- Keystore: `android/app/upload-keystore.jks`
- خصائص التوقيع: `android/key.properties`
- إعدادات Gradle: `android/app/build.gradle.kts`

## تنبيه أمني مهم
القيم الحالية في `android/key.properties` تبدو افتراضية للتطوير (`CHANGE_ME_STRONG_PASSWORD`).
قبل النشر على Google Play يجب استخدام كلمة مرور قوية وحفظها بشكل آمن.

## مثال إنشاء Keystore جديد
```bash
keytool -genkey -v \
  -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

## أوامر التحقق والبناء
```bash
cd android
./gradlew :app:processReleaseManifestForPackage
cd ..
flutter clean
flutter pub get
flutter build appbundle --release
```

## التحقق من ملف AAB
```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```
