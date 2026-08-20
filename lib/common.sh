#!/usr/bin/env bash
# Shared runtime for the binary installer entry points.

if [[ -n "${BIS_COMMON_LOADED:-}" ]]; then
  return 0
fi
readonly BIS_COMMON_LOADED=1

# Consumed by each entry point after argument parsing.
# shellcheck disable=SC2034
BIS_VERSION=""
BIS_FORCE=0
BIS_DRY_RUN=0
BIS_SYSTEM=0
BIS_PREFIX="${BIS_PREFIX:-$HOME/.local}"
BIS_CACHE_DIR="${BIS_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/binary-install-scripts}"
BIS_TMP_DIR=""
BIS_RELEASE_JSON=""
BIS_TOOL="${BIS_TOOL:-tool}"
BIS_DESCRIPTION="${BIS_DESCRIPTION:-Install a prebuilt binary}"

bis_usage() {
  cat <<EOF
Usage: ${0##*/} [OPTIONS]

${BIS_DESCRIPTION}

Options:
  --version VERSION  Install a specific release instead of latest
  --prefix PATH      Install below PATH (default: ~/.local)
  --system           Install below /usr/local, using sudo when needed
  --force            Reinstall even when the requested version is present
  --dry-run          Resolve the release and print actions without changing files
  -h, --help         Show this help
EOF
}

bis_die() {
  echo "${BIS_TOOL}: $*" >&2
  exit 1
}

bis_parse_args() {
  local prefix_set=0
  while (($#)); do
    case "$1" in
    --version)
      (($# >= 2)) || bis_die "--version requires a value"
      BIS_VERSION="$2"
      shift 2
      ;;
    --prefix)
      (($# >= 2)) || bis_die "--prefix requires a value"
      [[ -n "$2" ]] || bis_die "--prefix cannot be empty"
      BIS_PREFIX="$2"
      prefix_set=1
      shift 2
      ;;
    --system)
      BIS_SYSTEM=1
      BIS_PREFIX="/usr/local"
      shift
      ;;
    --force)
      BIS_FORCE=1
      shift
      ;;
    --dry-run)
      BIS_DRY_RUN=1
      shift
      ;;
    -h | --help)
      bis_usage
      exit 0
      ;;
    *) bis_die "unknown option: $1 (try --help)" ;;
    esac
  done
  if ((BIS_SYSTEM && prefix_set)); then
    bis_die "--system and --prefix cannot be used together"
  fi
  : "$BIS_VERSION"
}

bis_require() {
  local command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || bis_die "required command not found: $command_name"
  done
}

bis_cleanup() {
  if [[ -n "$BIS_TMP_DIR" && -d "$BIS_TMP_DIR" ]]; then
    case "$BIS_TMP_DIR" in
    "${TMPDIR:-/tmp}"/binary-install.*) command rm -rf -- "$BIS_TMP_DIR" ;;
    *) echo "Refusing to remove unexpected temporary path: $BIS_TMP_DIR" >&2 ;;
    esac
  fi
}

bis_make_temp_dir() {
  [[ -n "$BIS_TMP_DIR" ]] && return 0
  BIS_TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/binary-install.XXXXXXXX")
  trap bis_cleanup EXIT INT TERM
}

bis_curl() {
  local -a args=(
    --fail
    --location
    --show-error
    --silent
    --retry 3
    --retry-delay 1
    --connect-timeout 15
    --proto '=https'
    --tlsv1.2
  )
  curl "${args[@]}" "$@"
}

bis_github_curl() {
  local -a auth=()
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  bis_curl "${auth[@]}" "$@"
}

bis_download() {
  local url=$1 output=$2
  echo "Downloading: $url"
  if ((BIS_DRY_RUN)); then
    return 0
  fi
  bis_curl --output "$output" "$url" || bis_die "download failed: $url"
}

bis_json_tag() {
  local json_file=$1
  if command -v jq >/dev/null 2>&1; then
    jq -er '.tag_name' "$json_file"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tag_name"])' "$json_file"
  else
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$json_file" | head -n 1
  fi
}

bis_json_asset_field() {
  local json_file=$1 asset_name=$2 field=$3
  if command -v jq >/dev/null 2>&1; then
    jq -er --arg name "$asset_name" --arg field "$field" \
      '.assets[] | select(.name == $name) | .[$field] // empty' "$json_file"
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$json_file" "$asset_name" "$field" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    release = json.load(stream)
for asset in release.get("assets", []):
    if asset.get("name") == sys.argv[2]:
        value = asset.get(sys.argv[3])
        if value:
            print(value)
            raise SystemExit(0)
raise SystemExit(1)
PY
  else
    return 1
  fi
}

bis_github_release() {
  local repo=$1 tag=${2:-}
  local endpoint cache_key cache_file

  bis_make_temp_dir
  BIS_RELEASE_JSON="$BIS_TMP_DIR/release.json"
  if [[ -n "$tag" ]]; then
    [[ "$tag" =~ ^[0-9A-Za-z._-]+$ ]] || bis_die "unsafe GitHub release tag: $tag"
    cache_key=${repo//\//_}
    cache_file="$BIS_CACHE_DIR/github/${cache_key}/${tag}.json"
    if [[ -s "$cache_file" ]]; then
      install -m 600 "$cache_file" "$BIS_RELEASE_JSON"
      if [[ "$(bis_json_tag "$BIS_RELEASE_JSON" 2>/dev/null || true)" == "$tag" ]]; then
        return 0
      fi
    fi
    endpoint="https://api.github.com/repos/${repo}/releases/tags/${tag}"
  else
    endpoint="https://api.github.com/repos/${repo}/releases/latest"
  fi
  bis_github_curl --header 'Accept: application/vnd.github+json' --output "$BIS_RELEASE_JSON" "$endpoint" ||
    bis_die "could not resolve GitHub release: ${repo}${tag:+@$tag}; set GITHUB_TOKEN if the API rate limit was reached"
  if [[ -n "$tag" && "$(bis_json_tag "$BIS_RELEASE_JSON" 2>/dev/null || true)" == "$tag" ]]; then
    mkdir -p "${cache_file%/*}"
    install -m 600 "$BIS_RELEASE_JSON" "$cache_file"
  fi
}

bis_github_latest_tag() {
  local repo=$1 effective tag
  effective=$(bis_github_curl --output /dev/null --write-out '%{url_effective}' \
    "https://github.com/${repo}/releases/latest") || bis_die "could not resolve latest release for $repo"
  tag=${effective##*/}
  [[ "$effective" == *"/releases/tag/"* && -n "$tag" ]] || bis_die "unexpected latest-release URL for $repo: $effective"
  echo "$tag"
}

bis_verify_sha256() {
  local file=$1 expected=$2 actual
  expected=${expected#sha256:}
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
  else
    bis_die "cannot verify SHA-256: install sha256sum or shasum"
  fi
  [[ "$actual" == "$expected" ]] || bis_die "SHA-256 mismatch for ${file##*/}"
  echo "Verified SHA-256: ${file##*/}"
}

bis_download_github_asset() {
  local repo=$1 tag=$2 asset_name=$3 output=$4
  local url digest

  if [[ ! -s "$BIS_RELEASE_JSON" ]] || [[ "$(bis_json_tag "$BIS_RELEASE_JSON" 2>/dev/null || true)" != "$tag" ]]; then
    bis_github_release "$repo" "$tag"
  fi
  url=$(bis_json_asset_field "$BIS_RELEASE_JSON" "$asset_name" browser_download_url) ||
    bis_die "release $repo@$tag has no asset named $asset_name"
  digest=$(bis_json_asset_field "$BIS_RELEASE_JSON" "$asset_name" digest 2>/dev/null || true)

  if ((BIS_DRY_RUN)); then
    echo "Would download: $url"
    return 0
  fi
  echo "Downloading: $url"
  bis_github_curl --output "$output" "$url" || bis_die "download failed: $url"
  if [[ "$digest" == sha256:* ]]; then
    bis_verify_sha256 "$output" "$digest"
  else
    echo "Warning: GitHub did not provide a SHA-256 digest for $asset_name" >&2
  fi
}

bis_safe_extract_tar() {
  local archive=$1 destination=$2
  local member
  while IFS= read -r member; do
    case "$member" in
    /* | ../* | */../* | */..) bis_die "unsafe archive member: $member" ;;
    esac
  done < <(tar tf "$archive")
  mkdir -p "$destination"
  tar xf "$archive" -C "$destination"
}

bis_safe_extract_zip() {
  local archive=$1 destination=$2
  local member
  while IFS= read -r member; do
    case "$member" in
    /* | ../* | */../* | */..) bis_die "unsafe archive member: $member" ;;
    esac
  done < <(unzip -Z1 "$archive")
  mkdir -p "$destination"
  unzip -q -o "$archive" -d "$destination"
}

bis_installed_version() {
  local binary=$1
  shift
  [[ -x "$binary" ]] || return 1
  "$binary" "$@" 2>&1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+(-[0-9A-Za-z.]+)*)?' | head -n 1
}

bis_skip_if_installed() {
  local binary=$1 expected=$2 receipt
  shift 2
  local actual
  ((BIS_FORCE)) && return 1
  receipt="$BIS_PREFIX/share/binary-install-scripts/${BIS_TOOL}.version"
  if [[ -x "$binary" && -f "$receipt" && "$(<"$receipt")" == "$expected" ]]; then
    echo "${BIS_TOOL} $expected is already installed at $binary"
    return 0
  fi
  actual=$(bis_installed_version "$binary" "$@" || true)
  if [[ "$actual" == "$expected" ]]; then
    echo "${BIS_TOOL} $expected is already installed at $binary"
    return 0
  fi
  return 1
}

bis_mark_installed() {
  local version=$1 receipt receipt_dir source
  ((BIS_DRY_RUN)) && return 0
  bis_make_temp_dir
  source="$BIS_TMP_DIR/${BIS_TOOL}.version"
  printf '%s\n' "$version" >"$source"
  receipt_dir="$BIS_PREFIX/share/binary-install-scripts"
  receipt="$receipt_dir/${BIS_TOOL}.version"
  # This directory holds nothing but receipts, so its mode is ours to set. A
  # --system install creates it through sudo, and a root umask of 077 would
  # otherwise leave it unreadable to the user whose next run wants to read it.
  bis_run_privileged install -d -m 755 "$receipt_dir"
  bis_install_file "$source" "$receipt" 644
}

bis_run_privileged() {
  if ((BIS_DRY_RUN)); then
    printf 'Would run:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  if ((BIS_SYSTEM)) && ((EUID != 0)); then
    sudo "$@"
  else
    "$@"
  fi
}

bis_install_file() {
  local source=$1 destination=$2 mode=${3:-755}
  bis_run_privileged mkdir -p "${destination%/*}"
  bis_run_privileged install -m "$mode" "$source" "$destination"
}
