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
# Despacha o modo ANTES de injetar --output: o prepend muda $1 e o
# --drun deixava de casar (virava tofi comum vazio em vez de tofi-drun).
mode=run
case "${1:-}" in
    --drun) mode=drun; shift ;;
esac
# Todo tofi/yambar vai pro monitor principal: injeta --output do
# primary-output.sh (HDMI se conectado, senao eDP), salvo flag explicita.
case " $* " in
    *" --output"*|*" --output="*) ;;
    *)
        _primary=$("$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/primary-output.sh" 2>/dev/null || printf '%s' '')
        if [ -n "$_primary" ]; then
            set -- --output="$_primary" "$@"
        fi
        unset _primary
        ;;
esac
case "$mode" in
    drun)
        exec tofi-drun "$@"
        ;;
    *)
        exec tofi "$@"
        ;;
esac
