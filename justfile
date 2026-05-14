default:
    @just --list

# List available install scripts
list:
    @ls *.sh | sed 's/\.sh$//'

# Install one tool: just install fish [--system] [--version X.Y.Z]
install tool *args:
    ./{{tool}}.sh {{args}}

# Install every tool (pass --system to install to /usr/local/bin)
install-all *args:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    for script in *.sh; do
        echo "==> $script"
        ./"$script" {{args}} || failed+=("$script")
    done
    if (( ${#failed[@]} )); then
        echo "Failed: ${failed[*]}" >&2
        exit 1
    fi

# Re-install tools currently present in ~/.local/bin
update:
    @just _update "$HOME/.local"

# Re-install tools currently present in /usr/local/bin
update-system:
    @just _update /usr/local --system

[private]
_update prefix *flags:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    for script in *.sh; do
        bin=$(grep -oP '\$INSTALL_DIR/\K[^"]+' "$script" | tail -1)
        bin="${bin##*/}"
        if [[ -x "{{prefix}}/bin/$bin" ]]; then
            echo "==> $script"
            ./"$script" {{flags}} || failed+=("$script")
        fi
    done
    if (( ${#failed[@]} )); then
        echo "Failed: ${failed[*]}" >&2
        exit 1
    fi

# Remove tool binaries from ~/.local/bin (does not clean up support files)
uninstall:
    @just _uninstall "$HOME/.local" ""

# Remove tool binaries from /usr/local/bin (does not clean up support files)
uninstall-system:
    @just _uninstall /usr/local sudo

[private]
_uninstall prefix sudo:
    #!/usr/bin/env bash
    set -euo pipefail
    for script in *.sh; do
        bin=$(grep -oP '\$INSTALL_DIR/\K[^"]+' "$script" | tail -1)
        bin="${bin##*/}"
        target="{{prefix}}/bin/$bin"
        if [[ -e "$target" ]]; then
            echo "==> rm $target"
            {{sudo}} rm -f "$target"
            note=$(grep -oP '^# uninstall-note: \K.*' "$script" || true)
            if [[ -n "$note" ]]; then echo "    warning: $note" >&2; fi
        fi
    done
