#!/usr/bin/dash
# waylock com as cores do tema corrente. O waylock (1.6) não tem arquivo de
# config: tudo é flag de CLI (-init-color/-input-color/-fail-color 0xRRGGBB),
# então o "writer" é este wrapper. Guardado: só roda com o waylock instalado.
set -eu

command -v waylock >/dev/null 2>&1 || {
    notify-send "Waylock" "waylock não instalado (docs/PENDING.md)." 2>/dev/null || true
    exit 1
}

# Singleton: timeout 300 + evento lock + before-sleep disparam juntos no
# suspend; sem isto cada instância empilhada cobra uma senha no resume.
if command -v pgrep >/dev/null 2>&1 && pgrep -x waylock >/dev/null 2>&1; then
    exit 0
fi

# --pre-sleep (só para o before-sleep do swayidle): -fork-on-lock faz o
# waylock sair após travar, liberando o delay lock do logind para suspender.
# Sem isto o logind força o sleep após InhibitDelayMaxSec (5s) com a tela
# em estado indefinido. Nunca use no lock manual: ele precisa ficar em
# foreground.
fork=
if [ "${1:-}" = "--pre-sleep" ]; then
    fork=1
    shift
fi

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

if [ -n "$fork" ]; then
    # shellcheck disable=SC2086
    exec waylock -fork-on-lock -init-color "0x$BG" -input-color "0x$ACCENT" -fail-color "0x$FAIL" "$@"
fi

exec waylock -init-color "0x$BG" -input-color "0x$ACCENT" -fail-color "0x$FAIL" "$@"
