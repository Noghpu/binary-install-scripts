# binary-install-scripts — design guide

Each script installs one upstream tool's prebuilt binary into `~/.local/bin`
(default) or `/usr/local/bin` (`--system`). When `--system` is used, the script
self-elevates via `sudo` for the install step only (download/extract stay
unprivileged). No package manager, no build step, no checksums, no idempotency.

**To write a new script: copy the closest existing one and adapt per this guide.**

## Canonical shape (all scripts)

1. `#!/usr/bin/env bash`; line 2 = one-line purpose comment; `set -euo pipefail`.
2. Top-level constants: `INSTALL_DIR="$HOME/.local/bin"`, `REPO="owner/repo"`, `SUDO=""`, `VERSION=""`.
3. Flag parser (hand-rolled `while`/`case`): only `--system` and `--version <V>`. Unknown → `exit 1`. No `--help`, no short flags, no `getopts`. `--system` sets `INSTALL_DIR="/usr/local/bin"` and, if `EUID != 0`, sets `SUDO="sudo"` and runs `sudo -v` to prime the credential cache before any download.
4. `get_arch()` — `case "$(uname -m)"` mapping `x86_64` and `aarch64` to the tokens upstream uses; default branch prints `Unsupported architecture: $(uname -m)` to stderr and exits 1.
5. Cleanup prelude (must appear before `main`):
   ```bash
   TMP_DIR=""
   cleanup() { [[ -n "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
   trap cleanup EXIT
   ```
6. `main()` with `local arch version download_url`:
   - resolve `version` (see §Version source)
   - build `download_url`
   - `TMP_DIR=$(mktemp -d)`; download with `curl -fsSL -o ... "$download_url"` wrapped in `if ! curl ...; then` that prints the expected version format and the releases URL on failure
   - extract (see §Extraction)
   - `$SUDO mkdir -p "$INSTALL_DIR"` then `$SUDO install -m 755 ...` (prefix all write-to-install-dir commands with `$SUDO`; leave download/extract unprivileged)
   - final two lines: `echo "<tool> $version installed to $INSTALL_DIR/<tool>"` and `"$INSTALL_DIR/<tool>" --version` as a smoke test
7. Last line of file: `main`.

Plain `echo` for info, `echo ... >&2` for errors. No colors, no log levels.

`git-delta.sh` is the cleanest reference for the canonical form.

## Version tag camp (pick one per script)

Upstream tags are usually `vX.Y.Z`; asset filenames differ:

- **Strip** (fish, delta, zmx — filename uses `X.Y.Z`):
  `version="${VERSION#v}"` — hint: `Expected format: '0.18.2' (no 'v' prefix).`
- **Prepend** (gcm, gitea — filename uses `vX.Y.Z`):
  `version="v${VERSION#v}"` — hint: `Expected format: 'v2.6.1' (with 'v' prefix).`
  Use `${version#v}` inline wherever the bare form is needed.

`${VAR#v}` is idempotent, so users can pass either form.

## Version source

- **GitHub (default):** `curl -fsSL https://api.github.com/repos/${REPO}/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+'`. No `jq`.
- **Gitea:** `https://gitea.com/api/v1/repos/${REPO}/releases?limit=1`, same grep.
- **Tag list filter** (non-GitHub asset host): `/tags` + `grep -oP '"name":\s*"\Kv[0-9][^"]+' | head -1`.
- **Channel-based** (no version API, e.g. neovim): skip lookup; default `TAG="nightly"`; accept `nightly|stable|vX.Y.Z`.

## Arch tokens (common upstream conventions)

| Convention         | x86_64                     | aarch64                         | Example        |
|--------------------|----------------------------|---------------------------------|----------------|
| Kernel-style       | `x86_64`                   | `aarch64` (sometimes `arm64`)   | fish, nvim, zmx |
| Go-style           | `amd64`                    | `arm64`                         | gitea          |
| .NET-style         | `x64`                      | `arm64`                         | gcm            |
| Rust target triple | `x86_64-unknown-linux-gnu` | `aarch64-unknown-linux-gnu`     | delta          |

## OS detection

Linux-only scripts hardcode `linux` in the URL. Add `get_os()` (`Linux→linux`, `Darwin→macos`, else exit 1) **only** when the tool supports macOS (see `zmx.sh`).

## Extraction → install (pick by upstream shape)

- **Raw binary, no archive** → download to tmp, `install -m 755`. Ref: `gitea.sh`.
- **tar with single binary at root** → `tar xf`, then `install -m 755 "$TMP_DIR/<tool>" "$INSTALL_DIR/<tool>"`. Ref: `fish.sh`, `zmx.sh`.
- **tar with versioned top-level dir** → `tar xzf ... --strip-components=1`, then `install`. Ref: `git-delta.sh`.
- **tar already laid out as install tree** → `tar -xzf ... -C "$INSTALL_DIR"` directly. Ref: `git-credential-manager.sh`.
- **Multi-dir install** (`bin/` + `lib/` + `share/`) → change `INSTALL_DIR` default to `$HOME/.local` and `cp -rf "$TMP_DIR"/{bin,lib,share} "$INSTALL_DIR"/`. Smoke-test with `"$INSTALL_DIR/bin/<tool>" --version | head -1`. Ref: `neovim.sh`.

## Uninstall hint

`just uninstall` removes only `<prefix>/bin/<binary>`. If your script also writes
outside that path (multi-dir installs, completions, man pages, etc.), add a
header comment so the recipe can warn the user about stragglers:

```bash
# uninstall-note: also installs lib/<tool> and share/<tool> under the prefix
```

Ref: `neovim.sh`.

## Checklist for a new script

1. Gather upstream facts: repo, release source, tag style, asset filename template, archive shape, supported arches.
2. Copy the closest reference script (see §Extraction list).
3. Change: purpose comment, `REPO`, `get_arch()` tokens, asset URL template, version-tag camp + error hint, tool name in the `install` target / final echo / smoke-test.
4. Verify:
   ```bash
   ./<tool>.sh                    # default latest → ~/.local/bin
   ./<tool>.sh --version X.Y.Z    # pinned
   ./<tool>.sh --system           # prompts for sudo, installs to /usr/local/bin
   ```
   Final line must print the installed version.

## Deliberate non-goals

Don't add without a reason: checksum/signature verification, "already installed" short-circuit, `--help` / `--dry-run` / `--install-dir=`, shell completions, man pages, PATH mutation, symlinks, `wget` fallback, proxy config, colored output, log levels.
