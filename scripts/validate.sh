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

scheme_data_ok() {
    jq -e 'length > 1000' "$ROOT/sway/schemes/gogh-themes-min.json" >/dev/null
}
check 'scheme data (gogh json)' scheme_data_ok
check 'scheme tests' dash "$ROOT/scripts/test-schemelib.sh"

c_core_ok() {
    tmp=${TMPDIR:-/tmp}/tasks-core-test-$$
    if cc -std=c17 -O2 -Wall -Wextra -DTASKS_CORE_TEST -o "$tmp" \
        "$ROOT/sway/scripts/tasks-core.c" 2>"$tmp.err" && "$tmp"; then
        rm -f "$tmp" "$tmp.err"
        return 0
    fi
    cat "$tmp.err" >&2
    rm -f "$tmp" "$tmp.err"
    return 1
}
check 'tasks core selftest' c_core_ok

c_ui_ok() {
    # Link-check da UI (rodar exige TTY): compila p/ $TMPDIR, sem artefato.
    tmp=${TMPDIR:-/tmp}/yambar-tasks-c-check-$$
    # shellcheck disable=SC2046
    cc -std=c17 -O2 -Wall -Wextra -o "$tmp" \
        "$ROOT/sway/scripts/yambar-tasks.c" \
        "$ROOT/sway/scripts/tasks-core.c" \
        $(pkg-config --cflags --libs notcurses) 2>&1
    rc=$?
    rm -f "$tmp"
    return "$rc"
}
if pkg-config --exists notcurses 2>/dev/null; then
    check 'tasks UI builds' c_ui_ok
else
    printf '[SKIP] tasks UI builds (sem notcurses: sudo pacman -S notcurses)\n'
fi

action_ok() {
    grep -q '^\[Desktop Entry\]$' "$1" &&
        grep -q '^Type=Action$' "$1" &&
        grep -q '^\[X-Action-Profile ' "$1" &&
        grep -q '^MimeTypes=' "$1" &&
        grep -q '^Exec=' "$1"
}
for f in "$ROOT"/pcmanfm/actions/*.desktop; do
    check "action: ${f##*/}" action_ok "$f"
done

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
