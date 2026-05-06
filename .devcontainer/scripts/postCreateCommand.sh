#!/usr/bin/env bash
set -Eeuo pipefail
set -o noglob

workspace_dir="$1"

. "$workspace_dir/.devcontainer/scripts/common.sh"

install_oh_my_posh() {
  local arch

  if [ -x "$HOME/.local/bin/oh-my-posh" ]; then
    return 0
  fi

  arch="$(linux_arch)"

  install_binary_from_release \
    "JanDeDobbeleer/oh-my-posh" \
    '
      .assets[]
      | .browser_download_url
      | select(endswith("/posh-linux-" + $arch))
    ' \
    "$arch" \
    "oh-my-posh"
}

install_zsh_syntax_highlighting() {
  local target_dir="$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

  if [ -f "$target_dir/zsh-syntax-highlighting.zsh" ]; then
    return 0
  fi

  rm -rf "$target_dir"
  GIT_CONFIG_GLOBAL=/dev/null git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$target_dir"
}

install_minijinja_cli() {
  if [ -x "$HOME/.local/bin/minijinja-cli" ]; then
    return 0
  fi

  export MINIJINJA_CLI_INSTALL_DIR="$HOME/.local/bin"
  curl -sSfL "https://github.com/mitsuhiko/minijinja/releases/latest/download/minijinja-cli-installer.sh" | sh

  rm -f "$HOME/.local/env" "$HOME/.local/env.fish"
  sed -i '/^\\. "\$HOME\\/\\.local\\/env"$/d' "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
}

install_talhelper() {
  local arch

  if [ -x "$HOME/.local/bin/talhelper" ]; then
    return 0
  fi

  arch="$(linux_arch)"

  install_binary_from_release \
    "budimanjojo/talhelper" \
    '
      .assets[]
      | .browser_download_url
      | select(test("talhelper"; "i"))
      | select(test("linux"; "i"))
      | select(test($arch; "i"))
      | select(test("\\.tar\\.gz$"; "i"))
    ' \
    "$arch" \
    "talhelper"
}

install_krew() {
  local arch
  local asset_name

  if [ -x "$HOME/.krew/bin/kubectl-krew" ]; then
    return 0
  fi

  arch="$(linux_arch)"

  asset_name="$(download_github_release_asset \
    "kubernetes-sigs/krew" \
    '
      .assets[]
      | .browser_download_url
      | select(test("krew-linux"; "i"))
      | select(test($arch; "i"))
      | select(test("\\.tar\\.gz$"; "i"))
    ' \
    "$arch")" || return 1
  extract_archive "$asset_name" || return 1

  GIT_CONFIG_GLOBAL=/dev/null "./${asset_name%.tar.gz}" install krew
}

install_krew_plugins() {
  local plugin
  local installed_plugins

  [ -x "$HOME/.krew/bin/kubectl-krew" ] || return 1
  installed_plugins="$("$HOME/.krew/bin/kubectl-krew" list 2>/dev/null)" || return 1

  for plugin in pv-mounter browse-pvc df-pv; do
    printf '%s\n' "$installed_plugins" | grep -qxF "$plugin" || break
  done

  if [ "$plugin" = "df-pv" ]; then
    return 0
  fi

  for plugin in pv-mounter browse-pvc df-pv; do
    if "$HOME/.krew/bin/kubectl-krew" list | grep -qxF "$plugin"; then
      continue
    fi

    GIT_CONFIG_GLOBAL=/dev/null "$HOME/.krew/bin/kubectl-krew" install "$plugin"
  done
}

install_krr() {
  local arch
  local tag
  local tmp_dir
  local src_dir
  local venv_dir="$HOME/.local/share/krr-venv"

  if [ -x "$HOME/.local/bin/krr" ]; then
    return 0
  fi

  arch="$(linux_arch)"

  if [ "$arch" = "amd64" ]; then
    install_binary_from_release \
      "robusta-dev/krr" \
      '
        .assets[]
        | .browser_download_url
        | select(test("ubuntu"; "i"))
        | select(test("\\.zip$"; "i"))
      ' \
      "$arch" \
      "krr"
    return 0
  fi

  tag="$(curl -fsSL "https://api.github.com/repos/robusta-dev/krr/releases/latest" | jq -r '.tag_name')"
  tmp_dir="$(mktemp -d)"

  curl -fsSL "https://github.com/robusta-dev/krr/archive/refs/tags/${tag}.tar.gz" -o "$tmp_dir/krr.tar.gz"
  tar -xzf "$tmp_dir/krr.tar.gz" -C "$tmp_dir"
  src_dir="$(find "$tmp_dir" -maxdepth 1 -mindepth 1 -type d -name 'krr-*' | head -n1)"

  python3 -m venv "$venv_dir"
  "$venv_dir/bin/pip" install --quiet --upgrade pip
  "$venv_dir/bin/pip" install --quiet --no-cache-dir -r "$src_dir/requirements.txt"
  "$venv_dir/bin/pip" install --quiet --no-deps "$src_dir"
  install -m 0755 "$venv_dir/bin/krr" "$HOME/.local/bin/krr"

  rm -rf "$tmp_dir"
}

process_talosconfig() {
  local source_file="/tmp/host-secrets/talos/config"
  local target_file="$HOME/.talos/config"

  if [ ! -s "$source_file" ]; then
    rm -f "$source_file"
    echo "Missing or empty host secret file: ${source_file}" >&2
    return 1
  fi

  install -d -m 0700 "$(dirname "$target_file")"

  if ! base64 --decode "$source_file" >"$target_file"; then
    rm -f "$source_file" "$target_file"
    echo "Unable to decode host secret file: ${source_file}" >&2
    return 1
  fi

  if ! rm -f "$source_file"; then
    echo "WARNING: unable to remove talosconfig host file: ${source_file}" >&2
    sleep 60
  fi

  if ! chmod 0600 "$target_file"; then
    echo "WARNING: talosconfig permissions could not be set in the devcontainer: ${target_file}" >&2
  fi

  if [ ! -s "$target_file" ]; then
    rm -f "$target_file"
    echo "Decoded host secret file is empty: ${source_file}" >&2
    return 1
  fi
}

generate_kubeconfig() {
  cd "$workspace_dir"
  install -d -m 0700 "$HOME/.kube"
  task talos:generate-kubeconfig
}

post_create() {
  local tmp_dir

  tmp_dir="$(mktemp -d)"
  cd "$tmp_dir"

  run_step "Installing oh-my-posh" install_oh_my_posh
  run_step "Installing zsh-syntax-highlighting" install_zsh_syntax_highlighting
  run_step "Installing minijinja-cli" install_minijinja_cli
  run_step "Installing talhelper" install_talhelper
  run_step "Installing krew" install_krew
  run_step "Installing krew plugins" install_krew_plugins
  # run_step "Installing krr" install_krr
  run_step "Processing talosconfig" process_talosconfig
  run_step "Generating kubeconfig" generate_kubeconfig

  cd "$HOME"
  rm -rf "$tmp_dir"
}

post_create
