#!/usr/bin/env bash
# Install the nightly build of Neovim from GitHub releases into ~/.local
set -euo pipefail

INSTALL_DIR="$HOME/.local"
REPO="neovim/neovim"

if [[ "${1:-}" == "--system" ]]; then
  INSTALL_DIR="/usr/local"
  shift
fi
TAG="nightly"

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

  download_url="https://github.com/${REPO}/releases/download/${TAG}/nvim-linux-${arch}.tar.gz"
  echo "Downloading from: $download_url"

  TMP_DIR=$(mktemp -d)
  curl -fsSL -o "$TMP_DIR/nvim.tar.gz" "$download_url"
  tar xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR" --strip-components=1

  mkdir -p "$INSTALL_DIR"
  cp -rf "$TMP_DIR/bin/"* "$INSTALL_DIR/bin/"
  cp -rf "$TMP_DIR/lib/"* "$INSTALL_DIR/lib/"
  cp -rf "$TMP_DIR/share/"* "$INSTALL_DIR/share/"

  echo "neovim (nightly) installed to ${INSTALL_DIR}"
  "$INSTALL_DIR/bin/nvim" --version | head -1
}

main "$@"
