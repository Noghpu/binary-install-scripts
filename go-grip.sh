#!/usr/bin/env bash
# Install go-grip from GitHub releases.
set -euo pipefail

BIS_TOOL="go-grip"
BIS_DESCRIPTION="Install go-grip from a verified GitHub release."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

get_arch() {
  case "$(uname -m)" in
  x86_64) echo amd64 ;;
  aarch64 | arm64) echo arm64 ;;
  *) bis_die "unsupported architecture: $(uname -m)" ;;
  esac
}

main() {
  local repo="chrishrb/go-grip" arch version tag asset archive binary help_text
  [[ "$(uname -s)" == Linux ]] || bis_die "only Linux is supported"
  bis_require curl tar install
  arch=$(get_arch)
  if [[ -n "$BIS_VERSION" ]]; then
    version=${BIS_VERSION#v}
    tag="v${version}"
  else
    tag=$(bis_github_latest_tag "$repo")
    version=${tag#v}
  fi
  binary="$BIS_PREFIX/bin/go-grip"
  bis_skip_if_installed "$binary" "$version" --version && return 0

  bis_make_temp_dir
  asset="go-grip-v${version}-linux-${arch}.tar.gz"
  archive="$BIS_TMP_DIR/$asset"
  bis_download_github_asset "$repo" "$tag" "$asset" "$archive"
  ((BIS_DRY_RUN)) && return 0
  bis_safe_extract_tar "$archive" "$BIS_TMP_DIR/extracted"
  bis_install_file "$BIS_TMP_DIR/extracted/go-grip" "$binary"
  help_text=$("$binary" --help 2>&1)
  printf '%s\n' "${help_text%%$'\n'*}"
  bis_mark_installed "$version"
}

main
