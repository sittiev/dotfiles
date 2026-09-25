#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=15274c --border=4BC37D --border-bottom=4BC37D   --text=e6e6e6 --button-background=4BC37D --button-text=15274c   -B 'Sim, sair' 'swaymsg exit'
