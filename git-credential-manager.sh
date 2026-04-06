#!/usr/bin/env bash
# Install the latest git-credential-manager from GitHub releases into ~/.local/bin
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
REPO="git-ecosystem/git-credential-manager"

VERSION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
  --system)
    INSTALL_DIR="/usr/local/bin"
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
  x86_64) echo "x64" ;;
  aarch64) echo "arm64" ;;
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
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
      grep -oP '"tag_name":\s*"\K[^"]+')
    echo "Latest version: $version"
  fi

  download_url="https://github.com/${REPO}/releases/download/${version}/gcm-linux-${arch}-${version#v}.tar.gz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/gcm.tar.gz" "$download_url"; then
    echo "Error: failed to download version '${version}'." >&2
    echo "Expected format: 'v2.6.1' (with 'v' prefix). See: https://github.com/${REPO}/releases" >&2
    exit 1
  fi

  mkdir -p "$INSTALL_DIR"
  tar -xzf "$TMP_DIR/gcm.tar.gz" -C "$INSTALL_DIR"

  echo "git-credential-manager installed to ${INSTALL_DIR}"
  "$INSTALL_DIR/git-credential-manager" --version
}

main
