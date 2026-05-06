#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"
devcontainer_dir="$workspace_dir/.devcontainer"

. "$devcontainer_dir/scripts/common.sh"

setup_clipboard_shim() {
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$devcontainer_dir/templates/xclip" "$HOME/.local/bin/xclip"
  export PATH="$HOME/.local/bin:$PATH"
}

setup_shell_config() {
  mkdir -p "$HOME/.config/zsh"
  install -m 0644 "$devcontainer_dir/.config/.zprofile" "$HOME/.zprofile"
  install -m 0644 "$devcontainer_dir/.config/.zshrc" "$HOME/.zshrc"
  cp -R "$devcontainer_dir/.config/zsh/." "$HOME/.config/zsh/"
}

setup_ssh_config() {
  local ssh_auth_sock="/tmp/ssh-agent.sock"
  local onepassword_include=""
  local onepassword_mount="/tmp/host-ssh/1Password"

  install -d -m 700 "$HOME/.ssh"
  rm -rf "$HOME/.ssh/1Password"

  if [ -d "$onepassword_mount" ]; then
    ln -sfn "$onepassword_mount" "$HOME/.ssh/1Password"
    onepassword_include="Include ~/.ssh/1Password/config"
  fi

  if [ -f /tmp/host-ssh/known_hosts ]; then
    cp /tmp/host-ssh/known_hosts "$HOME/.ssh/known_hosts"
  fi

  sed \
    -e "s|__SSH_INCLUDE_1PASSWORD__|$onepassword_include|g" \
    -e "s|__SSH_AUTH_SOCK__|$ssh_auth_sock|g" \
    "$devcontainer_dir/templates/.sshconfig" >"$HOME/.ssh/config"

  chmod 600 "$HOME/.ssh/config"
}

setup_git_config() {
  local gitconfig_template
  local ssh_keygen_bin

  gitconfig_template="$devcontainer_dir/templates/.gitconfig"
  ssh_keygen_bin="$(command -v ssh-keygen)"

  sed \
    -e "s|__SSH_KEYGEN__|$ssh_keygen_bin|g" \
    "$gitconfig_template" >"$HOME/.gitconfig"

  mkdir -p "$HOME/.config/git"
  git config --file "$HOME/.config/git/config" --replace-all safe.directory "$workspace_dir"
}

setup_git_hooks() {
  chmod 0755 "$workspace_dir/.githooks/commit-msg"
  chmod 0755 "$workspace_dir/.githooks/pre-commit"
  git -C "$workspace_dir" config --local core.hooksPath .githooks
}

setup_k9s_config() {
  local source_config_dir="$devcontainer_dir/.config/k9s"
  local target_config_dir="$HOME/.config/k9s"

  mkdir -p "$HOME/.config"
  rm -rf "$target_config_dir"
  ln -sfn "$source_config_dir" "$target_config_dir"
}

on_create() {
  run_step "Setting up clipboard shim" setup_clipboard_shim
  run_step "Setting up shell config" setup_shell_config
  run_step "Setting up SSH config" setup_ssh_config
  run_step "Setting up git config" setup_git_config
  run_step "Setting up git hooks" setup_git_hooks
  run_step "Setting up K9s config" setup_k9s_config
}

on_create
