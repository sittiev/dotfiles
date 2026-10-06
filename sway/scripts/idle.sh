#!/usr/bin/dash
# idle.sh — swayidle: trava com swaylock (tema), apaga telas e suspende.
# Na tomada: trava aos 5min, apaga telas aos 10min, suspende após $SUSPEND
# (cache ~/.cache/suspend-timeout, 0=nunca, padrão 900).
# Descarregando (bateria): trava aos 3min, apaga telas aos 5min, suspende em
# min($SUSPEND, 10min). battery.sh reinicia este script ao trocar de fonte.
# Trava antes de suspender. Sem duplicar a cada `swaymsg reload`.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v swayidle >/dev/null 2>&1 || exit 0
SUSPEND=$(cat "$HOME/.cache/suspend-timeout" 2>/dev/null || printf '900')
case "$SUSPEND" in '' | *[!0-9]*) SUSPEND=900 ;; esac
PS_DIR=${POWER_SUPPLY_DIR:-/sys/class/power_supply}
on_battery() {
    online=$(cat "$PS_DIR"/AC*/online 2>/dev/null | head -n 1 || true)
    case "$online" in
        0) return 0 ;;
        1) return 1 ;;
    esac
    st=$(cat "$PS_DIR"/BAT*/status 2>/dev/null | head -n 1 || true)
    [ "$st" = Discharging ]
}
if on_battery; then
    LOCK=180
    SCREEN=300
    if [ "$SUSPEND" -gt 600 ] 2>/dev/null; then SUSPEND=600; fi
else
    LOCK=300
    SCREEN=600
fi
pkill -x swayidle >/dev/null 2>&1 || true
sleep 0.2
if [ "$SUSPEND" -gt 0 ] 2>/dev/null; then
    # shellcheck disable=SC2086
    exec swayidle -w \
        timeout "$LOCK" "$script_dir/swaylock.sh" \
        timeout "$SCREEN" 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
        timeout "$SUSPEND" 'systemctl suspend' \
        lock "$script_dir/swaylock.sh" \
        before-sleep "$script_dir/swaylock.sh --pre-sleep" >/dev/null 2>&1
else
    exec swayidle -w \
        timeout "$LOCK" "$script_dir/swaylock.sh" \
        timeout "$SCREEN" 'swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
        lock "$script_dir/swaylock.sh" \
        before-sleep "$script_dir/swaylock.sh --pre-sleep" >/dev/null 2>&1
fi
