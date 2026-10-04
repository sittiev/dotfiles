#!/usr/bin/dash
# Escolhe a fonte da UI (mako/yambar/tofi) entre Noto Sans, SF Pro e Segoe UI.
# Sem arg: abre o seletor no tofi. Salva a chave em ~/.cache/ui-font;
# render.sh e tofi-apply.sh leem de la (ausente = noto).
# Uso: ui-font.sh [noto|sf|segoe]   (TOFI_UIFONT dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/ui-font"

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_UIFONT:-}" ]; then
        choice=$TOFI_UIFONT
    else
        choice=$(printf '%s\n' '< Voltar' 'Noto Sans' 'SF Pro Display' 'Segoe UI' \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fonte" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        'Noto Sans') pick=noto ;;
        'SF Pro Display') pick=sf ;;
        'Segoe UI') pick=segoe ;;
        *) notify-send "Fonte inválida" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
    esac
fi
case "$pick" in noto|sf|segoe) ;; *) echo "uso: ui-font.sh [noto|sf|segoe]" >&2; exit 1 ;; esac

cur=$(cat "$state" 2>/dev/null || printf 'noto')
case "$cur" in noto|sf|segoe) ;; *) cur=noto ;; esac
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

name=$(case "$pick" in noto) printf 'Noto Sans' ;; sf) printf 'SF Pro Display' ;; *) printf 'Segoe UI' ;; esac)
notify-send "Fonte da interface" "$name aplicada." 2>/dev/null || true
