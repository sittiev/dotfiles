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
    notify-send "Tofi indisponível" "Para aplicar o layout, rode theme.sh primeiro." 2>/dev/null || true
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

# render_layout <layout-src> <dest> [font-size]
#   1) copia o layout filtrando TODAS as cores + outline/corner (radius 0 global)
#      Remove: *-color, *-background (cor), outline-*, corner-radius, border-width,
#      font (re-injetado no bloco canonico). Mantém *-padding, geometria, comportamento.
#      font-size: mantido do layout, salvo override no $3 (ver abaixo).
#   2) injeta o bloco de cor canonico
#   3) preserva o border-width proprio do layout, se houver
render_layout() {
    _rl_src=$1
    _rl_dest=$2
    _rl_size=${3:-}
    awk '
        /^[[:space:]]*border-width[[:space:]]*=/ { next }
        /^[[:space:]]*outline-(width|color)[[:space:]]*=/ { next }
        /^[[:space:]]*corner-radius[[:space:]]*=/ { next }
        /corner-radius[[:space:]]*=/ { next }
        # familia via Pango: o nome vem do bloco canonico, nunca do layout
        /^[[:space:]]*font[[:space:]]*=/ { next }
        /^[[:space:]]*[a-zA-Z0-9_.-]*color[[:space:]]*=/ { next }
        /^[[:space:]]*[a-zA-Z0-9_.-]*background[[:space:]]*=/ {
            if ($0 ~ /padding/) { print; next }
            next
        }
        { print }
    ' "$_rl_src" > "$_rl_dest.tmp"

    # Tamanho compartilhado com o mako (ui-font-size.sh; mesma selecao do
    # render.sh): $3 substitui o font-size do layout. Vazio = mantém o layout
    # (dmenu 12 na barra 18px, clipboard 18 na lista densa, dark-paper 28 Title).
    if [ -n "$_rl_size" ]; then
        _rl_ftmp="$_rl_dest.tmp2.$$"
        awk -v sz="font-size = $_rl_size" '
            /^[[:space:]]*font-size[[:space:]]*=/ { if (!t++) { print sz; next } next }
            { print }
            END { if (!t) print sz }
        ' "$_rl_dest.tmp" > "$_rl_ftmp"
        cat "$_rl_ftmp" > "$_rl_dest.tmp"
        rm -f "$_rl_ftmp"
    fi

    # outline 0 = sem "borda preta" padrão 4px #080800
    # Fonte mono (mono-font.sh; mesma selecao do render.sh). Por NOME de
    # familia, nunca por caminho: com caminho absoluto o Pango nao monta a
    # cadeia de fallback do fontconfig e todo emoji vira caixa vazia.
    # Auto (padrao) segue a fonte da UI (rampa MS/Apple); tamanho Body via
    # ui-font-size.sh (só layouts Body seguem; fixos preservados pelo $3 vazio).
    # Cache guarda a família direto (fc-list); chaves antigas continuam válidas.
    _rl_uif=$(cat "$HOME/.cache/ui-font" 2>/dev/null || printf 'noto')
    case "$_rl_uif" in
        sf) _rl_ui="SF Pro Display" ;;
        segoe) _rl_ui="Segoe UI" ;;
        noto|"") _rl_ui="Noto Sans" ;;
        *) _rl_ui=$_rl_uif ;;
    esac
    _rl_monof=$(cat "$HOME/.cache/mono-font" 2>/dev/null || printf 'auto')
    case "$_rl_monof" in
        noto) _rl_ui="Noto Sans Mono" ;;
        jetbrains) _rl_ui="JetBrainsMono Nerd Font" ;;
        atkinson) _rl_ui="Atkinson Hyperlegible Mono" ;;
        auto|"") ;;
        *) _rl_ui=$_rl_monof ;;
    esac
    cat >> "$_rl_dest.tmp" <<EOF
# tofi-colors-begin (gerado por tofi-apply.sh — nao editar este bloco)
font = $_rl_ui
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

    _rl_bw="$(sed -n 's/^[[:space:]]*border-width[[:space:]]*=[[:space:]]*//p' "$_rl_src" | head -1 | tr -d ' ')"
    if [ -n "$_rl_bw" ]; then
        sed -i "s/^border-width = .*/border-width = $_rl_bw/" "$_rl_dest.tmp"
    fi

    # Write through the symlink; mv would replace it with a regular file.
    cat "$_rl_dest.tmp" > "$_rl_dest"
    rm -f "$_rl_dest.tmp"
    unset _rl_src _rl_dest _rl_size _rl_ftmp _rl_uif _rl_monof
}

# Tamanho Body compartilhado mako+tofi (ui-font-size.sh; mesmo default do
# render.sh). Layouts Body seguem; dmenu (barra 18px), clipboard (lista
# densa) e dark-paper (Title 28) mantêm o fixo.
case "$(cat "$HOME/.cache/ui-font-size" 2>/dev/null || printf '14')" in
    12|14|18) UISIZE_UI=$(cat "$HOME/.cache/ui-font-size" 2>/dev/null || printf '14') ;;
    *) UISIZE_UI=14 ;;
esac

case "$LAYOUT" in
    dmenu|dark-paper) _rl_main_size="" ;;
    *) _rl_main_size="$UISIZE_UI" ;;
esac
render_layout "$SRC" "$DEST" "$_rl_main_size"

# Layouts com janela propria: cada um rende um config extra pela MESMA funcao,
# entao a paleta nunca diverge do launcher.
#   clipboard -> fixo 18: lista vertical (50 entradas do cliphist nao cabem
#     numa barra); denso demais para acompanhar o Body.
#   emoji -> Body como o launcher (mesmo aviso de metricas no layout).
#   search -> fixo 12: busca de arquivos estilo FSearch (plocate), paths
#     longos; densa de propósito.
#   dirs -> fixo 12: pop-up de diretórios pinados ancorado no canto
#     inferior esquerdo (em cima do chip do yambar).
for _rl_extra in clipboard emoji search dirs; do
    _rl_xsrc="$THEMES/$_rl_extra/config"
    if [ -f "$_rl_xsrc" ]; then
        case "$_rl_extra" in
            clipboard) render_layout "$_rl_xsrc" "$HOME/.config/tofi/config-$_rl_extra" "" ;;
            search|dirs) render_layout "$_rl_xsrc" "$HOME/.config/tofi/config-$_rl_extra" "" ;;
            *) render_layout "$_rl_xsrc" "$HOME/.config/tofi/config-$_rl_extra" "$UISIZE_UI" ;;
        esac
    fi
done

# cache do layout só após sucesso (falha não pode envenenar a próxima chamada)
echo "$LAYOUT" > "$HOME/.cache/tofi-layout"
