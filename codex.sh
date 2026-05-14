#!/usr/bin/env bash
# Install the latest OpenAI Codex CLI (openai/codex) from GitHub releases into ~/.local/bin
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
REPO="openai/codex"
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
  x86_64) echo "x86_64-unknown-linux-musl" ;;
  aarch64) echo "aarch64-unknown-linux-musl" ;;
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
  local arch version tag download_url

  arch=$(get_arch)

  if [[ -n "$VERSION" ]]; then
    version="${VERSION#rust-v}"
    version="${version#v}"
    echo "Using specified version: $version"
  else
    echo "Fetching latest release info..."
    tag=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
      grep -oP '"tag_name":\s*"\K[^"]+')
    version="${tag#rust-v}"
    echo "Latest version: $version"
  fi

  tag="rust-v${version}"
  download_url="https://github.com/${REPO}/releases/download/${tag}/codex-${arch}.tar.gz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/codex.tar.gz" "$download_url"; then
    echo "Error: failed to download version '${version}'." >&2
    echo "Expected format: '0.121.0' (no 'v' prefix). See: https://github.com/${REPO}/releases" >&2
    exit 1
  fi
  tar xzf "$TMP_DIR/codex.tar.gz" -C "$TMP_DIR"

  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO install -m 755 "$TMP_DIR/codex-${arch}" "$INSTALL_DIR/codex"

  echo "codex ${version} installed to ${INSTALL_DIR}/codex"
  "$INSTALL_DIR/codex" --version
}

main
