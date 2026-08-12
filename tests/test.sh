#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

for script in "$repo_dir"/*.sh "$repo_dir"/lib/*.sh "$repo_dir"/tests/*.sh; do
  bash -n "$script" || fail "syntax: ${script#"$repo_dir/"}"
done

for script in "$repo_dir"/*.sh; do
  name=${script##*/}
  output=$(bash "$script" --help) || {
    fail "$name --help"
    continue
  }
  [[ "$output" == *"--version VERSION"* ]] || fail "$name help omits --version"
  [[ "$output" == *"--dry-run"* ]] || fail "$name help omits --dry-run"

  if bash "$script" --version >/dev/null 2>&1; then
    fail "$name accepts a missing --version value"
  fi
  if bash "$script" --definitely-invalid >/dev/null 2>&1; then
    fail "$name accepts an unknown option"
  fi
  if bash "$script" --system --prefix /tmp/test >/dev/null 2>&1; then
    fail "$name accepts conflicting destination options"
  fi
done

# Exercise receipt-based idempotency and first-version extraction without
# depending on any upstream network service.
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/binary-install-tests.XXXXXXXX")
cleanup() {
  case "$test_dir" in
  "${TMPDIR:-/tmp}"/binary-install-tests.*) command rm -rf -- "$test_dir" ;;
  *) fail "refusing to clean unexpected test path: $test_dir" ;;
  esac
}
trap cleanup EXIT

# shellcheck source=lib/common.sh
source "$repo_dir/lib/common.sh"
BIS_TOOL=test-tool
BIS_PREFIX=$test_dir
mkdir -p "$test_dir/bin"
mock_binary="$test_dir/bin/test-tool"
printf '#!/usr/bin/env bash\necho "tool 1.2.3 dependency 9.8.7"\n' >"$mock_binary"
chmod 755 "$mock_binary"
actual=$(bis_installed_version "$mock_binary" --version)
[[ "$actual" == 1.2.3 ]] || fail "version parser returned $actual instead of 1.2.3"

mkdir -p "$test_dir/share/binary-install-scripts"
printf '4.5.6\n' >"$test_dir/share/binary-install-scripts/test-tool.version"
bis_skip_if_installed "$mock_binary" 4.5.6 --version >/dev/null || fail "matching receipt was not skipped"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x -P "$repo_dir" "$repo_dir"/*.sh "$repo_dir"/lib/*.sh "$repo_dir"/tests/*.sh ||
    fail "shellcheck"
else
  echo "SKIP: shellcheck is not installed"
fi

if ((failures)); then
  echo "$failures test(s) failed" >&2
  exit 1
fi
echo "All tests passed"
