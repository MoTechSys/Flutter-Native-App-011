# CarCare – ملاحظات الإصدار 1.2.0 (build 6)

> مستودع: `MoTechSys/Flutter-Native-App-011` · الحزمة: `com.carcare.maintenance`
> ملف التحكم: `license.json` في جذر المستودع (فرع `main`)

## 1. بوابة الترخيص (Remote Kill-Switch) – إعادة بناء

**الملفات:** `lib/services/license_service.dart` (`LicenseGate`, `LicenseStatus`,
`LicenseGateResult`), `lib/screens/license_screen.dart`, `lib/main.dart`

**المشاكل التي كانت في النسخة السابقة:**
| # | المشكلة | الأثر |
|---|---|---|
| 1 | قراءة الملف من `raw.githubusercontent.com` فقط – يمر عبر CDN بكاش 5 دقائق | تغيير `active` لا يظهر مباشرة؛ التطبيق يطلب كوداً رغم أن الملف `true` |
| 2 | الكود المُدخل لا يُخزَّن ("جلسة واحدة") | كل تشغيل يطلب الكود من جديد |
| 3 | لا توجد طريقة لإعادة الفحص من داخل الشاشة | المستخدم مضطر لإغلاق التطبيق |

**التصميم الجديد:**
- `enum LicenseStatus { open, needsCode, revoked }` بدل bool.
- القراءة **أولاً من GitHub REST API** (`/repos/{owner}/{repo}/contents/license.json?ref=main`
  → `content` base64) لأنها تعكس الكوميت الحالي بلا كاش؛ الاحتياط: الملف الخام مع
  معامل `v=<microseconds>` وترويسات `no-cache`.
- الجسم يُفكّ بـ `utf8.decode(bodyBytes)` (تفادي أخطاء Content-Type).
- عميل HTTP ثابت `LicenseGate.http_` قابل للاستبدال في الاختبارات.

| `license.json` | النتيجة |
|---|---|
| `"active": true` | `open` – دخول فوري، يُمسح أي قفل سابق |
| `"active": false` | `needsCode` – يُطلب الكود؛ عند مطابقة `code` يُحفظ في `gate.unlocked_with` ويبقى مفتوحاً ما دام نفس الكود في الملف |
| تغيير `"code"` | يعود `needsCode` |
| حذف الملف/المستودع (404) | `revoked` – إغلاق تام، حقل الكود يختفي |
| بدون إنترنت | آخر حالة محفوظة (`fromCache = true`) |

مفاتيح التخزين: `gate.status`, `gate.message`, `gate.remote_code`, `gate.unlocked_with`.

**الشاشة:** بطاقة داكنة بأيقونة السيارة وشارة قفل، حقل كود بنمط `XXX-0000`،
زر "فتح التطبيق" وزر "تحديث حالة الترخيص" (يعيد `evaluate()`).

## 2. استعادة كلمة المرور – OTP بثلاث مراحل
**الملف:** `lib/screens/auth/forgot_password_screen.dart`

`enum _Stage { email, verify, reset }` مع رأس شرائح (Chips) وتبديل `AnimatedSwitcher`:
1. **البريد** – التحقق من وجوده في SQLite.
2. **التحقق** – رمز **4 أرقام** (`Random.secure`) يُعرض في خانات، صالح **3 دقائق** مع
   عدّاد تنازلي حي (`Timer`)، زر نسخ (`Clipboard`), زر "رمز جديد"، حد **3 محاولات**
   ثم يُلغى الرمز.
3. **كلمة جديدة** – حقلان مع Validation ثم `resetPassword()`.

## 3. أيقونة الإطلاق (Adaptive Icon)
السبب: `ic_launcher.png` كان صورة كاملة بزوايا **بيضاء** على بلاطة داكنة وبدون
`mipmap-anydpi-v26` → أندرويد يعرضها مصغّرة داخل قناع بخلفية غريبة.
الحل: `docs/make_launcher_icons.py` يولّد طبقة خلفية (لون البلاطة `#0C1C2C`)
وطبقة رسم شفافة داخل منطقة الأمان + أيقونات قديمة/دائرية + أيقونات الويب.

## 4. أخرى
- `pubspec.yaml`: تصحيح مسار الأصول `assets/icon/` (كان `assets/icons/` غير موجود).
- الإصدار `1.2.0+6`.

## الاختبارات
`test/gate_and_recovery_test.dart` (5): بوابة الترخيص بأربع حالات (MockClient) +
تدفق OTP الكامل. إجمالي المجموعة: 17 اختباراً – `flutter analyze` بلا ملاحظات.
