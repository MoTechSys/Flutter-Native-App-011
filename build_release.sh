#!/usr/bin/env bash
# بناء APK موقّع مع تضمين إعدادات SMTP من android/smtp.env (غير مرفوع على GitHub)
set -euo pipefail
cd "$(dirname "$0")"
ENV_FILE="android/smtp.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ لا يوجد $ENV_FILE — انسخ android/smtp.env.example إلى android/smtp.env وضع بيانات البريد."; exit 1
fi
set -a; source <(sed 's/\r$//' "$ENV_FILE" | grep -E '^[A-Z_]+=' | sed 's/=\(.*\)/="\1"/'); set +a
DEFINES=(--dart-define=SMTP_USER="$SMTP_USER" --dart-define=SMTP_PASS="$SMTP_PASS" --dart-define=SMTP_NAME="${SMTP_NAME:-CarCare}")
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 "${DEFINES[@]}" "$@"
echo "✅ build/app/outputs/flutter-apk/app-release.apk"
