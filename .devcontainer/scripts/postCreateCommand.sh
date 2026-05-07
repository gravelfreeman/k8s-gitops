#!/usr/bin/env bash
set -Eeuo pipefail
set -o noglob

workspace_dir="$1"

. "$workspace_dir/.devcontainer/scripts/common.sh"

install_oh_my_posh() {
  install_binary_from_release \
    "JanDeDobbeleer/oh-my-posh" \
    '
      .assets[]
      | .browser_download_url
      | select(endswith("/posh-linux-" + $arch))
    ' \
    "$(linux_arch)" \
    "oh-my-posh"
}

install_zsh_syntax_highlighting() {
  mkdir -p "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  ln -sfn \
    "$workspace_dir/.devcontainer/.config/zsh/syntax-highlighting.zsh" \
    "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
}

install_minijinja_cli() {
  export MINIJINJA_CLI_INSTALL_DIR="$HOME/.local/bin"
  curl -sSfL "https://github.com/mitsuhiko/minijinja/releases/latest/download/minijinja-cli-installer.sh" | sh
  rm -f "$HOME/.local/env" "$HOME/.local/env.fish"
  sed -i '/^\\. "\$HOME\\/\\.local\\/env"$/d' "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
}

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
  local venv_dir="$HOME/.local/share/krr-venv"
  local tmp_dir="$(mktemp -d)"

  curl -fsSL "https://github.com/robusta-dev/krr/archive/refs/tags/$(
    curl -fsSL "https://api.github.com/repos/robusta-dev/krr/releases/latest" \
      | jq -r '.tag_name').tar.gz" -o "$tmp_dir/krr.tar.gz"
  tar -xzf "$tmp_dir/krr.tar.gz" -C "$tmp_dir"
  local src_dir="$(find "$tmp_dir" -maxdepth 1 -mindepth 1 -type d -name 'krr-*' | head -n1)"

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

  install -d -m 0700 "$(dirname "$target_file")"
  base64 --decode "$source_file" >"$target_file"

  if ! rm -f "$source_file"; then
    echo "WARNING: unable to remove talosconfig host file: ${source_file}" >&2
    sleep 60
  fi

  chmod 0600 "$target_file"
}

generate_kubeconfig() {
  cd "$workspace_dir"
  install -d -m 0700 "$HOME/.kube"
  task talos:generate-kubeconfig
}

post_create() {
  local tmp_dir="$(mktemp -d)" && cd "$tmp_dir"

  run_step "Installing oh-my-posh" install_oh_my_posh
  run_step "Installing zsh-syntax-highlighting" install_zsh_syntax_highlighting
  run_step "Installing minijinja-cli" install_minijinja_cli
  run_step "Installing krew" install_krew
  run_step "Installing krew plugins" install_krew_plugins
  # run_step "Installing krr" install_krr
  run_step "Processing talosconfig" process_talosconfig
  run_step "Generating kubeconfig" generate_kubeconfig

  cd "$HOME" && rm -rf "$tmp_dir"
}

post_create
