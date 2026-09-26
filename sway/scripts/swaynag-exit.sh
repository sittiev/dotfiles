#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway?'   --background=d0deeb --border=536D85 --border-bottom=536D85   --text=343637 --button-background=536D85 --button-text=d0deeb   -B 'Sim, sair' 'swaymsg exit'
