#!/usr/bin/dash
# Lightweight Tofi emoji picker; labels remain readable even without color emoji.
set -eu

list='grinning 😀
smile 😄
joy 😁
wink 😉
heart ❤️
cool 😎
thinking 🤔
cry 😢
fire 🔥
star ⭐
check ✅
cross ❌
warning ⚠️
rocket 🚀
coffee ☕
beer 🍺
pizza 🍕
cat 🐱
dog 🐶
rocket_nation 🌍'

if [ -n "${TOFI_PICK:-}" ]; then
    entry=$TOFI_PICK
else
    entry=$(printf '%s\n' "< Voltar" "$list" | "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tofi-safe.sh" --config "$HOME/.config/tofi/config-emoji" --prompt-text "Emoji" --hide-input=true --text-cursor=false || true)
fi
[ -n "$entry" ] || exit 0
case "$entry" in *Voltar*) exit 0 ;; esac
emoji=${entry#* }
printf '%s' "$emoji" | wl-copy
wtype "$emoji"
