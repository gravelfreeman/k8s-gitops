#!/usr/bin/env bash
set -Eeuo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
socket_path="$runtime_dir/1Password-BrowserSupport.sock"
host_socket_path="/run/host-runtime/$(id -u)/1Password-BrowserSupport.sock"

install -d -m 0700 "$runtime_dir"

if [ -L "$socket_path" ]; then
  ln -sfn "$host_socket_path" "$socket_path"
else
  rm -f "$socket_path"
  ln -s "$host_socket_path" "$socket_path"
fi

if [ ! -S "$socket_path" ]; then
  echo "1Password app socket is not available at $host_socket_path" >&2
  exit 1
fi
