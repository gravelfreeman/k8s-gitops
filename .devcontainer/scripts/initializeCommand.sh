#!/usr/bin/env bash
set -Eeuo pipefail

install -d -m 0700 \
  "$HOME/.cache/k8s-gitops/opencode" \
  "$HOME/.cache/k8s-gitops/talos"

workspace_dir="${1:?Usage: initializeCommand.sh <workspace-dir>}"
script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
log_file="$HOME/.cache/k8s-gitops/rebindZedThreads.log"
agent_ids=("OpenCode v2")
session_db="$HOME/.local/share/opencode/opencode.db"
session_query="SELECT id FROM session_v2 WHERE directory = ?"

nohup python3 "$script_dir/rebindZedThreads.py" "$workspace_dir" \
  --session-db "$session_db" \
  --session-query "$session_query" \
  "${agent_ids[@]}" \
  >>"$log_file" 2>&1 </dev/null &
