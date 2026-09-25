#!/usr/bin/dash
# theme-toggle.sh — toggle claro/escuro (ícone lua/sol)
#   get    → ícone do modo atual
#   toggle → aplica o modo oposto e trava (sobrevive ao próximo wallpaper)
#   auto   → destrava (volta a decidir por luminância com histerese)

set -u
STATE="$HOME/.cache/theme-mode"
MODE_LOCK="$HOME/.cache/theme-mode-lock"
THEME_MODE="$HOME/.config/sway/scripts/theme-mode.sh"

MODE="$(cat "$STATE" 2>/dev/null)"
if [ "$MODE" != light ] && [ "$MODE" != dark ]; then MODE="dark"; fi

case "${1:-}" in
    get)
        if [ "$MODE" = light ]; then
            echo ""   # sol
        else
            echo ""   # lua
        fi
        ;;
    toggle)
        if [ "$MODE" = light ]; then
            printf '%s' "dark" > "$MODE_LOCK"
            "$THEME_MODE" apply dark
        else
            printf '%s' "light" > "$MODE_LOCK"
            "$THEME_MODE" apply light
        fi
        ;;
    auto)
        rm -f "$MODE_LOCK"
        mode=$("$THEME_MODE" compute)
        "$THEME_MODE" apply "$mode"
        ;;
    *) exit 1 ;;
esac
