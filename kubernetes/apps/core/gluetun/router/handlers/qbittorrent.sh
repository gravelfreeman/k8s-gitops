#!/bin/sh
set -eu

prefs="$(curl -fs --max-time 10 "${TARGET_URL}/api/v2/app/preferences")"
listen_port="$(printf '%s' "${prefs}" | jq -r '.listen_port // empty')"
announce_port="$(printf '%s' "${prefs}" | jq -r '.announce_port // empty')"

if [ "${listen_port}" = "${TARGET_TCP_PORT}" ] && [ "${announce_port}" = "${EXTERNAL_PORT}" ]; then
  printf '%s [handler:qbittorrent] slot %s: already synced listen_port=%s announce_port=%s at %s\n' \
    "$(date -Iseconds)" \
    "${SLOT}" \
    "${TARGET_TCP_PORT}" \
    "${EXTERNAL_PORT}" \
    "${TARGET_URL}"
  exit 0
fi

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
