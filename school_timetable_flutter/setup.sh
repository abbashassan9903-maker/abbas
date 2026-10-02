#!/usr/bin/env bash
# يهيّئ مشروع Flutter كاملاً (أندرويد + iOS) ويضع ملفات البرنامج فيه.
set -e
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "Flutter غير مثبت. ثبّته من https://docs.flutter.dev/get-started/install"; exit 1; }

if [ ! -d android ]; then
  flutter create --project-name school_timetable --org iq.tqadum --platforms=android,ios .
fi
cp -f template/pubspec.yaml pubspec.yaml
mkdir -p lib assets
cp -f template/lib/main.dart lib/main.dart
cp -f template/assets/app.html assets/app.html

# اسم التطبيق على الهاتف + الحد الأدنى لإصدار أندرويد
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i.bak 's/android:label="[^"]*"/android:label="جدول الحصص"/' "$MANIFEST" && rm -f "$MANIFEST.bak"
for g in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$g" ]; then sed -i.bak -E 's/minSdk(Version)?( =|) *flutter\.minSdkVersion/minSdk\1\2 24/' "$g"; rm -f "$g.bak"; fi
done
# iOS
if [ -f ios/Runner/Info.plist ]; then sed -i.bak 's#<string>School Timetable</string>#<string>جدول الحصص</string>#' ios/Runner/Info.plist; rm -f ios/Runner/Info.plist.bak; fi

flutter pub get
echo
echo "تم التجهيز. الآن:"
echo "  flutter run                      # تشغيل على هاتف موصول"
echo "  flutter build apk --release      # بناء ملف APK  → build/app/outputs/flutter-apk/app-release.apk"
echo "  flutter build appbundle          # بناء AAB لمتجر Google Play"
