#!/usr/bin/dash
# powermenu.sh — energia via tofi (menu Mod+Shift+x → Energia).
# Suspender-ocioso grava ~/.cache/suspend-timeout (0=nunca) e reinicia idle.sh.
# Tampa-fechada grava ~/.cache/lid-action (suspend|nada), lido por outputs.sh.
# Non-interactive test hook: TOFI_PICK="<exact entry>" forces a choice.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

pick() {
    if [ -n "${TOFI_PICK:-}" ]; then printf '%s\n' "$TOFI_PICK"; return 0; fi
    printf '%s\n' "Suspender em 5min" "Suspender em 10min" "Suspender em 15min" \
        "Suspender em 30min" "Nunca suspender" "Tampa: suspender" "Tampa: nada" \
        | "$script_dir/tofi-safe.sh" --prompt-text "Energia: " || true
}

choice=$(pick)
[ -n "$choice" ] || exit 0
case "$choice" in
    "Suspender em 5min") printf '300' > "$HOME/.cache/suspend-timeout" ;;
    "Suspender em 10min") printf '600' > "$HOME/.cache/suspend-timeout" ;;
    "Suspender em 15min") printf '900' > "$HOME/.cache/suspend-timeout" ;;
    "Suspender em 30min") printf '1800' > "$HOME/.cache/suspend-timeout" ;;
    "Nunca suspender") printf '0' > "$HOME/.cache/suspend-timeout" ;;
    "Tampa: suspender") printf 'suspend' > "$HOME/.cache/lid-action" ; exit 0 ;;
    "Tampa: nada") printf 'nada' > "$HOME/.cache/lid-action"; exit 0 ;;
    *) exit 0 ;;
esac
exec "$script_dir/idle.sh"
