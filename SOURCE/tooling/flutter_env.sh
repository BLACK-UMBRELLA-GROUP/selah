#!/usr/bin/env bash
# Project-local cached tooling only. Never source Flutter's shared.sh.
set -euo pipefail
unset CDPATH

SELAH_TOOLING_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
FLUTTER_ROOT='/opt/homebrew/Caskroom/flutter/3.44.2/flutter'
SELAH_CACHED_DART="$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart"
SELAH_FLUTTER_SNAPSHOT="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"

if [[ ! -x "$SELAH_CACHED_DART" || ! -f "$SELAH_FLUTTER_SNAPSHOT" ]]; then
  printf '%s\n' 'The pinned cached Dart/Flutter snapshot is unavailable. Stop; do not fall back to an SDK wrapper.' >&2
  exit 1
fi

export FLUTTER_ROOT
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
export PUB_ENVIRONMENT=selah_no_git_delivery
"$SELAH_CACHED_DART" "$SELAH_TOOLING_DIR/cached_version.dart" "$FLUTTER_ROOT"
