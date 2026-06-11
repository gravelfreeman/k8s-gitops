#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"
cache_dir="$HOME/.cache/k8s-gitops"

install -d -m 0700 "$cache_dir/ssh" "$cache_dir/talos"

rm -f "$cache_dir/ssh-agent.sock"
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
  ln -s "$SSH_AUTH_SOCK" "$cache_dir/ssh-agent.sock"
elif [ -S /tmp/1password-ssh-agent.sock ]; then
  ln -s /tmp/1password-ssh-agent.sock "$cache_dir/ssh-agent.sock"
else
  ln -s "$HOME/.1password/agent.sock" "$cache_dir/ssh-agent.sock"
fi

if command -v docker >/dev/null 2>&1 \
  && docker ps -aq --filter "label=devcontainer.local_folder=$workspace_dir" 2>/dev/null | grep -q .; then
  exit 0
fi

op item get "GitHub Auth Key" --fields "label=public key" --reveal >"$cache_dir/ssh/github-auth.pub"
op item get "GitHub Signing Key" --fields "label=public key" --reveal >"$cache_dir/ssh/github-signing.pub"
op read "op://Kubernetes/talos/talosconfig" </dev/null | base64 >"$cache_dir/talos/config"
chmod 0600 "$cache_dir/ssh/github-auth.pub" "$cache_dir/ssh/github-signing.pub"
chmod 0600 "$cache_dir/talos/config"
