#!/usr/bin/env bash
set -euo pipefail

highlight_backup="${4:-}"

{
  aws --endpoint-url "https://${S3_ENDPOINT}" s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix cnpg/ \
    | jq -r --arg app "${1:-}" --arg path "s3://${S3_BUCKET}/cnpg" '
        (.Contents // [])
        | map(
            select(.Key | test("^cnpg/[^/]+/base/[^/]+(/|$)"))
            | . + {parts: (.Key | split("/"))}
            | select($app == "" or .parts[1] == $app)
          )
        | if length == 0 then
            "No CNPG backups found at \($path)"
          else
            group_by(.parts[1] + "\u0000" + .parts[3])
            | map({
                app: .[0].parts[1],
                backup: .[0].parts[3],
                objects: length,
                bytes: (map(.Size) | add),
                latest: (map(.LastModified) | max)
              })
            | sort_by(.app, .backup)
            | (["APP", "BACKUP", "OBJECTS", "BYTES", "LATEST_OBJECT"] | @tsv),
              (.[] | [.app, .backup, (.objects | tostring), (.bytes | tostring), .latest] | @tsv)
          end
      ' \
    | while IFS="$(printf '\t')" read -r backup_app backup objects bytes latest; do
        if [ -z "$backup" ]; then
          printf '%s\n' "$backup_app"
          continue
        fi

        printf '%s\t%s\t%s\t%s\t%s\n' \
          "$backup_app" \
          "$backup" \
          "$objects" \
          "$bytes" \
          "$latest"
      done

  if [ -n "${1:-}" ] && [ -n "${2:-}" ] && [ -n "${3:-}" ]; then
    printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  fi
} \
  | column -t -s "$(printf '\t')" -o "   " \
  | awk -v highlight="${highlight_backup:-}" -v deleted="${2:-}" '
      function strike(s, i, out) {
        for (i = 1; i <= length(s); i++) {
          out = out substr(s, i, 1) "\314\266"
        }
        return out
      }

      NR == 1 && $1 == "APP" {
        print "\033[1m" $0 "\033[0m"
        next
      }

      deleted != "" && $2 == deleted {
        print "\033[38;5;7m" strike($0) "   [deleted]\033[0m"
        next
      }

      highlight != "" && $2 == highlight {
        print "\033[32m" $0 "   [verified]\033[0m"
        next
      }

      { print }
    '
