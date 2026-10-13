#!/usr/bin/dash
# Abre/fecha a TUI de tarefas do vault (foot + curses), app_id
# yambar-tasks para a regra floating do sway. Toggle: se já existe,
# foca; um segundo clique no chip fecha (padrão do yambar-clock-toggle,
# mas a janela morre sozinha quando o yambar reinicia — o on-click não
# é filho do foot).
set -eu

app_id=yambar-tasks

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Binário C primeiro (make em sway/scripts); .py de fallback.
if [ -x "$script_dir/yambar-tasks-c" ]; then
    bin="$script_dir/yambar-tasks-c"
else
    bin="$script_dir/yambar-tasks.py"
fi

if swaymsg -t get_tree 2>/dev/null | grep -q "\"app_id\": \"$app_id\""; then
    swaymsg "[app_id=\"$app_id\"]" kill >/dev/null 2>&1 || true
    exit 0
fi

foot -a "$app_id" --override="initial-window-size-chars=90x28" \
    "$bin" >/dev/null 2>&1 &
