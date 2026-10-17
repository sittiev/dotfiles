#!/usr/bin/dash
# Escolhe a fonte da UI (mako/yambar/tofi/GTK/Qt) entre todas as fontes do
# sistema (fc-list). Sem arg: abre o seletor no tofi. Salva a família em
# ~/.cache/ui-font (chaves antigas noto/sf/segoe continuam válidas);
# render.sh e tofi-apply.sh leem de lá (ausente = noto).
# Uso: ui-font.sh [noto|sf|segoe|<família>]   (TOFI_UIFONT dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/ui-font"

# Todas as famílias instaladas; fc-list junta estilos com vírgula e ':' quebra
# a spec de fonte dos apps, então ambos saem da lista.
families() {
    fc-list : family 2>/dev/null | tr ',' '\n' | sort -u | grep -v ':'
}
# Chaves antigas viram família; valor novo já é a família.
to_family() {
    case "$1" in
        sf) printf 'SF Pro Display' ;;
        segoe) printf 'Segoe UI' ;;
        noto) printf 'Noto Sans' ;;
        *) printf '%s' "$1" ;;
    esac
}

cur=$(cat "$state" 2>/dev/null || printf 'noto')

pick=${1:-}
if [ -z "$pick" ]; then
    if [ -n "${TOFI_UIFONT:-}" ]; then
        choice=$TOFI_UIFONT
    else
        fam=$(to_family "$cur")
        list=$(families | awk -v cur="$fam" '{ if ($0 == cur) print $0 " (atual)"; else print }')
        choice=$(printf '%s\n' '< Voltar' "$list" \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Fonte" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        *)
            pick=${choice% (atual)}
            case "$pick" in sf|segoe|noto) ;; *)
                if ! families | grep -Fxq -- "$pick"; then
                    notify-send "Fonte não instalada" "Para aplicar, escolha um nome da lista." 2>/dev/null || true
                    exit 1
                fi
            ;;
            esac
        ;;
    esac
fi
[ -n "$pick" ] || { echo "uso: ui-font.sh [noto|sf|segoe|<família>]" >&2; exit 1; }

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
notify-send "Fonte da interface" "$name aplicada." 2>/dev/null || true
