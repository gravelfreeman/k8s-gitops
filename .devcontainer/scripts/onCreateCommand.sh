#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"

. "$workspace_dir/.devcontainer/scripts/common.sh"

setup_clipboard_shim() {
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$workspace_dir/.devcontainer/templates/xclip" "$HOME/.local/bin/xclip"
  export PATH="$HOME/.local/bin:$PATH"
}

setup_shell_config() {
  rm -rf "$HOME/.config/zsh"
  rm -f "$HOME/.zprofile" "$HOME/.zshrc"
  ln -sfn "$workspace_dir/.devcontainer/.config/.zprofile" "$HOME/.zprofile"
  ln -sfn "$workspace_dir/.devcontainer/.config/.zshrc" "$HOME/.zshrc"
  ln -sfn "$workspace_dir/.devcontainer/.config/zsh" "$HOME/.config/zsh"
}

setup_ssh_config() {
  install -d -m 700 "$HOME/.ssh"
  rm -rf "$HOME/.ssh/1Password"
  ln -sfn /tmp/host-ssh/1Password "$HOME/.ssh/1Password"

  if [ -f /tmp/host-ssh/known_hosts ]; then
    cp /tmp/host-ssh/known_hosts "$HOME/.ssh/known_hosts"
  fi

  sed \
    -e "s|__SSH_INCLUDE_1PASSWORD__|Include ~/.ssh/1Password/config|g" \
    -e "s|__SSH_AUTH_SOCK__|/tmp/ssh-agent.sock|g" \
    "$workspace_dir/.devcontainer/templates/.sshconfig" >"$HOME/.ssh/config"

  chmod 600 "$HOME/.ssh/config"
}

setup_git_config() {
  sed \
    -e "s|__SSH_KEYGEN__|$(command -v ssh-keygen)|g" \
    "$workspace_dir/.devcontainer/templates/.gitconfig" >"$HOME/.gitconfig"

  mkdir -p "$HOME/.config/git"
  git config --file "$HOME/.config/git/config" --replace-all safe.directory "$workspace_dir"
}

setup_git_hooks() {
  chmod 0755 "$workspace_dir/.githooks/commit-msg"
  chmod 0755 "$workspace_dir/.githooks/pre-commit"
  git -C "$workspace_dir" config --local core.hooksPath .githooks
}

setup_k9s_config() {
  rm -rf "$HOME/.config/k9s"
  ln -sfn "$workspace_dir/.devcontainer/.config/k9s" "$HOME/.config/k9s"
}

on_create() {
  mkdir -p "$HOME/.config"
  run_step "Setting up clipboard shim" setup_clipboard_shim
  run_step "Setting up shell config" setup_shell_config
  run_step "Setting up SSH config" setup_ssh_config
  run_step "Setting up git config" setup_git_config
  run_step "Setting up git hooks" setup_git_hooks
  run_step "Setting up K9s config" setup_k9s_config
}

on_create
