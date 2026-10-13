#!/usr/bin/dash
# Abre/fecha a TUI de diretórios fixados (foot + curses), app_id
# yambar-dirs para a regra floating do sway. Toggle: se já existe,
# foca; um segundo clique no chip fecha (padrão do yambar-tasks-toggle).
set -eu

app_id=yambar-dirs

if swaymsg -t get_tree 2>/dev/null | grep -q "\"app_id\": \"$app_id\""; then
    swaymsg "[app_id=\"$app_id\"]" kill >/dev/null 2>&1 || true
    exit 0
fi

foot -a "$app_id" --override="initial-window-size-chars=70x20" \
    "$HOME/.config/sway/scripts/yambar-dirs.py" >/dev/null 2>&1 &
