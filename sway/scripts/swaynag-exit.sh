#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=15274c --border=64A3E6 --border-bottom=64A3E6   --text=e6e6e6 --button-background=64A3E6 --button-text=15274c   -B 'Sim, sair' 'swaymsg exit'
