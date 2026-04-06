#!/usr/bin/env bash
# Install the latest git-delta (dandavison/delta) from GitHub releases into ~/.local/bin
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
REPO="dandavison/delta"

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
  x86_64) echo "x86_64-unknown-linux-gnu" ;;
  aarch64) echo "aarch64-unknown-linux-gnu" ;;
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

  download_url="https://github.com/${REPO}/releases/download/${version}/delta-${version}-${arch}.tar.gz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/delta.tar.gz" "$download_url"; then
    echo "Error: failed to download version '${version}'." >&2
    echo "Expected format: '0.18.2' (no 'v' prefix). See: https://github.com/${REPO}/releases" >&2
    exit 1
  fi
  tar xzf "$TMP_DIR/delta.tar.gz" -C "$TMP_DIR" --strip-components=1

  mkdir -p "$INSTALL_DIR"
  install -m 755 "$TMP_DIR/delta" "$INSTALL_DIR/delta"

  echo "delta ${version} installed to ${INSTALL_DIR}/delta"
  "$INSTALL_DIR/delta" --version
}

main
