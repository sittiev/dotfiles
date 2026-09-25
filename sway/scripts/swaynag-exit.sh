#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=e0e6e2 --border=F1F7F3 --border-bottom=F1F7F3   --text=353635 --button-background=F1F7F3 --button-text=e0e6e2   -B 'Sim, sair' 'swaymsg exit'
