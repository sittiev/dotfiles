#!/usr/bin/dash
# Launch Waypaper with swaybg and refresh the pywal theme after each change.
set -eu

config_dir=${XDG_CONFIG_HOME:-$HOME/.config}/waypaper
config=$config_dir/config.ini
theme=$HOME/.config/sway/scripts/theme.sh

if ! command -v waypaper >/dev/null 2>&1; then
    notify-send "Papel de parede" "Instale waypaper (yay -S waypaper)." 2>/dev/null || true
    exit 127
fi
if ! command -v swaybg >/dev/null 2>&1; then
    notify-send "Papel de parede" "Instale swaybg (sudo pacman -S swaybg)." 2>/dev/null || true
    exit 127
fi

mkdir -p "$config_dir"
if [ ! -f "$config" ]; then
    cat > "$config" <<EOF
[Settings]
backend = swaybg
post_command = "$theme" \$wallpaper
EOF
else
    if ! grep -q '^\[Settings\]' "$config"; then
        printf '\n[Settings]\n' >> "$config"
    fi

    set_setting() {
        key=$1
        value=$2
        temporary=$config.tmp.$$
        awk -v key="$key" -v value="$value" '
            BEGIN { in_settings = 0; found = 0 }
            /^\[Settings\]$/ { in_settings = 1; print; next }
            /^\[/ { in_settings = 0 }
            {
                if (in_settings && $0 ~ "^[[:space:]]*" key "[[:space:]]*=") {
                    if (!found) {
                        print key " = " value
                        found = 1
                    }
                    next
                }
                print
            }
            END {
                if (in_settings && !found) {
                    print key " = " value
                }
            }
        ' "$config" > "$temporary"
        mv "$temporary" "$config"
    }

    set_setting backend swaybg
    set_setting post_command "\"$theme\" \$wallpaper"
fi

# Note: never pass --backend here. Waypaper's swaybg backend picks its
# previous process with `pgrep -f swaybg` (lowest PID), and a command line
# containing "swaybg" matches this very process: waypaper used to kill itself
# before running post_command, so the wallpaper changed but theme.sh did not
# run (the "press twice" bug). The backend stays in config.ini above.
if [ "${1:-}" = "--restore" ]; then
    saved=$(sed -n 's|^wallpaper[[:space:]]*=[[:space:]]*||p' "$config" | head -1 | sed 's|^~|'"$HOME"'|')
    if [ -z "$saved" ] || [ ! -f "$saved" ]; then
        saved=$(cat "$HOME/.cache/current-wallpaper" 2>/dev/null || true)
    fi
    if [ -n "$saved" ] && [ -f "$saved" ]; then
        # Startup already runs theme.sh once (sway config); skip the duplicate.
        exec waypaper --no-post-command --wallpaper "$saved"
    fi
fi

exec waypaper "$@"
