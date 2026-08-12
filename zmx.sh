#!/usr/bin/env bash
# Install zmx from GitHub releases.
set -euo pipefail

BIS_TOOL="zmx"
BIS_DESCRIPTION="Install zmx from a verified GitHub release on Linux or macOS."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

get_os() {
  case "$(uname -s)" in
  Linux) echo linux ;;
  Darwin) echo macos ;;
  *) bis_die "unsupported OS: $(uname -s)" ;;
  esac
}

get_arch() {
  case "$(uname -m)" in
  x86_64) echo x86_64 ;;
  aarch64 | arm64) echo aarch64 ;;
  *) bis_die "unsupported architecture: $(uname -m)" ;;
  esac
}

main() {
  local repo="neurosnap/zmx" os arch version tag asset archive binary
  bis_require curl tar install
  os=$(get_os)
  arch=$(get_arch)
  if [[ -n "$BIS_VERSION" ]]; then
    version=${BIS_VERSION#v}
    tag="v${version}"
  else
    tag=$(bis_github_latest_tag "$repo")
    version=${tag#v}
  fi
  binary="$BIS_PREFIX/bin/zmx"
  bis_skip_if_installed "$binary" "$version" --version && return 0

  bis_make_temp_dir
  asset="zmx-${version}-${os}-${arch}.tar.gz"
  archive="$BIS_TMP_DIR/$asset"
  bis_download_github_asset "$repo" "$tag" "$asset" "$archive"
  ((BIS_DRY_RUN)) && return 0
  bis_safe_extract_tar "$archive" "$BIS_TMP_DIR/extracted"
  bis_install_file "$BIS_TMP_DIR/extracted/zmx" "$binary"
  "$binary" --version
  bis_mark_installed "$version"
}

main
