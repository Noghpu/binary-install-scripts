default:
    @just --list

# List available installers
list:
    @for script in *.sh; do basename "$script" .sh; done

# Install one tool: just install zmx [--version X.Y.Z]
install tool *args:
    ./{{tool}}.sh {{args}}

# Install every tool
install-all *args:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    for script in ./*.sh; do
        echo "==> ${script#./}"
        "$script" {{args}} || failed+=("${script#./}")
    done
    if ((${#failed[@]})); then
        echo "Failed: ${failed[*]}" >&2
        exit 1
    fi

# Update tools currently present in ~/.local/bin
update:
    @just _update "$HOME/.local"

# Update tools currently present in /usr/local/bin
update-system:
    @just _update /usr/local --system

# Run syntax, interface, and static checks
test:
    ./tests/test.sh

[private]
_update prefix *flags:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    for script_path in ./*.sh; do
        script="${script_path#./}"
        script="${script%.sh}"
        case "$script" in
            git-delta) bin=delta ;;
            gitea) bin=tea ;;
            neovim) bin=nvim ;;
            *) bin=$script ;;
        esac
        if [[ -x "{{prefix}}/bin/$bin" ]]; then
            echo "==> ${script}.sh"
            "$script_path" {{flags}} || failed+=("${script}.sh")
        fi
    done
    if ((${#failed[@]})); then
        echo "Failed: ${failed[*]}" >&2
        exit 1
    fi

# Remove installed command entry points from ~/.local/bin
uninstall:
    @just _uninstall "$HOME/.local" ""

# Remove installed command entry points from /usr/local/bin
uninstall-system:
    @just _uninstall /usr/local sudo

[private]
_uninstall prefix sudo:
    #!/usr/bin/env bash
    set -euo pipefail
    for script_path in ./*.sh; do
        script="${script_path#./}"
        script="${script%.sh}"
        case "$script" in
            git-delta) bin=delta ;;
            gitea) bin=tea ;;
            neovim) bin=nvim ;;
            *) bin=$script ;;
        esac
        target="{{prefix}}/bin/$bin"
        if [[ -e "$target" || -L "$target" ]]; then
            echo "==> rm $target"
            {{sudo}} rm -f -- "$target"
            note=$(grep -E '^# uninstall-note:' "$script_path" | sed 's/^# uninstall-note: *//' || true)
            [[ -z "$note" ]] || echo "    warning: $note" >&2
        fi
    done
