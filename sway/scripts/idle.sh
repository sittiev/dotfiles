#!/usr/bin/dash
# idle.sh — swayidle: trava com swaylock (tema), apaga telas e suspende.
# Trava após ~/.cache/lock-timeout (segundos, 0=nunca, padrão 300),
# definido no menu Mod+Shift+x → Sistema → Bloqueio automático
# (lockmenu.sh). O valor vale na tomada e na bateria; apagar telas usa 5min
# na bateria e 10min na tomada, e suspender usa $SUSPEND (0=nunca, padrão 900).
# Trava antes de suspender. Sem duplicar a cada `swaymsg reload`.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v swayidle >/dev/null 2>&1 || exit 0
SUSPEND=$(cat "$HOME/.cache/suspend-timeout" 2>/dev/null || printf '900')
case "$SUSPEND" in '' | *[!0-9]*) SUSPEND=900 ;; esac
LOCK=$(cat "$HOME/.cache/lock-timeout" 2>/dev/null || printf '300')
case "$LOCK" in '' | *[!0-9]*) LOCK=300 ;; esac
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
    SCREEN=300
    if [ "$SUSPEND" -gt 600 ] 2>/dev/null; then SUSPEND=600; fi
else
    SCREEN=600
fi
pkill -x swayidle >/dev/null 2>&1 || true
sleep 0.2
# Argumento por argumento: LOCK=0 (nunca travar sozinho) e SUSPEND=0 (nunca
# suspender) omitem a linha em vez de passar "timeout 0", que dispararia na
# hora. SCREEN não precisa de guarda: sempre tem valor (>0) nos dois ramos.
set -- -w
if [ "$LOCK" -gt 0 ] 2>/dev/null; then
    # shellcheck disable=SC2086
    set -- "$@" timeout "$LOCK" "$script_dir/swaylock.sh"
fi
set -- "$@" \
    timeout "$SCREEN" 'swaymsg "output * power off"' resume 'swaymsg "output * power on"'
if [ "$SUSPEND" -gt 0 ] 2>/dev/null; then
    # shellcheck disable=SC2086
    set -- "$@" timeout "$SUSPEND" 'systemctl suspend'
fi
set -- "$@" \
    lock "$script_dir/swaylock.sh" \
    before-sleep "$script_dir/swaylock.sh --pre-sleep"
exec swayidle "$@" >/dev/null 2>&1
