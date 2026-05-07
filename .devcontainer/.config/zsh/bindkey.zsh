autoload -Uz compinit
compinit

eval "$(task --completion zsh)"

_task_on_empty_tab() {
  if [[ -z "$BUFFER" ]]; then
    BUFFER="task "
    CURSOR=${#BUFFER}
    zle expand-or-complete
  else
    zle expand-or-complete
  fi
}

zle -N _task_on_empty_tab
bindkey '^I' _task_on_empty_tab
