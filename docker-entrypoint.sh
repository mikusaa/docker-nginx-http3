#!/bin/sh
set -eu

is_positive_integer() {
  case "$1" in
    ''|*[!0-9]*)
      return 1
      ;;
  esac

  [ "$1" -gt 0 ]
}

if [ "$(id -u)" -ne 0 ]; then
  echo "Running as a non-root user; PUID/PGID changes are skipped." >&2
  exec "$@"
fi

if ! is_positive_integer "$PUID"; then
  echo "ERROR: PUID must be a positive integer, got '$PUID'" >&2
  exit 1
fi

if ! is_positive_integer "$PGID"; then
  echo "ERROR: PGID must be a positive integer, got '$PGID'" >&2
  exit 1
fi

current_uid="$(id -u nginx)"
current_gid="$(id -g nginx)"

if [ "$current_gid" != "$PGID" ]; then
  groupmod -o -g "$PGID" nginx
fi

if [ "$current_uid" != "$PUID" ] || [ "$current_gid" != "$PGID" ]; then
  usermod -o -u "$PUID" -g nginx nginx
fi

chown -R nginx:nginx /var/run/nginx /var/cache/nginx

if [ "${1:-}" = "nginx" ]; then
  exec "$@"
fi

exec su-exec nginx "$@"
