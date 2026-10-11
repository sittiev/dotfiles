#!/usr/bin/dash
# Escolhe a família de ícones global entre YAMIS-wal e Papirus.
# Estado: ~/.cache/icon-theme (yamis|papirus; ausente = yamis, o comportamento
# atual), ~/.cache/icon-theme-papirus-variant (auto|Papirus|Papirus-Dark|
# Papirus-Light; ausente = auto, segue o modo claro/escuro) e
# ~/.cache/icon-theme-papirus-folders (auto|<cor>|default; ausente = auto,
# a cor segue o ACCENT da paleta via papirus-folders).
# theme-mode.sh consulta _resolve a cada apply: sem Papirus instalado ele
# falha silencioso e o YAMIS-wal assume (nada quebra sem o pacote).
# Cores de pasta verificadas no README do papirus-folders (preview): a lista
# abaixo só traz nomes de lá; papirus-folders -l -C -D --theme é a CLI usada.
# Uso: icon-theme.sh [yamis|papirus|menu|variant [V]|folders [C]|hardcode]
#   (TOFI_ICONTHEME / TOFI_PAPIRUS_VARIANT / TOFI_PAPIRUS_FOLDERS driblam o
#   seletor, p/ teste). _resolve <dark|light> é interno do theme-mode.sh.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/icon-theme"
state_variant="${XDG_CACHE_HOME:-$HOME/.cache}/icon-theme-papirus-variant"
state_folders="${XDG_CACHE_HOME:-$HOME/.cache}/icon-theme-papirus-folders"
# Nomes confirmados no README do papirus-folders; nada fora daqui é aceito.
folder_colors='adwaita black blue bluegrey breeze brown carmine cyan darkcyan deeporange green grey indigo magenta nordic orange palebrown paleorange pink teal white yellow'

icon_family() {
    cur=$(cat "$state" 2>/dev/null || printf 'yamis')
    case "$cur" in papirus|yamis) printf '%s' "$cur" ;; *) printf 'yamis' ;; esac
    unset cur
}

icon_variant() {
    cur=$(cat "$state_variant" 2>/dev/null || printf 'auto')
    case "$cur" in auto|Papirus|Papirus-Dark|Papirus-Light) printf '%s' "$cur" ;; *) printf 'auto' ;; esac
    unset cur
}

icon_folders() {
    cur=$(cat "$state_folders" 2>/dev/null || printf 'auto')
    case "$cur" in auto|default) printf '%s' "$cur" ;; *)
        case " $folder_colors " in *" $cur "*) printf '%s' "$cur" ;; *) printf 'auto' ;; esac ;;
    esac
    unset cur
}

icon_write() {
    printf '%s\n' "$2" > "$1.tmp.$$"
    mv -f -- "$1.tmp.$$" "$1"
}

papirus_root() {
    for root in "$HOME/.icons" "$HOME/.local/share/icons" /usr/local/share/icons /usr/share/icons; do
        if [ -f "$root/$1/index.theme" ]; then printf '%s' "$root"; return 0; fi
    done
    return 1
}

papirus_available() { papirus_root Papirus >/dev/null || papirus_root Papirus-Dark >/dev/null || papirus_root Papirus-Light >/dev/null; }

variant_resolve() {
    # variant_resolve [modo] → imprime a variante Papirus a usar.
    want=$(icon_variant)
    mode=${1:-$(cat "$HOME/.cache/theme-mode" 2>/dev/null || printf 'dark')}
    case "$want" in Papirus|Papirus-Dark|Papirus-Light)
        if papirus_root "$want" >/dev/null 2>&1; then printf '%s' "$want"; unset want mode; return 0; fi ;;
    esac
    if [ "$mode" = light ]; then
        for cand in Papirus-Light Papirus Papirus-Dark; do
            if papirus_root "$cand" >/dev/null 2>&1; then printf '%s' "$cand"; unset want mode cand; return 0; fi
        done
    else
        for cand in Papirus-Dark Papirus Papirus-Light; do
            if papirus_root "$cand" >/dev/null 2>&1; then printf '%s' "$cand"; unset want mode cand; return 0; fi
        done
    fi
    unset want mode cand
    return 1
}

folders_auto_color() {
    # ACCENT da paleta → cor papirus-folders mais próxima (matiz; S baixo = grey).
    pal="$HOME/.cache/theme-palette"
    [ -f "$pal" ] || return 1
    # shellcheck disable=SC1091
    . "$pal" 2>/dev/null || return 1
    [ -n "${ACCENT:-}" ] || return 1
    python3 - "$ACCENT" <<'PY' || return 1
import sys

def hsl(h):
    h = h.lstrip("#")
    r, g, b = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2
    if mx == mn:
        return 0.0, 0.0
    d = mx - mn
    s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        hh = ((g - b) / d + (6 if g < b else 0)) / 6
    elif mx == g:
        hh = ((b - r) / d + 2) / 6
    else:
        hh = ((r - g) / d + 4) / 6
    return hh * 360, s * 100

hue, sat = hsl(sys.argv[1])
if sat < 18:
    print("grey")
elif hue < 12 or hue >= 335:
    print("carmine")
elif hue < 38:
    print("deeporange")
elif hue < 58:
    print("orange")
elif hue < 80:
    print("yellow")
elif hue < 140:
    print("green")
elif hue < 168:
    print("teal")
elif hue < 195:
    print("cyan")
elif hue < 250:
    print("blue")
elif hue < 282:
    print("indigo")
elif hue < 305:
    print("magenta")
else:
    print("pink")
PY
    unset pal
}

folders_apply() {
    # folders_apply <variante> [ruidoso] — best effort, nunca quebra o apply.
    variant=$1
    noisy=${2:-0}
    command -v papirus-folders >/dev/null 2>&1 || return 1
    want=$(icon_folders)
    if [ "$want" = default ]; then
        if papirus-folders -D --theme "$variant" >/dev/null 2>&1; then unset variant noisy want; return 0; fi
    else
        if [ "$want" = auto ]; then want=$(folders_auto_color || true); fi
        [ -n "${want:-}" ] || { unset variant noisy want; return 0; }
        case " $folder_colors " in *" $want "*) ;;
            *) unset variant noisy want; return 1 ;;
        esac
        if papirus-folders -C "$want" --theme "$variant" >/dev/null 2>&1; then unset variant noisy want; return 0; fi
    fi
    if [ "$noisy" = 1 ]; then
        notify-send "Cor das pastas indisponível" "Para aplicar, rode: sudo papirus-folders -C $want --theme $variant." 2>/dev/null || true
    fi
    unset variant noisy want
    return 1
}

icon_apply() {
    "$script_dir/theme-mode.sh" apply >/dev/null 2>&1 || true
}

icon_set() {
    pick=$1
    case "$pick" in yamis|papirus) ;; *) echo "uso: icon-theme.sh [yamis|papirus|menu|variant [V]|folders [C]|hardcode]" >&2; exit 1 ;; esac
    if [ "$pick" = papirus ] && ! papirus_available; then
        notify-send "Ícones indisponíveis" "Para usar, instale papirus-icon-theme: sudo pacman -S papirus-icon-theme." 2>/dev/null || true
        exit 1
    fi
    cur=$(icon_family)
    if [ "$pick" = "$cur" ]; then unset pick cur; exit 0; fi
    unset cur
    mkdir -p -- "${state%/*}"
    icon_write "$state" "$pick"
    icon_apply
    if [ "$pick" = papirus ]; then name='Papirus'; else name='YAMIS-wal'; fi
    notify-send "Ícones" "$name aplicado. Reinicie apps abertos para ver a troca." 2>/dev/null || true
    unset pick name
}

variant_set() {
    pick=${1:-}
    if [ -z "$pick" ]; then
        if [ -n "${TOFI_PAPIRUS_VARIANT:-}" ]; then
            choice=$TOFI_PAPIRUS_VARIANT
        else
            choice=$(printf '%s\n' '< Voltar' 'Automática' 'Base' 'Escura' 'Clara' \
                | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Variante do Papirus" || true)
        fi
        [ -n "${choice:-}" ] || exit 0
        case "$choice" in
            *Voltar*) exit 0 ;;
            'Automática') pick=auto ;;
            'Base') pick=Papirus ;;
            'Escura') pick=Papirus-Dark ;;
            'Clara') pick=Papirus-Light ;;
            *) notify-send "Variante inválida" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
        esac
        unset choice
    fi
    case "$pick" in auto|Papirus|Papirus-Dark|Papirus-Light) ;; *) echo "uso: icon-theme.sh variant [auto|Papirus|Papirus-Dark|Papirus-Light]" >&2; exit 1 ;; esac
    cur=$(icon_variant)
    if [ "$pick" = "$cur" ]; then unset pick cur; exit 0; fi
    unset cur
    mkdir -p -- "${state_variant%/*}"
    icon_write "$state_variant" "$pick"
    icon_apply
    notify-send "Variante do Papirus" "Aplicada. Reinicie apps abertos para ver a troca." 2>/dev/null || true
    unset pick
}

folders_set() {
    pick=${1:-}
    if [ -z "$pick" ]; then
        if [ -n "${TOFI_PAPIRUS_FOLDERS:-}" ]; then
            choice=$TOFI_PAPIRUS_FOLDERS
        else
            # shellcheck disable=SC2086
            choice=$(printf '%s\n' '< Voltar' 'Automática' 'Padrão' $folder_colors \
                | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Cor das pastas" || true)
        fi
        [ -n "${choice:-}" ] || exit 0
        case "$choice" in
            *Voltar*) exit 0 ;;
            'Automática') pick=auto ;;
            'Padrão') pick=default ;;
            *)
                case " $folder_colors " in *" $choice "*) pick=$choice ;; *)
                    notify-send "Cor inválida" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
                esac ;;
        esac
        unset choice
    fi
    case "$pick" in auto|default) ;; *)
        case " $folder_colors " in *" $pick "*) ;; *) echo "uso: icon-theme.sh folders [auto|default|$folder_colors]" >&2; exit 1 ;; esac ;;
    esac
    if ! command -v papirus-folders >/dev/null 2>&1; then
        notify-send "Cor das pastas indisponível" "Para trocar, instale papirus-folders." 2>/dev/null || true
        exit 1
    fi
    cur=$(icon_folders)
    if [ "$pick" = "$cur" ]; then unset pick cur; exit 0; fi
    unset cur
    mkdir -p -- "${state_folders%/*}"
    icon_write "$state_folders" "$pick"
    variant=$(variant_resolve || true)
    if [ -n "${variant:-}" ]; then
        folders_apply "$variant" 1 || true
    fi
    unset pick variant
}

hardcode_fix() {
    notify-send "Ícones fixos" "Para corrigir, use hardcode-fixer e Hardcode-Tray (GitHub)." 2>/dev/null || true
}

icon_menu() {
    if [ -n "${TOFI_ICONTHEME:-}" ]; then
        choice=$TOFI_ICONTHEME
    else
        choice=$(printf '%s\n' '< Voltar' 'YAMIS-wal' 'Papirus' \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Ícones" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        'YAMIS-wal') icon_set yamis ;;
        'Papirus') icon_set papirus ;;
        *) notify-send "Ícones inválidos" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
    esac
    unset choice
}

cmd=${1:-menu}
case "$cmd" in
    yamis|papirus) icon_set "$cmd" ;;
    menu) icon_menu ;;
    variant) shift; variant_set "${1:-}" ;;
    folders) shift; folders_set "${1:-}" ;;
    hardcode) hardcode_fix ;;
    _resolve)
        # Interno do theme-mode.sh: imprime a variante e aplica pastas (silencioso).
        variant=$(variant_resolve "${2:-}" || exit 1)
        folders_apply "$variant" 0 || true
        printf '%s\n' "$variant"
        unset variant ;;
    *) echo "uso: icon-theme.sh [yamis|papirus|menu|variant [V]|folders [C]|hardcode]" >&2; exit 1 ;;
esac
unset cmd
