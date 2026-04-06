#!/usr/bin/env bash
# Install the nightly build of Neovim from GitHub releases into ~/.local
set -euo pipefail

INSTALL_DIR="$HOME/.local"
REPO="neovim/neovim"

TAG="nightly"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --system)
    INSTALL_DIR="/usr/local"
    shift
    ;;
  --version)
    case "$2" in
    nightly | stable) TAG="$2" ;;
    *) TAG="v${2#v}" ;;
    esac
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
  local arch download_url

  arch=$(get_arch)

  echo "Using tag: $TAG"
  download_url="https://github.com/${REPO}/releases/download/${TAG}/nvim-linux-${arch}.tar.gz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  if ! curl -fsSL -o "$TMP_DIR/nvim.tar.gz" "$download_url"; then
    echo "Error: failed to download tag '${TAG}'." >&2
    echo "Expected format: 'v0.10.0', 'nightly', or 'stable'. See: https://github.com/${REPO}/releases" >&2
    exit 1
  fi
  tar xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR" --strip-components=1

  mkdir -p "$INSTALL_DIR"
  cp -rf "$TMP_DIR/bin/"* "$INSTALL_DIR/bin/"
  cp -rf "$TMP_DIR/lib/"* "$INSTALL_DIR/lib/"
  cp -rf "$TMP_DIR/share/"* "$INSTALL_DIR/share/"

  echo "neovim (${TAG}) installed to ${INSTALL_DIR}"
  "$INSTALL_DIR/bin/nvim" --version | head -1
}

main
