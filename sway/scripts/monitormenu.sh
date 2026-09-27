#!/usr/bin/dash
# monitormenu.sh — submenu de monitores estilo nightmenu (Mod+Shift+x → Monitores).
# HDMI-A-1 e o principal (esquerda); eDP-1 desliga com HDMI (outputs.sh auto).
# Non-interactive test hook: TOFI_PICK="<exact entry>" forces a choice.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

pick() {
    if [ -n "${TOFI_PICK:-}" ]; then printf '%s\n' "$TOFI_PICK"; return 0; fi
    printf '%s\n' "Auto (HDMI)" "Só HDMI" "Só notebook" "Estender" "Espelhar" \
        | "$script_dir/tofi-safe.sh" --prompt-text "Monitor: " || true
}

choice=$(pick)
[ -n "$choice" ] || exit 0
case "$choice" in
    "Auto (HDMI)") exec "$script_dir/outputs.sh" auto ;;
    "Só HDMI") exec "$script_dir/outputs.sh" hdmi ;;
    "Só notebook") exec "$script_dir/outputs.sh" laptop ;;
    "Estender") exec "$script_dir/outputs.sh" extend ;;
    "Espelhar") exec "$script_dir/outputs.sh" mirror ;;
    *) exit 0 ;;
esac
