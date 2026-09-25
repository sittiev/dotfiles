#!/usr/bin/dash
# waylock com as cores do tema corrente. O waylock (1.6) não tem arquivo de
# config: tudo é flag de CLI (-init-color/-input-color/-fail-color 0xRRGGBB),
# então o "writer" é este wrapper. Guardado: só roda com o waylock instalado.
set -eu

command -v waylock >/dev/null 2>&1 || {
    notify-send "Waylock" "waylock não instalado (docs/PENDING.md)." 2>/dev/null || true
    exit 1
}

c=${XDG_CACHE_HOME:-$HOME/.cache}
mode=$(cat "$c/theme-mode" 2>/dev/null || printf '%s' dark)
pal="$c/theme-palette.$mode"
[ -f "$pal" ] || pal="$c/theme-palette"
[ -f "$pal" ] || {
    notify-send "Waylock" "Paleta ausente; rode theme.sh." 2>/dev/null || true
    exit 1
}
# shellcheck disable=SC1090
. "$pal"

exec waylock -init-color "0x$BG" -input-color "0x$ACCENT" -fail-color "0x$FAIL" "$@"
