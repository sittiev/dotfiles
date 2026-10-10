#!/usr/bin/dash
# lockmenu.sh — tempo do bloqueio automático (menu Mod+Shift+x → Sistema).
# Grava ~/.cache/lock-timeout (segundos, 0=nunca) e reinicia idle.sh, dono
# do timeout do swayidle. Sem o arquivo: 300 s. Apagar telas e suspender
# (powermenu.sh) são independentes deste valor.
# Non-interactive test hook: TOFI_PICK="<exact entry>" forces a choice.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cache="$HOME/.cache/lock-timeout"

pick() {
    if [ -n "${TOFI_PICK:-}" ]; then printf '%s\n' "$TOFI_PICK"; return 0; fi
    printf '%s\n' "< Voltar" "Bloquear em 1 min" "Bloquear em 2 min" "Bloquear em 5 min" \
        "Bloquear em 10 min" "Bloquear em 15 min" "Bloquear em 30 min" "Bloquear em 1 hora" \
        "Nunca bloquear" \
        | "$script_dir/tofi-safe.sh" --prompt-text "Bloqueio automático" || true
}

choice=$(pick)
[ -n "$choice" ] || exit 0
case "$choice" in
    *Voltar*) exit 0 ;;
    "Bloquear em 1 min") printf '60' > "$cache" ;;
    "Bloquear em 2 min") printf '120' > "$cache" ;;
    "Bloquear em 5 min") printf '300' > "$cache" ;;
    "Bloquear em 10 min") printf '600' > "$cache" ;;
    "Bloquear em 15 min") printf '900' > "$cache" ;;
    "Bloquear em 30 min") printf '1800' > "$cache" ;;
    "Bloquear em 1 hora") printf '3600' > "$cache" ;;
    "Nunca bloquear") printf '0' > "$cache" ;;
    *) exit 0 ;;
esac
exec "$script_dir/idle.sh"
