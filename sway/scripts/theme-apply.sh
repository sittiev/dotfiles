#!/usr/bin/dash
# Compatibility entry point. Theme ownership lives in theme-mode.sh/render.sh.
set -eu
mode=${1:-$(cat "$HOME/.cache/theme-mode" 2>/dev/null || printf '%s' dark)}
case "$mode" in light|dark) ;; *) mode=dark ;; esac
exec "$HOME/.config/sway/scripts/theme-mode.sh" apply "$mode"
