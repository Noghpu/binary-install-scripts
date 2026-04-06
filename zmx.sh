#!/usr/bin/env bash
# Install the latest zmx (https://github.com/neurosnap/zmx) into ~/.local/bin
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
REPO="neurosnap/zmx"

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

get_os() {
  case "$(uname -s)" in
  Linux) echo "linux" ;;
  Darwin) echo "macos" ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
  x86_64) echo "x86_64" ;;
  aarch64 | arm64) echo "aarch64" ;;
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
  local os arch version download_url

  os=$(get_os)
  arch=$(get_arch)

  if [[ -n "$VERSION" ]]; then
    version="${VERSION#v}"
    echo "Using specified version: $version"
  else
    echo "Fetching latest release info..."
    version=$(curl -fsSL "https://api.github.com/repos/${REPO}/tags" |
      grep -oP '"name":\s*"\Kv[0-9][^"]+' | head -1)
    version="${version#v}"
    echo "Latest version: $version"
  fi

  download_url="https://zmx.sh/a/zmx-${version}-${os}-${arch}.tar.gz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/zmx.tar.gz" "$download_url"; then
    echo "Error: failed to download version '${version}'." >&2
    echo "Expected format: 'v0.3.0' or '0.3.0' (v prefix is stripped automatically). See: https://github.com/${REPO}/releases" >&2
    exit 1
  fi
  tar xzf "$TMP_DIR/zmx.tar.gz" -C "$TMP_DIR"

  mkdir -p "$INSTALL_DIR"
  install -m 755 "$TMP_DIR/zmx" "$INSTALL_DIR/zmx"

  echo "zmx ${version} installed to ${INSTALL_DIR}/zmx"
  "$INSTALL_DIR/zmx" --version
}

main
