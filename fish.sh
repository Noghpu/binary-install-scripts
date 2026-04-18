#!/usr/bin/env bash
# Install the latest fish shell from GitHub releases into ~/.local/bin
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
REPO="fish-shell/fish-shell"
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
  x86_64) echo "x86_64" ;;
  aarch64) echo "aarch64" ;;
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
    version="${VERSION#v}"
    echo "Using specified version: $version"
  else
    echo "Fetching latest release info..."
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
      grep -oP '"tag_name":\s*"\K[^"]+')
    echo "Latest version: $version"
  fi

  download_url="https://github.com/${REPO}/releases/download/${version}/fish-${version}-linux-${arch}.tar.xz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/fish.tar.xz" "$download_url"; then
    echo "Error: failed to download version '${version}'." >&2
    echo "Expected format: '4.0.0' (no 'v' prefix). See: https://github.com/${REPO}/releases" >&2
    exit 1
  fi
  tar xf "$TMP_DIR/fish.tar.xz" -C "$TMP_DIR"

  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO install -m 755 "$TMP_DIR/fish" "$INSTALL_DIR/fish"

  echo "fish ${version} installed to ${INSTALL_DIR}/fish"
  "$INSTALL_DIR/fish" --version
}

main
