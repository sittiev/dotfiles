#!/usr/bin/dash
# Instala as fontes vendidas em fonts/ para ~/.local/share/fonts e atualiza
# o cache do fontconfig. Idempotente: só copia o que mudou.
# Uso: install-fonts.sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"

[ -d "$ROOT/fonts" ] || { echo "sem $ROOT/fonts" >&2; exit 1; }
command -v fc-cache >/dev/null || { echo "fontconfig ausente: pacman -S fontconfig" >&2; exit 1; }

mkdir -p -- "$DEST"
find "$ROOT/fonts" -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.TTF' -o -name '*.ttc' \) |
    while IFS= read -r src; do
        rel=${src#"$ROOT/fonts"/}
        # mesma árvore no destino: fonts/pixel/Foo.ttf -> fonts/pixel/Foo.ttf
        dst="$DEST/${rel%/*}"
        mkdir -p -- "$dst"
        if [ ! -f "$dst/${src##*/}" ] || ! cmp -s -- "$src" "$dst/${src##*/}"; then
            cp -f -- "$src" "$dst/${src##*/}"
            printf 'instalada: %s\n' "$rel"
        fi
    done

fc-cache -f "$DEST" >/dev/null 2>&1
echo "fontes em $DEST"
