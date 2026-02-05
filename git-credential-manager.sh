#!/usr/bin/env bash
# Install the latest git-credential-manager release into ~/.local/bin
set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
REPO="git-ecosystem/git-credential-manager"

get_architecture() {
  local arch
  arch=$(uname -m)
  case "$arch" in
  x86_64) echo "amd64" ;;
  aarch64) echo "arm64" ;;
  armv7l) echo "arm" ;;
  *)
    echo "Unsupported architecture: $arch" >&2
    exit 1
    ;;
  esac
}

main() {
  local download_url tmp_dir api_response

  echo "Fetching latest release info..."
  api_response=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
  # Extract tarball URL for linux + architecture (handles both _ and - separators)
  download_url=$(echo "$api_response" |
    grep -o '"browser_download_url": *"[^"]*"' |
    grep -i "linux" |
    grep '\.tar\.gz"' |
    grep -v 'symbols' |
    grep -v 'arm64' |
    head -1 |
    sed 's/.*"\(http[^"]*\)".*/\1/')

  echo "Downloading from: $download_url"

  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL -o "$tmp_dir/gcm.tar.gz" "$download_url"

  mkdir -p "$INSTALL_DIR"
  tar -xzf "$tmp_dir/gcm.tar.gz" -C "$INSTALL_DIR"

  echo "Installed to $INSTALL_DIR"

  if [[ -x "$INSTALL_DIR/git-credential-manager" ]]; then
    "$INSTALL_DIR/git-credential-manager" --version
    echo ""
    echo "To configure git, run:"
    echo "  git-credential-manager configure"
    echo ""
    echo "Ensure $INSTALL_DIR is in your PATH"
  fi
}

main "$@"
