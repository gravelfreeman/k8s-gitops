#!/usr/bin/env bash
set -euo pipefail

ansi_bold="$(printf '\033[1m')"
ansi_green="$(printf '\033[32m')"
ansi_pink="$(printf '\033[95m')"
ansi_reset="$(printf '\033[0m')"

cleanup() {
  stty "${stty_state:-sane}" < /dev/tty 2>/dev/null || true
  tput smam 2>/dev/null || true
  tput cnorm 2>/dev/null || true
}

clear_terminal() {
  printf '\033[H\033[2J\033[3J'
}

line() {
  printf "$@"
  printf '\n'
}

lines() {
  local row

  while IFS= read -r row; do
    case "$row" in
      *[![:space:]]*) line '%s' "$row" ;;
    esac
  done
}

blank_line() {
  printf '\n'
}

table() {
  local cols kind names

  kind="$1"
  names="${2:-}"
  cols="$(tput cols 2>/dev/null || true)"
  case "$cols" in
    ""|*[!0-9]*) cols=80 ;;
  esac

  {
    kubectl get kustomizations.kustomize.toolkit.fluxcd.io --all-namespaces \
      --output jsonpath='{range .items[*]}ks{"\t"}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.lastAppliedRevision}{"\t"}{.spec.suspend}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.message}{end}{"\n"}{end}' 2>/dev/null || true
    kubectl get helmreleases.helm.toolkit.fluxcd.io --all-namespaces \
      --output jsonpath='{range .items[*]}hr{"\t"}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.lastAttemptedRevision}{"\t"}{.spec.suspend}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.message}{end}{"\n"}{end}' 2>/dev/null || true
  } \
    | awk -F '\t' \
        -v show="$kind" \
        -v names="$names" \
        -v cols="$cols" '
      function bool(value, default_value) {
        if (value == "true") return "True"
        if (value == "false") return "False"
        if (value == "True" || value == "False" || value == "Unknown") return value
        return default_value
      }

      function color(ready, suspended) {
        if (suspended == "True" && ready == "False") return gray red
        if (suspended == "True" && ready == "Unknown") return gray yellow
        if (suspended == "True") return gray
        if (ready == "False") return red
        if (ready == "Unknown") return yellow
        return ""
      }

      function ellipsize(value, limit) {
        if (length(value) <= limit) return value
        if (limit <= 3) return substr(value, 1, limit)
        return substr(value, 1, limit - 3) "..."
      }

      function short_revision(kind, value) {
        if (kind == "ks" && value ~ /@sha1:/) return substr(value, length(value) - 6)
        return value
      }

      function row(i,    c, prefix, value) {
        prefix = color(cell[i,5], cell[i,4])
        if (prefix) printf "%s", prefix
        for (c = 1; c <= 6; c++) {
          value = cell[i,c]
          if (c == 6) value = ellipsize(value, width[c])
          printf "%-*s%s", width[c], value, c < 6 ? "   " : ""
        }
        if (prefix) printf "%s", reset
        printf "\n"
      }

      BEGIN {
        bold = "\033[1m"
        red = "\033[31m"
        yellow = "\033[33m"
        gray = "\033[2m"
        reset = "\033[0m"

        split(names, item, "\n")
        for (i in item) wanted[item[i]] = 1
        header[1]="NAMESPACE"; header[2]="NAME"; header[3]="REVISION"; header[4]="SUSPENDED"; header[5]="READY"; header[6]="MESSAGE"
        for (i = 1; i <= 6; i++) width[i] = length(header[i])
      }
      !NF || $1 != show { next }
      names && $1 == "ks" && !wanted[$3] { next }
      names && $1 == "hr" && !wanted[$2] && !wanted[$3] { next }
      {
        msg = $7
        if ($1 == "ks") sub(/Applied revision.*/, "Applied revision", msg); else sub(/[[:space:]]+for release.*/, "", msg)
        rows++
        cell[rows,1] = $2
        cell[rows,2] = $3
        cell[rows,3] = short_revision($1, $4)
        cell[rows,4] = bool($5, "False")
        cell[rows,5] = bool($6, "Unknown")
        cell[rows,6] = msg ? msg : "."
        for (i = 1; i <= 6; i++) if (length(cell[rows,i]) > width[i]) width[i] = length(cell[rows,i])
      }
      END {
        fixed = 15
        for (i = 1; i <= 5; i++) fixed += width[i]
        available = cols - fixed - 1
        if (available < length(header[6])) available = length(header[6])
        if (width[6] > available) width[6] = available

        printf "%s", bold
        for (i = 1; i <= 6; i++) printf "%-*s%s", width[i], header[i], i < 6 ? "   " : reset "\n"
        for (i = 1; i <= rows; i++) row(i)
      }'
}
draw_app() {
  local deps names

  deps="$(
    kubectl get kustomizations.kustomize.toolkit.fluxcd.io "$1" \
      --namespace flux-system \
      --output jsonpath='{range .spec.dependsOn[*]}{.name}{"\n"}{end}' 2>/dev/null || true
  )"
  names="$(printf '%s\n%s\n' "$1" "$deps" | awk 'NF && !seen[$0]++')"

  line '%s[%s]%s\t(q) Exit' "$ansi_pink" "$1" "$ansi_reset"
  blank_line
  flux tree kustomization "$1" -n flux-system 2>/dev/null \
    | awk -v bold="$ansi_bold" -v reset="$ansi_reset" 'NR == 1 { print bold $0 reset; next } { print }' \
    | lines || line 'tree unavailable'
  blank_line
  line '%sDependencies:%s' "$ansi_bold" "$ansi_reset"
  { [ -n "$deps" ] && printf '%s\n' "$deps" | sed 's/^/  - /' || printf '  - no dependencies\n'; } | lines

  blank_line
  line '%s[Kustomizations]%s' "$ansi_green" "$ansi_reset"
  blank_line
  table ks "$names" | lines

  blank_line
  line '%s[HelmReleases]%s' "$ansi_green" "$ansi_reset"
  blank_line
  table hr "$names" | lines
}

draw_global() {
  [ "${mode:-ks}" = ks ] && title='[Kustomizations]' || title='[HelmReleases]'

  line '%s%-22s%s%-18s%s' "$ansi_green" "$title" "$ansi_reset" "(t) Toggle" "(q) Exit"
  blank_line
  table "${mode:-ks}" | lines
}

render_frame() {
  [ -n "${1:-}" ] && draw_app "${1:-}" || draw_global
}

draw() {
  local frame_line frame_text
  local -a frame_lines

  frame_lines=()
  while IFS= read -r frame_line; do
    frame_lines+=("$frame_line")
  done < <(render_frame "${1:-}")
  printf -v frame_text '%s\n' "${frame_lines[@]}"

  if [ "$frame_text" = "${last_frame_text:-}" ]; then
    return
  fi

  clear_terminal
  printf '%s' "$frame_text"
  last_frame_text="$frame_text"
}

read_keys() {
  local key

  while IFS= read -rsn1 -t 0.02 -u 3 key; do
    case "$key" in
      q|Q) exit 0 ;;
      t|T|$'	')
        [ "${mode:-ks}" = ks ] && mode=hr || mode=ks
        last_frame_text=""
        last_draw=-1
        ;;
    esac
  done
}

exec 3< /dev/tty
stty_state="$(stty -g < /dev/tty 2>/dev/null || true)"
stty -echo -icanon time 0 min 0 < /dev/tty 2>/dev/null || true
tput rmam 2>/dev/null || true
trap cleanup EXIT
trap 'exit 130' INT TERM

last_draw=-1
clear_terminal
while true; do
  if [ "$SECONDS" != "$last_draw" ]; then
    draw "${1:-}"
    last_draw="$SECONDS"
  fi

  read_keys
  sleep 0.03
done
