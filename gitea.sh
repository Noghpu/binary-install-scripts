#!/usr/bin/env bash
# Install the latest Gitea tea CLI on Ubuntu using prebuilt binaries
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
TEA_BINARY="tea"

get_architecture() {
  local arch
  arch=$(uname -m)
  case "$arch" in
  x86_64) echo "amd64" ;;
  aarch64) echo "arm64" ;;
  armv7l) echo "arm-7" ;;
  armv6l) echo "arm-6" ;;
  armv5l) echo "arm-5" ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
  esac
}

get_latest_version() {
  curl -fsSL "https://gitea.com/api/v1/repos/gitea/tea/releases?limit=1" |
    grep -oP '"tag_name":\s*"\K[^"]+'
}

main() {
  local arch version download_url tmp_file

  arch=$(get_architecture)
  echo "Detected architecture: $arch"

  echo "Fetching latest version..."
  version=$(get_latest_version)
  echo "Latest version: $version"

  download_url="https://gitea.com/gitea/tea/releases/download/${version}/tea-${version#v}-linux-${arch}"
  echo "Downloading from: $download_url"

  tmp_file=$(mktemp)
  trap 'rm -f "$tmp_file"' EXIT

  curl -fsSL -o "$tmp_file" "$download_url"
  chmod +x "$tmp_file"

  echo "Installing to ${INSTALL_DIR}/${TEA_BINARY}..."
  sudo install -m 755 "$tmp_file" "${INSTALL_DIR}/${TEA_BINARY}"

  echo "tea $(tea --version) installed successfully"
}

main "$@"
