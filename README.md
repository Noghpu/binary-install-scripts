# Binary install scripts

Small Bash installers for upstream prebuilt command-line tools. They are useful
on servers, disposable development environments, and machines where a distro
package is missing or too old.

Each public `*.sh` file is an installer. By default it installs below
`~/.local`; it can also target an arbitrary prefix or `/usr/local`.

```console
./zmx.sh
./zmx.sh --version 0.7.0
./zmx.sh --prefix "$HOME/.tools"
./zmx.sh --system
./zmx.sh --dry-run
```

## Guarantees

- Exact-version installs are idempotent unless `--force` is supplied.
- GitHub release assets are verified against the SHA-256 digest returned by
  GitHub's release API. Tea is checked against its upstream `.sha256` file.
- Downloads use HTTPS-only redirects, connection timeouts, and retries.
- Archives are extracted into a temporary directory and rejected if they
  contain absolute paths or parent-directory traversal.
- Only the final installation step uses `sudo`, and only with `--system`.
- `GITHUB_TOKEN` is honored for private repositories and higher API limits.
- Immutable per-tag GitHub metadata is cached below
  `${XDG_CACHE_HOME:-~/.cache}/binary-install-scripts` to conserve API quota.

Checksums retrieved from the same release service provide transport and file
integrity, but are not a substitute for maintainer signature or provenance
verification. An installer should additionally verify Sigstore/GPG metadata
when an upstream project publishes a stable, automatable policy for it.

## Available installers

| Script | Installed command | Platforms |
| --- | --- | --- |
| `codex.sh` | `codex` | Linux x86-64/ARM64 |
| `fish.sh` | `fish` | Linux x86-64/ARM64 |
| `git-credential-manager.sh` | `git-credential-manager` | Linux x86-64/ARM64 |
| `git-delta.sh` | `delta` | Linux x86-64/ARM64 |
| `gitea.sh` | `tea` | Linux x86-64/ARM variants |
| `go-grip.sh` | `go-grip` | Linux x86-64/ARM64 |
| `jj.sh` | `jj` | Linux x86-64/ARM64 |
| `kanata.sh` | `kanata` | Linux x86-64 |
| `neovim.sh` | `nvim` | Linux x86-64/ARM64 |
| `zmx.sh` | `zmx` | Linux/macOS x86-64/ARM64 |

`kanata.sh` installs the default build. The release archive also contains a
`cmd_allowed` build whose `cmd` action runs arbitrary programs named in the
keyboard configuration; that one is deliberately not installed. Upstream
publishes prerelease tags, so `--version 1.12.1-prerelease-1` is valid and
`--version` with no prerelease suffix resolves to the latest stable release.

`neovim.sh` defaults to the moving `nightly` channel. Use `--version stable`
for the moving stable channel or a semantic version for an idempotent pin.

## Using with chezmoi

Keep this repository separate and let chezmoi clone it as an external. Put
versions in chezmoi's package manifest so a manifest change triggers its
`run_onchange_` installer:

```yaml
binaries:
  zmx:
    script: zmx.sh
    version: 0.7.0
```

```bash
~/.local/share/binary-install-scripts/zmx.sh --version 0.7.0
```

## Development

```console
just test
```

The test suite always runs Bash syntax and CLI contract tests. If `shellcheck`
is installed, it also runs static analysis over every shell file.
