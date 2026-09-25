#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=20201D --border=6684E1 --border-bottom=6684E1   --text=999580 --button-background=6684E1 --button-text=20201D   -B 'Sim, sair' 'swaymsg exit'
