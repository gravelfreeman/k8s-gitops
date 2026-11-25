#!/bin/sh
set -eu

current_port="$(curl -fs --max-time 10 "${TARGET_URL}/api/v0/options" | jq -r '.soulseek.listenPort // empty')"

if [ "${current_port}" = "${TARGET_TCP_PORT}" ]; then
  printf '%s [handler:slskd] slot %s: already synced listen_port=%s at %s\n' \
    "$(date -Iseconds)" \
    "${SLOT}" \
    "${TARGET_TCP_PORT}" \
    "${TARGET_URL}"
  exit 0
fi

payload="$(printf '{"soulseek":{"listenPort":%s}}' "${TARGET_TCP_PORT}")"

curl -fs --max-time 10 \
  -X PATCH \
  -H @/run/secrets/router/slskd-api-key \
  -H 'Content-Type: application/json' \
  --data "${payload}" \
  "${TARGET_URL}/api/v0/options" \
  >/dev/null

printf '%s [handler:slskd] slot %s: synced listen_port=%s at %s\n' \
  "$(date -Iseconds)" \
  "${SLOT}" \
  "${TARGET_TCP_PORT}" \
  "${TARGET_URL}"
