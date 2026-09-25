#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=20201D --border=5FC489 --border-bottom=5FC489   --text=999580 --button-background=5FC489 --button-text=20201D   -B 'Sim, sair' 'swaymsg exit'
