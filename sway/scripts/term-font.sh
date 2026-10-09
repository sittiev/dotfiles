#!/usr/bin/dash
# Escolhe a fonte do terminal (foot) entre JetBrains Mono, Lexend e
# Atkinson Hyperlegible Mono.
# Sem arg: abre o seletor no tofi. Salva a chave em ~/.cache/term-font;
# render.sh lê de lá (ausente = jetbrains).
# Uso: term-font.sh [jetbrains|lexend|atkinson]   (TOFI_TERMFONT dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/term-font"

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_TERMFONT:-}" ]; then
        choice=$TOFI_TERMFONT
    else
        choice=$(printf '%s\n' '< Voltar' 'JetBrains Mono' 'Lexend' 'Atkinson Hyperlegible Mono' \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fonte do terminal" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        'JetBrains Mono') pick=jetbrains ;;
        'Lexend') pick=lexend ;;
        'Atkinson Hyperlegible Mono') pick=atkinson ;;
        *) notify-send "Fonte inválida" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
    esac
fi
case "$pick" in jetbrains|lexend|atkinson) ;; *) echo "uso: term-font.sh [jetbrains|lexend|atkinson]" >&2; exit 1 ;; esac

cur=$(cat "$state" 2>/dev/null || printf 'jetbrains')
case "$cur" in jetbrains|lexend|atkinson) ;; *) cur=jetbrains ;; esac
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

name=$(case "$pick" in jetbrains) printf 'JetBrains Mono' ;; lexend) printf 'Lexend' ;; *) printf 'Atkinson Hyperlegible Mono' ;; esac)
notify-send "Fonte do terminal" "$name aplicada. Novas janelas usam a fonte." 2>/dev/null || true
