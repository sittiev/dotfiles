#!/usr/bin/dash
# dewlock com as cores do tema corrente. Regenera ~/.config/dewlock/config
# a cada trava (paleta viva do theme.sh, sem estado duplicado).
# Singleton e --pre-sleep seguem o contrato do swaylock.sh.
set -eu

command -v dewlock >/dev/null 2>&1 || {
    notify-send "Bloqueio indisponível" "Para bloquear a tela, reinstale dewlock: make install em /tmp/opencode/dewlock." 2>/dev/null || true
    exit 1
}

# Singleton: flock no lugar do pgrep — o pgrep tem janela de corrida: timeout,
# lock e before-sleep disparam juntos no suspend e instâncias empilhadas
# cobram a senha duas vezes no resume. O fd 9 passa ao dewlock no exec e o
# lock cai sozinho quando ele fecha.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/dewlock.lock" 2>/dev/null || exec 9>"/tmp/dewlock.lock"
flock -n 9 || exit 0

fork=
if [ "${1:-}" = "--pre-sleep" ]; then
    fork=1
fi

c=${XDG_CACHE_HOME:-$HOME/.cache}
mode=$(cat "$c/theme-mode" 2>/dev/null || printf '%s' dark)
pal="$c/theme-palette.$mode"
[ -f "$pal" ] || pal="$c/theme-palette"
[ -f "$pal" ] || {
    notify-send "Tema indisponível" "Para bloquear com as cores do tema, rode theme.sh primeiro." 2>/dev/null || true
    exit 1
}
# shellcheck disable=SC1090
. "$pal"

case "$(cat "$c/ui-font" 2>/dev/null || printf 'noto')" in
    sf) UI="SF Pro Display" ;;
    segoe) UI="Segoe UI" ;;
    *) UI="Noto Sans" ;;
esac

cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dewlock"
cfg="$cfg_dir/config"
mkdir -p -- "$cfg_dir"
tmp="$cfg_dir/.config.$$"
cat > "$tmp" <<EOF
background.mode=solid_color
font.family=$UI
font.size=16
color.background=${BG}FF
color.overlay=00000000
color.text=${FG}FF
color.warning=${FAIL}FF
color.error=${FAIL}FF
EOF
mv -f -- "$tmp" "$cfg"

if [ -n "$fork" ]; then
    exec dewlock -f
fi

exec dewlock
