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

extract_archive() {
  local asset_name="$1"

  case "$asset_name" in
  *.tar.gz | *.tgz)
    tar -xzf "$asset_name"
    ;;
  *.zip)
    unzip -o "$asset_name"
    ;;
  *)
    echo "Unsupported archive format: $asset_name" >&2
    return 1
    ;;
  esac
}

linux_arch() {
  case "$(uname -m)" in
  aarch64 | arm64)
    echo "arm64"
    ;;
  x86_64 | amd64)
    echo "amd64"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
  esac
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
