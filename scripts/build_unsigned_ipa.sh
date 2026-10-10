#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_DIR="$BUILD_DIR/archive"
PACKAGE_DIR="$BUILD_DIR/package"
OUTPUT="$ROOT_DIR/EXTERNAL-unsigned.ipa"

rm -rf "$BUILD_DIR" "$OUTPUT"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project "$ROOT_DIR/ThreeOneOSFive.xcodeproj" \
  -scheme 3105 \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO

APP_PATH="$(find "$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos" -maxdepth 1 -type d -name '*.app' -print -quit)"
if [ -z "$APP_PATH" ]; then
  echo "No .app product was produced" >&2
  exit 1
fi

mkdir -p "$PACKAGE_DIR/Payload"
cp -R "$APP_PATH" "$PACKAGE_DIR/Payload/"
(cd "$PACKAGE_DIR" && /usr/bin/zip -qry "$OUTPUT" Payload)

/usr/bin/unzip -l "$OUTPUT" | sed -n '1,80p'
printf '\nCreated: %s\n' "$OUTPUT"
