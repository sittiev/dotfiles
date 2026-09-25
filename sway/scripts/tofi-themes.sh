#!/usr/bin/dash
# Pick and apply a Tofi layout from the native Tofi dmenu interface.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
themes="$HOME/.config/tofi/themes"

[ -d "$themes" ] || {
    notify-send "Tofi" "Pasta de temas não encontrada." 2>/dev/null || true
    exit 1
}

names=$(find -L "$themes" -mindepth 2 -maxdepth 2 -type f -name config -exec dirname {} \; 2>/dev/null | xargs -r -n1 basename | sort)
[ -n "$names" ] || {
    notify-send "Tofi" "Nenhum tema disponível." 2>/dev/null || true
    exit 1
}

if [ -n "${TOFI_PICK:-}" ]; then
    choice=$TOFI_PICK
else
    choice=$(printf '%s\n' "$names" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Tema tofi: " || true)
fi
[ -n "$choice" ] || exit 0
choice=$(basename -- "$choice")
[ -f "$themes/$choice/config" ] || exit 1

exec "$script_dir/tofi-apply.sh" "$choice"
