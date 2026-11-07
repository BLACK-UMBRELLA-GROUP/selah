#!/usr/bin/env bash
# Rebuild only Selah's Profile Dart layer, transplant it into the preserved
# signed native shell, then re-sign the staged copy. Never mutates the base.
set -euo pipefail
unset CDPATH

fail() {
  printf 'Selah Dart-layer delivery failed: %s\n' "$1" >&2
  exit 1
}

[[ $# -eq 4 ]] || fail 'usage: dart_layer_delivery.sh PROJECT_ROOT SOURCE_FINGERPRINT RECEIPT_DIR BUILD_ROOT'

SELAH_PROJECT_ROOT="$(cd -- "$1" && pwd -P)"
SELAH_SOURCE_FINGERPRINT="$2"
SELAH_RECEIPT_DIR="$(cd -- "$3" && pwd -P)"
SELAH_LAYER_ROOT="$(cd -- "$4" && pwd -P)"
SELAH_BASE_APP="$SELAH_PROJECT_ROOT/build/ios/iphoneos/Runner.app"
SELAH_ASSEMBLED="$SELAH_LAYER_ROOT/assembled"
SELAH_STAGED_APP="$SELAH_LAYER_ROOT/Runner.app"
SELAH_BASE_APP_BACKUP="$SELAH_LAYER_ROOT/base-App.framework"
SELAH_SIGN_ID="${SELAH_SIGN_ID:?Set SELAH_SIGN_ID to your Apple development signing identity.}"
SELAH_BUNDLE_ID='com.blackumbrella.selah.draft'
SELAH_TEAM_ID="${SELAH_TEAM_ID:?Set SELAH_TEAM_ID to your Apple development team.}"
SELAH_BASE_RUNNER_SHA='88a99a6adb494c48e9053d681ccd4d85d4517bab4d46bb11a017ca3386a124c6'
SELAH_BASE_DART_SHA='9d0c9a9eccdafae33a758c9f4b2f307e10117dcbb51dd3a3d0f3ead04b08ecbe'
SELAH_BASE_INFO_SHA='9c7696ea45803bd687ed40a9467a234f20a483c47c9500abe849b235c8a93fd8'
SELAH_BASE_NATIVE_DIGEST='a104602eb1ae37108f5daf98d6023b4fa332a6c30abb2856852a363fadd5da3c'
SELAH_FLUTTER_ENGINE_SHA='9745a51f5788e5faa565f5285945ede63714e98cc06039d7cb13b5c70be0ad8e'
SELAH_RUNNER_UNSIGNED_SHA='0b29a219c69a869771305adc0bc6e918d3dc0cee804300fd37effbf3db6a40ce'
SELAH_APP_NORMALIZED_SHA='400c857fff7810f582d7b82eb6b6fef45ad54350370edf5232f0810154033bbd'
SELAH_OBJECTIVE_C_NORMALIZED_SHA='2217039d1873d374727fcfa83d94f9203b136c45dda037b933e011027456bcc6'
SELAH_OBJECTIVE_C_INFO_SHA='21eabba1ce090680496e14367008f7952305d214d3828af85e395761384e28b0'

case "$SELAH_RECEIPT_DIR" in
  "$SELAH_PROJECT_ROOT"/build/selah-delivery-receipts/*) ;;
  *) fail 'receipt directory escaped the Selah delivery area' ;;
esac
case "$SELAH_LAYER_ROOT" in
  "$SELAH_PROJECT_ROOT"/build/selah-dart-layer.*) ;;
  *) fail 'build root escaped the Selah Dart-layer staging area' ;;
esac
[[ -d "$SELAH_BASE_APP" && -d "$SELAH_BASE_APP/Frameworks/App.framework" ]] ||
  fail 'reviewed prepared native shell is missing'
[[ ! -e "$SELAH_STAGED_APP" && ! -e "$SELAH_BASE_APP_BACKUP" ]] ||
  fail 'fresh staging root is not empty'
[[ "$SELAH_SOURCE_FINGERPRINT" =~ ^[0-9a-f]{64}$ ]] ||
  fail 'source fingerprint is malformed'
[[ -x "$SELAH_PROJECT_ROOT/tooling/no_git/xcrun" ]] ||
  fail 'the bounded xcrun resolver is missing or not executable'

source "$SELAH_PROJECT_ROOT/tooling/flutter_env.sh"

sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/cut -d ' ' -f 1
}

require_sha() {
  local expected="$1"
  local file="$2"
  [[ -f "$file" ]] || fail "required retained-shell input is missing: $file"
  [[ "$(sha256 "$file")" == "$expected" ]] ||
    fail "retained-shell input drifted; a full native rebuild is required: $file"
}

normalized_macho_sha() {
  local source="$1"
  local output="$2"
  [[ -f "$source" && ! -e "$output" ]] || fail 'normalization requires a fresh disposable copy'
  /bin/cp "$source" "$output"
  /usr/bin/codesign --remove-signature "$output" >/dev/null 2>&1 || fail 'could not strip copied Mach-O signature'
  /usr/bin/python3 "$SELAH_PROJECT_ROOT/tooling/macho_content_digest.py" \
    --expected-size 146192 --normalize-uuid "$output" || fail 'reviewed Mach-O structure changed'
}

unsigned_runner_sha() {
  local source="$1"
  local output="$2"
  [[ -f "$source" && ! -e "$output" ]] ||
    fail 'cannot prepare a fresh signature-independent Runner check'
  /bin/cp "$source" "$output"
  /usr/bin/codesign --remove-signature "$output" >/dev/null 2>&1 ||
    fail "could not remove the copied Runner signature: $source"
  [[ "$(/usr/bin/stat -f '%z' "$output")" == '2826656' ]] ||
    fail 'native Runner Mach-O layout changed'
  sha256 "$output"
}

normalized_app_sha() {
  local source="$1"
  local output="$2"
  [[ -f "$source" && ! -e "$output" ]] || fail 'normalization requires a fresh disposable copy'
  /bin/cp "$source" "$output"
  /usr/bin/codesign --remove-signature "$output" >/dev/null 2>&1 || fail 'could not strip copied Mach-O signature'
  /usr/bin/python3 "$SELAH_PROJECT_ROOT/tooling/macho_content_digest.py" \
    --expected-size 14434488  "$output" || fail 'reviewed Mach-O structure changed'
}

native_digest() {
  local app="$1"
  find "$app" -type f \
    ! -path '*/_CodeSignature/*' \
    ! -path '*/Frameworks/App.framework/*' \
    ! -path "$app/Info.plist" -print0 |
    while IFS= read -r -d '' file; do
      local relative="${file#$app/}"
      printf '%s  %s\n' "$(sha256 "$file")" "$relative"
    done | LC_ALL=C /usr/bin/sort | /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1
}

native_payload_digest() {
  local app="$1"
  find "$app" -type f \
    ! -path '*/_CodeSignature/*' \
    ! -path '*/Frameworks/App.framework/*' \
    ! -path "$app/Info.plist" \
    ! -path "$app/Runner" -print0 |
    while IFS= read -r -d '' file; do
      local relative="${file#$app/}"
      printf '%s  %s\n' "$(sha256 "$file")" "$relative"
    done | LC_ALL=C /usr/bin/sort | /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1
}

retained_inputs_digest() {
  /usr/bin/shasum -a 256 \
    "$SELAH_CACHED_DART" \
    "$SELAH_FLUTTER_SNAPSHOT" \
    "$SELAH_PROJECT_ROOT/tooling/no_git/xcrun" \
    "$SELAH_PROJECT_ROOT/tooling/macho_content_digest.py" \
    "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios-profile/gen_snapshot_arm64" \
    "$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/frontend_server_aot.dart.snapshot" \
    "$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/font-subset" \
    "$SELAH_PROJECT_ROOT/pubspec.yaml" \
    "$SELAH_PROJECT_ROOT/pubspec.lock" \
    "$SELAH_PROJECT_ROOT/.dart_tool/package_config.json" \
    "$SELAH_PROJECT_ROOT/.flutter-plugins-dependencies" \
    "$SELAH_PROJECT_ROOT/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift" \
    "$SELAH_PROJECT_ROOT/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
    "$SELAH_PROJECT_ROOT/ios/Runner/AppDelegate.swift" \
    "$SELAH_PROJECT_ROOT/ios/Runner/GeneratedPluginRegistrant.h" \
    "$SELAH_PROJECT_ROOT/ios/Runner/GeneratedPluginRegistrant.m" \
    "$SELAH_PROJECT_ROOT/ios/Runner/SceneDelegate.swift" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Runner-Bridging-Header.h" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Runner.entitlements" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Info.plist" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Base.lproj/Main.storyboard" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Base.lproj/LaunchScreen.storyboard" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Selah-1024.png" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/Contents.json" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/SelahLaunchWordmark.png" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/SelahLaunchWordmark@2x.png" \
    "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/SelahLaunchWordmark@3x.png" |
    /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1
}

# Pin the actual executables/snapshots used by this exceptional no-Xcode-build
# route, not only the SDK version labels that describe them.
require_sha '3760a76d390be872c4b4a44a5d045f06183bc21b191b98c8f1e26bc9b1d65d20' "$SELAH_CACHED_DART"
require_sha '13abc665bbccfaf78f1357ada1818adf27ed05663a1d3c4519da5b89e3ea0f1a' "$SELAH_FLUTTER_SNAPSHOT"
require_sha 'd34533af4fd0e24526f721694b2d79a474afe62752fb117e93b768e8a6f69120' "$SELAH_PROJECT_ROOT/tooling/no_git/xcrun"
require_sha '94e8eb91c6f0ac4ca9612e6298fd8fb08d445afee53b24155b60a18555b4f54d' "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios-profile/gen_snapshot_arm64"
require_sha 'd560d64f6c5484b234e34aaa5c91d16ef3c028b768f591ae27d33ea98c69f9c3' "$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/frontend_server_aot.dart.snapshot"
require_sha '1b56f94b39506146474a18372137bc948eb8a5cb7fd19a643ea7d0765e0ed386' "$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/font-subset"

require_sha '7067eda658de481ef3d52039009541a20276e38c6793cc66c3594c49fd82f3d9' "$SELAH_PROJECT_ROOT/tooling/macho_content_digest.py"

# These exact inputs produced, or define compatibility with, the retained
# native shell. Any drift stops the transplant instead of guessing ABI safety.
require_sha '5a8423d41b6ef6fea9de02c259cd4dbe5f95fda4f0f0ac20a7ef4c399f72f8f4' "$SELAH_PROJECT_ROOT/pubspec.yaml"
require_sha 'adf4a5d8e8e3e3d9366b0be138f72b6a33564c35dc15e1fce1a585c1638f7ce8' "$SELAH_PROJECT_ROOT/pubspec.lock"
require_sha 'a4ac457d2c63f0c2a0283ea4fbe80ca3caa4b897ff42566c0b67b98c87cf4016' "$SELAH_PROJECT_ROOT/.dart_tool/package_config.json"
require_sha '0ee3c6889e0d9c1234d5612029e6bb42ca7fc70d4e132304389b36caec40cef0' "$SELAH_PROJECT_ROOT/.flutter-plugins-dependencies"
require_sha 'd07ad9434c73235a8156e8bf21be24c85b38510ec14e958b5212dfb6b7e1a929' "$SELAH_PROJECT_ROOT/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
require_sha '50f8d28dd5c6b93cfb1696cc2d27ba5218e634f19bb6708eddeb1f1fead1a762' "$SELAH_PROJECT_ROOT/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved"
require_sha 'e30fec8e7c988f25942f580b77886caaec4e479ac1164e52eb8160b959784dda' "$SELAH_PROJECT_ROOT/ios/Runner/AppDelegate.swift"
require_sha 'a5f88cc6415d2e639d2cb549348b84e02a7fdd0261603b0063abef6fa11f075a' "$SELAH_PROJECT_ROOT/ios/Runner/GeneratedPluginRegistrant.h"
require_sha '3c6859f314e4b898af97986456ef2eb83a31fdc8a281086a7559281bd350f0ab' "$SELAH_PROJECT_ROOT/ios/Runner/GeneratedPluginRegistrant.m"
require_sha 'add68b905971dedfcc0d0b5b7118030de5925ba8c081ad9815463699e3a444ad' "$SELAH_PROJECT_ROOT/ios/Runner/SceneDelegate.swift"
require_sha '1a8d11d01d1cc92c650c9c9ed35299240052d4683a15a719a2315ef44185e074' "$SELAH_PROJECT_ROOT/ios/Runner/Runner-Bridging-Header.h"
require_sha '3f7508bd0620ba4c063f96057f4e3837e4d3643348ef8b81bbb104e7cfdbed4e' "$SELAH_PROJECT_ROOT/ios/Runner/Runner.entitlements"
require_sha '5303948239b1752ec6ef5bd7c6914c48790da895019166fb2bfb200066a2aff5' "$SELAH_PROJECT_ROOT/ios/Runner/Info.plist"
require_sha 'fd367b6c43006d61b730f674970dd48b9f662c8f2264e52ffc1558102a2c9f2d' "$SELAH_PROJECT_ROOT/ios/Runner/Base.lproj/Main.storyboard"
require_sha '50a4033bbf50aa66ff00e578ddc130073c167a0429b8a41e467a90655f90cab1' "$SELAH_PROJECT_ROOT/ios/Runner/Base.lproj/LaunchScreen.storyboard"
require_sha '6c7b1aa108325d655dfe8741e66dc66784d2c3e3e158d567ddfd9a9f525d590f' "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
require_sha '4ed7d2ba6992411572b571e8c39a5d6f4ac49d782a0dd7dcd294f9dd4ebb8dca' "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset/Selah-1024.png"
require_sha 'c3b94ce4029490720ac5f91c5b1e5f79fd80795fd0f0faa932b9642556bfabc3' "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/Contents.json"
require_sha '674f5adc2db889795546883b5329e0792709c57914fcde3312a5ee85de31f378' "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/SelahLaunchWordmark.png"
require_sha 'bb7d4dbee852cae7c21eb4eb3187a38b42865e9d47338d75538ab5985e86a634' "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/SelahLaunchWordmark@2x.png"
require_sha 'f0abee505c39b608d0aa83e45c8e257e34d8e993461b962291aaf75a5557a2f3' "$SELAH_PROJECT_ROOT/ios/Runner/Assets.xcassets/SelahLaunchWordmark.imageset/SelahLaunchWordmark@3x.png"
SELAH_RETAINED_INPUTS_BEFORE="$(retained_inputs_digest)"

require_sha "$SELAH_BASE_RUNNER_SHA" "$SELAH_BASE_APP/Runner"
require_sha "$SELAH_BASE_DART_SHA" "$SELAH_BASE_APP/Frameworks/App.framework/App"
require_sha "$SELAH_BASE_INFO_SHA" "$SELAH_BASE_APP/Info.plist"
require_sha "$SELAH_FLUTTER_ENGINE_SHA" "$SELAH_BASE_APP/Frameworks/Flutter.framework/Flutter"
[[ "$(native_digest "$SELAH_BASE_APP")" == "$SELAH_BASE_NATIVE_DIGEST" ]] ||
  fail 'preserved native shell contents drifted'
SELAH_BASE_NATIVE_PAYLOAD_DIGEST="$(native_payload_digest "$SELAH_BASE_APP")"
/usr/bin/codesign --verify --deep --strict "$SELAH_BASE_APP" ||
  fail 'preserved native shell signature is invalid'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SELAH_BASE_APP/Info.plist")" == "$SELAH_BUNDLE_ID" ]] ||
  fail 'preserved native shell has the wrong bundle identifier'
[[ "$(/usr/bin/security find-identity -v -p codesigning)" == *"$SELAH_SIGN_ID"* ]] ||
  fail 'the exact retained development signing identity is unavailable'

SELAH_ENTITLEMENTS="$SELAH_RECEIPT_DIR/base-entitlements.plist"
/usr/bin/codesign -d --entitlements :- "$SELAH_BASE_APP" > "$SELAH_ENTITLEMENTS" 2>/dev/null
/usr/bin/plutil -lint "$SELAH_ENTITLEMENTS" >/dev/null
[[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.team-identifier' "$SELAH_ENTITLEMENTS")" == "$SELAH_TEAM_ID" ]] ||
  fail 'base app entitlement team does not match Selah'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$SELAH_ENTITLEMENTS")" == "$SELAH_TEAM_ID.$SELAH_BUNDLE_ID" ]] ||
  fail 'base app application identifier does not match Selah'

SELAH_SDKROOT="$(/usr/bin/xcrun --sdk iphoneos --show-sdk-path)"
[[ -d "$SELAH_SDKROOT" ]] || fail 'the prepared iPhoneOS SDK is unavailable'
[[ "$SELAH_SDKROOT" == '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.2.sdk' ]] ||
  fail 'the iPhoneOS SDK changed from the retained native shell toolchain'
SELAH_DART_DEFINES='U0VMQUhfRFJBRlRfTE9DQUxfT05MWT10cnVl,RkxVVFRFUl9BUFBfRkxBVk9SPWRyYWZ0,RkxVVFRFUl9WRVJTSU9OPTMuNDQuMg==,RkxVVFRFUl9DSEFOTkVMPXN0YWJsZQ==,RkxVVFRFUl9HSVRfVVJMPWh0dHBzOi8vZ2l0aHViLmNvbS9mbHV0dGVyL2ZsdXR0ZXIuZ2l0,RkxVVFRFUl9GUkFNRVdPUktfUkVWSVNJT049YzlhNmM0ODQyMw==,RkxVVFRFUl9FTkdJTkVfUkVWSVNJT049NzdlMmU5NDc3Mg==,RkxVVFRFUl9EQVJUX1ZFUlNJT049My4xMi4y'
/bin/mkdir -p "$SELAH_ASSEMBLED"
SELAH_SANDBOX_TMP="$SELAH_LAYER_ROOT/tmp"
/bin/mkdir -p "$SELAH_SANDBOX_TMP"

# Kernel-enforced network denial plus explicit Git/xcodebuild execution denial.
# The raw cached assemble target compiles only App.framework and its assets.
SELAH_SANDBOX="(version 1)
(allow default)
(deny network*)
(deny process-exec
  (literal \"/usr/bin/git\")
  (literal \"/opt/homebrew/bin/git\")
  (literal \"/Applications/Xcode.app/Contents/Developer/usr/bin/git\")
  (literal \"$SELAH_PROJECT_ROOT/tooling/no_git/git\")
  (literal \"/usr/bin/xcodebuild\")
  (literal \"/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild\"))"

PATH="$SELAH_PROJECT_ROOT/tooling/no_git:/usr/bin:/bin:/usr/sbin:/sbin" \
GIT_TERMINAL_PROMPT=0 \
GIT_CONFIG_NOSYSTEM=1 \
GIT_CONFIG_GLOBAL=/dev/null \
HTTP_PROXY=http://127.0.0.1:9 \
HTTPS_PROXY=http://127.0.0.1:9 \
ALL_PROXY=socks5://127.0.0.1:9 \
NO_PROXY=localhost,127.0.0.1 \
/usr/bin/sandbox-exec -p "$SELAH_SANDBOX" \
  /usr/bin/env -i \
    FLUTTER_ROOT="$FLUTTER_ROOT" \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    DART_SUPPRESS_ANALYTICS=true \
    PUB_ENVIRONMENT=selah_no_git_dart_layer \
    PATH="$SELAH_PROJECT_ROOT/tooling/no_git:/usr/bin:/bin:/usr/sbin:/sbin" \
    HOME=/Users/shakeelahmad \
    TMPDIR="$SELAH_SANDBOX_TMP" \
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    LANG=en_US.UTF-8 \
    GIT_TERMINAL_PROMPT=0 \
    GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_GLOBAL=/dev/null \
    HTTP_PROXY=http://127.0.0.1:9 \
    HTTPS_PROXY=http://127.0.0.1:9 \
    ALL_PROXY=socks5://127.0.0.1:9 \
    NO_PROXY=localhost,127.0.0.1 \
    "$SELAH_CACHED_DART" "$SELAH_FLUTTER_SNAPSHOT" \
      --no-version-check --suppress-analytics assemble \
      --no-version-check \
      --output="$SELAH_ASSEMBLED/" \
      -dTargetPlatform=ios \
      -dTargetFile="$SELAH_PROJECT_ROOT/lib/main.dart" \
      -dBuildMode=profile \
      -dFlavor=draft \
      -dConfiguration=Profile-draft \
      -dIosArchs=arm64 \
      -dSdkRoot="$SELAH_SDKROOT" \
      -dSplitDebugInfo= \
      -dTreeShakeIcons=false \
      -dTrackWidgetCreation=true \
      -dDartObfuscation=false \
      -dAction=build \
      -dFrontendServerStarterPath= \
      --ExtraGenSnapshotOptions= \
      --DartDefines="$SELAH_DART_DEFINES" \
      --ExtraFrontEndOptions= \
      -dSrcRoot="$SELAH_PROJECT_ROOT/ios" \
      -dXcodeBuildScript=build \
      -dTargetDeviceOSVersion= \
      profile_ios_bundle_flutter_assets

[[ -f "$SELAH_ASSEMBLED/App.framework/App" &&
   -f "$SELAH_ASSEMBLED/App.framework/flutter_assets/AssetManifest.bin" ]] ||
  fail 'raw assemble did not produce a complete App.framework'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SELAH_ASSEMBLED/App.framework/Info.plist")" == 'io.flutter.flutter.app' ]] ||
  fail 'assembled framework identifier is wrong'
[[ "$(/usr/bin/lipo -archs "$SELAH_ASSEMBLED/App.framework/App")" == 'arm64' ]] ||
  fail 'assembled App.framework is not arm64-only'
SELAH_NEW_DART_SHA="$(sha256 "$SELAH_ASSEMBLED/App.framework/App")"
SELAH_ASSEMBLED_APP_NORMALIZED="$SELAH_LAYER_ROOT/assembled-App.normalized"
[[ "$(normalized_app_sha "$SELAH_ASSEMBLED/App.framework/App" "$SELAH_ASSEMBLED_APP_NORMALIZED")" == "$SELAH_APP_NORMALIZED_SHA" ]] ||
  fail 'assembled Dart content does not match the reviewed current-source build'
[[ -d "$SELAH_ASSEMBLED/native_assets/objective_c.framework" ]] ||
  fail 'raw assemble did not reproduce the pinned objective_c native asset'
SELAH_NATIVE_ASSET_DIRS="$(find "$SELAH_ASSEMBLED/native_assets" -mindepth 1 -maxdepth 1 -type d -exec /usr/bin/basename {} \; | LC_ALL=C /usr/bin/sort | /usr/bin/tr '\n' ' ')"
if [[ "$SELAH_NATIVE_ASSET_DIRS" != 'objective_c.framework ' &&
      "$SELAH_NATIVE_ASSET_DIRS" != 'objective_c.framework objective_c.framework.dSYM ' ]]; then
  fail "unexpected native assets were generated: $SELAH_NATIVE_ASSET_DIRS"
fi
require_sha "$SELAH_OBJECTIVE_C_INFO_SHA" "$SELAH_ASSEMBLED/native_assets/objective_c.framework/Info.plist"
SELAH_BASE_OBJECTIVE_NORMALIZED="$SELAH_LAYER_ROOT/base-objective_c.normalized"
SELAH_NEW_OBJECTIVE_NORMALIZED="$SELAH_LAYER_ROOT/new-objective_c.normalized"
[[ "$(normalized_macho_sha "$SELAH_BASE_APP/Frameworks/objective_c.framework/objective_c" "$SELAH_BASE_OBJECTIVE_NORMALIZED")" == "$SELAH_OBJECTIVE_C_NORMALIZED_SHA" ]] ||
  fail 'retained objective_c native asset content drifted'
[[ "$(normalized_macho_sha "$SELAH_ASSEMBLED/native_assets/objective_c.framework/objective_c" "$SELAH_NEW_OBJECTIVE_NORMALIZED")" == "$SELAH_OBJECTIVE_C_NORMALIZED_SHA" ]] ||
  fail 'assembled objective_c native asset content drifted'
[[ "$(retained_inputs_digest)" == "$SELAH_RETAINED_INPUTS_BEFORE" ]] ||
  fail 'tool, dependency, plugin or native input changed during raw assemble'

# Clone first, then replace only the cloned App.framework. The known-good base
# remains signed, byte-for-byte guarded and available for rollback/evidence.
/usr/bin/ditto "$SELAH_BASE_APP" "$SELAH_STAGED_APP"
/bin/mv "$SELAH_STAGED_APP/Frameworks/App.framework" "$SELAH_BASE_APP_BACKUP"
/usr/bin/ditto "$SELAH_ASSEMBLED/App.framework" "$SELAH_STAGED_APP/Frameworks/App.framework"
/usr/libexec/PlistBuddy -c 'Set :SelahDeliveryMode profile-draft' "$SELAH_STAGED_APP/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SelahSourceFingerprint $SELAH_SOURCE_FINGERPRINT" "$SELAH_STAGED_APP/Info.plist"
[[ "$(sha256 "$SELAH_STAGED_APP/Runner")" == "$SELAH_BASE_RUNNER_SHA" ]] ||
  fail 'staged native Runner changed before signing'
[[ "$(sha256 "$SELAH_STAGED_APP/Frameworks/App.framework/App")" == "$SELAH_NEW_DART_SHA" ]] ||
  fail 'staged Dart layer does not match assembled output before signing'
[[ "$(native_digest "$SELAH_STAGED_APP")" == "$SELAH_BASE_NATIVE_DIGEST" ]] ||
  fail 'staged native shell changed before signing'

/usr/bin/codesign --force --sign "$SELAH_SIGN_ID" --timestamp=none \
  --identifier io.flutter.flutter.app \
  "$SELAH_STAGED_APP/Frameworks/App.framework"
/usr/bin/codesign --force --sign "$SELAH_SIGN_ID" --timestamp=none \
  --generate-entitlement-der --entitlements "$SELAH_ENTITLEMENTS" \
  "$SELAH_STAGED_APP"
/usr/bin/codesign --verify --deep --strict "$SELAH_STAGED_APP"

require_sha "$SELAH_BASE_RUNNER_SHA" "$SELAH_BASE_APP/Runner"
require_sha "$SELAH_BASE_DART_SHA" "$SELAH_BASE_APP/Frameworks/App.framework/App"
require_sha "$SELAH_BASE_INFO_SHA" "$SELAH_BASE_APP/Info.plist"
require_sha "$SELAH_FLUTTER_ENGINE_SHA" "$SELAH_BASE_APP/Frameworks/Flutter.framework/Flutter"
[[ "$(native_digest "$SELAH_BASE_APP")" == "$SELAH_BASE_NATIVE_DIGEST" ]] ||
  fail 'preserved native shell changed during staging'
SELAH_BASE_RUNNER_UNSIGNED="$SELAH_LAYER_ROOT/base-Runner.normalized"
SELAH_STAGED_RUNNER_UNSIGNED="$SELAH_LAYER_ROOT/staged-Runner.normalized"
[[ "$(unsigned_runner_sha "$SELAH_BASE_APP/Runner" "$SELAH_BASE_RUNNER_UNSIGNED")" == "$SELAH_RUNNER_UNSIGNED_SHA" ]] ||
  fail 'retained native Runner content drifted'
[[ "$(unsigned_runner_sha "$SELAH_STAGED_APP/Runner" "$SELAH_STAGED_RUNNER_UNSIGNED")" == "$SELAH_RUNNER_UNSIGNED_SHA" ]] ||
  fail 'staged native Runner content changed during signing'
[[ "$(native_payload_digest "$SELAH_STAGED_APP")" == "$SELAH_BASE_NATIVE_PAYLOAD_DIGEST" ]] ||
  fail 'content outside App.framework, Info.plist and Runner signature changed'
SELAH_STAGED_APP_NORMALIZED="$SELAH_LAYER_ROOT/staged-App.normalized"
[[ "$(normalized_app_sha "$SELAH_STAGED_APP/Frameworks/App.framework/App" "$SELAH_STAGED_APP_NORMALIZED")" == "$SELAH_APP_NORMALIZED_SHA" ]] ||
  fail 'staged Dart content changed during signing'
[[ "$(retained_inputs_digest)" == "$SELAH_RETAINED_INPUTS_BEFORE" ]] ||
  fail 'retained input changed during staging/signing'

printf '%s\n' \
  'delivery_path=retained-native-shell+raw-profile-dart-layer' \
  "base_app=$SELAH_BASE_APP" \
  "base_runner_sha256=$SELAH_BASE_RUNNER_SHA" \
  "base_app_framework_sha256=$SELAH_BASE_DART_SHA" \
  "new_app_framework_sha256=$SELAH_NEW_DART_SHA" \
  "new_app_framework_normalized_sha256=$SELAH_APP_NORMALIZED_SHA" \
  "staged_app=$SELAH_STAGED_APP" \
  "source_fingerprint=$SELAH_SOURCE_FINGERPRINT" \
  > "$SELAH_RECEIPT_DIR/dart-layer-summary.txt"
