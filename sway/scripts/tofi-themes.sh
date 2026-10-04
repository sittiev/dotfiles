#!/usr/bin/dash
# Pick and apply a Tofi layout from the native Tofi dmenu interface.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
themes="$HOME/.config/tofi/themes"

[ -d "$themes" ] || {
    notify-send "Temas do Tofi indisponíveis" "Para escolher um layout, restaure ~/.config/tofi/themes." 2>/dev/null || true
    exit 1
}

names=$(find -L "$themes" -mindepth 2 -maxdepth 2 -type f -name config -exec dirname {} \; 2>/dev/null | xargs -r -n1 basename | sort)
# "clipboard" e "emoji" sao layouts reservados (janela propria, um so por
# consumidor): nao entram no seletor, senao virariam o layout do launcher.
kept=""
for n in $names; do
    case "$n" in
        clipboard|emoji) ;;
        *) kept="$kept$n
" ;;
    esac
done
names=$kept
[ -n "$names" ] || {
    notify-send "Nenhum tema do Tofi" "Para escolher um layout, adicione um config em ~/.config/tofi/themes." 2>/dev/null || true
    exit 1
}

if [ -n "${TOFI_PICK:-}" ]; then
    choice=$TOFI_PICK
else
    choice=$(printf '%s\n' "< Voltar" "$names" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Tema" --hide-input=true --text-cursor=false || true)
fi
[ -n "$choice" ] || exit 0
case "$choice" in *Voltar*) exit 0 ;; esac
choice=$(basename -- "$choice")
[ -f "$themes/$choice/config" ] || exit 1

exec "$script_dir/tofi-apply.sh" "$choice"
