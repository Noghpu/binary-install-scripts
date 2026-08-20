#!/usr/bin/env bash
# Install kanata from GitHub releases.
# uninstall-note: a systemd unit or drop-in may still point ExecStart here.
set -euo pipefail

BIS_TOOL="kanata"
BIS_DESCRIPTION="Install kanata from a verified GitHub release."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

main() {
  local repo="jtroo/kanata" version tag asset archive binary
  [[ "$(uname -s)" == Linux ]] || bis_die "only Linux is supported"
  # Upstream publishes one Linux archive and it is x86-64 only.
  [[ "$(uname -m)" == x86_64 ]] || bis_die "unsupported architecture: $(uname -m)"
  bis_require curl unzip install

  if [[ -n "$BIS_VERSION" ]]; then
    version=${BIS_VERSION#v}
    tag="v${version}"
  else
    tag=$(bis_github_latest_tag "$repo")
    version=${tag#v}
  fi
  binary="$BIS_PREFIX/bin/kanata"
  bis_skip_if_installed "$binary" "$version" --version && return 0

  bis_make_temp_dir
  asset="linux-binaries-x64.zip"
  archive="$BIS_TMP_DIR/$asset"
  bis_download_github_asset "$repo" "$tag" "$asset" "$archive"
  ((BIS_DRY_RUN)) && return 0
  bis_safe_extract_zip "$archive" "$BIS_TMP_DIR/extracted"
  # The archive also carries kanata_linux_cmd_allowed_x64, a build whose cmd
  # action can execute arbitrary programs from the keyboard configuration.
  # Install only the default build, which refuses to run commands.
  bis_install_file "$BIS_TMP_DIR/extracted/kanata_linux_x64" "$binary"
  "$binary" --version
  bis_mark_installed "$version"
}

main
