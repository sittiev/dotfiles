#!/usr/bin/dash
# Escolhe o tamanho da fonte da UI (mako principal + launcher tofi) na rampa
# MS/Apple: 12 Caption/Legenda, 14 Body/Corpo (padrao), 18 Destaque.
# Sem arg: abre o seletor no tofi. Salva o número em ~/.cache/ui-font-size;
# render.sh (mako) e tofi-apply.sh (launcher) leem de lá (ausente = 14).
# Fixos fora do ajuste: OSDs mako Caption 12 (mínimo), yambar 12 (18px da
# barra), GTK 11 (padrão desktop), tofi dmenu 12 (barra 18px), clipboard 18
# (lista densa), dark-paper 28 (Title).
# Uso: ui-font-size.sh [12|14|18]   (TOFI_UISIZE dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/ui-font-size"

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_UISIZE:-}" ]; then
        choice=$TOFI_UISIZE
    else
        choice=$(printf '%s\n' '12' '14' '18' \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Tamanho: " || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        12|14|18) pick=$choice ;;
        *) notify-send "Tamanho inválido" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
    esac
fi
case "$pick" in 12|14|18) ;; *) echo "uso: ui-font-size.sh [12|14|18]" >&2; exit 1 ;; esac

cur=$(cat "$state" 2>/dev/null || printf '14')
case "$cur" in 12|14|18) ;; *) cur=14 ;; esac
[ "$pick" = "$cur" ] && exit 0

mkdir -p -- "${state%/*}"
tmp="$state.tmp.$$"
trap 'rm -f -- "$tmp"' EXIT
printf '%s\n' "$pick" > "$tmp"
mv -f -- "$tmp" "$state"
trap - EXIT

mode=$(cat "$HOME/.cache/theme-mode" 2>/dev/null || printf 'dark')
case "$mode" in light|dark) ;; *) mode=dark ;; esac
"$script_dir/render.sh" "$mode" >/dev/null 2>&1

notify-send "Tamanho da interface" "$pick aplicado." 2>/dev/null || true
