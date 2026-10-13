#!/bin/sh
# e2e.sh — exercita o caminho real do menu sem display: MENU_SEQ injeta as
# teclas no binário release e o próprio app executa as ações (hooks TOFI_*,
# notify-send etc.). Cada caso valida a saída RUN/STATE esperada.
#
# Casos:
#   1. estados do sistema são lidos (STATE ... = ...)
#   2. filtro + Enter executa "Hora" (notify) e mantém o menu aberto
#   3. toggle da divisão automática duas vezes (liga → desliga) — caminho
#      real de pgrep/pkill/flag, sem depender do estado inicial
set -eu

cd "$(dirname -- "$0")/.."
BIN=${MENU_BIN:-target/release/menu}
[ -x "$BIN" ] || { echo "build primeiro: make e2e"; exit 1; }
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

fail() {
    echo "E2E FALHOU: $1" >&2
    echo "--- saída ---" >&2
    printf '%s\n' "$OUT" >&2
    exit 1
}

# caso 1: estados
OUT=$(MENU_SEQ=$'state\nquit' "$BIN" 2>&1)
printf '%s' "$OUT" | grep -q '^STATE Autotiling = ' || fail "estados: STATE Autotiling ausente"
printf '%s' "$OUT" | grep -q '^SEQ_END$' || fail "estados: falta SEQ_END"

# caso 2: filtro + Hora (notify-send), menu fica aberto
OUT=$(MENU_SEQ=$'char:h\nchar:o\nchar:r\nchar:a\nkey:enter\nkey:esc' "$BIN" 2>&1)
printf '%s' "$OUT" | grep -Eq '^RUN Hora · .* \[stay\]$' || fail "filtro/hora: RUN Hora [stay] ausente"

# caso 3: toggle da divisão automática ida e volta
OUT=$(MENU_SEQ=$'char:d\nchar:i\nchar:v\nchar:i\nchar:s\nkey:enter\nchar:d\nchar:i\nchar:v\nchar:i\nchar:s\nkey:enter\nkey:esc' "$BIN" 2>&1)
n=$(printf '%s' "$OUT" | grep -Ec '^RUN Divisão automática · .* \[stay\]$' || true)
[ "$n" -eq 2 ] || fail "toggle divisão: esperava 2 RUNs, veio $n"

echo "E2E ok (3 casos)"