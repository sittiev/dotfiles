#!/usr/bin/dash
# Small Sway action hub using Tofi; avoids the old Hypr-only launcher.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
list='Terminal
Arquivos
Navegador
Tema do Tofi
Tema claro/escuro
Clipboard
Emoji
Luz noturna
Notificações
Horário
Data atual
Bateria
Yambar
Papel de parede'

choice=$(printf '%s\n' "$list" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Sway: " || true)
[ -n "$choice" ] || exit 0

case "$choice" in
    Terminal) exec foot ;;
    Arquivos) exec pcmanfm ;;
    Navegador) exec librewolf ;;
    'Tema do Tofi') exec "$script_dir/tofi-themes.sh" ;;
    'Tema claro/escuro') exec "$script_dir/theme-toggle.sh" toggle ;;
    Clipboard) exec "$script_dir/clipboard.sh" ;;
    Emoji) exec "$script_dir/emoji.sh" ;;
    'Luz noturna') exec "$script_dir/nightlight.sh" ;;
    Notificações) exec makoctl mode -t do-not-disturb ;;
    Horário) notify-send "Horário" "$(date '+%H:%M')" ;;
    'Data atual') notify-send "Data atual" "$(date '+%A, %d de %B de %Y')" ;;
    Bateria)
        capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || printf '?')
        notify-send "Bateria" "$capacity%" ;;
    Yambar) exec "$script_dir/yambar-toggle.sh" ;;
    'Papel de parede') exec "$script_dir/wallpaper.sh" ;;
esac
