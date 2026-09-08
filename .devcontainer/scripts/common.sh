download_github_release_asset() {
  local repo="$1"
  local match_filter="$2"
  local arch="${3:-}"
  local api_url="https://api.github.com/repos/${repo}/releases/latest"
  local download_url

  download_url="$(
    curl -fsSL "$api_url" \
      | jq -r --arg arch "$arch" "$match_filter" \
      | head -n1
  )"

  if [ -z "$download_url" ]; then
    echo "Unable to find a matching release asset for ${repo}" >&2
    return 1
  fi

  curl -fsSLO "$download_url"
  printf '%s\n' "${download_url##*/}"
}

run_step() {
  local label="$1"
  local log_file
  shift

  log_file="$(mktemp)"
  printf '%s\n' "$label"

  if "$@" >"$log_file" 2>&1; then
    rm -f "$log_file"
    return 0
  fi

  cat "$log_file" >&2
  rm -f "$log_file"
  return 1
}
