#!/usr/bin/dash
# kanshi-hook.sh — pós-perfil kanshi: foca a saida, sem reaplicar output.
# O kanshi já aplicou enable/disable/pos do perfil; reaplicar aqui (swaymsg
# output) correria contra o daemon.
# Uso: kanshi-hook.sh hdmi|laptop|extend   (chamado via `exec` no kanshi/config)
set -eu

HDMI=HDMI-A-1
LAPTOP=eDP-1

mode=${1:-}
case "$mode" in
    hdmi|laptop|extend)
        case "$mode" in
            laptop) out=$LAPTOP ;;
            *) out=$HDMI ;;
        esac
        swaymsg focus output "$out" >/dev/null 2>&1 || true
        ;;
    *) printf '%s\n' "uso: $0 hdmi|laptop|extend" >&2; exit 1 ;;
esac
