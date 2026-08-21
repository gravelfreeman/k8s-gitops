#!/usr/bin/bash
# Publishes Git-managed files and reloads valid Home Assistant configuration.
# Parameter expansions use doubled '$' to survive Flux substitution.
set -eu
shopt -s nullglob dotglob globstar

root=/config
git_sync_root=$root/.git-sync
checkout=$git_sync_root/ha-gitops
source_root=$checkout/app
token_file=/run/secrets/git-sync-secret/HOME_ASSISTANT_API_TOKEN_GIT_SYNC
ha_url=http://127.0.0.1:8123
commit=$${GITSYNC_HASH:-unknown}
dry_run=$${HA_GITOPS_DRY_RUN:-0}

for argument in "$@"; do
  [ "$argument" = --dry-run ] || exit 2
  dry_run=1
done

log() {
  printf '%s\n' "ha-gitops: $*" >&2
}

is_managed_file() {
  grep -qE '^(//|#) ha-gitops$' "$1"
}

remove_path() {
  if (( dry_run )); then
    log "dry-run: remove $1"
  else
    rm -f "$1"
    local directory=$${1%/*}
    while [ "$directory" != "$root" ] && rmdir "$directory" 2>/dev/null; do
      directory=$${directory%/*}
    done
  fi
}

remove_stale_paths() {
  local directory path source relative
  for directory in "$root"/*; do
    [ "$directory" = "$git_sync_root" ] && continue
    [ -e "$directory" ] || [ -L "$directory" ] || continue

    for path in "$directory" "$directory"/**; do
      if [ -L "$path" ]; then
        source=$(readlink "$path")
        [[ "$source" == "$source_root/"* ]] || continue
        [ -e "$source" ] || remove_path "$path"
        continue
      fi

      case "$path" in
        "$root/www"/*)
          [ -f "$path" ] || continue
          is_managed_file "$path" || continue
          relative=$${path#"$root/"}
          source=$source_root/$relative
          if [ -f "$source" ] && is_managed_file "$source"; then
            continue
          fi
          remove_path "$path"
          ;;
      esac
    done
  done
}

ha_api() {
  curl -fsS --connect-timeout 5 --max-time 60 \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d '{}' "$1"
}

publish_file() {
  local source=$1 target=$2 copy=$3 entry

  if [ -d "$target" ] && [ ! -L "$target" ]; then
    if (( dry_run )); then
      log "dry-run: blocked by directory $target"
      for entry in "$target"/**; do
        log "dry-run: keep $entry"
      done
      return 0
    fi
    log "cannot publish $source: directory exists at $target"
    exit 1
  fi

  if (( dry_run )); then
    if [ -e "$target" ] || [ -L "$target" ]; then
      log "dry-run: replace $target -> $source"
    fi
    return 0
  fi

  if (( copy )); then
    rm -f "$target"
    cp "$source" "$target"
    return 0
  fi

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return 0
  fi
  rm -f "$target"
  ln -s "$source" "$target"
}

[ -d "$source_root" ] || exit 0
remove_stale_paths

for source in "$source_root"/**; do
  [ -f "$source" ] || continue
  relative=$${source#"$source_root/"}
  target=$root/$relative
  copy=0

  case "$relative" in
    www/*)
      is_managed_file "$source" || continue
      copy=1
      ;;
  esac

  (( dry_run )) || mkdir -p "$${target%/*}"
  publish_file "$source" "$target" "$copy"
done

if (( dry_run )); then
  log "dry-run complete: commit=$commit"
  exit 0
fi

token=$(cat "$token_file")
check=$(ha_api "$ha_url/api/config/core/check_config" 2>&1) || {
  log "configuration check failed: commit=$commit error=$check"
  exit 1
}

printf '%s' "$check" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"valid"' || {
  log "configuration rejected: commit=$commit response=$check"
  exit 1
}

reload=$(ha_api "$ha_url/api/services/homeassistant/reload_all" 2>&1) || {
  log "configuration reload failed: commit=$commit error=$reload"
  exit 1
}

log "configuration applied: commit=$commit"
