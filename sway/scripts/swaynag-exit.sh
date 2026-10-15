#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway? A sessão será encerrada.'   --background=141414 --border=B8B59D --border-bottom=B8B59D   --text=c0bfba --button-background=B8B59D --button-text=141414   -B 'Sair' 'swaymsg exit'
