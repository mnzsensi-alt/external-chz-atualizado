#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v xcodebuild >/dev/null || { echo 'É necessário macOS com Xcode e ferramentas de linha de comando.'; exit 1; }
PROJECT="$PWD/projeto-ios/ThreeOneOSFive.xcodeproj"
SCHEME=$(xcodebuild -list -json -project "$PROJECT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["project"]["schemes"][0])')
mkdir -p build dist
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -sdk iphoneos -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$PWD/build/inject-chz-sem-api.xcarchive" archive \
  LIBRARY_SEARCH_PATHS="$PWD/projeto-ios/ThreeOneOSFive/SDK" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO MARKETING_VERSION=2026.10.07 \
  CURRENT_PROJECT_VERSION="$(date +%Y%m%d).${GITHUB_RUN_NUMBER:-1}" \
  SWIFT_OPTIMIZATION_LEVEL=-O STRIP_INSTALLED_PRODUCT=YES COPY_PHASE_STRIP=YES \
  DEAD_CODE_STRIPPING=YES GCC_GENERATE_DEBUGGING_SYMBOLS=NO
APP=$(find build/inject-chz-sem-api.xcarchive/Products/Applications -maxdepth 1 -type d -name '*.app' -print -quit)
test -n "$APP"
mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry "$OLDPWD/dist/inject-chz-sem-api.ipa" Payload)
test -s dist/inject-chz-sem-api.ipa
echo "IPA não assinada gerada em: $PWD/dist/inject-chz-sem-api.ipa"
