#!/usr/bin/env bash
# Install the Gitea tea CLI from checksummed release artifacts.
set -euo pipefail

BIS_TOOL="tea"
BIS_DESCRIPTION="Install Gitea's tea CLI and verify its published SHA-256 checksum."
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
bis_parse_args "$@"

get_arch() {
  case "$(uname -m)" in
  x86_64) echo amd64 ;;
  aarch64 | arm64) echo arm64 ;;
  armv7l) echo arm-7 ;;
  armv6l) echo arm-6 ;;
  armv5l) echo arm-5 ;;
  *) bis_die "unsupported architecture: $(uname -m)" ;;
  esac
}

latest_tag() {
  local json
  bis_make_temp_dir
  json="$BIS_TMP_DIR/tea-release.json"
  bis_curl --output "$json" 'https://gitea.com/api/v1/repos/gitea/tea/releases?limit=1' ||
    bis_die "could not resolve the latest tea release"
  if command -v jq >/dev/null 2>&1; then
    jq -er '.[0].tag_name' "$json"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[0]["tag_name"])' "$json"
  else
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json" | head -n 1
  fi
}

main() {
  local arch version tag asset base archive checksum expected binary
  [[ "$(uname -s)" == Linux ]] || bis_die "only Linux is supported"
  bis_require curl xz install
  arch=$(get_arch)
  if [[ -n "$BIS_VERSION" ]]; then
    version=${BIS_VERSION#v}
    tag="v${version}"
  else
    tag=$(latest_tag)
    version=${tag#v}
  fi
  binary="$BIS_PREFIX/bin/tea"
  bis_skip_if_installed "$binary" "$version" --version && return 0

  bis_make_temp_dir
  asset="tea-${version}-linux-${arch}.xz"
  base="https://gitea.com/gitea/tea/releases/download/${tag}"
  archive="$BIS_TMP_DIR/$asset"
  checksum="$BIS_TMP_DIR/$asset.sha256"
  bis_download "$base/$asset" "$archive"
  bis_download "$base/$asset.sha256" "$checksum"
  ((BIS_DRY_RUN)) && return 0
  expected=$(awk 'NR == 1 {print $1}' "$checksum")
  [[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]] || bis_die "invalid checksum published for $asset"
  bis_verify_sha256 "$archive" "$expected"
  xz -dc "$archive" >"$BIS_TMP_DIR/tea"
  bis_install_file "$BIS_TMP_DIR/tea" "$binary"
  "$binary" --version
  bis_mark_installed "$version"
}

main
