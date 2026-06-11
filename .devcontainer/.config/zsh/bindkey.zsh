autoload -Uz compinit
compinit

eval "$(task --completion zsh)"

sshm() {
  local host
  host=$(grep -E '^Host ' ~/.ssh/config \
    | awk '{for (i=2; i<=NF; i++) print $i}' \
    | grep -v '[*?]' \
    | fzf)

  [[ -n "$host" ]] && ssh "$host"
}

_ssh_config_host_list() {
  grep -hE '^[[:space:]]*Host[[:space:]]+' ~/.ssh/config 2>/dev/null \
    | awk '{for (i=2; i<=NF; i++) print $i}' \
    | grep -Ev '^[*?]|[*?]|^(localhost|127\.0\.0\.1)$' \
    | sort -u
}

_devcontainer_tab_completion() {
  setopt localoptions noshwordsplit noksharrays

  local -a tokens
  local host query
  tokens=(${(z)LBUFFER})

  if [[ "${tokens[1]}" == "ssh" ]]; then
    [[ "$LBUFFER" == *" " ]] && query="" || query="${tokens[-1]}"

    host=$(_ssh_config_host_list | FZF_DEFAULT_OPTS="--height ${FZF_TMUX_HEIGHT:-40%} \
      --reverse $FZF_DEFAULT_OPTS $FZF_COMPLETION_OPTS \
      --bind 'shift-tab:up,tab:down,bspace:backward-delete-char/eof'" fzf --query "$query")

    if [[ -n "$host" ]]; then
      if [[ "$LBUFFER" == *" " ]]; then
        LBUFFER+="$host"
      else
        LBUFFER="${LBUFFER%${tokens[-1]}}$host"
      fi
    fi

    zle reset-prompt
    return
  fi

  if [[ -z "$BUFFER" ]]; then
    BUFFER="task "
    CURSOR=${#BUFFER}
    zle expand-or-complete
  else
    zle expand-or-complete
  fi
}

zle -N _devcontainer_tab_completion
bindkey '^I' _devcontainer_tab_completion
