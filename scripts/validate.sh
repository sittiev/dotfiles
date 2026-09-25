#!/usr/bin/dash
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FAILED=0

check() {
    name=$1
    shift
    if "$@"; then
        printf '[OK] %s\n' "$name"
    else
        printf '[FAIL] %s\n' "$name" >&2
        FAILED=1
    fi
}

check 'sway config' sway --validate -c "$ROOT/sway/config"
check 'foot config' foot --check-config -c "$ROOT/foot/foot.ini"

if command -v checkbashisms >/dev/null 2>&1; then
    HAVE_CB=1
else
    HAVE_CB=0
    printf '[FAIL] %s\n' 'checkbashisms not installed (pacman -S checkbashisms)' >&2
    FAILED=1
fi

for file in "$ROOT"/sway/scripts/*.sh "$ROOT"/scripts/*.sh; do
    check "dash syntax: ${file##*/}" dash -n "$file"
    if [ "$HAVE_CB" -eq 1 ]; then
        check "no bashisms: ${file##*/}" checkbashisms "$file"
    fi
done

if [ -d "$ROOT/.git" ]; then
    check 'git whitespace' git -C "$ROOT" diff --check
fi

if [ "$FAILED" -ne 0 ]; then
    printf '%s\n' 'dotfiles validation failed' >&2
    exit 1
fi

printf '%s\n' 'dotfiles validation passed'
