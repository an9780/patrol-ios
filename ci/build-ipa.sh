#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then brew install xcodegen; fi
xcodebuild -version
xcodegen --version
xcodegen generate --spec project.yml
xcodebuild -list -project PatrolCheckin.xcodeproj
stage="$(mktemp -d)"
out="$PWD/dist"
mkdir -p "$out" "$stage/Payload"
xcodebuild -project PatrolCheckin.xcodeproj -scheme PatrolCheckin \
  -configuration Release -destination 'generic/platform=iOS' -sdk iphoneos \
  -derivedDataPath "$stage/products" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" build
app="$stage/products/Build/Products/Release-iphoneos/PatrolCheckin.app"
info="$app/Info.plist"
plutil -lint "$info"
test "$(plutil -extract CFBundleIdentifier raw "$info")" = "com.patrol.checkin"
test "$(plutil -extract DTPlatformName raw "$info")" = "iphoneos"
exe="$(plutil -extract CFBundleExecutable raw "$info")"
test -x "$app/$exe"
xcrun lipo "$app/$exe" -verify_arch arm64
test -s "$app/Assets.car"
ditto "$app" "$stage/Payload/PatrolCheckin.app"
(cd "$stage" && /usr/bin/zip -qr -y "$stage/current.ipa" Payload)
unzip -tq "$stage/current.ipa"
cp "$stage/current.ipa" "$out/PatrolCheckin-unsigned.ipa"
ditto -c -k --keepParent PatrolCheckin.xcodeproj "$out/XcodeProject.zip"
(cd "$out" && shasum -a 256 PatrolCheckin-unsigned.ipa > SHA256.txt)
git rev-parse HEAD > "$out/commit.txt"

