#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"
talosconfig_source="op://Kubernetes/talos/talosconfig"
talosconfig_target="$HOME/.cache/k8s-gitops/talos/config"

docker ps -aq \
  --filter "label=devcontainer.local_folder=$workspace_dir" \
  | grep -q . && exit 0

install -d -m 0700 "$(dirname "$talosconfig_target")"

op read "$talosconfig_source" </dev/null | base64 >"$talosconfig_target"

chmod 0600 "$talosconfig_target"
