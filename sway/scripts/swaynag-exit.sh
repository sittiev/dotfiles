#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=0b0d0e --border=8E9192 --border-bottom=8E9192   --text=ecedee --button-background=8E9192 --button-text=0b0d0e   -B 'Sim, sair' 'swaymsg exit'
