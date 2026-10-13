#!/usr/bin/dash
# Abre/fecha a TUI de diretórios fixados (foot + curses), app_id
# yambar-dirs para a regra floating do sway. Toggle: se já existe,
# foca; um segundo clique no chip fecha (padrão do yambar-tasks-toggle).
set -eu

app_id=yambar-dirs

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Binário C primeiro (make em sway/scripts); .py de fallback.
if [ -x "$script_dir/yambar-dirs-c" ]; then
    bin="$script_dir/yambar-dirs-c"
else
    bin="$script_dir/yambar-dirs.py"
fi

if swaymsg -t get_tree 2>/dev/null | grep -q "\"app_id\": \"$app_id\""; then
    swaymsg "[app_id=\"$app_id\"]" kill >/dev/null 2>&1 || true
    exit 0
fi

foot -a "$app_id" --override="initial-window-size-chars=70x20" \
    "$bin" >/dev/null 2>&1 &
