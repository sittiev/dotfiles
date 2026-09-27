#!/usr/bin/dash
# Small Sway action hub using Tofi; avoids the old Hypr-only launcher.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
list='Terminal
Arquivos
Navegador
Tema do Tofi
Tema claro/escuro
Esquemas de cores
Clipboard
Emoji
Luz noturna
Notificações
Horário
Data atual
Bateria
Yambar
Papel de parede
Monitores
Bloquear tela
Energia
Bluetooth
Rede (iwgtk)'

choice=$(printf '%s\n' "$list" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Sway: " || true)
[ -n "$choice" ] || exit 0

case "$choice" in
    Terminal) exec foot ;;
    Arquivos) exec pcmanfm ;;
    Navegador) exec librewolf ;;
    'Tema do Tofi') exec "$script_dir/tofi-themes.sh" ;;
    'Tema claro/escuro') exec "$script_dir/theme-toggle.sh" toggle ;;
    'Esquemas de cores') exec "$script_dir/scheme-menu.sh" ;;
    Clipboard) exec "$script_dir/clipboard.sh" ;;
    Emoji) exec "$script_dir/emoji.sh" ;;
    'Luz noturna') exec "$script_dir/nightlight.sh" ;;
    Notificações)
        if makoctl mode 2>/dev/null | grep -q do-not-disturb; then
            makoctl mode -r do-not-disturb 2>/dev/null || true
            notify-send "Notificações" "Ativadas" 2>/dev/null || true
        else
            notify-send "Notificações" "Silenciadas" 2>/dev/null || true
            makoctl mode -a do-not-disturb 2>/dev/null || true
        fi ;;
    Horário) notify-send "Horário" "$(date '+%H:%M')" ;;
    'Data atual') notify-send "Data atual" "$(date '+%A, %d de %B de %Y')" ;;
    Bateria)
        capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || printf '?')
        notify-send "Bateria" "$capacity%" ;;
    Yambar) exec "$script_dir/yambar-toggle.sh" ;;
    'Papel de parede') exec "$script_dir/wallpaper.sh" ;;
    'Monitores') exec "$script_dir/monitormenu.sh" ;;
    'Bloquear tela') exec "$script_dir/waylock.sh" ;;
    Energia) exec "$script_dir/powermenu.sh" ;;
    Bluetooth)
        if command -v overskride >/dev/null 2>&1; then exec overskride; fi
        if command -v bluetoothctl >/dev/null 2>&1; then exec foot -e bluetoothctl; fi
        notify-send "Bluetooth" "overskride não instalado (paru -S overskride)." 2>/dev/null || true ;;
    'Rede (iwgtk)')
        if command -v iwgtk >/dev/null 2>&1; then exec iwgtk; fi
        notify-send "Rede" "iwgtk não instalado (paru -S iwgtk)." 2>/dev/null || true ;;
esac
