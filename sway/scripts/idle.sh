#!/usr/bin/dash
# idle.sh — swayidle: trava com waylock (tema) aos 5min, apaga telas aos 10min,
# suspende após $SUSPEND (cache ~/.cache/suspend-timeout, 0=nunca, padrao 900),
# trava antes de suspender. Sem duplicar a cada `swaymsg reload`.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v swayidle >/dev/null 2>&1 || exit 0
SUSPEND=$(cat "$HOME/.cache/suspend-timeout" 2>/dev/null || printf '900')
case "$SUSPEND" in '' | *[!0-9]*) SUSPEND=900 ;; esac
pkill -x swayidle >/dev/null 2>&1 || true
sleep 0.2
if [ "$SUSPEND" -gt 0 ] 2>/dev/null; then
    # shellcheck disable=SC2086
    exec swayidle -w \
        timeout 300 "$script_dir/waylock.sh" \
        timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
        timeout "$SUSPEND" 'systemctl suspend' \
        lock "$script_dir/waylock.sh" \
        before-sleep "$script_dir/waylock.sh --pre-sleep" >/dev/null 2>&1
else
    exec swayidle -w \
        timeout 300 "$script_dir/waylock.sh" \
        timeout 600 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
        lock "$script_dir/waylock.sh" \
        before-sleep "$script_dir/waylock.sh --pre-sleep" >/dev/null 2>&1
fi
