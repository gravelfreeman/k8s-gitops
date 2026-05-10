#!/usr/bin/env bash
set -euo pipefail

read -r begin_wal end_wal system_id < <(
  barman-cloud-backup-show \
    --endpoint-url "https://${S3_ENDPOINT}" \
    --format json "s3://${S3_BUCKET}/cnpg" "$1" "$2" \
    | jq -er '[.cloud.begin_wal, .cloud.end_wal, .cloud.systemid] | @tsv'
)

wal="$(mktemp)"; trap 'rm -f "$wal"' EXIT

for wal_name in "$begin_wal" "$end_wal"; do
  timeout 10m sh -c '
    until barman-cloud-wal-restore --endpoint-url "$1" --no-partial "$2" "$3" "$4" "$5"; do
      sleep 5
    done
  ' \
    sh "https://${S3_ENDPOINT}" "s3://${S3_BUCKET}/cnpg" "$1" "$wal_name" "$wal"

  got="$(
    perl -e '
      open my $fh, "<:raw", $ARGV[0] or die $!;
      seek $fh, 24, 0;
      read $fh, my $buf, 8;
      print unpack(q(Q<), $buf);
    ' "$wal"
  )"

  if [ "$got" != "$system_id" ]; then
    printf '%s %s: %s has system_id %s, expected %s\n' "$1" "$2" "$wal_name" "$got" "$system_id"
    exit 1
  fi
done

if [ "${3:-}" = "--list" ]; then
  task cnpg:list APP="$1" VERIFIED="$2"
else
  printf '%s %s is recoverable\n' "$1" "$2"
fi
