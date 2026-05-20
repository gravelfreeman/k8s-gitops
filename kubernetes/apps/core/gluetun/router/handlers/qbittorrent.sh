#!/bin/sh
set -eu

qbit_url="http://${TARGET_IP}:8080"

payload="$(printf \
  'json={"announce_port":%s,"reannounce_when_address_changed":true}' \
  "${EXTERNAL_PORT}" \
)"

curl -fsS --max-time 10 \
  --data "${payload}" \
  "${qbit_url}/api/v2/app/setPreferences" \
  >/dev/null

curl -fsS --max-time 10 \
  --data "hashes=all" \
  "${qbit_url}/api/v2/torrents/reannounce" \
  >/dev/null || true

printf '%s [handler:qbittorrent] slot %s: synced announce_port=%s at %s\n' \
  "$(date -Iseconds)" \
  "${SLOT}" \
  "${EXTERNAL_PORT}" \
  "${qbit_url}"
