@echo off
chcp 65001 >nul
cd /d "%~dp0"
where flutter >nul 2>nul || (echo Flutter غير مثبت. ثبّته من https://docs.flutter.dev/get-started/install & exit /b 1)
if not exist android flutter create --project-name school_timetable --org iq.tqadum --platforms=android,ios .
copy /Y template\pubspec.yaml pubspec.yaml
if not exist lib mkdir lib
if not exist assets mkdir assets
copy /Y template\lib\main.dart lib\main.dart
copy /Y template\assets\app.html assets\app.html
powershell -NoProfile -Command "$m='android/app/src/main/AndroidManifest.xml'; (Get-Content $m -Raw -Encoding UTF8) -replace 'android:label=\"[^\"]*\"','android:label=\"جدول الحصص\"' | Set-Content $m -Encoding UTF8; foreach($g in 'android/app/build.gradle','android/app/build.gradle.kts'){ if(Test-Path $g){ (Get-Content $g -Raw) -replace 'flutter\.minSdkVersion','24' | Set-Content $g } }"
call flutter pub get
echo.
echo تم التجهيز. الآن:
echo   flutter run
echo   flutter build apk --release
