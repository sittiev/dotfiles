#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=2a322d --border=75A388 --border-bottom=75A388   --text=c2c2c2 --button-background=75A388 --button-text=2a322d   -B 'Sim, sair' 'swaymsg exit'
