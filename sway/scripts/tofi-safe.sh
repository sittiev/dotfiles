#!/usr/bin/dash
# Minimal Tofi launcher: toggles an existing instance and removes only a stale lock.
set -eu

runtime=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
lock="$runtime/tofi.lock"

if pgrep -x tofi >/dev/null 2>&1 || pgrep -x tofi-drun >/dev/null 2>&1; then
    pkill -x tofi 2>/dev/null || true
    pkill -x tofi-drun 2>/dev/null || true
    rm -f "$lock"
    exit 0
fi

rm -f "$lock"
case "${1:-}" in
    --drun)
        shift
        exec tofi-drun "$@"
        ;;
    *)
        exec tofi "$@"
        ;;
esac
