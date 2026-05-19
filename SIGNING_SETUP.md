# إعداد توقيع Android (Release Signing)

تم إعداد بنية التوقيع لتطبيق Android بحيث يقرأ معلومات التوقيع من ملف `android/key.properties`.

## الملفات المستخدمة
- Keystore: `android/app/upload-keystore.jks`
- خصائص التوقيع: `android/key.properties`
- إعدادات Gradle: `android/app/build.gradle.kts`

## تنبيه أمني مهم
لا ترفع أي ملف موقّع بتوقيع Debug إلى Google Play.
إعداد Gradle الحالي يمنع بناء نسخة Release إذا كانت بيانات التوقيع ناقصة أو ما زالت تحتوي على `CHANGE_ME`.

القيم في `android/key.properties` يجب أن تكون حقيقية وقوية، ويجب حفظ ملفي `android/key.properties` و`android/app/upload-keystore.jks` في مكان آمن خارج Git.
إذا كان التطبيق منشوراً سابقاً على Google Play، لا تنشئ مفتاحاً جديداً عشوائياً قبل التأكد من أنك تستخدم Upload Key الصحيح لهذا التطبيق.

## مثال إنشاء Keystore جديد
```bash
keytool -genkeypair -v \
  -keystore android/app/upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

## مثال ملف android/key.properties
```properties
storeFile=app/upload-keystore.jks
storePassword=YOUR_STRONG_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_STRONG_KEY_PASSWORD
```

## أوامر التحقق والبناء
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

## التحقق من ملف AAB
```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

يجب ألا يظهر في نتيجة التحقق:
```text
CN=Android Debug
```
