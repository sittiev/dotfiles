#!/usr/bin/dash
# outputs.sh — HDMI-A-1 e o principal (esquerda, pos 0 0); eDP-1 e secundario.
# Com HDMI conectado: so HDMI (eDP desligado). Sem HDMI: so eDP.
# Uso: outputs.sh auto|hdmi|laptop|extend|mirror|lid <on|off>|status
set -eu

HDMI=HDMI-A-1
LAPTOP=eDP-1

connected() { # <output> → 0 se conectado (via swaymsg, fallback drm)
    if command -v swaymsg >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        swaymsg -t get_outputs 2>/dev/null | jq -e --arg n "$1" \
            'any(.[]; .name == $n and ((.active // true) or (.dpms // true)))' >/dev/null 2>&1 && return 0 || true
        # fallback: existe na lista mesmo sem active/dpms
        swaymsg -t get_outputs 2>/dev/null | jq -e --arg n "$1" \
            'any(.[]; .name == $n)' >/dev/null 2>&1 && return 0
        return 1
    fi
    [ "$(cat "/sys/class/drm/card1-$1/status" 2>/dev/null || printf 'unknown')" = connected ]
}

# out <name> <sub...> — enable e pos em chamadas separadas: num unico
# `swaymsg output X enable, pos ..` o sway reaplica o pos do config file ao
# re-habilitar um output desligado, engolindo o pos do mesmo comando.
out() { # <nome> [enable|disable] [pos X Y]
    _n=$1 _st=${2:-} _p1=${3:-} _p2=${4:-}
    case "$_st" in
        enable|disable) swaymsg output "$_n" "$_st" >/dev/null 2>&1 || true ;;
    esac
    if [ -n "$_p1" ]; then
        swaymsg output "$_n" pos "$_p1" "$_p2" >/dev/null 2>&1 || true
    fi
    unset _n _st _p1 _p2
}

notify() { notify-send "Monitores" "$1" 2>/dev/null || true; }

cmd=${1:-auto}
case "$cmd" in
    auto)
        if connected "$HDMI"; then
            out "$HDMI" enable 0 0
            out "$LAPTOP" disable
            swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
        else
            out "$LAPTOP" enable 0 0
            swaymsg focus output "$LAPTOP" >/dev/null 2>&1 || true
        fi
        ;;
    hdmi)
        out "$HDMI" enable 0 0
        out "$LAPTOP" disable
        swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
        notify "Só HDMI ($HDMI, esquerda)"
        ;;
    laptop)
        out "$LAPTOP" enable 0 0
        out "$HDMI" disable
        swaymsg focus output "$LAPTOP" >/dev/null 2>&1 || true
        notify "Só notebook ($LAPTOP)"
        ;;
    extend)
        out "$HDMI" enable 0 0
        out "$LAPTOP" enable 1920 0
        swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
        notify "Estendido: HDMI esquerda + notebook direita"
        ;;
    mirror)
        out "$HDMI" enable 0 0
        out "$LAPTOP" enable 0 0
        swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
        notify "Espelhado"
        ;;
    lid)
        case "${2:-}" in
            on) # tampa fechada: com HDMI, so HDMI; sem HDMI, acao do cache
                if connected "$HDMI"; then
                    swaymsg output "$LAPTOP" disable >/dev/null 2>&1 || true
                    swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
                else
                    case "$(cat "$HOME/.cache/lid-action" 2>/dev/null || printf 'suspend')" in
                        nada) swaymsg output "$LAPTOP" disable >/dev/null 2>&1 || true ;;
                        *) systemctl suspend 2>/dev/null || true ;;
                    esac
                fi
                ;;
            off) # tampa aberta: volta ao auto
                "$0" auto
                ;;
            *) printf '%s\n' "uso: $0 lid <on|off>" >&2; exit 1 ;;
        esac
        ;;
    status)
        swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | "\(.name) active=\(.active)"' 2>/dev/null \
            || { connected "$HDMI" && printf '%s\n' "$HDMI conectado" || printf '%s\n' "$HDMI ausente"; }
        ;;
    *) printf '%s\n' "uso: $0 auto|hdmi|laptop|extend|mirror|lid <on|off>|status" >&2; exit 1 ;;
esac
