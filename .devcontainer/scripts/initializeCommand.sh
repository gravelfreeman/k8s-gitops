#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"
cache_dir="$HOME/.cache/k8s-gitops"

install -d -m 0700 "$cache_dir/ssh" "$cache_dir/talos"

rm -f "$cache_dir/ssh-agent.sock"
agent_socket=""
for candidate in \
  "${SSH_AUTH_SOCK:-}" \
  "$HOME/.1password/agent.sock" \
  /tmp/1password-ssh-agent.sock
do
  [ -n "$candidate" ] || continue
  [ -S "$candidate" ] || continue

  if SSH_AUTH_SOCK="$candidate" ssh-add -l >/dev/null 2>&1; then
    agent_socket="$candidate"
    break
  fi
done

if [ -n "$agent_socket" ]; then
  ln -s "$agent_socket" "$cache_dir/ssh-agent.sock"
else
  echo "Unable to find a working SSH agent socket" >&2
  exit 1
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
