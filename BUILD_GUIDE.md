# دليل البناء — CarCare

> لأي شخص يحمّل المستودع ويريد **تشغيل التطبيق أو إنتاج ملف APK بنفسه** خطوة بخطوة.
> آخر APK جاهز موجود في [`releases/CarCare-v1.2.0.apk`](releases/CarCare-v1.2.0.apk) — إن أردت التثبيت فقط بلا بناء، حمّله من هناك.

---

## 0. ما الموجود في المستودع؟

| المسار | الغرض |
|---|---|
| `releases/CarCare-v1.2.0.apk` | **آخر إصدار جاهز للتثبيت** (موقّع، android-arm64) |
| `lib/` | كود التطبيق (18 ملف Dart) |
| `test/` | 3 ملفات اختبار (`gate_and_recovery_test.dart`, `layout_test.dart`, `screens_test.dart`) |
| `assets/` | الصور والأصول |
| `android/` | مشروع أندرويد (الحزمة `com.carcare.maintenance`) |
| `web/` | ملفات الويب (تشمل `sqlite3.wasm` و`sqflite_sw.js` لعمل SQLite في المتصفح) |
| `license.json` | **ملف التحكم عن بُعد** — يقرأه التطبيق عند كل تشغيل (§6) |
| `docs/RELEASE_NOTES_1.2.0.md` | ملاحظات وتوثيق إصدار 1.2.0 |
| `docs/make_launcher_icons.py` | سكربت توليد أيقونة الإطلاق |
| `docs/SESSION_LOG.md` | سجل التطوير: القرارات والمشاكل وحلولها |

---

## 1. المتطلبات

| الأداة | الإصدار | ملاحظة |
|---|---|---|
| Flutter | **3.35.4** (stable) | أي 3.35.x يعمل |
| Dart | 3.9.2 | يأتي مع Flutter |
| Java (JDK) | **17** | لا تستخدم 21 |
| Android SDK | compileSdk 36 / Build-Tools 35.0.0 | من Android Studio → SDK Manager |

```bash
flutter --version && java -version && flutter doctor
```

---

## 2. تحميل وتشغيل

```bash
git clone https://github.com/MoTechSys/Flutter-Native-App-011.git
cd Flutter-Native-App-011
flutter pub get
flutter analyze          # No issues found!
flutter test             # All tests passed!
flutter run              # جهاز/محاكي أندرويد
flutter run -d chrome    # معاينة ويب
```

---

## 3. بناء APK

### 3.أ — بمفتاح التوقيع الأصلي (نفس مفتاح الإصدارات المنشورة)
يلزمك ملفان **غير مضمّنين في المستودع** (في `.gitignore`):
```
android/release-key.jks
android/key.properties
```
شكل `android/key.properties`:
```properties
storePassword=********
keyPassword=********
keyAlias=release
storeFile=../release-key.jks
```
> اطلبهما من صاحب المشروع. نفس المفتاح مستخدم في المشاريع الثلاثة (EduAcademy, CarCare, Kitabi).
> **لتثبيت تحديث فوق نسخة مثبّتة يجب نفس المفتاح**، وإلا يطلب أندرويد حذف التطبيق أولاً.

```bash
flutter build apk --release --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-release.apk
```
كل المعالجات: `flutter build apk --release` · ملف لكل معمارية: `--split-per-abi`

### 3.ب — بلا مفتاح؟ أنشئ واحداً
```bash
keytool -genkey -v -keystore android/release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
```
ثم أنشئ `android/key.properties` كما أعلاه.

### 3.ج — للتجربة فقط
```bash
flutter build apk --debug
```

### التحقق والتثبيت
```bash
$ANDROID_HOME/build-tools/35.0.0/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
$ANDROID_HOME/build-tools/35.0.0/aapt dump badging build/app/outputs/flutter-apk/app-release.apk | grep ^package
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. إصدار نسخة جديدة

1. عدّل الكود.
2. `pubspec.yaml` → `version: X.Y.Z+N` — **N (versionCode) يجب أن يزيد** كل إصدار.
3. `flutter analyze && flutter test`.
4. `flutter build apk --release --target-platform android-arm64`.
5. انسخ الناتج إلى `releases/CarCare-vX.Y.Z.apk`.
6. حدّث ملاحظات الإصدار في `docs/`.
7. `git add -A && git commit -m "vX.Y.Z: ..." && git tag vX.Y.Z && git push origin main --tags`.

---

## 5. أخطاء شائعة

| الخطأ | السبب | الحل |
|---|---|---|
| `Keystore file not found` | ملفا التوقيع غير موجودين | §3.أ أو §3.ب |
| Gradle يفشل بـ `Unsupported class file major version` | JDK 21 | ثبّت JDK 17 واضبط `JAVA_HOME` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | مفتاح توقيع مختلف | احذف القديم أو استخدم المفتاح الأصلي |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | versionCode لم يزد | ارفع الرقم بعد `+` |
| شاشة "الترخيص موقوف نهائياً" | `license.json` غير موجود على GitHub (404) | أعِد الملف إلى جذر `main` |
| شاشة بيضاء على الويب | ملفات `web/sqlite3.wasm` / `sqflite_sw.js` مفقودة | لا تحذفها |

---

## 6. التحكم عن بُعد (`license.json`)

يقرأ التطبيق `https://github.com/MoTechSys/Flutter-Native-App-011/blob/main/license.json` عند كل تشغيل (GitHub API أولاً — بلا كاش — ثم الملف الخام كاحتياط).

```json
{ "active": true, "code": "CAR-7K2M", "message": "رسالة تظهر عند القفل" }
```

| تريد | افعل | النتيجة |
|---|---|---|
| تشغيل عادي | `"active": true` | يدخل مباشرة |
| إيقاف مع كود | `"active": false` + `code` | شاشة قفل تطلب الكود؛ بعد نجاحه يُحفظ ويفتح تلقائياً **ما لم تغيّر الكود** |
| إيقاف نهائي | **احذف الملف** | "موقوف نهائياً" — لا يقبل أي كود |
| بلا إنترنت | — | آخر حالة محفوظة |

التعديل يصل خلال ثوانٍ. الشيفرة في `lib/services/license_service.dart` ومغطّاة بالاختبارات.
