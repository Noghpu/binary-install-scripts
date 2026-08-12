#!/usr/bin/env bash
# Install Git Credential Manager from GitHub releases.
# uninstall-note: also installs lib/git-credential-manager below the selected prefix
set -euo pipefail

BIS_TOOL="git-credential-manager"
BIS_DESCRIPTION="Install Git Credential Manager and its runtime libraries from a verified GitHub release."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

get_arch() {
  case "$(uname -m)" in
  x86_64) echo x64 ;;
  aarch64 | arm64) echo arm64 ;;
  *) bis_die "unsupported architecture: $(uname -m)" ;;
  esac
}

main() {
  local repo="git-ecosystem/git-credential-manager" arch version tag asset archive binary file runtime_dir
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
  binary="$BIS_PREFIX/bin/git-credential-manager"
  bis_skip_if_installed "$binary" "$version" --version && return 0

  bis_make_temp_dir
  asset="gcm-linux-${arch}-${version}.tar.gz"
  archive="$BIS_TMP_DIR/$asset"
  bis_download_github_asset "$repo" "$tag" "$asset" "$archive"
  ((BIS_DRY_RUN)) && return 0
  bis_safe_extract_tar "$archive" "$BIS_TMP_DIR/extracted"
  runtime_dir="$BIS_PREFIX/lib/git-credential-manager"
  for file in "$BIS_TMP_DIR"/extracted/*; do
    [[ -f "$file" ]] || continue
    if [[ "${file##*/}" == git-credential-manager ]]; then
      bis_install_file "$file" "$runtime_dir/${file##*/}" 755
    else
      bis_install_file "$file" "$runtime_dir/${file##*/}" 644
    fi
  done
  bis_run_privileged mkdir -p "$BIS_PREFIX/bin"
  bis_run_privileged ln -sfn ../lib/git-credential-manager/git-credential-manager "$binary"
  "$binary" --version
  bis_mark_installed "$version"
}

main
