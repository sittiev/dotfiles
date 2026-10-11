#!/usr/bin/dash
# Escolhe o gerenciador de arquivos padrão entre PCManFM e Dolphin.
# Sem arg: abre o padrão. Salva a chave em ~/.cache/file-manager;
# render nenhum lê daqui (ausente = pcmanfm).
# Uso: file-manager.sh [open|pcmanfm|dolphin|menu]   (TOFI_FILEMANAGER dribla o seletor, p/ teste)
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state="${XDG_CACHE_HOME:-$HOME/.cache}/file-manager"

fm_get() {
    cur=$(cat "$state" 2>/dev/null || printf 'pcmanfm')
    case "$cur" in pcmanfm|dolphin) printf '%s' "$cur" ;; *) printf 'pcmanfm' ;; esac
    unset cur
}

fm_set() {
    pick=$1
    case "$pick" in pcmanfm|dolphin) ;; *) echo "uso: file-manager.sh [open|pcmanfm|dolphin|menu]" >&2; exit 1 ;; esac
    if [ "$pick" = pcmanfm ]; then desktop=pcmanfm.desktop; else desktop=org.kde.dolphin.desktop; fi
    if [ "$pick" = pcmanfm ]; then bin=pcmanfm; else bin=dolphin; fi
    if ! command -v "$bin" >/dev/null 2>&1; then
        notify-send "Gerenciador indisponível" "Para usar, instale $bin: sudo pacman -S $bin." 2>/dev/null || true
        exit 1
    fi
    cur=$(fm_get)
    if [ "$pick" = "$cur" ]; then
        if command -v xdg-mime >/dev/null 2>&1 && [ -f "/usr/share/applications/$desktop" ]; then
            xdg-mime default "$desktop" inode/directory >/dev/null 2>&1 || true
        fi
        unset cur pick desktop bin
        exit 0
    fi
    unset cur
    mkdir -p -- "${state%/*}"
    tmp="$state.tmp.$$"
    trap 'rm -f -- "$tmp"' EXIT
    printf '%s\n' "$pick" > "$tmp"
    mv -f -- "$tmp" "$state"
    trap - EXIT
    if command -v xdg-mime >/dev/null 2>&1 && [ -f "/usr/share/applications/$desktop" ]; then
        xdg-mime default "$desktop" inode/directory >/dev/null 2>&1 || true
    fi
    if [ "$pick" = pcmanfm ]; then name='PCManFM'; else name='Dolphin'; fi
    notify-send "Gerenciador de arquivos" "$name definido como padrão." 2>/dev/null || true
    unset pick desktop bin name tmp
}

fm_open() {
    cur=$(fm_get)
    case "$cur" in
        dolphin)
            if ! command -v dolphin >/dev/null 2>&1; then
                notify-send "Gerenciador indisponível" "Para usar, instale dolphin: sudo pacman -S dolphin." 2>/dev/null || true
                exit 1
            fi
            unset cur
            exec dolphin "$@" ;;
        *)
            if ! command -v pcmanfm >/dev/null 2>&1; then
                notify-send "Gerenciador indisponível" "Para usar, instale pcmanfm: sudo pacman -S pcmanfm." 2>/dev/null || true
                exit 1
            fi
            unset cur
            exec pcmanfm "$@" ;;
    esac
}

fm_menu() {
    if [ -n "${TOFI_FILEMANAGER:-}" ]; then
        choice=$TOFI_FILEMANAGER
    else
        choice=$(printf '%s\n' '< Voltar' 'PCManFM' 'Dolphin' \
            | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Gerenciador de arquivos" || true)
    fi
    [ -n "${choice:-}" ] || exit 0
    case "$choice" in
        *Voltar*) exit 0 ;;
        'PCManFM') fm_set pcmanfm ;;
        'Dolphin') fm_set dolphin ;;
        *) notify-send "Gerenciador inválido" "Para aplicar, escolha um nome da lista." 2>/dev/null || true; exit 1 ;;
    esac
    unset choice
}

cmd=${1:-open}
case "$cmd" in
    open) shift; fm_open "$@" ;;
    pcmanfm|dolphin) fm_set "$cmd" ;;
    menu) fm_menu ;;
    *) echo "uso: file-manager.sh [open|pcmanfm|dolphin|menu]" >&2; exit 1 ;;
esac
unset cmd
