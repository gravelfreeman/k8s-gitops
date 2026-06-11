export DEVCONTAINER="${DEVCONTAINER:-true}"
export K8S_GITOPS_DEVCONTAINER="${K8S_GITOPS_DEVCONTAINER:-true}"
export TERM="${TERM:-xterm-256color}"
export COLORTERM="${COLORTERM:-truecolor}"
export MICRO_TRUECOLOR=1
export FZF_BASE="/usr/share/fzf"
export ZSH="$HOME/.oh-my-zsh"
export ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump-${HOST:-devcontainer}-${ZSH_VERSION}"
export HISTORY_IGNORE="(\&|[bf]g|c|clear|history|exit|q|pwd|* --help)"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 \
--color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF \
--color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 \
--color=selected-bg:#51576D \
--color=border:#737994,label:#C6D0F5"

DISABLE_MAGIC_FUNCTIONS="true"
COMPLETION_WAITING_DOTS="true"

setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_EXPIRE_DUPS_FIRST
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

mkdir -p "$ZSH_CACHE_DIR" "${ZSH_COMPDUMP:h}"
fpath=("$ZSH/completions" $fpath)

plugins=(
  1password
  colorize
  extract
  fluxcd
  fzf
  git
  history-substring-search
  helm
  k9s
  kubectl
  nmap
  pip
  python
  rsync
  task
  zsh-interactive-cd
)

source "$ZSH/oh-my-zsh.sh"

autoload -Uz add-zsh-hook
add-zsh-hook -d precmd omz_termsupport_cwd 2>/dev/null || true

source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /etc/zsh_command_not_found
eval "$(oh-my-posh init zsh --config ~/.config/zsh/catppuccin_frappe.omp.json)"
eval "$(op completion zsh)"

source "$HOME/.config/zsh/bindkey.zsh"
source "$HOME/.config/zsh/syntax-highlighting.zsh"
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
