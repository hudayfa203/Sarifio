#!/usr/bin/env bash
# Builds SARIFIO-Android-Test.apk. Needs Flutter (stable) + Android SDK + Java 17.
#   ./tool/build_apk.sh                                  → on-device Test Mode build
#   API_BASE_URL=https://staging-api.sarifio.com ./tool/build_apk.sh   → staging build
set -euo pipefail
cd "$(dirname "$0")/.."
flutter --version

# Generate the standard platform scaffolding once. Existing SARIFIO files
# (manifest, icons, splash, styles, lib/, test/) are never overwritten.
if [ ! -f android/app/build.gradle ] && [ ! -f android/app/build.gradle.kts ]; then
  flutter create --org com.sarifio --project-name sarifio_app --platforms android,ios .
fi

# iOS: single-size app icon from the approved logo package.
if [ -d ios/Runner/Assets.xcassets/AppIcon.appiconset ]; then
  rm -f ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png
  cp -R ios_overlay/Runner/Assets.xcassets/AppIcon.appiconset/. ios/Runner/Assets.xcassets/AppIcon.appiconset/
fi

flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings || echo "::warning::flutter analyze reported issues"
flutter test

DEFINE=()
if [ -n "${API_BASE_URL:-}" ]; then DEFINE=(--dart-define=API_BASE_URL="$API_BASE_URL"); fi
flutter build apk --release "${DEFINE[@]}"

mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/SARIFIO-Android-Test.apk
ls -lh dist/SARIFIO-Android-Test.apk
echo "APK ready: mobile/dist/SARIFIO-Android-Test.apk"
