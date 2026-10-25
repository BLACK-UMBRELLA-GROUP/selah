#!/usr/bin/env bash
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
# Project-local Xcode entry point: raw cached Dart, never Flutter's shell wrappers.
set -euo pipefail
unset CDPATH

SELAH_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SELAH_SCRIPT_DIR/flutter_env.sh"
exec "$SELAH_CACHED_DART" "$SELAH_SCRIPT_DIR/xcode_backend.dart" "$@" ios
