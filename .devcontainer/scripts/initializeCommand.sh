#!/usr/bin/env bash
set -Eeuo pipefail
set -o noglob

workspace_dir="$1"
talosconfig_source="op://Kubernetes/talos/talosconfig"
talosconfig_target="$HOME/.cache/k8s-gitops/talos/config"

devcontainer_state() {
  local container_id

  command -v docker >/dev/null 2>&1 || return 1

  container_id="$(
    docker ps -aq \
      --filter "label=devcontainer.local_folder=$workspace_dir" \
      | head -n1
  )"

  [ -n "$container_id" ]
}

process_talosconfig() {
  if ! command -v op >/dev/null 2>&1; then
    echo "1Password CLI is not available on the host" >&2
    return 1
  fi

  if ! op read "$talosconfig_source" </dev/null | base64 >"$talosconfig_target"; then
    echo "Unable to read talosconfig from 1Password" >&2
    return 1
  fi
}

initialize() {
  devcontainer_state && exit 0

  install -d -m 0700 "$(dirname "$talosconfig_target")"

  process_talosconfig

  if [ ! -s "$talosconfig_target" ]; then
    echo "1Password talosconfig item returned an empty value" >&2
    return 1
  fi

  chmod 0600 "$talosconfig_target"
}

initialize
