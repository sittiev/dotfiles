#!/usr/bin/dash
# Sway theme entry point: pywal palette -> light/dark -> render.
# Wallpaper is supplied by Waypaper; this script never changes outputs or wallpaper.
set -eu

LOG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waltheme-sway.log"
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >> "$LOG"; }

# Single writer: overlapping runs (sway exec + waypaper post_command) wait
# instead of racing on the shared caches and tmp files.
LOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waltheme.lock"
exec 9>"$LOCK"
if ! flock -w 60 9; then
    log "timeout esperando o lock; execucao abandonada"
    exit 1
fi

# The body runs in a subshell that closes fd 9 first: flock() is only released
# when every process sharing the open file description closes it, and long-lived
# children (yambar, mako) would inherit the fd and hold the lock forever.
(
exec 9>&-

wallpaper=${1:-}
waypaper_config=${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini
if [ -z "$wallpaper" ] && [ -f "$waypaper_config" ]; then
    wallpaper=$(sed -n 's|^wallpaper[[:space:]]*=[[:space:]]*||p' "$waypaper_config" | sed 's|^~|'"$HOME"'|' | head -1)
fi
if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
    wallpaper=$(cat "$HOME/.cache/current-wallpaper" 2>/dev/null || true)
fi

if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
    printf '%s\n' "$wallpaper" > "$HOME/.cache/current-wallpaper"
    if command -v wal >/dev/null 2>&1; then
        if wal -q -n -i "$wallpaper" --cols16 >/dev/null 2>&1; then
            log "pywal palette updated"
        else
            log "pywal failed; keeping existing palette"
        fi
    else
        log "pywal unavailable; using seed/current palette"
    fi
else
    log "no wallpaper found; using seed/current palette"
fi

mode=$(cat "$HOME/.cache/theme-mode" 2>/dev/null || printf '%s' dark)
case "$mode" in light|dark) ;; *) mode=dark ;; esac
if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
    mode=$("$HOME/.config/sway/scripts/theme-mode.sh" compute "$wallpaper")
fi
LOWC_SAT=45 "$HOME/.config/sway/scripts/theme-mode.sh" apply "$mode"
log "theme applied: $mode"
)
