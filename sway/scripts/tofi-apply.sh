#!/usr/bin/dash
# tofi-apply.sh (sway) — merge layout-only + cores pywal low-contrast
# Uso: tofi-apply.sh [layout]   (sem arg = usa ~/.cache/tofi-layout ou padrao)
# Fonte unica de cor: ~/.cache/theme-palette (BG FG ACCENT MUTED BORDER sem #)
# Layout: ~/tofi-themes/<nome>/config (só geometria/fontes/comportamento)
# Saída atomica: ~/.config/tofi/config
set -eu

LAYOUT="${1:-}"
if [ -z "$LAYOUT" ]; then
    LAYOUT="$(cat "$HOME/.cache/tofi-layout" 2>/dev/null || echo padrao)"
fi
# sanitiza: só basename, sem path traversal
LAYOUT="$(basename -- "$LAYOUT")"
[ -n "$LAYOUT" ] || LAYOUT="padrao"

THEMES="$HOME/.config/tofi/themes"
DEST="$HOME/.config/tofi/config"
# cadeia de fallback real (padrao/inexistente → default-two → default → 1º existente)
SRC=""
for _cand in "$THEMES/$LAYOUT/config" "$THEMES/default-two/config" "$THEMES/default/config"; do
    if [ -f "$_cand" ]; then SRC="$_cand"; LAYOUT="$(basename "$(dirname "$_cand")")"; break; fi
done
if [ -z "$SRC" ]; then
    SRC="$(find "$THEMES" -mindepth 2 -maxdepth 2 -name config 2>/dev/null | head -1)"
    [ -n "$SRC" ] && LAYOUT="$(basename "$(dirname "$SRC")")"
fi
if [ -z "${SRC:-}" ] || [ ! -f "$SRC" ]; then
    echo "tofi-apply: nenhum layout em $THEMES" >&2; exit 1
fi

if [ ! -f "$HOME/.cache/theme-palette" ]; then
    notify-send "tofi" "Paleta não encontrada (~/.cache/theme-palette). Rode theme.sh primeiro." 2>/dev/null || true
    exit 1
fi
# shellcheck disable=SC1091
. "$HOME/.cache/theme-palette" # BG FG BASE ACCENT MUTED BORDER FAIL
# shellcheck disable=SC1091
. "$HOME/.config/sway/scripts/colorlib.sh"
: "${FAIL:=$ACCENT}"

# valida hex básico (6 dígitos — evita config quebrada se paleta corrompida)
for _c in "$BG" "$FG" "$ACCENT"; do
    case "$_c" in ''|*[!0-9A-Fa-f]*) echo "tofi-apply: hex inválido: $_c" >&2; exit 1;; esac
    [ "${#_c}" -eq 6 ] || { echo "tofi-apply: hex inválido (len): $_c" >&2; exit 1; }
done

# seleção legível nos dois modos (bugs reais medidos: dark MATCH FG/ACCENT=1.05,
# light SEL BG/ACCENT=2.79 — o termo digitado "sumia" no destaque do match).
# SEL parte do BG (mantém matiz do texto normal). MATCH vai p/ o extremo que
# passa em accent médio (branco capa em ~2.7-4.1 — teto físico, não iteração):
# preto passa se lum(ACCENT)>=0.18, i.e. ratio(black,ACCENT)>=4.5.
_TOFI_SEL="$(ensure_contrast "$BG" "$ACCENT" 4.5)"
_TOFI_MATCH="$(ensure_contrast "000000" "$ACCENT" 4.5)"
if [ "$(contrast_ratio "$_TOFI_MATCH" "$ACCENT" | tr ',' '.' | cut -d. -f1)" -lt 4 ] 2>/dev/null; then
    _TOFI_MATCH="$(ensure_contrast "ffffff" "$ACCENT" 4.5)"
fi
if [ "$_TOFI_MATCH" = "$_TOFI_SEL" ]; then
    _TOFI_MATCH="$(ensure_contrast "$(mix_hex "$FG" "$FAIL" 0.5)" "$ACCENT" 4.5)"
fi

mkdir -p "$(dirname "$DEST")"

# 1) copia layout filtrando TODAS as cores + outline/corner (decisão: radius 0 global)
#    Remove: *-color, *-background (cor), outline-*, corner-radius variants, border-width (re-injetado depois)
#    Mantém: *-padding, fontes, geometria, comportamento
awk '
    /^[[:space:]]*border-width[[:space:]]*=/ { next }
    /^[[:space:]]*outline-(width|color)[[:space:]]*=/ { next }
    /^[[:space:]]*corner-radius[[:space:]]*=/ { next }
    /corner-radius[[:space:]]*=/ { next }
    # familia via Pango (fontconfig faz fallback p/ Noto Color Emoji); tamanho vem do layout
    /^[[:space:]]*font[[:space:]]*=/ { next }
    /^[[:space:]]*[a-zA-Z0-9_.-]*color[[:space:]]*=/ { next }
    /^[[:space:]]*[a-zA-Z0-9_.-]*background[[:space:]]*=/ {
        if ($0 ~ /padding/) { print; next }
        next
    }
    { print }
' "$SRC" > "$DEST.tmp"

# 2) injeta bloco de cor canônico (outline 0 = sem "borda preta" padrão 4px #080800)
cat >> "$DEST.tmp" <<EOF
# tofi-colors-begin (gerado por tofi-apply.sh — nao editar este bloco)
# fonte por nome Pango (nao caminho direto): fontconfig resolve JetBrainsMono
# e faz fallback p/ Noto Color Emoji nos glifos coloridos
font = /usr/share/fonts/noto/NotoSansMono-Regular.ttf
text-color = #$FG
background-color = #$BG
selection-color = #$_TOFI_SEL
selection-background = #$ACCENT
selection-match-color = #$_TOFI_MATCH
placeholder-color = #${FG}A8
prompt-background = #00000000
input-background = #00000000
input-color = #$FG
alternate-result-background = #00000000
default-result-background = #00000000
prompt-color = #$FG
border-color = #$ACCENT
outline-width = 0
corner-radius = 0
border-width = 2
EOF

# 3) se layout original tinha border-width próprio (dos=4, fullscreen=0), preserva
#    extrai do SRC e sobrescreve o padrão 2 acima
BW="$(sed -n 's/^[[:space:]]*border-width[[:space:]]*=[[:space:]]*//p' "$SRC" | head -1 | tr -d ' ')"
if [ -n "$BW" ]; then
    sed -i "s/^border-width = .*/border-width = $BW/" "$DEST.tmp"
fi

# Write through the symlink; mv would replace it with a regular file.
cat "$DEST.tmp" > "$DEST"
rm -f "$DEST.tmp"
# cache do layout só após sucesso (falha não pode envenenar a próxima chamada)
echo "$LAYOUT" > "$HOME/.cache/tofi-layout"
