#!/usr/bin/dash
# kanshi-hook.sh — pós-perfil kanshi: foco + swayrst, sem reaplicar output.
# O kanshi já aplicou enable/disable/pos do perfil; reaplicar aqui (swaymsg
# output) correria contra o daemon. Espelha o caminho silencioso do
# `outputs.sh auto` (sem notify no hotplug/login).
# Uso: kanshi-hook.sh hdmi|laptop|extend   (chamado via `exec` no kanshi/config)
set -eu

HDMI=HDMI-A-1
LAPTOP=eDP-1

# restore <perfil> — mesmo do outputs.sh: cada modo tem um perfil swayrst
# salvo; roda depois da troca porque o swayrst só move com o output alvo já
# habilitado. Silencioso se ainda não salvo.
restore() { # <perfil>
    [ -f "$HOME/.config/sway/workspace_$1" ] || return 0
    command -v swayrst >/dev/null 2>&1 || return 0
    sleep 0.3 # outputs recém-trocados ainda não assentaram na árvore
    swayrst load "$1" >/dev/null 2>&1 || true
}

mode=${1:-}
case "$mode" in
    hdmi)
        swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
        restore hdmi
        ;;
    laptop)
        swaymsg focus output "$LAPTOP" >/dev/null 2>&1 || true
        restore laptop
        ;;
    extend)
        swaymsg focus output "$HDMI" >/dev/null 2>&1 || true
        restore extend
        ;;
    *) printf '%s\n' "uso: $0 hdmi|laptop|extend" >&2; exit 1 ;;
esac
