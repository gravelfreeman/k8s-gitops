#!/usr/bin/env bash
set -Eeuo pipefail

workspace_dir="$1"

. "$workspace_dir/.devcontainer/scripts/common.sh"

setup_shell_config() {
  rm -rf "$HOME/.config/zsh"
  rm -f "$HOME/.zshrc"
  ln -sfn "$workspace_dir/.devcontainer/.config/.zshrc" "$HOME/.zshrc"
  ln -sfn "$workspace_dir/.devcontainer/.config/zsh" "$HOME/.config/zsh"
}

setup_ssh_config() {
  install -d -m 700 "$HOME/.ssh"
  touch "$HOME/.ssh/known_hosts"

  if [ -f /tmp/host-secrets/ssh/github-auth.pub ]; then
    cp /tmp/host-secrets/ssh/github-auth.pub "$HOME/.ssh/github-auth.pub"
    chmod 600 "$HOME/.ssh/github-auth.pub"
  fi

  if [ -f /tmp/host-secrets/ssh/github-signing.pub ]; then
    cp /tmp/host-secrets/ssh/github-signing.pub "$HOME/.ssh/github-signing.pub"
    chmod 600 "$HOME/.ssh/github-signing.pub"
  fi

  sed \
    -e "s|__SSH_AUTH_SOCK__|/tmp/ssh-agent.sock|g" \
    "$workspace_dir/.devcontainer/templates/.sshconfig" >"$HOME/.ssh/config"

  chmod 600 "$HOME/.ssh/config" "$HOME/.ssh/known_hosts"
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
  run_step "Setting up shell config" setup_shell_config
  run_step "Setting up SSH config" setup_ssh_config
  run_step "Setting up git config" setup_git_config
  run_step "Setting up git hooks" setup_git_hooks
  run_step "Setting up K9s config" setup_k9s_config
}

on_create
