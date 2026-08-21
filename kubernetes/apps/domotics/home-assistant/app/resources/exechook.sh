#!/bin/sh
# Links Git-managed files and reloads valid Home Assistant configuration.
set -eu

root=/config
checkout=$root/.git-sync/ha-gitops
source_root=$checkout/app
token_file=/run/secrets/git-sync-secret/HOME_ASSISTANT_API_TOKEN_GIT_SYNC
ha_url=http://127.0.0.1:8123
commit=${GITSYNC_HASH:-unknown}
dry_run=${HA_GITOPS_DRY_RUN:-}

for argument in "$@"; do
  case "$argument" in
    --dry-run) dry_run=1 ;;
    *) exit 2 ;;
  esac
done

log_message() {
  printf '%s\n' "ha-gitops: $*" >&2
}

remove_empty_parents() {
  directory=${1%/*}

  while [ "$directory" != "$root" ] && rmdir "$directory" 2>/dev/null; do
    directory=${directory%/*}
  done
}

remove_stale_file_links() {
  find "$root" -type l -lname "$source_root/*" -print |
    while IFS= read -r link; do
      source=$(readlink "$link")
      if [ ! -e "$source" ]; then
        if [ -n "$dry_run" ]; then
          log_message "dry-run: remove $link"
        else
          rm -f "$link"
          remove_empty_parents "$link"
        fi
      fi
    done
}

call_ha_api() {
  curl -fsS --connect-timeout 5 --max-time 60 \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d '{}' "$1"
}

publish_git_file() {
  source=$1
  target=$2

  if [ -d "$target" ] && [ ! -L "$target" ]; then
    if [ -n "$dry_run" ]; then
      log_message "dry-run: blocked by directory $target"
      find "$target" -mindepth 1 -print |
        sed 's|^|ha-gitops: dry-run: keep |' >&2
      return 0
    fi
    log_message "cannot publish $source: directory exists at $target"
    exit 1
  fi

  if [ -n "$dry_run" ]; then
    if [ -e "$target" ] || [ -L "$target" ]; then
      log_message "dry-run: replace $target -> $source"
    else
      log_message "dry-run: create $target -> $source"
    fi
  elif [ ! -L "$target" ] || [ "$(readlink "$target")" != "$source" ]; then
    rm -rf "$target"
    ln -s "$source" "$target"
  fi
}

[ -d "$source_root" ] || exit 0

remove_stale_file_links

find "$source_root" -type f -print |
  while IFS= read -r source; do
    target=$root/${source#"$source_root/"}
    [ -n "$dry_run" ] || mkdir -p "${target%/*}"
    publish_git_file "$source" "$target"
  done

if [ -n "$dry_run" ]; then
  log_message "dry-run complete: commit=$commit"
  exit 0
fi

token=$(cat "$token_file")

check=$(call_ha_api "$ha_url/api/config/core/check_config" 2>&1) || {
  log_message "configuration check failed: commit=$commit error=$check"
  exit 0
}

printf '%s' "$check" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"valid"' || {
  log_message "configuration rejected: commit=$commit response=$check"
  exit 0
}

reload=$(call_ha_api "$ha_url/api/services/homeassistant/reload_all" 2>&1) || {
  log_message "configuration reload failed: commit=$commit error=$reload"
  exit 0
}

log_message "configuration applied: commit=$commit"
