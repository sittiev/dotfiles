#!/usr/bin/dash
# Small Sway action hub using Tofi; avoids the old Hypr-only launcher.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
list='Terminal
Arquivos
Navegador
Tema do Tofi
Claro ou escuro
Esquemas de cores
Itens copiados
Emoji
Luz noturna
Avisos
Hora
Data
Bateria
Yambar
Papel de parede
Monitores
Bloquear tela
Energia
Bluetooth
Rede'

choice=$(printf '%s\n' "$list" | "$script_dir/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Ações: " || true)
[ -n "$choice" ] || exit 0

case "$choice" in
    Terminal) exec foot ;;
    Arquivos) exec pcmanfm ;;
    Navegador) exec librewolf ;;
    'Tema do Tofi') exec "$script_dir/tofi-themes.sh" ;;
    'Claro ou escuro') exec "$script_dir/theme-toggle.sh" toggle ;;
    'Esquemas de cores') exec "$script_dir/scheme-menu.sh" ;;
    'Itens copiados') exec "$script_dir/clipboard.sh" ;;
    Emoji) exec "$script_dir/emoji.sh" ;;
    'Luz noturna') exec "$script_dir/nightlight.sh" ;;
    Avisos)
        if makoctl mode 2>/dev/null | grep -q do-not-disturb; then
            makoctl mode -r do-not-disturb 2>/dev/null || true
            notify-send "Avisos ativados" 2>/dev/null || true
        else
            notify-send "Avisos silenciados" 2>/dev/null || true
            makoctl mode -a do-not-disturb 2>/dev/null || true
        fi ;;
    Hora) notify-send "Hora" "$(date '+%H:%M')" ;;
    'Data') notify-send "Data" "$(date '+%A, %d de %B de %Y')" ;;
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
        notify-send "Bluetooth indisponível" "Para configurar, instale overskride: paru -S overskride." 2>/dev/null || true ;;
    'Rede')
        if command -v iwgtk >/dev/null 2>&1; then exec iwgtk; fi
        notify-send "Rede indisponível" "Para configurar, instale iwgtk: paru -S iwgtk." 2>/dev/null || true ;;
esac
