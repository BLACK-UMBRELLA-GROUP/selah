#!/usr/bin/env bash
# Static/read-only verification for Selah's project-local delivery chain.
set -euo pipefail
unset CDPATH

SELAH_PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "$SELAH_PROJECT_ROOT"

/bin/bash -n run.sh
/bin/bash -n tooling/flutter_env.sh
/bin/bash -n tooling/flutter_cached.sh
/bin/bash -n tooling/xcode_backend.sh
/bin/bash -n tooling/dart_layer_delivery.sh
/bin/bash -n tooling/no_git/xcrun
/usr/bin/plutil -lint ios/Runner/Info.plist >/dev/null
/usr/bin/plutil -lint ios/Runner.xcodeproj/project.pbxproj >/dev/null
if [[ ! -x tooling/no_git/git || ! -x tooling/no_git/xcrun ]]; then
  printf '%s\n' 'A project-local execution guard is missing or not executable.' >&2
  exit 1
fi
/usr/bin/xmllint --noout \
  ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme \
  ios/Runner.xcodeproj/xcshareddata/xcschemes/draft.xcscheme

if /usr/bin/grep -R -Fq \
  '$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh' \
  ios/Runner.xcodeproj; then
  printf '%s\n' 'SDK Xcode shell wrapper remains referenced.' >&2
  exit 1
fi
if /usr/bin/grep -Eq \
  '(^|[[:space:]])flutter([[:space:]]|$)|allowProvisioningUpdates|allowProvisioningDeviceRegistration' \
  run.sh; then
  printf '%s\n' 'run.sh contains a Flutter wrapper or provisioning-update path.' >&2
  exit 1
fi
for required in \
  'tooling/dart_layer_delivery.sh' \
  'Profile-draft' \
  'com.blackumbrella.selah.draft' \
  '9Y7Z8F36SJ' \
  'SELAH_DRAFT_LOCAL_ONLY=true' \
  'FLUTTER_BUILD_MODE FLUTTER_TARGET DART_DEFINES' \
  'sandbox-exec' \
  'profile_ios_bundle_flutter_assets' \
  'build/ios/iphoneos/Runner.app' \
  'retained-native-shell+raw-profile-dart-layer' \
  'tooling/no_git' \
  'tooling/no_git/xcrun' \
  'GIT_TERMINAL_PROMPT=0' \
  'HTTP_PROXY=http://127.0.0.1:9' \
  'codesign --verify --deep --strict' \
  'devicectl device install app' \
  'devicectl device process launch' \
  'devicectl device info apps' \
  'devicectl device info processes'; do
  if ! /usr/bin/grep -R -Fq "$required" \
       run.sh tooling/dart_layer_delivery.sh ios/Runner.xcodeproj tooling/xcode_backend.sh \
       tooling/generate_xcode_config.dart; then
    printf 'Required delivery control is missing: %s\n' "$required" >&2
    exit 1
  fi
done

source tooling/flutter_env.sh
"$SELAH_CACHED_DART" tooling/delivery_preflight.dart "$SELAH_PROJECT_ROOT"
"$SELAH_CACHED_DART" analyze \
  tooling/cached_version.dart \
  tooling/delivery_preflight.dart \
  tooling/generate_xcode_config.dart \
  tooling/verify_devicectl_receipt.dart \
  tooling/xcode_backend.dart
if /usr/bin/grep -Fq 'build ios' run.sh; then
  printf '%s\n' 'run.sh must not enter Flutter build ios/config-only dependency resolution.' >&2
  exit 1
fi
if /usr/bin/grep -Fq 'xcodebuild' run.sh; then
  printf '%s\n' 'run.sh must not invoke an Xcode project build.' >&2
  exit 1
fi
if ! /usr/bin/grep -Fq '(deny network*)' tooling/dart_layer_delivery.sh ||
   ! /usr/bin/grep -Fq '/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild' tooling/dart_layer_delivery.sh; then
  printf '%s\n' 'Dart-layer sandbox does not fail closed against network/Xcode build access.' >&2
  exit 1
fi
if /usr/bin/grep -Fq 'SELAH_DEVICE_ID' run.sh; then
  printf '%s\n' 'Default phone target must not be inherited from the environment.' >&2
  exit 1
fi
if /usr/bin/grep -Eq '(^|[|[:space:]])assemble([|)])|^[[:space:]]*build\)' \
     tooling/flutter_cached.sh; then
  printf '%s\n' 'The bounded cached wrapper must not expose assemble/build routes.' >&2
  exit 1
fi
printf '%s\n' 'Selah project-local delivery chain: static checks passed.'
