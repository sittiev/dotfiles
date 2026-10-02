#!/usr/bin/dash
# battery.sh — monitor de bateria do notebook.
# Descarregando: avisa em WARN% (padrão 20) e CRITICAL% (padrão 10) e
# suspende em SUSPEND% (padrão 5), avisando antes de suspender.
# Limites em ~/.cache/battery-warn, ~/.cache/battery-critical e
# ~/.cache/battery-suspend (só número, 1–100). Na tomada só rearma os avisos.
# Troca tomada/bateria: reinicia idle.sh para trocar os timeouts do swayidle.
# Sem bateria (desktop): só observa a tomada. Singleton: a nova instância
# (exec_always a cada reload) mata a anterior.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PS_DIR=${POWER_SUPPLY_DIR:-/sys/class/power_supply}
POLL=${BATTERY_POLL:-30}
case "$POLL" in '' | *[!0-9]* | 0) POLL=30 ;; esac
RUN_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
CACHE_DIR=${XDG_CACHE_HOME:-$HOME/.cache}
NOTIFIED_FILE=$RUN_DIR/battery-notified
AC_FILE=$RUN_DIR/battery-ac
GAME_ACTIVE=$CACHE_DIR/sway-game-mode/active

if command -v pgrep >/dev/null 2>&1; then
    me=$$
    # shellcheck disable=SC2046
    for pid in $(pgrep -f 'sway/scripts/battery.sh' 2>/dev/null || true); do
        [ "$pid" != "$me" ] || continue
        kill "$pid" 2>/dev/null || true
    done
fi

read_num() { # <arquivo> <padrão> → só dígitos ou o padrão
    v=$(cat "$1" 2>/dev/null || printf '%s' "$2")
    case "$v" in '' | *[!0-9]*) printf '%s' "$2" ;; *) printf '%s' "$v" ;; esac
}

threshold() { # <arquivo> <padrão> → 1–100 ou o padrão
    v=$(read_num "$1" "$2")
    if [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 100 ] 2>/dev/null; then
        printf '%s' "$v"
    else
        printf '%s' "$2"
    fi
}

capacity() {
    cat "$PS_DIR"/BAT*/capacity 2>/dev/null | head -n 1 || true
}

discharging() {
    st=$(cat "$PS_DIR"/BAT*/status 2>/dev/null | head -n 1 || true)
    [ "$st" = Discharging ]
}

ac_state() {
    v=$(cat "$PS_DIR"/AC*/online 2>/dev/null | head -n 1 || true)
    case "$v" in 0 | 1) printf '%s' "$v" ;; *) printf 'unknown' ;; esac
}

notified() { # <limite> → 0 se já avisou neste ciclo de descarga
    [ -f "$NOTIFIED_FILE" ] || return 1
    case " $(cat "$NOTIFIED_FILE") " in *" $1 "*) return 0 ;; esac
    return 1
}

mark_notified() { # <limite>
    if [ -f "$NOTIFIED_FILE" ]; then
        printf '%s %s' "$(cat "$NOTIFIED_FILE")" "$1" > "$NOTIFIED_FILE"
    else
        printf '%s' "$1" > "$NOTIFIED_FILE"
    fi
}

while true; do
    WARN=$(threshold "$CACHE_DIR/battery-warn" 20)
    CRIT=$(threshold "$CACHE_DIR/battery-critical" 10)
    SUSP=$(threshold "$CACHE_DIR/battery-suspend" 5)

    ac=$(ac_state)
    last_ac=$(cat "$AC_FILE" 2>/dev/null || printf '')
    if [ -n "$last_ac" ] && [ "$ac" != "$last_ac" ] \
        && [ "$ac" != unknown ] && [ "$last_ac" != unknown ] \
        && [ ! -f "$GAME_ACTIVE" ]; then
        "$script_dir/idle.sh" >/dev/null 2>&1 &
    fi
    printf '%s' "$ac" > "$AC_FILE"

    cap=$(capacity)
    case "$cap" in '' | *[!0-9]*)
        sleep "$POLL"
        continue
        ;;
    esac
    if ! discharging; then
        rm -f "$NOTIFIED_FILE"
        sleep "$POLL"
        continue
    fi
    if [ "$cap" -gt "$WARN" ] 2>/dev/null; then
        rm -f "$NOTIFIED_FILE"
        sleep "$POLL"
        continue
    fi

    if [ "$cap" -le "$SUSP" ] 2>/dev/null; then
        if ! notified "$SUSP"; then
            notify-send -u critical --expire-time=15000 \
                -h string:x-canonical-private-synchronous:battery \
                "Suspensão por bateria fraca" \
                "$cap% restante. Suspendendo para proteger a sessão." \
                >/dev/null 2>&1 || true
            mark_notified "$SUSP"
        fi
        sleep 8
        systemctl suspend >/dev/null 2>&1 || true
    elif [ "$cap" -le "$CRIT" ] 2>/dev/null; then
        if ! notified "$CRIT"; then
            notify-send -u critical --expire-time=15000 \
                -h string:x-canonical-private-synchronous:battery \
                "Bateria muito fraca" \
                "$cap% restante. Conecte o carregador agora." \
                >/dev/null 2>&1 || true
            mark_notified "$CRIT"
        fi
    elif [ "$cap" -le "$WARN" ] 2>/dev/null; then
        if ! notified "$WARN"; then
            notify-send -u normal --expire-time=8000 \
                -h string:x-canonical-private-synchronous:battery \
                "Bateria fraca" \
                "$cap% restante. Conecte o carregador." \
                >/dev/null 2>&1 || true
            mark_notified "$WARN"
        fi
    fi
    sleep "$POLL"
done
