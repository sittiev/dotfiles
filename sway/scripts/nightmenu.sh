#!/usr/bin/dash
# nightmenu.sh — temperature presets picker via tofi (Super+Shift+n).
#
# Extremes: 1000 K (night) … 6500 K (day/off), plus gamma shapers.
# Everything goes through nightlib.sh, hence wlsunset on every output.
# Non-interactive test hook: TOFI_PICK="<exact entry>" forces a choice.

set -eu

# shellcheck disable=SC1091
. "${0%/*}/nightlib.sh"

readonly MENU_PROMPT="Luz noturna"

# is_temp VALUE: true iff VALUE is an integer in wlsunset range.
is_temp() {
    case ${1:-} in
        '' | *[!0-9]*) return 1 ;;
    esac
    [ "$1" -ge 1000 ] && [ "$1" -le 6500 ]
}

pick_choice() {
    if [ -n "${TOFI_PICK:-}" ]; then
        printf '%s\n' "$TOFI_PICK"
        return 0
    fi
    printf '%s\n' "< Voltar" "1000 K — noite" "2000 K" "3000 K" "4500 K" \
        "6500 K — dia" "Escurecer (gamma 0.8)" "Normal (gamma 1.0)" "Desligar" \
        | "$(CDPATH= cd -- "${0%/*}" && pwd)/tofi-safe.sh" --prompt-text "$MENU_PROMPT" --hide-input=true --text-cursor=false || true
}

apply_choice() {
    # $1: menu entry. Reads current temp from the running instance, if any.
    choice=$1
    current=$(pgrep -a -x wlsunset 2>/dev/null | head -n 1)
    case $current in
        *"-t "[0-9]*) current=${current#*-t }; current=${current%% *} ;;
        *) current="" ;;
    esac
    case $choice in
        *Voltar*) return 0 ;;
        "1000 K — noite") night_apply 1000 ;;
        "2000 K") night_apply 2000 ;;
        "3000 K") night_apply 3000 ;;
        "4500 K") night_apply 4500 ;;
        "6500 K — dia" | "Desligar") night_off || true ;;
        "Escurecer"*)
            if ! is_temp "$current"; then current=1000; fi
            night_apply "$current" 0.8
            ;;
        "Normal"*)
            if ! is_temp "$current"; then current=1000; fi
            night_apply "$current" 1.0
            ;;
        *) return 0 ;;
    esac
}

main() {
    choice=$(pick_choice)
    [ -n "$choice" ] || exit 0
    apply_choice "$choice"
}

main "$@"
