#!/bin/sh
set -eu

dockerfile="${DOCKERFILE:-Dockerfile}"
nginx_repo="${NGINX_REPO:-https://github.com/nginx/nginx.git}"

output() {
  name="$1"
  value="$2"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$name" "$value" >> "$GITHUB_OUTPUT"
  fi

  printf '%s=%s\n' "$name" "$value"
}

read_arg() {
  name="$1"
  awk -v name="$name" 'index($0, "ARG " name "=") == 1 {
    print substr($0, length(name) + 6)
    exit
  }' "$dockerfile"
}

current_version="$(read_arg NGINX_VERSION)"
current_commit="$(read_arg NGINX_COMMIT)"

if [ -z "$current_version" ]; then
  echo "Unable to read NGINX_VERSION from $dockerfile" >&2
  exit 1
fi

if [ -z "$current_commit" ]; then
  echo "Unable to read NGINX_COMMIT from $dockerfile" >&2
  exit 1
fi

latest="$(
  git ls-remote --tags "$nginx_repo" 'refs/tags/release-*' \
    | awk '
      function newer(a, b,    av, bv, i) {
        split(a, av, ".")
        split(b, bv, ".")
        for (i = 1; i <= 3; i++) {
          av[i] += 0
          bv[i] += 0
          if (av[i] > bv[i]) {
            return 1
          }
          if (av[i] < bv[i]) {
            return 0
          }
        }
        return 0
      }

      $2 ~ /^refs\/tags\/release-[0-9]+\.[0-9]+\.[0-9]+$/ {
        version = $2
        sub(/^refs\/tags\/release-/, "", version)
        if (latest_version == "" || newer(version, latest_version)) {
          latest_version = version
          latest_commit = $1
        }
      }

      END {
        if (latest_version != "") {
          print latest_version " " latest_commit
        }
      }
    '
)"

if [ -z "$latest" ]; then
  echo "Unable to find a release-* NGINX tag in $nginx_repo" >&2
  exit 1
fi

latest_version="${latest%% *}"
latest_commit="${latest#* }"

output old_version "$current_version"
output new_version "$latest_version"
output old_commit "$current_commit"
output new_commit "$latest_commit"

if [ "$current_version" = "$latest_version" ] && [ "$current_commit" = "$latest_commit" ]; then
  output changed false
  echo "NGINX is already up to date: $current_version ($current_commit)"
  exit 0
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

awk -v version="$latest_version" -v commit="$latest_commit" '
  /^ARG NGINX_VERSION=/ {
    print "ARG NGINX_VERSION=" version
    next
  }

  /^ARG NGINX_COMMIT=/ {
    print "ARG NGINX_COMMIT=" commit
    next
  }

  {
    print
  }
' "$dockerfile" > "$tmp_file"
cp "$tmp_file" "$dockerfile"

output changed true
echo "Updated NGINX from $current_version ($current_commit) to $latest_version ($latest_commit)"
