#!/usr/bin/dash
# Relogio do yambar: default so horario, clique alterna data+horario.
# Estado em XDG_RUNTIME_DIR (some no logout => volta ao default).
set -eu
state="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/yambar-clock-full"
if [ -f "$state" ]; then
    out=$(LC_TIME=C date '+%a %d %b, %H:%M')
else
    out=$(LC_TIME=C date '+%H:%M')
fi
printf 'display|string|%s\n\n' "$out"
