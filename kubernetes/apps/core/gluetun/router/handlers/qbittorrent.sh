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

printf '%s [handler:qbittorrent] slot %s: synced announce_port=%s at %s; restart requested\n' \
  "$(date -Iseconds)" \
  "${SLOT}" \
  "${EXTERNAL_PORT}" \
  "${TARGET_URL}"

curl -fs --max-time 10 \
  --data "" \
  "${TARGET_URL}/api/v2/app/shutdown" \
  >/dev/null
