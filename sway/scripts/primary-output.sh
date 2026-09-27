#!/usr/bin/dash
# primary-output.sh — imprime o output principal: HDMI-A-1 se conectado, senao eDP-1.
set -eu
HDMI=HDMI-A-1
LAPTOP=eDP-1
if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    if swaymsg -t get_outputs 2>/dev/null | jq -e --arg n "$HDMI" \
        'any(.[]; .name == $n)' >/dev/null 2>&1; then
        printf '%s\n' "$HDMI"
        exit 0
    fi
elif [ "$(cat /sys/class/drm/card1-$HDMI/status 2>/dev/null || printf '')" = connected ]; then
    printf '%s\n' "$HDMI"
    exit 0
fi
printf '%s\n' "$LAPTOP"
