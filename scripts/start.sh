#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
case "${1:-}" in
  ''|--skip-build) ;;
  *) printf 'Usage: sh scripts/start.sh [--skip-build]\n' >&2; exit 1 ;;
esac
if [ "$#" -gt 1 ]; then printf 'Usage: sh scripts/start.sh [--skip-build]\n' >&2; exit 1; fi
for tool in flutter dart; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing %s. Install Flutter 3.47.7 (includes Dart 3.13.5) and add its bin directory to PATH. See docs/development.md.\n' "$tool" >&2
    exit 1
  fi
done
export PUB_CACHE="${PUB_CACHE:-$ROOT/.cache/pub}"
APP="$ROOT/secretpod/secretpod_server/web/app"
if [ "${1:-}" = '--skip-build' ]; then
  for asset in index.html main.dart.js flutter_bootstrap.js; do
    if [ ! -f "$APP/$asset" ]; then
      printf 'No complete web build exists. Run sh scripts/start.sh without --skip-build first.\n' >&2
      exit 1
    fi
  done
fi
export SECRETPOD_DATA_DIR="${SECRETPOD_DATA_DIR:-${PODVAULT_DATA_DIR:-$ROOT/secretpod/secretpod_server/data}}"
case "$SECRETPOD_DATA_DIR" in /*) ;; *) SECRETPOD_DATA_DIR="$PWD/$SECRETPOD_DATA_DIR" ;; esac
export SECRETPOD_MASTER_KEY="${SECRETPOD_MASTER_KEY:-${PODVAULT_MASTER_KEY:-}}"
if [ -z "${SECRETPOD_MASTER_KEY:-}" ]; then
  if [ ! -f "$ROOT/.env" ]; then
    if [ -e "$SECRETPOD_DATA_DIR/vault.sqlite" ] || [ -e "$SECRETPOD_DATA_DIR/vault.json" ]; then
      printf 'An existing vault has no configured master key. Restore its matching .env or set SECRETPOD_MASTER_KEY; a replacement key cannot decrypt existing data.\n' >&2
      exit 1
    fi
    if ! command -v openssl >/dev/null 2>&1; then
      printf 'OpenSSL is required to generate the first master key. Install it or supply SECRETPOD_MASTER_KEY.\n' >&2
      exit 1
    fi
    umask 077
    new_key=$(openssl rand -base64 32) || exit 1
    printf 'SECRETPOD_MASTER_KEY=%s\n' "$new_key" > "$ROOT/.env"
    unset new_key
    printf 'Created the local master key in .env. Keep this file with your backups.\n'
  fi
  SECRETPOD_MASTER_KEY=$(sed -n 's/^SECRETPOD_MASTER_KEY=//p' "$ROOT/.env" | head -n 1 | tr -d '\r')
  if [ -z "$SECRETPOD_MASTER_KEY" ]; then
    SECRETPOD_MASTER_KEY=$(sed -n 's/^PODVAULT_MASTER_KEY=//p' "$ROOT/.env" | head -n 1 | tr -d '\r')
  fi
  if [ -z "$SECRETPOD_MASTER_KEY" ]; then
    printf 'The .env file does not contain SECRETPOD_MASTER_KEY.\n' >&2
    exit 1
  fi
  export SECRETPOD_MASTER_KEY
fi
cd "$ROOT/secretpod"
if ! flutter pub get; then
  printf 'Dependency installation failed. Check your Flutter version and network connection; see docs/development.md.\n' >&2
  exit 1
fi
if [ "${1:-}" != '--skip-build' ]; then
  cd "$ROOT/secretpod/secretpod_flutter"
  flutter build web --no-web-resources-cdn
  # Replace only the generated app, after the new build succeeds.
  [ "$APP" = "$ROOT/secretpod/secretpod_server/web/app" ] || exit 1
  rm -rf -- "$APP"
  mkdir -p "$APP"
  cp -R build/web/. "$APP/"
fi
cd "$ROOT/secretpod/secretpod_server"
printf 'SecretPod: http://localhost:%s - press Ctrl+C to stop.\n' "${SERVERPOD_WEB_SERVER_PORT:-8082}"
exec dart run bin/main.dart --mode development
