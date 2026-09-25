#!/usr/bin/dash
# update-schemes.sh — re-sincroniza a biblioteca de esquemas Gogh vendorizados.
# Baixa themes-min.json para um .tmp, valida (JSON, contagem, campos, nomes
# únicos) e só então substitui o alvo via `cat tmp > alvo` (nunca mv/sed -i —
# hábito symlink-safe do repo). Falhou a validação? Alvo atual fica intacto.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
URL='https://raw.githubusercontent.com/Gogh-Co/Gogh/master/data/themes-min.json'
TARGET="$ROOT/sway/schemes/gogh-themes-min.json"
TMP="$TARGET.tmp.$$"

cleanup() { rm -f -- "$TMP"; }
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || {
    echo 'update-schemes: jq ausente (pacman -S jq)' >&2
    exit 1
}

mkdir -p -- "$(dirname -- "$TARGET")"
curl -fL --max-time 60 -o "$TMP" "$URL"

# ---- validações: nada destrói o alvo atual se algo falhar ----
if ! jq -e 'length > 1000' "$TMP" >/dev/null; then
    echo 'update-schemes: JSON inválido ou < 1001 esquemas' >&2
    exit 1
fi

if ! jq -e 'all(.[];
        has("name") and has("variant") and has("background")
        and has("foreground") and has("color_01") and has("color_16"))' \
        "$TMP" >/dev/null; then
    echo 'update-schemes: campos obrigatórios ausentes (name/variant/background/foreground/color_01/color_16)' >&2
    exit 1
fi

dups=$(jq -r '.[].name' "$TMP" | sort | uniq -d)
if [ -n "$dups" ]; then
    echo 'update-schemes: nomes duplicados:' >&2
    echo "$dups" >&2
    exit 1
fi

count=$(jq 'length' "$TMP")
cat "$TMP" > "$TARGET"
printf 'update-schemes: %s esquemas gravados em %s\n' "$count" "$TARGET"
