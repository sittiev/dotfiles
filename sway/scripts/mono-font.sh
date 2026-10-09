#!/usr/bin/dash
# Escolhe a fonte mono (yambar, tofi, OSDs do mako) entre Automática,
# Noto Sans Mono, JetBrains Mono e Atkinson Hyperlegible Mono.
# Sem arg: abre o seletor no tofi. Salva a chave em ~/.cache/mono-font;
# render.sh e tofi-apply.sh leem de lá (ausente = auto: yambar e tofi
# seguem a fonte da UI, relógio e OSDs usam Noto Sans Mono).
# Uso: mono-font.sh [auto|noto|jetbrains|atkinson]   (TOFI_MONOFONT dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/mono-font"

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_MONOFONT:-}" ]; then
        choice=$TOFI_MONOFONT
    else
        choice=$(printf '%s\n' '< Voltar' 'Automática' 'Noto Sans Mono' 'JetBrains Mono' 'Atkinson Hyperlegible Mono' \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fonte mono" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        'Automática') pick=auto ;;
        'Noto Sans Mono') pick=noto ;;
        'JetBrains Mono') pick=jetbrains ;;
        'Atkinson Hyperlegible Mono') pick=atkinson ;;
        *) notify-send "Fonte inválida" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
    esac
fi
case "$pick" in auto|noto|jetbrains|atkinson) ;; *) echo "uso: mono-font.sh [auto|noto|jetbrains|atkinson]" >&2; exit 1 ;; esac

cur=$(cat "$state" 2>/dev/null || printf 'auto')
case "$cur" in auto|noto|jetbrains|atkinson) ;; *) cur=auto ;; esac
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

name=$(case "$pick" in auto) printf 'Automática' ;; noto) printf 'Noto Sans Mono' ;; jetbrains) printf 'JetBrains Mono' ;; *) printf 'Atkinson Hyperlegible Mono' ;; esac)
notify-send "Fonte mono" "$name aplicada." 2>/dev/null || true
