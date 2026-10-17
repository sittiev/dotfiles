#!/usr/bin/dash
# Escolhe a fonte mono (yambar, tofi, OSDs do mako) entre todas as fontes do
# sistema (fc-list) e "Automática". Sem arg: abre o seletor no tofi. Salva a
# família em ~/.cache/mono-font (chaves antigas auto/noto/jetbrains/atkinson
# continuam válidas); render.sh e tofi-apply.sh leem de lá (ausente = auto:
# yambar e tofi seguem a fonte da UI, relógio e OSDs usam Noto Sans Mono).
# Uso: mono-font.sh [auto|noto|jetbrains|atkinson|<família>]   (TOFI_MONOFONT dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/mono-font"

# Todas as famílias instaladas; fc-list junta estilos com vírgula e ':' quebra
# a spec de fonte dos apps, então ambos saem da lista.
families() {
    fc-list : family 2>/dev/null | tr ',' '\n' | sort -u | grep -v ':'
}
# Chaves antigas viram família; valor novo já é a família.
to_family() {
    case "$1" in
        noto) printf 'Noto Sans Mono' ;;
        jetbrains) printf 'JetBrainsMono Nerd Font' ;;
        atkinson) printf 'Atkinson Hyperlegible Mono' ;;
        *) printf '%s' "$1" ;;
    esac
}

cur=$(cat "$state" 2>/dev/null || printf 'auto')

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_MONOFONT:-}" ]; then
        choice=$TOFI_MONOFONT
    else
        fam=$(to_family "$cur")
        list=$(families | awk -v cur="$fam" '{ if ($0 == cur) print $0 " (atual)"; else print }')
        choice=$(printf '%s\n' '< Voltar' 'Automática' "$list" \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fonte mono" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        'Automática (atual)'|'Automática') pick=auto ;;
        *)
            pick=${choice% (atual)}
            case "$pick" in noto|jetbrains|atkinson) ;; *)
                if ! families | grep -Fxq -- "$pick"; then
                    notify-send "Fonte não instalada" "Para aplicar, escolha um nome da lista." 2>/dev/null || true
                    exit 1
                fi
            ;;
            esac
        ;;
    esac
fi
case "$pick" in
    auto|noto|jetbrains|atkinson) ;;
    *) [ -n "$pick" ] || { echo "uso: mono-font.sh [auto|noto|jetbrains|atkinson|<família>]" >&2; exit 1; } ;;
esac

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

name=$(case "$pick" in auto) printf 'Automática' ;; *) to_family "$pick" ;; esac)
notify-send "Fonte mono" "$name aplicada." 2>/dev/null || true
