#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 rickytheoldtree
#
# SPDX-License-Identifier: AGPL-3.0-only

set -Eeuo pipefail
umask 022

readonly ROOT=/srv/pokerogue
readonly RELEASES="$ROOT/releases"
readonly INCOMING="$ROOT/incoming"
readonly KEEP_RELEASES=5

sha="${1:-}"
source_path="${2:-}"

if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Invalid commit SHA: $sha" >&2
  exit 2
fi

expected_archive="$INCOMING/$sha.tar.gz"
expected_directory="$INCOMING/release-$sha"
if [[ "$source_path" != "$expected_archive" ]] && [[ "$source_path" != "$expected_directory" ]]; then
  echo "Unexpected release source: $source_path" >&2
  exit 2
fi

mkdir -p "$RELEASES" "$INCOMING"
exec 9>"$ROOT/.deploy.lock"
flock -n 9 || {
  echo "Another deployment is already running" >&2
  exit 3
}

release="$RELEASES/$sha"
staging="$INCOMING/.release-$sha-$$"
archive_listing="$INCOMING/.archive-$sha-$$.txt"

cleanup() {
  rm -rf -- "$staging"
  rm -f -- "$archive_listing"
}
trap cleanup EXIT

if [[ ! -d "$release" ]]; then
  if [[ "$source_path" == "$expected_directory" ]]; then
    [[ -d "$source_path" ]] || {
      echo "Release directory not found: $source_path" >&2
      exit 4
    }
    staging="$source_path"
  else
    [[ -f "$source_path" ]] || {
      echo "Release archive not found: $source_path" >&2
      exit 4
    }

    tar -tzf "$source_path" > "$archive_listing"
    if grep -Eq '(^/|(^|/)\.\.(/|$))' "$archive_listing"; then
      echo "Unsafe path found in release archive" >&2
      exit 5
    fi

    mkdir -p "$staging"
    tar -xzf "$source_path" -C "$staging"
  fi

  [[ -f "$staging/index.html" ]] || {
    echo "Release is missing index.html" >&2
    exit 6
  }
  [[ -f "$staging/release.json" ]] || {
    echo "Release is missing release.json" >&2
    exit 6
  }
  chmod -R u=rwX,go=rX "$staging"
  mv "$staging" "$release"
elif [[ "$source_path" == "$expected_directory" ]]; then
  rm -rf -- "$source_path"
fi

current_target="$(readlink "$ROOT/current" 2>/dev/null || true)"
if [[ "$current_target" =~ ^releases/([0-9a-f]{40})$ ]] && [[ -d "$ROOT/$current_target" ]]; then
  previous_tmp="$ROOT/.previous-$sha-$$"
  ln -s "$current_target" "$previous_tmp"
  mv -Tf "$previous_tmp" "$ROOT/previous"
fi

current_tmp="$ROOT/.current-$sha-$$"
ln -s "releases/$sha" "$current_tmp"
mv -Tf "$current_tmp" "$ROOT/current"
rm -f -- "$expected_archive"

current_sha="$sha"
previous_target="$(readlink "$ROOT/previous" 2>/dev/null || true)"
previous_sha=""
if [[ "$previous_target" =~ ^releases/([0-9a-f]{40})$ ]]; then
  previous_sha="${BASH_REMATCH[1]}"
fi

mapfile -t old_releases < <(
  find "$RELEASES" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' \
    | sort -rn \
    | awk -v keep="$KEEP_RELEASES" 'NR > keep { print $2 }'
)

for old_sha in "${old_releases[@]}"; do
  [[ "$old_sha" =~ ^[0-9a-f]{40}$ ]] || continue
  [[ "$old_sha" != "$current_sha" ]] || continue
  [[ "$old_sha" != "$previous_sha" ]] || continue
  rm -rf -- "$RELEASES/$old_sha"
done

echo "Activated Pokerogue release $sha"
