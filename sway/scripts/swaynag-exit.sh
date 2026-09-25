#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=e0e6e2 --border=F5F7F5 --border-bottom=F5F7F5   --text=353635 --button-background=F5F7F5 --button-text=e0e6e2   -B 'Sim, sair' 'swaymsg exit'
