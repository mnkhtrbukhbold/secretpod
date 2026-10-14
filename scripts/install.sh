#!/usr/bin/env sh
# Release bootstrap. The lifecycle tool is retained in the installation directory.
set -eu
for dependency in docker curl; do
  command -v "$dependency" >/dev/null 2>&1 || { printf 'Install %s before running this installer.\n' "$dependency" >&2; exit 1; }
done
docker compose version >/dev/null
VERSION=0.1.1
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT HUP INT TERM
curl --fail --silent --show-error --location "https://raw.githubusercontent.com/mnkhtrbukhbold/secretpod/v$VERSION/scripts/host.sh" -o "$WORK/host.sh"
sh "$WORK/host.sh" setup "$@"
