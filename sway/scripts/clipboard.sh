#!/usr/bin/dash
# Select a cliphist entry with Tofi and copy it back to the Wayland clipboard.
set -eu

if [ -n "${TOFI_PICK:-}" ]; then
    selection=$TOFI_PICK
else
    selection=$(printf '%s\n' "< Voltar" "$(cliphist list | head -50)" | "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tofi-safe.sh" --config "$HOME/.config/tofi/config-clipboard" --prompt-text "Área de transferência" --hide-input=true --text-cursor=false || true)
fi
[ -n "$selection" ] || exit 0
case "$selection" in *Voltar*) exit 0 ;; esac
printf '%s' "$selection" | cliphist decode | wl-copy
