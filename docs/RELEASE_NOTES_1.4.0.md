# CarCare – ملاحظات الإصدار 1.4.0 (build 8)

> مستودع: `MoTechSys/Flutter-Native-App-011` · الحزمة: `com.carcare.maintenance`
> السابق: 1.3.0 (build 7) → **الحالي: 1.4.0 (build 8)**
> `license.json` لم يتغيّر (الكود `CAR-7K2M`).

## ما الجديد باختصار
**قائمة جانبية (Drawer)** + **شاشة إعدادات** + **وضع داكن/فاتح/حسب النظام** مع تحويل الثيم بالكامل ليدعم الوضعين، وإصلاحات دقّة في الواجهات.

---

## 1. القائمة الجانبية `AppDrawer` (جديد)
**الملف:** `lib/widgets/app_drawer.dart`
- رأس بتدرّج برتقالي: شعار CarCare + اسم المستخدم الحالي + اسم السيارة وقراءة العداد (يتحدّث تلقائياً).
- التنقل للتبويبات الأربعة (الرئيسية / الصيانة / الوقود / الإصلاحات) مع تمييز التبويب الحالي.
- **مفتاح "الوضع الداكن"** للتبديل الفوري داكن ↔ فاتح.
- الإعدادات · حول التطبيق · تسجيل الخروج (بتأكيد) · رقم الإصدار في الأسفل.
- زر القائمة `MenuButton` (☰) في شريط كل تبويب؛ يفتح Drawer الهيكل الرئيسي حتى من داخل Scaffold متداخل (`findRootAncestorStateOfType<ScaffoldState>`).

## 2. شاشة الإعدادات `SettingsScreen` (جديد)
**الملف:** `lib/screens/settings_screen.dart` — تُفتح من القائمة الجانبية أو أيقونة ⚙ في الرئيسية.

| القسم | المحتوى |
|---|---|
| المظهر | `SegmentedButton` داكن / فاتح / النظام + مفتاح "الوضع الداكن" |
| التفضيلات | **العملة** (ر.س، ر.ي، د.إ، ج.م، د.ك، $) تنعكس فوراً على كل المبالغ · **حدّ التنبيه "قريب"** (200–2000 كم) يدخل في حساب حالة الصيانة |
| السيارة | تعديل الاسم وقراءة العداد |
| الحساب | المستخدم الحالي · **تغيير كلمة المرور** (يتحقق من الحالية ثم يحدّث SQLite) · تسجيل الخروج |
| عن التطبيق | حول CarCare + رقم الإصدار |

## 3. خدمة الإعدادات `SettingsService` (جديد)
**الملف:** `lib/services/settings_service.dart` — `ChangeNotifier` محفوظ في SharedPreferences:
`settings.theme_mode` (dark/light/system) · `settings.currency` · `settings.reminder_km`.
تُحمَّل في `main()` قبل `runApp`، و`MaterialApp` يعيد البناء عند أي تغيير.

## 4. الثيم داكن/فاتح (تغيير معماري)
**الملف:** `lib/theme.dart`
- `AppPalette` لوحتان (`dark` / `light`) لألوان الأسطح والنص: `bg / card / cardLight / text / textDim / divider`.
- `AppColors` تحوّلت من ثوابت إلى **getters تقرأ اللوحة الحالية** — فبقيت كل الشاشات القديمة تعمل بلا تغيير مواقع الاستخدام، مع إزالة `const` حيث لزم (25 موقعاً).
- `buildTheme({dark})` يبني `ThemeData` كاملاً للوضعين: AppBar، Card، Dialog، BottomSheet، Drawer، ListTile، Switch، NavigationBar، Input، TabBar، DatePicker.
- أُزيلت كل الألوان الثابتة `Colors.white` / `Colors.white12` من الشاشات (نص → `AppColors.text`، فواصل → `AppColors.divider`)، وخلفيات الحوارات/الأوراق السفلية صارت من الثيم.
- لوحة الوضع الفاتح: خلفية `#F3F6FA`، بطاقات بيضاء، نص كحلي `#0D1B2A`، نص باهت `#5C6F8A` — مع بقاء الألوان المميِّزة (برتقالي/سماوي/أخضر/بنفسجي) كما هي.

## 5. إصلاحات
- **Overflow 7.8px** في شارة الحالة داخل بطاقات "حالة السيارة" على 360px (ظهر مع الوضع الفاتح) → `Flexible` + `ellipsis`.
- حوار تسجيل الخروج موحّد في `confirmLogout()` بدل تكراره.
- `AuthService.currentEmail()` جديد (لتغيير كلمة المرور).
- عزل قاعدة بيانات الاختبارات لكل ملف (`init(dbName:)`) لمنع تعارض التشغيل المتوازي.

## 6. جودة وتحقق
| الفحص | النتيجة |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` | **31/31** (5 جديدة: SettingsService حفظ/استرجاع، buildTheme للوضعين، مفتاح الإعدادات يبدّل الوضع، الإعدادات بلا Overflow في الوضع الفاتح، Drawer يفتح/ينقّل/يبدّل الوضع) — شُغّلت مرتين متتاليتين بنجاح |
| Playwright (ويب 390×844) | 11 لقطة: الرئيسية داكن → القائمة → تبديل فاتح → الإعدادات → العملة → الرئيسية/الصيانة/الوقود فاتح → الإعدادات داكن → وضع النظام. 0 أخطاء تطبيق (فقط CORS لملف الترخيص على localhost — سلوك معروف على الويب) |
| APK | `aapt`: `versionName 1.4.0 / versionCode 8` |

## 7. ملفات تغيّرت
```
pubspec.yaml                        1.3.0+7 → 1.4.0+8
lib/theme.dart                      AppPalette + AppColors getters + buildTheme(dark)
lib/services/settings_service.dart  (جديد)
lib/screens/settings_screen.dart    (جديد)
lib/widgets/app_drawer.dart         (جديد)
lib/widgets/common.dart             MenuButton + confirmLogout + fmtMoney بالعملة المختارة
lib/main.dart                       تحميل الإعدادات، MaterialApp يتبع الوضع، Drawer في MainShell
lib/screens/home|maintenance|fuel|repairs_screen.dart   MenuButton في AppBar، إزالة ألوان ثابتة
lib/screens/about|license|record_details_screen.dart    إزالة ألوان ثابتة
lib/screens/auth/*.dart, lib/widgets/otp_verify_panel.dart  إزالة const للألوان الديناميكية
lib/services/storage_service.dart   reminderKm في statusOf، refreshUi()، init(dbName)
lib/services/auth_service.dart      currentEmail()
test/settings_theme_test.dart       (جديد) · test/*.dart عزل DB
docs/screens_1.4.0/                 لقطات القائمة/الإعدادات/الوضع الفاتح
```

## 8. ملاحظة التوقيع
كما في 1.3.0: `releases/CarCare-v1.4.0.apk` مُوقَّع بمفتاح **debug** (مفتاح الإصدار غير متاح في جلسة البناء). يُثبَّت فوق 1.3.0 (نفس مفتاح debug، versionCode أعلى) لكن **ليس فوق 1.2.0**. لإصدار تحديث رسمي: ضع `release-key.jks` + `key.properties` في `android/` ثم `./build_release.sh`.
