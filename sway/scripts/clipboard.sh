#!/usr/bin/dash
# Select a cliphist entry with Tofi and copy it back to the Wayland clipboard.
set -eu

selection=$(cliphist list | head -50 | "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Clipboard: " || true)
[ -n "$selection" ] || exit 0
printf '%s' "$selection" | cliphist decode | wl-copy
