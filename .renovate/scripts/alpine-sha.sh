#!/usr/bin/env bash
set -euo pipefail

file="${1:-kubernetes/apps/media/plex/plex/app/config/worker-init.yaml}"
base="https://dl-cdn.alpinelinux.org/alpine/edge"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

while IFS= read -r line; do
  if [[ "$line" =~ ^([[:space:]]*)fetch_pkg[[:space:]]+(main|community)[[:space:]]+([^[:space:]]+\.apk)[[:space:]]+([a-f0-9]{64})$ ]]; then
    indent="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
    pkg="${BASH_REMATCH[3]}"
    url="$base/$repo/x86_64/$pkg"
    sha256="$(curl -fsSL "$url" | sha256sum | awk '{print $1}')"
    printf '%sfetch_pkg %s %s %s\n' "$indent" "$repo" "$pkg" "$sha256" >> "$tmp"
  else
    printf '%s\n' "$line" >> "$tmp"
  fi
done < "$file"

mv "$tmp" "$file"
trap - EXIT
