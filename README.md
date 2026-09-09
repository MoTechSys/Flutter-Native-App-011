# CarCare — كار كير

سجل السيارة الذكي: إدارة الزيت، الإطارات، البطارية، الصيانة الدورية، استهلاك الوقود وتاريخ الإصلاحات.

**الحزمة:** `com.carcare.maintenance` · **الإصدار الحالي:** 1.2.0 (build 6) · Flutter 3.35.4

**📱 آخر APK جاهز للتثبيت:** [`releases/CarCare-v1.2.0.apk`](releases/CarCare-v1.2.0.apk)
**🛠 كيف تبني APK بنفسك:** [`BUILD_GUIDE.md`](BUILD_GUIDE.md)
**📓 سجل التطوير والقرارات:** [`docs/SESSION_LOG.md`](docs/SESSION_LOG.md)

## الأدوار
- **مستخدم واحد لكل حساب**: يسجّل سيارته ويتابع الزيت والإطارات والبطارية والصيانة الدورية والوقود والإصلاحات، مع إضافة/تعديل/حذف كل سجل وشاشة تفاصيل.

## التشغيل السريع
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

## التحكم عن بُعد
`license.json` في جذر هذا المستودع يتحكم في التطبيق عند كل تشغيل (`active: true/false` + `code`؛ حذف الملف = قفل نهائي). التفاصيل في `BUILD_GUIDE.md` §6.
