#!/usr/bin/env sh
# Release bootstrap. The lifecycle tool is retained in the installation directory.
set -eu
for dependency in docker python3 curl tar; do
  command -v "$dependency" >/dev/null 2>&1 || { printf 'Install %s before running this installer.\n' "$dependency" >&2; exit 1; }
done
docker compose version >/dev/null
VERSION=0.1.0
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT HUP INT TERM
curl --fail --silent --show-error --location "https://github.com/mnkhtrbukhbold/secretpod/archive/refs/tags/v$VERSION.tar.gz" -o "$WORK/source.tar.gz"
tar -xzf "$WORK/source.tar.gz" -C "$WORK"
python3 "$WORK/secretpod-$VERSION/scripts/host.py" setup "$@"
