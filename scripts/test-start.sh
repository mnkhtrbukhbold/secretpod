#!/usr/bin/env sh
# Exercise the real launcher with fake external tools; never starts a server.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM
mkdir -p "$TEST_ROOT/tools"
cat > "$TEST_ROOT/tools/flutter" <<'EOF'
#!/usr/bin/env sh
set -eu
if [ "$1" = pub ]; then
  [ "${DEPENDENCY_FAILURE:-0}" = 0 ] || exit 1
  touch "$FIXTURE/dependencies-installed"
elif [ "$1" = build ]; then
  mkdir -p build/web
  for asset in index.html main.dart.js flutter_bootstrap.js; do printf 'new-build\n' > "build/web/$asset"; done
else
  exit 1
fi
EOF
cat > "$TEST_ROOT/tools/dart" <<'EOF'
#!/usr/bin/env sh
set -eu
[ "$1" = run ]
[ -f "$FIXTURE/dependencies-installed" ] || { printf 'Server launched without installing dependencies.\n' >&2; exit 1; }
touch "$FIXTURE/server-started"
EOF
chmod +x "$TEST_ROOT/tools/flutter" "$TEST_ROOT/tools/dart"
export PATH="$TEST_ROOT/tools:$PATH"
export FIXTURE="$TEST_ROOT/project"
mkdir -p "$FIXTURE/scripts" "$FIXTURE/secretpod/secretpod_server/web/app" "$FIXTURE/secretpod/secretpod_flutter"
cp "$ROOT/scripts/start.sh" "$FIXTURE/scripts/start.sh"
unset SECRETPOD_MASTER_KEY PODVAULT_MASTER_KEY PODVAULT_DATA_DIR
export PUB_CACHE="$FIXTURE/custom-cache" SECRETPOD_DATA_DIR="$FIXTURE/custom-data"
mkdir -p "$SECRETPOD_DATA_DIR"
printf 'preserve\n' > "$SECRETPOD_DATA_DIR/sentinel"
for asset in index.html main.dart.js flutter_bootstrap.js; do printf 'old\n' > "$FIXTURE/secretpod/secretpod_server/web/app/$asset"; done
printf 'SECRETPOD_MASTER_KEY=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n' > "$FIXTURE/.env"
cp "$FIXTURE/.env" "$TEST_ROOT/original-env"
sh "$FIXTURE/scripts/start.sh" --skip-build
cmp "$FIXTURE/.env" "$TEST_ROOT/original-env"
[ "$(cat "$SECRETPOD_DATA_DIR/sentinel")" = preserve ]
printf 'PASS: skip installs dependencies and preserves key/data\n'
rm "$FIXTURE/secretpod/secretpod_server/web/app/index.html" "$FIXTURE/server-started"
if sh "$FIXTURE/scripts/start.sh" --skip-build > "$TEST_ROOT/output" 2>&1; then exit 1; fi
[ ! -f "$FIXTURE/server-started" ]
grep -q 'build' "$TEST_ROOT/output"
printf 'PASS: skip rejects missing build\n'
printf 'stale\n' > "$FIXTURE/secretpod/secretpod_server/web/app/obsolete.js"
sh "$FIXTURE/scripts/start.sh"
[ ! -f "$FIXTURE/secretpod/secretpod_server/web/app/obsolete.js" ]
[ "$(cat "$FIXTURE/secretpod/secretpod_server/web/app/index.html")" = new-build ]
cmp "$FIXTURE/.env" "$TEST_ROOT/original-env"
printf 'PASS: rebuild removes stale assets and preserves key\n'
rm "$FIXTURE/server-started"
if DEPENDENCY_FAILURE=1 sh "$FIXTURE/scripts/start.sh" --skip-build > "$TEST_ROOT/output" 2>&1; then exit 1; fi
[ ! -f "$FIXTURE/server-started" ]
grep -q 'Dependency' "$TEST_ROOT/output"
printf 'PASS: dependency failure stops startup\n'
rm "$FIXTURE/.env"
printf 'synthetic-fixture\n' > "$SECRETPOD_DATA_DIR/vault.sqlite"
if sh "$FIXTURE/scripts/start.sh" --skip-build > "$TEST_ROOT/output" 2>&1; then exit 1; fi
[ ! -f "$FIXTURE/.env" ]
[ ! -f "$FIXTURE/server-started" ]
printf 'PASS: existing vault never receives a replacement key\n'
if sh "$FIXTURE/scripts/start.sh" --unknown > "$TEST_ROOT/output" 2>&1; then exit 1; fi
grep -q 'Usage:' "$TEST_ROOT/output"
printf 'PASS: unknown arguments fail\n'
