#!/usr/bin/env bash
# Selah private Profile-draft delivery. Project-local cached tooling only.
# No SDK wrapper, dependency fetch, provisioning update or device registration.
set -euo pipefail
unset CDPATH

SELAH_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SELAH_DEVICE='00008130-001A2C1E26F8001C'
SELAH_BUNDLE_ID='com.blackumbrella.selah.draft'
SELAH_TEAM_ID='9Y7Z8F36SJ'
SELAH_DISPLAY_NAME='Selah'
SELAH_BUILD_ONLY=false

usage() {
  printf '%s\n' \
    'Usage: ./run.sh [--device PAIRED_DEVICE_ID] [--build-only]' \
    'Builds the Profile Dart layer inside the preserved verified native shell.' \
    'Without --build-only it verifies, installs, launches and post-queries the intended iPhone.'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        printf '%s\n' '--device requires one explicit paired-device ID.' >&2
        exit 2
      fi
      SELAH_DEVICE="$2"
      shift 2
      ;;
    --build-only)
      SELAH_BUILD_ONLY=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd -- "$SELAH_PROJECT_ROOT"
unset \
  FLUTTER_ROOT SELAH_FLUTTER_ROOT FLUTTER_ENGINE LOCAL_ENGINE LOCAL_ENGINE_HOST \
  FLUTTER_BUILD_MODE FLUTTER_TARGET DART_DEFINES FLAVOR PACKAGE_CONFIG \
  EXTRA_FRONT_END_OPTIONS EXTRA_GEN_SNAPSHOT_OPTIONS SPLIT_DEBUG_INFO \
  PERFORMANCE_MEASUREMENT_FILE CODE_SIZE_DIRECTORY
source "$SELAH_PROJECT_ROOT/tooling/flutter_env.sh"

"$SELAH_CACHED_DART" \
  "$SELAH_PROJECT_ROOT/tooling/delivery_preflight.dart" \
  "$SELAH_PROJECT_ROOT"

delivery_state_hash() {
  /usr/bin/shasum -a 256 \
    "$SELAH_PROJECT_ROOT/pubspec.yaml" \
    "$SELAH_PROJECT_ROOT/pubspec.lock" \
    "$SELAH_PROJECT_ROOT/.dart_tool/package_config.json" \
    "$SELAH_PROJECT_ROOT/ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved" \
    "$FLUTTER_ROOT/bin/cache/flutter.version.json" \
    "$FLUTTER_ROOT/bin/cache/flutter_sdk.stamp" \
    "$FLUTTER_ROOT/bin/cache/ios-sdk.stamp" \
    "$FLUTTER_ROOT/bin/cache/font-subset.stamp" \
    "$FLUTTER_ROOT/bin/cache/material_fonts.stamp" \
    "$FLUTTER_ROOT/bin/cache/gradle_wrapper.stamp" \
    "$FLUTTER_ROOT/packages/flutter_tools/.dart_tool/package_config.json" \
    | /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1
}

source_fingerprint() {
  {
    find \
      "$SELAH_PROJECT_ROOT/lib" \
      "$SELAH_PROJECT_ROOT/assets" \
      "$SELAH_PROJECT_ROOT/ios/Runner" \
      "$SELAH_PROJECT_ROOT/ios/Runner.xcodeproj" \
      -type f -print | LC_ALL=C sort | while IFS= read -r file; do
        /usr/bin/shasum -a 256 "$file"
      done
    /usr/bin/shasum -a 256 \
      "$SELAH_PROJECT_ROOT/pubspec.yaml" \
      "$SELAH_PROJECT_ROOT/pubspec.lock" \
      "$SELAH_PROJECT_ROOT/ios/Flutter/Profile.xcconfig" \
      "$SELAH_PROJECT_ROOT/ios/Flutter/Profile-draft.xcconfig"
  } | /usr/bin/shasum -a 256 | /usr/bin/cut -d ' ' -f 1
}

SELAH_DEPENDENCY_STATE_BEFORE="$(delivery_state_hash)"

"$SELAH_CACHED_DART" \
  "$SELAH_PROJECT_ROOT/tooling/generate_xcode_config.dart" \
  "$SELAH_PROJECT_ROOT" "$FLUTTER_ROOT"

if [[ "$(delivery_state_hash)" != "$SELAH_DEPENDENCY_STATE_BEFORE" ]]; then
  printf '%s\n' 'Dependency state changed during local configuration. Stop; no native build or install was attempted.' >&2
  exit 1
fi

SELAH_LOCAL_DEFINE='U0VMQUhfRFJBRlRfTE9DQUxfT05MWT10cnVl'
if ! /usr/bin/grep -Fq "FLAVOR=draft" ios/Flutter/Generated.xcconfig ||
   ! /usr/bin/grep -Fq "$SELAH_LOCAL_DEFINE" ios/Flutter/Generated.xcconfig ||
   ! /usr/bin/grep -Fq "FLUTTER_TARGET=$SELAH_PROJECT_ROOT/lib/main.dart" ios/Flutter/Generated.xcconfig; then
  printf '%s\n' 'Generated Flutter settings do not identify the isolated Selah draft. No native build was attempted.' >&2
  exit 1
fi

SELAH_SOURCE_FINGERPRINT="$(source_fingerprint)"
SELAH_RECEIPT_ROOT="$SELAH_PROJECT_ROOT/build/selah-delivery-receipts"
/bin/mkdir -p "$SELAH_RECEIPT_ROOT"
SELAH_RECEIPT_DIR="$(/usr/bin/mktemp -d "$SELAH_RECEIPT_ROOT/$(/bin/date -u '+%Y%m%dT%H%M%SZ').XXXXXX")"
SELAH_LAYER_ROOT="$(/usr/bin/mktemp -d "$SELAH_PROJECT_ROOT/build/selah-dart-layer.XXXXXX")"

"$SELAH_PROJECT_ROOT/tooling/dart_layer_delivery.sh" \
  "$SELAH_PROJECT_ROOT" "$SELAH_SOURCE_FINGERPRINT" \
  "$SELAH_RECEIPT_DIR" "$SELAH_LAYER_ROOT"

if [[ "$(delivery_state_hash)" != "$SELAH_DEPENDENCY_STATE_BEFORE" ]]; then
  printf '%s\n' 'Locked dependency state changed during Dart-layer build. No install was attempted.' >&2
  exit 1
fi
"$SELAH_CACHED_DART" \
  "$SELAH_PROJECT_ROOT/tooling/cached_version.dart" "$FLUTTER_ROOT"

if [[ "$(source_fingerprint)" != "$SELAH_SOURCE_FINGERPRINT" ]]; then
  printf '%s\n' 'Source changed during Dart-layer build. No install was attempted.' >&2
  exit 1
fi

SELAH_APP="$SELAH_LAYER_ROOT/Runner.app"
if [[ ! -d "$SELAH_APP" ]] ||
   [[ "$(/usr/libexec/PlistBuddy -c 'Print :SelahSourceFingerprint' "$SELAH_APP/Info.plist" 2>/dev/null || true)" != "$SELAH_SOURCE_FINGERPRINT" ]]; then
  printf '%s\n' 'No newly fingerprinted Selah Profile-draft app was produced. No install was attempted.' >&2
  exit 1
fi

SELAH_BUILT_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SELAH_APP/Info.plist")"
SELAH_BUILT_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$SELAH_APP/Info.plist")"
SELAH_BUILT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SELAH_APP/Info.plist")"
SELAH_BUILT_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SELAH_APP/Info.plist")"
SELAH_BUILT_MODE="$(/usr/libexec/PlistBuddy -c 'Print :SelahDeliveryMode' "$SELAH_APP/Info.plist")"
if [[ "$SELAH_BUILT_BUNDLE_ID" != "$SELAH_BUNDLE_ID" ||
      "$SELAH_BUILT_NAME" != "$SELAH_DISPLAY_NAME" ||
      "$SELAH_BUILT_MODE" != 'profile-draft' ]]; then
  printf '%s\n' 'Built artifact identity verification failed. No install was attempted.' >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict "$SELAH_APP"
/usr/bin/codesign -d --entitlements :- "$SELAH_APP" \
  > "$SELAH_RECEIPT_DIR/artifact-entitlements.plist" 2>/dev/null
# PlistBuddy treats the entitlement name's dots as literal key characters;
# plutil's key-path extractor would instead split them into nested keys.
SELAH_SIGNED_TEAM="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.team-identifier' "$SELAH_RECEIPT_DIR/artifact-entitlements.plist")"
SELAH_SIGNED_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$SELAH_RECEIPT_DIR/artifact-entitlements.plist")"
if [[ "$SELAH_SIGNED_TEAM" != "$SELAH_TEAM_ID" ||
      "$SELAH_SIGNED_APP_ID" != "$SELAH_TEAM_ID.$SELAH_BUNDLE_ID" ]]; then
  printf '%s\n' 'Signed artifact team/application identity does not match Selah. No install was attempted.' >&2
  exit 1
fi

SELAH_PROFILE="$SELAH_APP/embedded.mobileprovision"
if [[ ! -f "$SELAH_PROFILE" ]]; then
  printf '%s\n' 'Signed artifact has no embedded development profile. No install was attempted.' >&2
  exit 1
fi
/usr/bin/security cms -D -i "$SELAH_PROFILE" \
  > "$SELAH_RECEIPT_DIR/embedded-profile.plist" 2>/dev/null
SELAH_PROFILE_TEAM="$(/usr/bin/plutil -extract TeamIdentifier.0 raw -o - "$SELAH_RECEIPT_DIR/embedded-profile.plist")"
SELAH_PROFILE_APP_ID="$(/usr/bin/plutil -extract Entitlements.application-identifier raw -o - "$SELAH_RECEIPT_DIR/embedded-profile.plist")"
if [[ "$SELAH_PROFILE_TEAM" != "$SELAH_TEAM_ID" ]]; then
  printf '%s\n' 'Embedded profile uses the wrong development team. No install was attempted.' >&2
  exit 1
fi
if [[ "$SELAH_PROFILE_APP_ID" != "$SELAH_TEAM_ID.*" &&
      "$SELAH_PROFILE_APP_ID" != "$SELAH_TEAM_ID.$SELAH_BUNDLE_ID" ]]; then
  printf '%s\n' 'Embedded profile does not admit the Selah bundle. No install was attempted.' >&2
  exit 1
fi
/usr/bin/plutil -extract ProvisionedDevices xml1 \
  -o "$SELAH_RECEIPT_DIR/profile-devices.plist" \
  "$SELAH_RECEIPT_DIR/embedded-profile.plist"
if ! /usr/bin/grep -Fq "$SELAH_DEVICE" \
     "$SELAH_RECEIPT_DIR/profile-devices.plist"; then
  printf '%s\n' 'Embedded profile does not contain the intended iPhone. No install was attempted.' >&2
  exit 1
fi

SELAH_ARTIFACT_SHA="$(/usr/bin/shasum -a 256 "$SELAH_APP/Runner" | /usr/bin/cut -d ' ' -f 1)"
printf '%s\n' \
  "artifact=$SELAH_APP" \
  "bundle=$SELAH_BUILT_BUNDLE_ID" \
  "version=$SELAH_BUILT_VERSION ($SELAH_BUILT_NUMBER)" \
  "source_fingerprint=$SELAH_SOURCE_FINGERPRINT" \
  "runner_sha256=$SELAH_ARTIFACT_SHA" \
  > "$SELAH_RECEIPT_DIR/artifact-summary.txt"

if [[ "$SELAH_BUILD_ONLY" == true ]]; then
  printf 'Verified Selah Profile-draft app: %s\n' "$SELAH_APP"
  printf 'Receipt: %s\n' "$SELAH_RECEIPT_DIR"
  exit 0
fi

SELAH_LOCK_JSON="$SELAH_RECEIPT_DIR/device-lock.json"
SELAH_INSTALL_JSON="$SELAH_RECEIPT_DIR/device-install.json"
SELAH_LAUNCH_JSON="$SELAH_RECEIPT_DIR/device-launch.json"
SELAH_APPS_JSON="$SELAH_RECEIPT_DIR/device-apps.json"
SELAH_PROCESSES_JSON="$SELAH_RECEIPT_DIR/device-processes.json"
SELAH_STABLE_PROCESSES_JSON="$SELAH_RECEIPT_DIR/device-processes-stable.json"

/usr/bin/xcrun devicectl device info lockState \
  --device "$SELAH_DEVICE" --timeout 30 --json-output "$SELAH_LOCK_JSON"
"$SELAH_CACHED_DART" "$SELAH_PROJECT_ROOT/tooling/verify_devicectl_receipt.dart" \
  lock "$SELAH_LOCK_JSON"

/usr/bin/xcrun devicectl device install app \
  --device "$SELAH_DEVICE" "$SELAH_APP" --timeout 60 \
  --json-output "$SELAH_INSTALL_JSON"
SELAH_CONTAINER="$("$SELAH_CACHED_DART" \
  "$SELAH_PROJECT_ROOT/tooling/verify_devicectl_receipt.dart" \
  install "$SELAH_INSTALL_JSON" "$SELAH_BUNDLE_ID")"

/usr/bin/xcrun devicectl device process launch \
  --terminate-existing --device "$SELAH_DEVICE" "$SELAH_BUNDLE_ID" \
  --timeout 60 --json-output "$SELAH_LAUNCH_JSON"
SELAH_PID="$("$SELAH_CACHED_DART" \
  "$SELAH_PROJECT_ROOT/tooling/verify_devicectl_receipt.dart" \
  launch "$SELAH_LAUNCH_JSON" "$SELAH_CONTAINER")"

/usr/bin/xcrun devicectl device info apps \
  --device "$SELAH_DEVICE" --bundle-id "$SELAH_BUNDLE_ID" \
  --timeout 30 --json-output "$SELAH_APPS_JSON"
SELAH_QUERIED_CONTAINER="$("$SELAH_CACHED_DART" \
  "$SELAH_PROJECT_ROOT/tooling/verify_devicectl_receipt.dart" \
  apps "$SELAH_APPS_JSON" "$SELAH_BUNDLE_ID" "$SELAH_DISPLAY_NAME" \
  "$SELAH_BUILT_VERSION" "$SELAH_BUILT_NUMBER")"
if [[ "$SELAH_QUERIED_CONTAINER" != "$SELAH_CONTAINER" ]]; then
  printf '%s\n' 'Installed app query returned a different Selah container.' >&2
  exit 1
fi

/usr/bin/xcrun devicectl device info processes \
  --device "$SELAH_DEVICE" --search "$SELAH_CONTAINER" \
  --timeout 30 --json-output "$SELAH_PROCESSES_JSON"
"$SELAH_CACHED_DART" "$SELAH_PROJECT_ROOT/tooling/verify_devicectl_receipt.dart" \
  processes "$SELAH_PROCESSES_JSON" "$SELAH_CONTAINER" "$SELAH_PID"

# A launch receipt alone cannot distinguish a healthy first frame from an app
# that remains on its native storyboard until the iOS watchdog terminates it.
# Re-query after that failure window before recording launch verification.
/bin/sleep 22
/usr/bin/xcrun devicectl device info processes \
  --device "$SELAH_DEVICE" --search "$SELAH_CONTAINER" \
  --timeout 30 --json-output "$SELAH_STABLE_PROCESSES_JSON"
"$SELAH_CACHED_DART" "$SELAH_PROJECT_ROOT/tooling/verify_devicectl_receipt.dart" \
  processes "$SELAH_STABLE_PROCESSES_JSON" "$SELAH_CONTAINER" "$SELAH_PID"

printf '%s\n' \
  "device=$SELAH_DEVICE" \
  "container=$SELAH_CONTAINER" \
  "pid=$SELAH_PID" \
  'install=verified' \
  'launch=verified' \
  'launch_stability_22s=verified' \
  'post_query=verified' \
  >> "$SELAH_RECEIPT_DIR/artifact-summary.txt"

printf 'Selah %s (%s) installed and launched on %s.\n' \
  "$SELAH_BUILT_VERSION" "$SELAH_BUILT_NUMBER" "$SELAH_DEVICE"
printf 'Receipt: %s\n' "$SELAH_RECEIPT_DIR"
