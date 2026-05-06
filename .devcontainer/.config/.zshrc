export ZSH="$HOME/.oh-my-zsh"
export ZSH_CACHE_DIR="$HOME/.cache/oh-my-zsh"
export ZSH_COMPDUMP="$HOME/.cache/zsh/.zcompdump-${HOST}-${ZSH_VERSION}"
export TERM=xterm-256color
export COLORTERM=truecolor

mkdir -p "$ZSH_CACHE_DIR" "${ZSH_COMPDUMP:h}"

plugins=(
  1password
  fluxcd
  git
  helm
  k9s
  kubectl
  pip
  python
  task
  zsh-interactive-cd
)

source $ZSH/oh-my-zsh.sh
add-zsh-hook -d precmd omz_termsupport_cwd

bindkey "\e[1~" beginning-of-line
bindkey "\e[4~" end-of-line
bindkey "\e[5~" up-line-or-history
bindkey "\e[6~" down-line-or-history

export FZF_DEFAULT_OPTS=" \
--color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284 \
--color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF \
--color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284 \
--color=border:#737994,label:#C6D0F5"

if [[ -x "$HOME/.local/bin/oh-my-posh" ]]; then
  eval "$("$HOME/.local/bin/oh-my-posh" init zsh --config ~/.config/zsh/catppuccin_frappe.omp.json)"
elif command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config ~/.config/zsh/catppuccin_frappe.omp.json)"
fi

if [[ -f ~/.config/zsh/catppuccin_frappe-zsh-syntax-highlighting.zsh ]]; then
  source ~/.config/zsh/catppuccin_frappe-zsh-syntax-highlighting.zsh
fi

if [[ -f ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
