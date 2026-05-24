@echo off
title Notenleser APK Build

set "FLUTTER_BIN=C:\Users\gollu\.puro\envs\stable\flutter\bin"
set "ANDROID_SDK_ROOT=C:\Users\gollu\AppData\Local\Android\Sdk"
set "PATH=%FLUTTER_BIN%;%PATH%"

cd /d "%~dp0android-app"

echo Baue APK...
flutter build apk --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FEHLGESCHLAGEN.
    pause
    exit /b 1
)

echo.
echo APK fertig: build\app\outputs\flutter-apk\app-release.apk
explorer build\app\outputs\flutter-apk
pause
