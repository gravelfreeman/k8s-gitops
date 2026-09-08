#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"
cache_dir="$HOME/.cache/k8s-gitops"
token_file="$cache_dir/op-service-account-token"
token_tmp=""

install -d -m 0700 "$cache_dir/ssh" "$cache_dir/talos"

if command -v docker >/dev/null 2>&1 \
  && docker ps -aq --filter "label=devcontainer.local_folder=$workspace_dir" 2>/dev/null | grep -q .; then
  exit 0
fi

token_tmp="$(mktemp "${token_file}.XXXXXX")"
trap 'rm -f "$token_tmp"' EXIT
op read "op://Homelab/kubernetes-rw/credential" >"$token_tmp"
chmod 0600 "$token_tmp"
mv "$token_tmp" "$token_file"
trap - EXIT

op item get "GitHub Auth Key" --fields "label=public key" --reveal >"$cache_dir/ssh/github-auth.pub"
op read "op://Kubernetes/talos/talosconfig" </dev/null | base64 >"$cache_dir/talos/config"
chmod 0600 "$cache_dir/ssh/github-auth.pub"
chmod 0600 "$cache_dir/talos/config"
