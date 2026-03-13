#!/usr/bin/env bash
# Install zmx (https://github.com/neurosnap/zmx) into ~/.local/bin
set -euo pipefail

VERSION="0.4.1"
INSTALL_DIR="$HOME/.local/bin"

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
  local os arch download_url

  os=$(get_os)
  arch=$(get_arch)
  download_url="https://zmx.sh/a/zmx-${VERSION}-${os}-${arch}.tar.gz"

  echo "Downloading zmx ${VERSION} for ${os}/${arch}..."

  TMP_DIR=$(mktemp -d)

  curl -fsSL -o "$TMP_DIR/zmx.tar.gz" "$download_url"
  tar xzf "$TMP_DIR/zmx.tar.gz" -C "$TMP_DIR"

  mkdir -p "$INSTALL_DIR"
  install -m 755 "$TMP_DIR/zmx" "$INSTALL_DIR/zmx"

  echo "zmx ${VERSION} installed to ${INSTALL_DIR}/zmx"
}

main "$@"
