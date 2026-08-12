#!/usr/bin/env bash
# Install git-delta from GitHub releases.
set -euo pipefail

BIS_TOOL="delta"
BIS_DESCRIPTION="Install git-delta from a verified GitHub release."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

get_arch() {
  case "$(uname -m)" in
  x86_64) echo x86_64-unknown-linux-gnu ;;
  aarch64 | arm64) echo aarch64-unknown-linux-gnu ;;
  *) bis_die "unsupported architecture: $(uname -m)" ;;
  esac
}

main() {
  local repo="dandavison/delta" arch version tag asset archive binary source
  [[ "$(uname -s)" == Linux ]] || bis_die "only Linux is supported"
  bis_require curl tar install
  arch=$(get_arch)
  if [[ -n "$BIS_VERSION" ]]; then
    version=${BIS_VERSION#v}
    tag=$version
  else
    tag=$(bis_github_latest_tag "$repo")
    version=${tag#v}
  fi
  binary="$BIS_PREFIX/bin/delta"
  bis_skip_if_installed "$binary" "$version" --version && return 0

  bis_make_temp_dir
  asset="delta-${version}-${arch}.tar.gz"
  archive="$BIS_TMP_DIR/$asset"
  bis_download_github_asset "$repo" "$tag" "$asset" "$archive"
  ((BIS_DRY_RUN)) && return 0
  bis_safe_extract_tar "$archive" "$BIS_TMP_DIR/extracted"
  source=$(find "$BIS_TMP_DIR/extracted" -type f -name delta -print -quit)
  [[ -n "$source" ]] || bis_die "delta binary missing from archive"
  bis_install_file "$source" "$binary"
  "$binary" --version
  bis_mark_installed "$version"
}

main
