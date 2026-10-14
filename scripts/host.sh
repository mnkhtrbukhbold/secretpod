#!/usr/bin/env sh
# The manager contains Python and Compose; the host needs only Docker.
set -eu
umask 077
IMAGE=${SECRETPOD_MANAGER_IMAGE:-ghcr.io/mnkhtrbukhbold/secretpod-manager:0.1.1}
command -v docker >/dev/null 2>&1 || { echo 'Install Docker with Compose v2 first.' >&2; exit 1; }
operation=${1:-help}
if [ "$#" -gt 0 ]; then shift; fi
case "$operation" in
  setup|up|stop|status|backup|restore|upgrade|trust-cert) ;;
  help|--help|-h) echo 'Usage: host.sh setup|up|stop|status|backup|restore|upgrade|trust-cert [--dir PATH] [--url URL] [--image IMAGE] [--http-port PORT] [--backup PATH] [--no-pull]'; exit 0 ;;
  *) echo "Unknown operation: $operation" >&2; exit 1 ;;
esac
install_dir=$HOME/secretpod
backup_dir= url= app_image= port= no_pull=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-pull) no_pull=1; shift; continue ;;
    --dir|--backup|--url|--image|--http-port)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "Missing value for $1" >&2; exit 1; } ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  case "$1" in
    --dir) install_dir=$2 ;; --backup) backup_dir=$2 ;; --url) url=$2 ;;
    --image) app_image=$2 ;; --http-port) port=$2 ;;
  esac
  shift 2
done
case "$operation" in backup|restore) [ -n "$backup_dir" ] || { echo '--backup is required.' >&2; exit 1; } ;; esac
endpoint=${DOCKER_HOST:-$(docker context inspect --format '{{.Endpoints.docker.Host}}')}
case "$endpoint" in unix://*) socket=${endpoint#unix://} ;; *) echo 'Use a local Docker Engine or Docker Desktop context.' >&2; exit 1 ;; esac
[ "$(docker info --format '{{.OSType}}')" = linux ] || { echo 'Switch Docker to Linux containers.' >&2; exit 1; }
docker compose version >/dev/null
desktop=$(docker info --format '{{.OperatingSystem}}')
case "$desktop" in *'Docker Desktop'*) socket=/var/run/docker.sock; socket_gid=0 ;;
  *) socket_gid=$(stat -c %g "$socket" 2>/dev/null || stat -f %g "$socket") ;;
esac
# Parents must exist. Resolve them physically, but never adopt a linked target.
absolute_path() {
  case "$1" in *,*|*'
'*) echo 'Paths cannot contain commas or newlines.' >&2; exit 1 ;; esac
  [ ! -L "$1" ] || { echo 'Symbolic-link destinations are not supported.' >&2; exit 1; }
  parent=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd -P)
  leaf=$(basename -- "$1")
  case "$leaf" in .|..|/) echo 'Choose a dedicated installation or backup directory.' >&2; exit 1 ;; esac
  printf '%s/%s\n' "$parent" "$leaf"
}
install_dir=$(absolute_path "$install_dir")
# A same-path parent mount must not hide the manager or its runtime libraries.
case "$(dirname -- "$install_dir")" in
  /|/__secretpod_manager|/__secretpod_manager/*|/usr|/usr/*|/bin|/bin/*|/sbin|/sbin/*|/lib|/lib/*|/lib64|/lib64/*|/etc|/etc/*|/dev|/dev/*|/proc|/proc/*|/sys|/sys/*|/run|/run/*|/var|/var/run|/var/run/*)
    echo 'Choose an installation under your home, /opt, /srv, or another data directory; this parent would hide the manager runtime.' >&2; exit 1 ;;
esac
case "$operation" in
  restore) [ ! -e "$install_dir" ] || { echo 'Restore destination must not exist.' >&2; exit 1; } ;;
  setup) ;;
  *) [ -f "$install_dir/manifest.json" ] || { echo 'Installation manifest not found.' >&2; exit 1; } ;;
esac
if [ -n "$backup_dir" ]; then
  backup_dir=$(absolute_path "$backup_dir")
  case "$operation" in
    backup) [ ! -e "$backup_dir" ] || { echo 'Backup destination must not exist.' >&2; exit 1; } ;;
    restore) [ -d "$backup_dir" ] || { echo 'Backup directory not found.' >&2; exit 1; } ;;
  esac
fi
# Create private directories as the invoking user, not as container root.
[ -d "$install_dir" ] || mkdir -m 700 -- "$install_dir"
if [ "$operation" = backup ]; then mkdir -m 700 -- "$backup_dir"; fi
set -- docker run --rm --init --user "$(id -u):$(id -g)" --group-add "$socket_gid" \
  --mount "type=bind,src=$socket,dst=/var/run/docker.sock" \
  --mount "type=bind,src=$(dirname -- "$install_dir"),dst=$(dirname -- "$install_dir")" \
  -e SECRETPOD_MANAGER=1
if [ -n "$backup_dir" ]; then
  readonly=
  if [ "$operation" = restore ]; then readonly=,readonly; fi
  set -- "$@" --mount "type=bind,src=$(dirname -- "$backup_dir"),dst=/backup$readonly" \
    -e "SECRETPOD_DISPLAY_BACKUP_PARENT=$(dirname -- "$backup_dir")"
fi
[ -z "$no_pull" ] || set -- "$@" --pull never
set -- "$@" "$IMAGE" "$operation" --dir "$install_dir"
[ -z "$backup_dir" ] || set -- "$@" --backup "/backup/$(basename -- "$backup_dir")"
[ -z "$url" ] || set -- "$@" --url "$url"
[ -z "$app_image" ] || set -- "$@" --image "$app_image"
[ -z "$port" ] || set -- "$@" --http-port "$port"
[ -z "$no_pull" ] || set -- "$@" --no-pull
if [ -z "$no_pull" ]; then
  case "$operation" in setup|up|restore|upgrade)
    # Credentials stay with the host CLI, including native credential helpers.
    pull_image=$("$@" --print-image)
    if docker pull "$pull_image"; then
      if [ "$operation" != upgrade ]; then docker pull caddy:2.11.2-alpine; fi
      set -- "$@" --no-pull
    else
      case "$pull_image" in
        ghcr.io/mnkhtrbukhbold/secretpod:*) ;; # Manager verifies the public archive fallback.
        *) echo 'Image pull failed. Check your host Docker login and image reference.' >&2; exit 1 ;;
      esac
    fi
  esac
fi
exec "$@"
