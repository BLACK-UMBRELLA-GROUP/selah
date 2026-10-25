#!/usr/bin/env bash
# Restricted Selah commands using Flutter's pinned cached snapshot.
set -euo pipefail
unset CDPATH

SELAH_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SELAH_SCRIPT_DIR/flutter_env.sh"

if [[ $# -eq 0 ]]; then
  printf '%s\n' 'Usage: tooling/flutter_cached.sh {analyze|test|pub get --offline} [arguments]' >&2
  exit 2
fi

case "$1" in
  analyze|test)
    has_no_pub=false
    for argument in "$@"; do
      [[ "$argument" == --no-pub ]] && has_no_pub=true
    done
    [[ "$has_no_pub" == true ]] || {
      printf '%s\n' 'Analysis/tests require --no-pub in the bounded cached route.' >&2
      exit 2
    }
    ;;
  pub)
    [[ "${2:-}" == get ]] || {
      printf '%s\n' 'Only pub get --offline is supported.' >&2
      exit 2
    }
    has_offline=false
    for argument in "$@"; do
      [[ "$argument" == --offline ]] && has_offline=true
    done
    [[ "$has_offline" == true ]] || {
      printf '%s\n' 'Dependency preparation must be explicit and offline: pub get --offline.' >&2
      exit 2
    }
    ;;
  *)
    printf '%s\n' 'Command outside Selah cached-tool scope. SDK upgrades, channels and Git operations belong to the Founder.' >&2
    exit 2
    ;;
esac

for argument in "$@"; do
  case "$argument" in
    --version-check|--version-check=*|upgrade|downgrade|channel|precache)
      printf 'Version/update operation refused: %s\n' "$argument" >&2
      exit 2
      ;;
  esac
done

exec "$SELAH_CACHED_DART" "$SELAH_FLUTTER_SNAPSHOT" \
  --no-version-check --suppress-analytics "$@"
