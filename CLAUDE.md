# binary-install-scripts — contributor guide

This repository installs upstream prebuilt tools below `~/.local` by default.
Every public installer is a thin `*.sh` entry point backed by `lib/common.sh`.

## Required behavior

- Preserve the common CLI: `--version`, `--prefix`, `--system`, `--force`,
  `--dry-run`, and `--help`.
- Download and extract as the invoking user. Elevate only final writes when
  `--system` is selected.
- Use `bis_download_github_asset` for GitHub releases. It validates the asset
  name and verifies GitHub's SHA-256 digest when one is published.
- For other hosts, verify a published SHA-256 checksum when available.
- Extract tar archives with `bis_safe_extract_tar`.
- Smoke-test the installed binary and then call `bis_mark_installed`.
- Support x86-64 and ARM64 whenever upstream publishes both.
- Keep project-specific release naming and archive layout in its entry point;
  put only genuinely shared mechanics in `lib/common.sh`.

## Adding an installer

1. Copy the closest existing entry point.
2. Set `BIS_TOOL` and `BIS_DESCRIPTION` before sourcing `lib/common.sh`.
3. Call `bis_parse_args "$@"` immediately after sourcing it.
4. Map `uname -m` to the asset's architecture token.
5. Normalize both `--version` input and upstream tags to a bare semantic
   version for receipts and comparisons.
6. Resolve latest with `bis_github_latest_tag`, or implement a small provider-
   specific function.
7. Call `bis_skip_if_installed` before downloading.
8. Download, safely extract, install, smoke-test, and write the receipt.
9. Add the script and installed command mapping to `README.md`; if names differ,
   update the mappings in `justfile`.
10. Run `just test`, a pinned install into a temporary `--prefix`, and the same
    command again to test idempotency.

## Security boundaries

Checksums fetched through the release provider establish file integrity but do
not independently prove maintainer identity. Add signature or provenance
verification when upstream provides a stable documented policy. Never execute
an installer directly from a pipe, extract archives into the final prefix, or
send `GITHUB_TOKEN` to a non-GitHub host.

Temporary cleanup is restricted to paths made by `bis_make_temp_dir`. Do not
weaken that guard or introduce broad recursive deletion.

## Tests

`tests/test.sh` must stay network-independent. CI and local tests cover syntax,
the shared CLI contract, and ShellCheck when available. Release-specific asset
tests are performed manually with pinned end-to-end installs because upstream
asset layouts can change independently of this repository.
