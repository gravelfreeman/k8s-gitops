#!/usr/bin/env bash
set -Eeuo pipefail
set -o noglob

workspace_dir="$1"

. "$workspace_dir/.devcontainer/scripts/common.sh"

install_krew() {
  local krew="$(download_github_release_asset \
    "kubernetes-sigs/krew" \
    '
      .assets[]
      | .browser_download_url
      | select(test("krew-linux"; "i"))
      | select(test($arch; "i"))
      | select(test("\\.tar\\.gz$"; "i"))
    ' \
    "$(linux_arch)")" || return 1

  extract_archive "$krew" || return 1

  GIT_CONFIG_GLOBAL=/dev/null "./${krew%.tar.gz}" install krew
}

install_krew_plugins() {
  GIT_CONFIG_GLOBAL=/dev/null "$HOME/.krew/bin/kubectl-krew" install \
    pv-mounter browse-pvc df-pv
}

install_krr() {
  local install_dir="$HOME/.local/share/krr"
  local asset_name

  if [ "$(uname -s)" != "Linux" ]; then
    echo "Skipping krr binary install on $(uname -s)"
    return 0
  fi

  asset_name="$(download_github_release_asset \
    "robusta-dev/krr" \
    '
      .assets[]
      | .browser_download_url
      | select(test("krr-ubuntu-latest-.*\\.zip$"))
    ')" || return 1

  rm -rf "$install_dir"
  mkdir -p "$install_dir" "$HOME/.local/bin"
  unzip -q "$asset_name" -d "$install_dir"
  ln -sfn "$install_dir/krr/krr" "$HOME/.local/bin/krr"
  chmod 0755 "$install_dir/krr/krr"
}

process_talosconfig() {
  local source_file="/tmp/host-secrets/talos/config"
  local target_file="$HOME/.talos/config"
  local tmp_file

  install -d -m 0700 "$(dirname "$target_file")"

  tmp_file="$(mktemp "${target_file}.tmp.XXXXXX")"
  if ! base64 --decode "$source_file" >"$tmp_file"; then
    rm -f "$tmp_file"
    echo "Unable to decode talosconfig source: ${source_file}" >&2
    return 1
  fi

  mv "$tmp_file" "$target_file"

  if ! rm -f "$source_file"; then
    echo "WARNING: unable to remove talosconfig host file: ${source_file}" >&2
    sleep 60
  fi

  chmod 0600 "$target_file"
}

generate_kubeconfig() {
  local controller

  cd "$workspace_dir"
  install -d -m 0700 "$HOME/.kube"

  controller="$(talosctl config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1)"
  talosctl kubeconfig --nodes "$controller" --force "$HOME/.kube/config"
  chmod 0600 "$HOME/.kube/config"
}

lock_runtime_sudo() {
  sudo rm -f /etc/sudoers.d/zed /etc/sudoers.d/vscode
}

post_create() {
  local tmp_dir="$(mktemp -d)" && cd "$tmp_dir"
  trap lock_runtime_sudo EXIT

  run_step "Installing krew" install_krew
  run_step "Installing krew plugins" install_krew_plugins
  run_step "Installing krr" install_krr
  run_step "Processing talosconfig" process_talosconfig
  run_step "Generating kubeconfig" generate_kubeconfig

  cd "$HOME" && rm -rf "$tmp_dir"
}

post_create
