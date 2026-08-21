#!/usr/bin/bash
# Links Git-managed files and reloads valid Home Assistant configuration.
# Shell expansions use a doubled '$' to survive Flux substitution.
set -eu
shopt -s nullglob dotglob globstar

root=/config
checkout=$root/.git-sync/ha-gitops
source_root=$checkout/app
token_file=/run/secrets/git-sync-secret/HOME_ASSISTANT_API_TOKEN_GIT_SYNC
ha_url=http://127.0.0.1:8123
commit=$${GITSYNC_HASH:-unknown}
dry_run=$${HA_GITOPS_DRY_RUN:-0}

for argument in "$@"; do
  [ "$argument" = --dry-run ] || exit 2
  dry_run=1
done

log_message() {
  printf '%s\n' "ha-gitops: $*" >&2
}

remove_empty_parents() {
  local directory=$${1%/*}
  while [ "$directory" != "$root" ] && rmdir "$directory" 2>/dev/null; do
    directory=$${directory%/*}
  done
}

remove_stale_file_links() {
  local link source
  for link in "$root"/**; do
    if [[ "$link" == "$root/.git-sync"* ]]; then
      continue
    fi

    [ -L "$link" ] || continue
    source=$(readlink "$link")
    [[ "$source" == "$source_root/"* ]] || continue
    [ -e "$source" ] && continue

    if (( dry_run )); then
      log_message "dry-run: remove $link"
    else
      rm -f "$link"
      remove_empty_parents "$link"
    fi
  done
}

call_ha_api() {
  curl -fsS --connect-timeout 5 --max-time 60 \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' -d '{}' "$1"
}

publish_git_file() {
  local source=$1 target=$2

  if [ -d "$target" ] && [ ! -L "$target" ]; then
    if (( dry_run )); then
      log_message "dry-run: blocked by directory $target"
      for entry in "$target"/**; do
        log_message "dry-run: keep $entry"
      done
      return 0
    fi
    log_message "cannot publish $source: directory exists at $target"
    exit 1
  fi

  if (( dry_run )); then
    if [ -e "$target" ] || [ -L "$target" ]; then
      log_message "dry-run: replace $target -> $source"
    fi
    return 0
  fi

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return 0
  fi

  rm -f "$target"
  ln -s "$source" "$target"
}

[ -d "$source_root" ] || exit 0

remove_stale_file_links

for source in "$source_root"/**; do
  [ -f "$source" ] || continue
  target=$root/$${source#"$source_root/"}
  (( dry_run )) || mkdir -p "$${target%/*}"
  publish_git_file "$source" "$target"
done

if (( dry_run )); then
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
