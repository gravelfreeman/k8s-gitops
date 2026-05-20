#!/bin/sh
set -eu

payload="$(printf \
  'json={"announce_port":%s,"reannounce_when_address_changed":true}' \
  "${EXTERNAL_PORT}" \
)"

curl -fs --max-time 10 \
  --data "${payload}" \
  "${TARGET_URL}/api/v2/app/setPreferences" \
  >/dev/null

curl -fs --max-time 10 \
  --data "hashes=all" \
  "${TARGET_URL}/api/v2/torrents/reannounce" \
  >/dev/null || true

printf '%s [handler:qbittorrent] slot %s: synced announce_port=%s at %s\n' \
  "$(date -Iseconds)" \
  "${SLOT}" \
  "${EXTERNAL_PORT}" \
  "${TARGET_URL}"
