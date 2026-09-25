#!/usr/bin/dash
# slurp-pick — selecao grim na cor da paleta (cache do theme.sh)
set -eu
C="$(cat "$HOME/.cache/slurp-color" 2>/dev/null || echo 888888)"
exec slurp -c "#${C}ff" -s "#${C}55"
