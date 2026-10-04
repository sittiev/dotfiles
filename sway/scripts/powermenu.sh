#!/usr/bin/dash
# powermenu.sh — energia via tofi (menu Mod+Shift+x → Energia).
# Suspender-ocioso grava ~/.cache/suspend-timeout (0=nunca) e reinicia idle.sh.
# Tampa-fechada grava ~/.cache/lid-action (suspend|nada), lido por outputs.sh.
# Non-interactive test hook: TOFI_PICK="<exact entry>" forces a choice.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

pick() {
    if [ -n "${TOFI_PICK:-}" ]; then printf '%s\n' "$TOFI_PICK"; return 0; fi
    printf '%s\n' "← Voltar" "Suspender em 5 min" "Suspender em 10 min" "Suspender em 15 min" \
        "Suspender em 30 min" "Nunca suspender" "Tampa fechada: suspender" "Tampa fechada: apenas desligar a tela" \
        | "$script_dir/tofi-safe.sh" --prompt-text "Energia: " || true
}

choice=$(pick)
[ -n "$choice" ] || exit 0
case "$choice" in
    *Voltar*) exit 0 ;;
    "Suspender em 5 min") printf '300' > "$HOME/.cache/suspend-timeout" ;;
    "Suspender em 10 min") printf '600' > "$HOME/.cache/suspend-timeout" ;;
    "Suspender em 15 min") printf '900' > "$HOME/.cache/suspend-timeout" ;;
    "Suspender em 30 min") printf '1800' > "$HOME/.cache/suspend-timeout" ;;
    "Nunca suspender") printf '0' > "$HOME/.cache/suspend-timeout" ;;
    "Tampa fechada: suspender") printf 'suspend' > "$HOME/.cache/lid-action" ; exit 0 ;;
    "Tampa fechada: apenas desligar a tela") printf 'nada' > "$HOME/.cache/lid-action"; exit 0 ;;
    *) exit 0 ;;
esac
exec "$script_dir/idle.sh"
