#!/usr/bin/dash
# menu.sh — hub de utilidades do rice (Mod+Shift+x): TUI Rust (`menu`,
# ratatui/glancer) num foot flutuante (app_id "menu"; regra no sway/config).
# Com a janela aberta, fecha (toggle, padrão do yambar-tasks-toggle.sh).
# Sem o binário, cai no tofi-menu.sh (nada quebra).
set -eu

app_id=menu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bin="${MENU_BIN:-$HOME/.local/bin/menu}"

if [ ! -x "$bin" ]; then
    exec "$script_dir/tofi-menu.sh" "$@"
fi

if swaymsg -t get_tree 2>/dev/null | grep -q "\"app_id\": \"$app_id\""; then
    swaymsg "[app_id=\"$app_id\"]" kill >/dev/null 2>&1 || true
    exit 0
fi

foot -a "$app_id" --override="initial-window-size-chars=110x34" \
    "$bin" >/dev/null 2>&1 &