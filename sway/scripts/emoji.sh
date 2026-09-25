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

entry=$(printf '%b\n' "$list" | "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/tofi-safe.sh" --config "$HOME/.config/tofi/config" --prompt-text "Emoji: " || true)
[ -n "$entry" ] || exit 0
emoji=${entry#* }
printf '%s' "$emoji" | wl-copy
wtype "$emoji"
