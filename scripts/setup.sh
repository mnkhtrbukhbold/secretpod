#!/usr/bin/env sh
set -eu
command -v python3 >/dev/null 2>&1 || { echo 'Install Python 3.10 or newer, then retry.' >&2; exit 1; }
exec python3 "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/host.py" setup "$@"
