#!/usr/bin/dash
# game-mode.sh — toggle p/ jogos (Mod+g): mouse-look nao sobrevive a
# focus_follows_mouse + mouse_warping (foco foge quando o cursor bate a borda
# ou troca de output). On: trava foco/warp e fullscreen na janela atual.
# Off: restaura o padrao do config. Estado em ~/.cache/game-mode.
set -eu
state=${XDG_CACHE_HOME:-$HOME/.cache}/game-mode
if [ "$(cat "$state" 2>/dev/null || printf off)" = on ]; then
    swaymsg focus_follows_mouse yes >/dev/null 2>&1 || true
    swaymsg mouse_warping output >/dev/null 2>&1 || true
    printf 'off' > "$state"
    notify-send "Jogo" "Modo jogo OFF" 2>/dev/null || true
else
    swaymsg focus_follows_mouse no >/dev/null 2>&1 || true
    swaymsg mouse_warping none >/dev/null 2>&1 || true
    swaymsg fullscreen enable >/dev/null 2>&1 || true
    printf 'on' > "$state"
    notify-send "Jogo" "Modo jogo ON (foco/warp travados)" 2>/dev/null || true
fi
