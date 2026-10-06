#!/usr/bin/dash
# swaylock com as cores do tema corrente. O wrapper passa a paleta viva do
# theme.sh via flags de CLI (sem duplicar estado em ~/.swaylock/config).
# Relógio: o swaylock upstream (1.8) não tem --clock (ver man 1.8.6 e o
# swaylock.1.scd no master); quando o binário suportar (fork
# swaylock-effects), o wrapper liga --clock/--timestr/--datestr sozinho.
# Guardado: só roda com o swaylock instalado.
set -eu

command -v swaylock >/dev/null 2>&1 || {
    notify-send "Bloqueio indisponível" "Para bloquear a tela, instale swaylock-effects: paru -S swaylock-effects-git." 2>/dev/null || true
    exit 1
}

# Singleton: timeout 300 + evento lock + before-sleep disparam juntos no
# suspend; sem isto cada instância empilhada cobra uma senha no resume.
if command -v pgrep >/dev/null 2>&1 && pgrep -x swaylock >/dev/null 2>&1; then
    exit 0
fi

# --pre-sleep (só para o before-sleep do swayidle): -f faz o swaylock
# bifurcar após travar, liberando o delay lock do logind para suspender.
# Sem isto o logind força o sleep após InhibitDelayMaxSec (5s) com a tela
# em estado indefinido. Nunca use no lock manual: ele precisa ficar em
# foreground.
fork=
if [ "${1:-}" = "--pre-sleep" ]; then
    fork=1
    shift
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

# Fonte da UI (ui-font.sh): a mesma do render.sh, para o relógio e o texto
# do bloqueio seguirem o tema.
case "$(cat "$c/ui-font" 2>/dev/null || printf 'noto')" in
    sf) UI="SF Pro Display" ;;
    segoe) UI="Segoe UI" ;;
    *) UI="Noto Sans" ;;
esac

# Todas as flags abaixo existem no upstream (man 1.8.6); as de relógio só
# entram quando o binário as anuncia (fork swaylock-effects).
help=$(swaylock --help 2>&1 || true)
# Token exato: sem isto --indicator casaria com --indicator-caps-lock do
# upstream (que não tem a flag --indicator sozinha) e o lock falharia.
has() { printf '%s\n' "$help" | grep -qE -- "(^|[[:space:],])$1([[:space:],]|$)"; }

set -- \
    --color "$BG" \
    --inside-color "$BG" \
    --inside-clear-color "$BG" \
    --inside-ver-color "$BG" \
    --inside-wrong-color "$FAIL" \
    --ring-color "$ACCENT" \
    --ring-clear-color "$MUTED" \
    --ring-ver-color "$ACCENT" \
    --ring-wrong-color "$FAIL" \
    --text-color "$FG" \
    --text-clear-color "$FG" \
    --text-ver-color "$FG" \
    --text-wrong-color "$FG" \
    --line-uses-inside \
    --separator-color "$MUTED" \
    --key-hl-color "$ACCENT" \
    --bs-hl-color "$MUTED" \
    --layout-bg-color "$BG" \
    --layout-border-color "$ACCENT" \
    --layout-text-color "$FG" \
    --font "$UI" \
    --show-failed-attempts \
    --indicator-caps-lock \
    --indicator-idle-visible \
    "$@"
if has --clock; then set -- --clock "$@"; fi
if has --indicator; then set -- --indicator "$@"; fi
if has --timestr; then set -- --timestr "%H:%M" "$@"; fi
if has --datestr; then set -- --datestr "%A, %d de %B de %Y" "$@"; fi

if [ -n "$fork" ]; then
    # shellcheck disable=SC2086
    exec swaylock --daemonize "$@"
fi

exec swaylock "$@"
