#!/usr/bin/env bash
# Install Neovim from GitHub releases.
# uninstall-note: also installs lib/nvim and share/nvim below the selected prefix
set -euo pipefail

BIS_TOOL="neovim"
BIS_DESCRIPTION="Install Neovim stable, nightly, or an exact verified GitHub release."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

get_arch() {
  case "$(uname -m)" in
  x86_64) echo x86_64 ;;
  aarch64 | arm64) echo arm64 ;;
  *) bis_die "unsupported architecture: $(uname -m)" ;;
  esac
}

main() {
  local repo="neovim/neovim" arch requested tag version asset archive binary tree path relative mode
  [[ "$(uname -s)" == Linux ]] || bis_die "only Linux is supported"
  bis_require curl tar install
  arch=$(get_arch)
  requested=${BIS_VERSION:-nightly}
  case "$requested" in
  nightly | stable)
    tag=$requested
    version=$requested
    ;;
  *)
    version=${requested#v}
    tag="v${version}"
    ;;
  esac
  binary="$BIS_PREFIX/bin/nvim"
  if [[ "$version" != nightly && "$version" != stable ]]; then
    bis_skip_if_installed "$binary" "$version" --version && return 0
  fi

  bis_make_temp_dir
  asset="nvim-linux-${arch}.tar.gz"
  archive="$BIS_TMP_DIR/$asset"
  bis_download_github_asset "$repo" "$tag" "$asset" "$archive"
  ((BIS_DRY_RUN)) && return 0
  bis_safe_extract_tar "$archive" "$BIS_TMP_DIR/extracted"
  tree=$(find "$BIS_TMP_DIR/extracted" -mindepth 1 -maxdepth 1 -type d -print -quit)
  [[ -n "$tree" ]] || bis_die "Neovim archive did not contain an install tree"
  while IFS= read -r -d '' path; do
    relative=${path#"$tree/"}
    [[ "$relative" != "$path" ]] || continue
    mode=644
    [[ -x "$path" ]] && mode=755
    bis_install_file "$path" "$BIS_PREFIX/$relative" "$mode"
  done < <(find "$tree" -type f -print0)
  "$binary" --version | head -n 1
  bis_mark_installed "$version"
}

main
