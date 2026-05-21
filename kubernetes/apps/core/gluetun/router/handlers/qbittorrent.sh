#!/bin/sh
set -eu

payload="$(printf \
  'json={"listen_port":%s,"announce_port":%s,"random_port":false,"reannounce_when_address_changed":true}' \
  "${TARGET_TCP_PORT}" \
  "${EXTERNAL_PORT}" \
)"

curl -fs --max-time 10 \
  --data "${payload}" \
  "${TARGET_URL}/api/v2/app/setPreferences" \
  >/dev/null

printf '%s [handler:qbittorrent] slot %s: synced listen_port=%s announce_port=%s at %s; restart requested\n' \
  "$(date -Iseconds)" \
  "${SLOT}" \
  "${TARGET_TCP_PORT}" \
  "${EXTERNAL_PORT}" \
  "${TARGET_URL}"

curl -fs --max-time 10 \
  --data "" \
  "${TARGET_URL}/api/v2/app/shutdown" \
  >/dev/null
