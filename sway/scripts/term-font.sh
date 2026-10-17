#!/usr/bin/dash
# Escolhe a fonte do terminal (foot) entre todas as fontes do sistema
# (fc-list). Sem arg: abre o seletor no tofi. Salva a família em
# ~/.cache/term-font (chaves antigas jetbrains/lexend/atkinson continuam
# válidas); render.sh lê de lá (ausente = jetbrains). Toda escolha cai no
# JetBrainsMono Nerd Font como fallback (glifos/ícones).
# Uso: term-font.sh [jetbrains|lexend|atkinson|<família>]   (TOFI_TERMFONT dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/term-font"

# Todas as famílias instaladas; fc-list junta estilos com vírgula e ':' quebra
# a spec de fonte do foot, então ambos saem da lista.
families() {
    fc-list : family 2>/dev/null | tr ',' '\n' | sort -u | grep -v ':'
}
# Chaves antigas viram família; valor novo já é a família.
to_family() {
    case "$1" in
        jetbrains) printf 'JetBrainsMono Nerd Font' ;;
        lexend) printf 'Lexend' ;;
        atkinson) printf 'Atkinson Hyperlegible Mono' ;;
        *) printf '%s' "$1" ;;
    esac
}

cur=$(cat "$state" 2>/dev/null || printf 'jetbrains')

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_TERMFONT:-}" ]; then
        choice=$TOFI_TERMFONT
    else
        fam=$(to_family "$cur")
        list=$(families | awk -v cur="$fam" '{ if ($0 == cur) print $0 " (atual)"; else print }')
        choice=$(printf '%s\n' '< Voltar' "$list" \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fonte do terminal" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        *)
            pick=${choice% (atual)}
            case "$pick" in jetbrains|lexend|atkinson) ;; *)
                if ! families | grep -Fxq -- "$pick"; then
                    notify-send "Fonte não instalada" "Para aplicar, escolha um nome da lista." 2>/dev/null || true
                    exit 1
                fi
            ;;
            esac
        ;;
    esac
fi
[ -n "$pick" ] || { echo "uso: term-font.sh [jetbrains|lexend|atkinson|<família>]" >&2; exit 1; }

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

name=$(to_family "$pick")
notify-send "Fonte do terminal" "$name aplicada. Novas janelas usam a fonte." 2>/dev/null || true
