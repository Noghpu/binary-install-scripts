#!/usr/bin/env bash
# Install the latest Gitea tea CLI from Gitea releases into ~/.local/bin
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
SUDO=""

VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --system)
    INSTALL_DIR="/usr/local/bin"
    if [[ $EUID -ne 0 ]]; then SUDO="sudo"; sudo -v; fi
    shift
    ;;
  --version)
    VERSION="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1" >&2
    exit 1
    ;;
  esac
done

get_arch() {
  case "$(uname -m)" in
  x86_64) echo "amd64" ;;
  aarch64) echo "arm64" ;;
  armv7l) echo "arm-7" ;;
  armv6l) echo "arm-6" ;;
  armv5l) echo "arm-5" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
  esac
}

TMP_DIR=""
cleanup() { [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

main() {
  local arch version download_url

  arch=$(get_arch)

  if [[ -n "$VERSION" ]]; then
    version="v${VERSION#v}"
    echo "Using specified version: $version"
  else
    echo "Fetching latest release info..."
    version=$(curl -fsSL "https://gitea.com/api/v1/repos/gitea/tea/releases?limit=1" |
      grep -oP '"tag_name":\s*"\K[^"]+')
    echo "Latest version: $version"
  fi

  download_url="https://gitea.com/gitea/tea/releases/download/${version}/tea-${version#v}-linux-${arch}"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/tea" "$download_url"; then
    echo "Error: failed to download version '${version}'." >&2
    echo "Expected format: 'v0.9.0' (with 'v' prefix). See: https://gitea.com/gitea/tea/releases" >&2
    exit 1
  fi

  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO install -m 755 "$TMP_DIR/tea" "$INSTALL_DIR/tea"

  echo "tea ${version} installed to ${INSTALL_DIR}/tea"
  "$INSTALL_DIR/tea" --version
}

main
