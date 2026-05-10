#!/usr/bin/env bash
set -euo pipefail

ansi_bold="$(printf '\033[1m')"
ansi_green="$(printf '\033[32m')"
ansi_pink="$(printf '\033[95m')"
ansi_reset="$(printf '\033[0m')"

cleanup() {
  stty "${stty_state:-sane}" < /dev/tty 2>/dev/null || true
  tput cnorm 2>/dev/null || true
  tput rmcup 2>/dev/null || true
}

line() {
  tput el
  printf "$@"
  tput el
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

table() {
  kind="$1"
  names="${2:-}"

  {
    flux get kustomizations --all-namespaces --no-header | sed 's/^/ks\t/'
    flux get helmreleases --all-namespaces --no-header | sed 's/^/hr\t/'
  } \
    | awk -F '\t|[[:space:]][[:space:]]+' \
        -v show="$kind" \
        -v names="$names" '
      function color(ready, suspended) {
        if (suspended == "True" && ready == "False") return gray red
        if (suspended == "True" && ready == "Unknown") return gray yellow
        if (suspended == "True") return gray
        if (ready == "False") return red
        if (ready == "Unknown") return yellow
        return ""
      }

      function row(i,    c, prefix) {
        prefix = color(cell[i,5], cell[i,4])
        if (prefix) printf "%s", prefix
        for (c = 1; c <= 6; c++) {
          printf "%-*s%s", width[c], cell[i,c], c < 6 ? "   " : ""
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
      !NF { next }
      names && $1 == "ks" && !wanted[$3] { next }
      names && $1 == "hr" && !wanted[$2] && !wanted[$3] { next }
      {
        msg = $7
        if ($1 == "ks") sub(/Applied revision.*/, "Applied revision", msg); else sub(/[[:space:]]+for release.*/, "", msg)
        if (length(msg) > 96) msg = substr(msg, 1, 93) "..."
        rows++; kind[rows]=$1; cell[rows,1]=$2; cell[rows,2]=$3; cell[rows,3]=$4; cell[rows,4]=$5; cell[rows,5]=$6; cell[rows,6]=msg
        for (i = 1; i <= 6; i++) if (length(cell[rows,i]) > width[i]) width[i] = length(cell[rows,i])
      }
      END { printf "%s", bold; for (i = 1; i <= 6; i++) printf "%-*s%s", width[i], header[i], i < 6 ? "   " : reset "\n"; for (i = 1; i <= rows; i++) if (kind[i] == show) row(i) }'
}

draw_app() {
  local deps names

  deps="$(
    kubectl get kustomizations.kustomize.toolkit.fluxcd.io "$1" \
      --namespace flux-system \
      --output jsonpath='{range .spec.dependsOn[*]}{.name}{"\n"}{end}' 2>/dev/null || true
  )"
  names="$(printf '%s\n%s\n' "$1" "$deps" | awk 'NF && !seen[$0]++')"

  tput cup 0 0

  line '%s[%s]%s\t(q) Exit' "$ansi_pink" "$1" "$ansi_reset"
  printf '\n'
  flux tree kustomization "$1" -n flux-system 2>/dev/null \
    | awk -v bold="$ansi_bold" -v reset="$ansi_reset" 'NR == 1 { print bold $0 reset; next } { print }' \
    | lines || line 'tree unavailable'
  printf '\n'
  line '%sDependencies:%s' "$ansi_bold" "$ansi_reset"
  { [ -n "$deps" ] && printf '%s\n' "$deps" | sed 's/^/  - /' || printf '  - no dependencies\n'; } | lines

  printf '\n'
  line '%s[Kustomizations]%s' "$ansi_green" "$ansi_reset"
  printf '\n'
  table ks "$names" | lines

  printf '\n'
  line '%s[HelmReleases]%s' "$ansi_green" "$ansi_reset"
  printf '\n'
  table hr "$names" | lines
  tput ed
}

draw_global() {
  [ "${mode:-ks}" = ks ] && title='[Kustomizations]' || title='[HelmReleases]'

  tput cup 0 0

  line '%s%-22s%s%-28s%s' "$ansi_green" "$title" "$ansi_reset" "(PgUp/PgDn) Toggle" "(q) Exit"
  printf '\n'
  table "${mode:-ks}" | lines
  tput ed
}

read_keys() {
  local key seq next

  while IFS= read -rsn1 -t 0.02 -u 3 key; do
    case "$key" in
      q|Q) exit 0 ;;
      $'\e')
        seq=""
        while IFS= read -rsn1 -t 0.05 -u 3 next; do seq="${seq}${next}"; [ "$next" = "~" ] && break; done
        case "$seq" in
          "[5~"|"[6~")
            [ "${mode:-ks}" = ks ] && mode=hr || mode=ks
            last_draw=-1
            ;;
        esac
        ;;
    esac
  done
}

exec 3< /dev/tty
stty_state="$(stty -g < /dev/tty 2>/dev/null || true)"
stty -echo -icanon time 0 min 0 < /dev/tty 2>/dev/null || true
tput smcup 2>/dev/null || true
tput civis 2>/dev/null || true
trap cleanup EXIT
trap 'exit 130' INT TERM

last_draw=-1
while true; do
  if [ "$SECONDS" != "$last_draw" ]; then
    [ -n "${1:-}" ] && draw_app "${1:-}" || draw_global
    last_draw="$SECONDS"
  fi

  read_keys
  sleep 0.03
done
