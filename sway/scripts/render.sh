#!/usr/bin/dash
# Single owner of theme output. Reads ~/.cache/theme-palette.<mode>.
# Layout/output policy stays outside this file.
set -eu

MODE="${1:-$(cat "$HOME/.cache/theme-mode" 2>/dev/null || printf '%s' dark)}"
case "$MODE" in light|dark) ;; *) MODE=dark ;; esac
PAL="$HOME/.cache/theme-palette.$MODE"
[ -f "$PAL" ] || PAL="$HOME/.cache/theme-palette"
[ -f "$PAL" ] || { printf '%s\n' 'render: palette ausente; rode theme.sh' >&2; exit 1; }

# shellcheck disable=SC1090
. "$PAL"
# shellcheck disable=SC1091
. "$HOME/.config/sway/scripts/colorlib.sh"
# Esquema ativo? (idem theme-mode; o pai já exporta ENV_*, aqui cobre execução
# standalone do render) Sem estado ⇒ exporta nada ⇒ output byte-idêntico.
. "$HOME/.config/sway/scripts/schemelib.sh"
scheme_init "$MODE"
: "${BASE:=$BG}"
: "${FAIL:=$ACCENT}"

# Fonte da UI (ui-font.sh): o cache guarda a família direto (fc-list); chaves
# antigas noto/sf/segoe continuam válidas. Mono tabular fixo em Noto Sans Mono
# (SF/Segoe instaladas nao tem variante mono).
_uif=$(cat "$HOME/.cache/ui-font" 2>/dev/null || printf 'noto')
case "$_uif" in
    sf) UI="SF Pro Display" ;;
    segoe) UI="Segoe UI" ;;
    noto|"") UI="Noto Sans" ;;
    *) UI=$_uif ;;
esac
# Fonte mono (mono-font.sh): o cache guarda a família direto; chaves antigas
# continuam válidas. auto=padrao segue a UI no yambar/tofi, relogio e OSDs em
# Noto Sans Mono. Escolha explícita vale para os quatro.
_monof=$(cat "$HOME/.cache/mono-font" 2>/dev/null || printf 'auto')
case "$_monof" in
    noto) _MONOFAM="Noto Sans Mono" ;;
    jetbrains) _MONOFAM="JetBrainsMono Nerd Font" ;;
    atkinson) _MONOFAM="Atkinson Hyperlegible Mono" ;;
    auto|"") _MONOFAM="" ;;
    *) _MONOFAM=$_monof ;;
esac
MONO_UI="${_MONOFAM:-$UI}"
MONO="${_MONOFAM:-Noto Sans Mono}"
unset _MONOFAM _uif _monof
# Tamanho da fonte nos apps (GTK/Qt): 11pt, padrao desktop.
UISIZE=11
# Tamanho da UI mako+tofi (ui-font-size.sh): rampa MS/Apple 12 Caption, 14
# Body (padrao), 18 Destaque. Só mako principal + launcher tofi Body
# compartilham; OSDs Caption 12 (mínimo), yambar 12 (18px da barra) e GTK 11
# ficam fixos (ver tofi-apply.sh p/ dmenu/clipboard/dark-paper fixos).
case "$(cat "$HOME/.cache/ui-font-size" 2>/dev/null || printf '14')" in
    12|14|18) UISIZE_UI=$(cat "$HOME/.cache/ui-font-size" 2>/dev/null || printf '14') ;;
    *) UISIZE_UI=14 ;;
esac

# ---- Fonte nos apps GTK/Qt (ui-font.sh) ----
# GTK3/4: gtk-font-name no settings.ini (replace-or-append, symlink-safe).
for _gv in 3.0 4.0; do
    _gi="$HOME/.config/gtk-${_gv}/settings.ini"
    [ -f "$_gi" ] || continue
    _gtmp=$_gi.tmp.$$
    awk -v fnt="gtk-font-name=$UI $UISIZE" '
        /^gtk-font-name=/ { if (!t++) print fnt; next }
        { print }
        END { if (!t) print fnt }
    ' "$_gi" > "$_gtmp"
    cat "$_gtmp" > "$_gi"
    rm -f "$_gtmp"
done
# GTK2 (pcmanfm): gtk-font-name no gtkrc, fora do bloco wal do theme-mode.
for _g2 in "$HOME/.gtkrc-2.0" "$HOME/.config/gtkrc-2.0"; do
    [ -f "$_g2" ] || continue
    _gtmp=$_g2.tmp.$$
    awk -v fnt="gtk-font-name=\"$UI $UISIZE\"" '
        /^gtk-font-name=/ { if (!t++) print fnt; next }
        { print }
        END { if (!t) print fnt }
    ' "$_g2" > "$_gtmp"
    cat "$_gtmp" > "$_g2"
    rm -f "$_gtmp"
done
unset _gv _gi _g2 _gtmp
# fontconfig: sans-serif generico resolve para a fonte da UI. E o mesmo que
# o "Create fonts.conf" do qt5ct faz — cobre Qt (qt6ct nao guarda fonte no
# .conf) e qualquer app que peca a familia generica. Pedidos explicitos
# (mako/tofi/yambar/foot) nao sao afetados pelo alias.
mkdir -p "$HOME/.config/fontconfig"
cat > "$HOME/.config/fontconfig/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- gerado por render.sh (ui-font.sh) — nao editar -->
<fontconfig>
  <alias>
    <family>sans-serif</family>
    <prefer><family>$UI</family></prefer>
  </alias>
</fontconfig>
EOF

# Yambar: chip "directories" na EXTREMIDADE ESQUERDA (left:, string pura
# sem script/poll — rótulo fixo; clique abre a TUI yambar-dirs-toggle.sh,
# foot flutuante em cima do chip) e dois chips à direita. Tarefas do vault
# Obsidian (chip esquerdo: contagem de checkboxes abertos via
# yambar-tasks.sh, clique abre a TUI yambar-tasks-toggle.sh; o script .py
# é a única fonte da verdade do escaneio/estado) e o relógio (default só
# horário; clique alterna para data+horário via on-click nativo da
# partícula — yambar-particles(5) — com estado em
# $XDG_RUNTIME_DIR/yambar-clock-full, some no logout).
# Tipografia (MS/Apple): barra e relógio via mono-font.sh (auto segue a
# fonte da UI: Noto/SF/Segoe), relógio em mono tabular para não pulsar a
# largura. Noto tem caixa win de 1.362em: size=12 rende 16.3px,
# cabe nos 18px da barra (size=14 daria 19.1px e cortaria).
# Sem margins: o espaçamento é só via gaps do sway (inner/outer). Sem monitor
# fixo: com HDMI conectado o eDP fica desligado (outputs.sh auto), então há
# um único output ativo e a bar vai sempre pro principal.
YF=$(ensure_contrast "$FG" "$BG" 4.5 | tr 'a-f' 'A-F')
YBG=$(printf '%s' "$BG" | tr 'a-f' 'A-F')
cat > "$HOME/.config/yambar/config.yml" <<EOF
# yambar (sway) — generated by render.sh ($MODE). Do not edit.
bar:
  height: 18
  location: bottom
  background: 00000000
  foreground: ${YF}ff
  font: "${MONO_UI}:size=12"
  font-shaping: none
  spacing: 4
  left:
    - script:
        path: ~/.config/sway/scripts/yambar-dirs.sh
        poll-interval: 3600000
        content:
          string:
            text: "{display}"
            font: "${MONO}:size=12"
            on-click: ~/.config/sway/scripts/yambar-dirs-toggle.sh
            deco: {background: {color: ${YBG}ff}}
  right:
    - script:
        path: ~/.config/sway/scripts/yambar-tasks.sh
        poll-interval: 2000
        content:
          string:
            text: " {display}"
            font: "${MONO}:size=12"
            on-click: ~/.config/sway/scripts/yambar-tasks-toggle.sh
            deco: {background: {color: ${YBG}ff}}
    - script:
        path: ~/.config/sway/scripts/yambar-clock.sh
        poll-interval: 1000
        content:
          string:
            text: "{display}"
            font: "${MONO}:size=12"
            on-click: ~/.config/sway/scripts/yambar-clock-toggle.sh
            deco: {background: {color: ${YBG}ff}}
EOF

# Mako: fonte da UI via ui-font.sh (família) + ui-font-size.sh (tamanho Body
# compartilhado com o launcher tofi; OSDs Caption 12, o minimo). Anchor
# bottom-right estilo Windows, mesmo com a bar embaixo
# (overlay passa por cima).
# urgency=critical usa a borda FAIL para destacar (ex.: bateria muito fraca).
cat > "$HOME/.config/mako/config" <<EOF
# mako — generated by render.sh ($MODE). Do not edit.
background-color=#$BG
text-color=#$FG
border-color=#$BG
border-size=0
border-radius=0
margin=14
font=$UI $UISIZE_UI
markup=1
anchor=bottom-right
default-timeout=8000

[mode=do-not-disturb]
invisible=1

[urgency=critical]
border-color=#$FAIL
border-size=2

[app-name="media-osd"]
background-color=#$BG
text-color=#$FG
border-color=#$ACCENT
border-size=1
border-radius=0
font=$MONO 12
anchor=center
text-alignment=center
width=152
height=132

[app-name="brightness-osd"]
background-color=#$BG
text-color=#$FG
border-color=#$ACCENT
border-size=1
border-radius=0
font=$MONO 12
anchor=center
text-alignment=center
width=172
height=168
EOF

# Fonte do terminal (term-font.sh): o cache guarda a família direto (fc-list);
# chaves antigas jetbrains/lexend/atkinson continuam válidas. A JetBrains Nerd
# entra como fallback de glifos (ícones); fonte proporcional/pixel mantém a
# grade fixa do foot — glifo fora da grade pode cortar/sobrepor. Tamanho 12pt.
_termf=$(cat "$HOME/.cache/term-font" 2>/dev/null || printf 'jetbrains')
case "$_termf" in
    lexend) TERMFONT="Lexend:size=12,JetBrainsMono Nerd Font:size=12" ;;
    atkinson) TERMFONT="Atkinson Hyperlegible Mono:size=12,JetBrainsMono Nerd Font:size=12" ;;
    jetbrains|"") TERMFONT="JetBrainsMono Nerd Font:size=12" ;;
    *) TERMFONT="$_termf:size=12,JetBrainsMono Nerd Font:size=12" ;;
esac
unset _termf

# Foot: fonte via term-font.sh, resto da geometria preservado; só as cores
# sao trocadas. Foot 1.28 usa
# [colors-light]/[colors-dark], not the backup's obsolete [colors] section.
# initial-color-theme must match the section we emit, otherwise a new foot
# looks for the absent one and falls back to its built-in defaults.
FOOT="$HOME/.config/foot/foot.ini"
FOOT_TMP="$FOOT.tmp.$$"
if [ -f "$FOOT" ]; then
    awk -v mode="$MODE" -v font="$TERMFONT" '
        /^\[colors(-light|-dark)?\]$/ { skip=1; next }
        /^\[/ { skip=0; inmain = ($0 == "[main]") }
        skip { next }
        inmain && /^initial-color-theme=/ { next }
        inmain && /^font=/ { next }
        {
            print
            if ($0 == "[main]" && !done) { print "initial-color-theme=" mode; print "font=" font; done=1 }
        }
        END { if (!done) { print "[main]"; print "initial-color-theme=" mode; print "font=" font } }
    ' "$FOOT" > "$FOOT_TMP"
else
    printf '%s\n' '[main]' "initial-color-theme=$MODE" \
        "font=$TERMFONT" > "$FOOT_TMP"
fi
cat >> "$FOOT_TMP" <<EOF
[colors-$MODE]
background=$BG
foreground=$FG
selection-foreground=$BG
selection-background=$ACCENT
flash=$FG
EOF
# pywal colors are the source for the 16 Foot ANSI colors.
set +u
# shellcheck disable=SC1091
. "$HOME/.cache/wal/colors.sh" 2>/dev/null || true
set -u

# ansi_blend <hex> <wall_h> <k> <scheme_h> <wall_s> <scheme_s> [span] → hex
# Um slot ANSI do scheme na família de cor do wallpaper:
#   H' = wall_h + (H − scheme_h) × k      (k=0 e wall_h vazio ⇒ identidade)
#   S' = S × wall_s / scheme_s            (wall_s vazio ⇒ S preservado)
# O L fica para a envelope do papel (apprentice_accent/bright) e para o
# ensure_contrast final, então quem manda em contraste/brilho é o scheme.
ansi_blend() {
    _ab_hex=${1#\#}
    _ab_wh=${2:-}
    _ab_k=${3:-1}
    _ab_sh=${4:-0}
    _ab_ws=${5:-}
    _ab_ss=${6:-0}
    _ab_sp=${7:-60}
    # Imagem P&B (sem assinatura de croma): o scheme manda na cor inteira.
    # exit-status, não stdout — `exit !(...)` não imprime nada.
    if [ -z "$_ab_ws" ] ||
        ! LC_ALL=C awk -v s="$_ab_ws" 'BEGIN { exit !(s + 0 > 0) }'; then
        printf '%s' "$_ab_hex"
        return 0
    fi
    _ab_f=$(LC_ALL=C awk -v w="$_ab_ws" -v s="$_ab_ss" \
        'BEGIN { printf "%.4f", (s + 0 > 0 ? w / s : 1) }')
    _ab_hsl=$(rgb2hsl_hex "$_ab_hex")
    _ab_tail=${_ab_hsl#* }
    # O slot já vem do scheme; preserva o L dele (a envelope do papel cuida do
    # resto) e só troca hue e croma.
    _ab_out=$(hue_pull "$_ab_hex" "$_ab_wh" "$_ab_k" "$_ab_sh" "$_ab_sp")
    _ab_pulled=$(rgb2hsl_hex "$_ab_out")
    _ab_ptail=${_ab_pulled#* }
    _ab_s=$(LC_ALL=C awk -v s="${_ab_ptail%% *}" -v f="$_ab_f" \
        'BEGIN { printf "%.2f", s * f }')
    hsl2rgb_hex "${_ab_pulled%% *}" "$_ab_s" "${_ab_ptail#* }"
}

# sat_l <hex> → L (0..100). Só o L de um hex, para reconstruir a mesma cor
# com S=0 sem passar o valor por dentro de um eval.
sat_l() {
    _sl=$(rgb2hsl_hex "${1#\#}")
    _sl=${_sl#* }
    printf '%s' "${_sl#* }"
}

# Esquema ativo: os 16 ANSI do terminal entram na MESMA blend dos demais
# papéis (ver schemelib: imagem dá hue + croma, scheme dá a envelope). Só o
# layout semântico (qual slot é vermelho/verde/amarelo/...) vem do JSON Gogh
# do esquema — sem ele o wallpaper pastel sem croma gerava 16 cinzas e
# "Esquemas de cores" não mudava nada no terminal.
#
#   H' = clamp(WALL_H + (H − centro_scheme) × ANSI_HUE_K, ±ANSI_HUE_SPAN)
#   S' = S × WALL_S / S_scheme
#
# SPAN (default 60°) é a janela de hue em torno da assinatura do wallpaper, e
# é o que segura a paleta dentro da família da imagem. As duas alternativas
# já falharam: comprimir o spread (K<1) colava os 8 slots na mesma cor — uma
# parede de azul — e só rotacionar (K=1 sem janela) deixava o spread de ~300°
# do scheme pintar o terminal de magenta num wallpaper azul.
#
# O croma é reescalado pelo do wallpaper: sem isso um scheme S=100 punha um
# terminal mais saturado que a própria imagem.
#
# Wallpaper acromático (P&B ⇒ WALL_H vazio): identidade — o scheme manda
# na cor, como antes.
if [ -n "${SCHEME_NAME:-}" ]; then
    _sj="${SCHEME_JSON:-$HOME/.config/sway/schemes/gogh-themes-min.json}"
    if command -v jq >/dev/null 2>&1 && [ -f "$_sj" ]; then
        _ansi=$(jq -r --arg n "$SCHEME_NAME" '
            ([.[] | select(.name == $n)] | last) as $e
            | if $e == null then empty else
                [range(1; 17) | . as $i
                  | ($e["color_" + (if $i < 10 then "0" + ($i | tostring)
                                    else ($i | tostring) end)] // empty)
                  | ascii_downcase | ltrimstr("#")
                  | "color" + (($i - 1) | tostring) + "=" + .] | .[]
              end' "$_sj" 2>/dev/null) || _ansi=''
        _sh=$(_acc_center "${SCHEME_ACC_CAND:-}" 2>/dev/null) || _sh=''
        _ss=$(chroma_mean "${SCHEME_ACC_CAND:-}" 2>/dev/null) || _ss=''
        # Âncoras do wallpaper. Vazias = imagem P&B: ANSI_HUE_K=0 e croma
        # descartado devolvem o slot idêntico ao do scheme (caminho antigo).
        _wh=${WALL_H:-}
        _ws=${WALL_S:-}
        while IFS='=' read -r _k _v; do
            case "$_k" in color[0-9] | color[0-9][0-9]) ;; *) continue ;; esac
            case "$_v" in ??????) ;; *) continue ;; esac
            case "$_v" in *[!0-9a-f]*) continue ;; esac
            # Janela de hue derivada da variedade da IMAGEM: um wallpaper
            # monocromático (spread ~4°) recebe uma janela estreita e o
            # terminal fica na mesma família; um wallpaper colorido (spread
            # 150°) recebe janela larga. Span fixo não servia: 60° num
            # wallpaper de 5° punha slots a 269° e o terminal saía roxo.
            _sp=$(LC_ALL=C awk -v s="${WALL_SPREAD:-0}" \
                -v lo="${ANSI_SPAN_MIN:-18}" -v hi="${ANSI_SPAN_MAX:-100}" \
                'BEGIN {
                    v = s * 2 + 12
                    if (v < lo) v = lo
                    if (v > hi) v = hi
                    printf "%d", v
                }')
            _r=$(ansi_blend "$_v" "$_wh" "${ANSI_HUE_K:-1}" "${_sh:-0}" \
                "$_ws" "$_ss" "$_sp")
            # Slots 0/7/8/15 são black/white e os "bright" deles: por
            # convenção do ANSI são acromáticos, e o que o scheme define ali
            # é o L, não a cor. Sem isto um scheme cujo color_01 é saturado
            # (Solarized #002b36) punha um "black" roxo no terminal. Zera o
            # croma e mantém o L — o envelope continua decidindo o brilho.
            _n=${_k#color}
            case "$_n" in
                0|7|8|15) _r=$(hsl2rgb_hex 0 0 "$(sat_l "$_r")") ;;
            esac
            eval "$_k=\$_r"
        done <<EOF
$_ansi
EOF
        unset _ansi _k _v _n _wh _ws _sh _ss _r _sp
    fi
    unset _sj
fi
FBG="$BG"
FFG=$(ensure_contrast "$FG" "$FBG" 4.5)
# Registra o que a blend produziu, para o log do theme.sh deixar de ser opaco:
# sem isso é impossível distinguir "o wallpaper é monocromático" de "a blend
# quebrou" — as duas produzem uma paleta parecida e cinza.
_ft_log=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/waltheme-sway.log
{
    printf 'blend fbg=%s ffg=%s scheme=%s wall_h=%s wall_s=%s k=%s' \
        "$FBG" "$FFG" "${SCHEME_NAME:-none}" "${WALL_H:-none}" "${WALL_S:-none}" \
        "${ANSI_HUE_K:-0.45}"
    i=0
    while [ "$i" -le 15 ]; do
        eval "_n=\${color$i:-}"
        printf ' %s=%s' "$i" "${_n:-?}"
        i=$((i + 1))
    done
    printf '\n'
} >> "$_ft_log" 2>/dev/null || true
# Replace the temporary header values with contrast-safe values.
sed -i "s/^foreground=.*/foreground=$FFG/; s/^flash=.*/flash=$FFG/" "$FOOT_TMP"
i=0
while [ "$i" -le 7 ]; do
    eval "normal=\${color$i:-}"
    eval "bright=\${color$((i + 8)):-}"
    normal=${normal:-"$FG"}
    bright=${bright:-"$FG"}
    # Slots acromáticos do ANSI (0=black, 7=white e os "bright" 8/15) são
    # neutros por definição: o clamp_neutral prende só o L, sem o piso de S
    # do envelope — senão o clamp forçava croma num cinza e o "black" do
    # terminal saía marrom. O L continua vindo do envelope do scheme, que é
    # onde mora o contraste; o que não entra é o croma.
    case "$i" in
        0|7)
            _mn=$(apprentice_clamp_neutral "${normal#\#}" \
                "${ENV_ACC_L_MIN:-45}" "${ENV_ACC_L_MAX:-55}")
            _mb=$(apprentice_clamp_neutral "${bright#\#}" \
                "${ENV_BRI_L_MIN:-55}" "${ENV_BRI_L_MAX:-70}")
            ;;
        *)
            _mn=$(apprentice_accent "${normal#\#}")
            _mb=$(apprentice_bright "${bright#\#}")
            ;;
    esac
    normal=$(ensure_contrast "$_mn" "$FBG" 2.0)
    bright=$(ensure_contrast "$_mb" "$FBG" 2.0)
    printf 'regular%s=%s\nbright%s=%s\n' "$i" "$normal" "$i" "$bright" >> "$FOOT_TMP"
    i=$((i + 1))
done
unset _mn _mb
cat "$FOOT_TMP" > "$FOOT"
rm -f "$FOOT_TMP"

# Best-effort live Foot color update. New windows always get the file above.
for tty in /dev/pts/*; do
    [ -w "$tty" ] || continue
    printf '\033]11;#%s\033\\' "$FBG" > "$tty" 2>/dev/null || true
    printf '\033]10;#%s\033\\' "$FFG" > "$tty" 2>/dev/null || true
done

# Optional Kitty/Alacritty consumers, only when their config exists.
if [ -f "$HOME/.config/kitty/kitty.conf" ]; then
    {
        printf 'background #%s\nforeground #%s\ncursor #%s\n' "$FBG" "$FFG" "$FFG"
        i=0
        while [ "$i" -le 15 ]; do
            eval "raw=\${color$i:-}"
            raw=${raw:-"$FG"}
            if [ "$i" -lt 8 ]; then value=$(apprentice_accent "${raw#\#}"); else value=$(apprentice_bright "${raw#\#}"); fi
            printf 'color%s #%s\n' "$i" "$(ensure_contrast "$value" "$FBG" 2.0)"
            i=$((i + 1))
        done
    } > "$HOME/.cache/wal/colors-kitty-lowc.conf"
    if ! grep -q 'colors-kitty-lowc.conf' "$HOME/.config/kitty/kitty.conf"; then
        printf '\ninclude %s\n' "$HOME/.cache/wal/colors-kitty-lowc.conf" >> "$HOME/.config/kitty/kitty.conf"
    fi
fi

if [ -f "$HOME/.config/alacritty/alacritty.toml" ]; then
    cp "$HOME/.config/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml.tmp"
    cat >> "$HOME/.config/alacritty/alacritty.toml.tmp" <<EOF
# wal-theme-begin — generated by render.sh
[colors.primary]
background = "#$FBG"
foreground = "#$FFG"
[colors.selection]
text = "#$FBG"
background = "#$ACCENT"
# wal-theme-end
EOF
    mv "$HOME/.config/alacritty/alacritty.toml.tmp" "$HOME/.config/alacritty/alacritty.toml"
fi

# Tofi keeps selected layout/geometry; only palette changes.
"$HOME/.config/sway/scripts/tofi-apply.sh" "$(cat "$HOME/.cache/tofi-layout" 2>/dev/null || printf '%s' dmenu)" >/dev/null

# Sway client colors only. Non-focused border, indicator and child_border are
# transparent, so only the focused window shows an edge. BG-colored borders
# looked white on light wallpapers (BG=e3e6e8) — the opposite of dim-inactive.
eval "$(sway_roles "$BG" "$FG" "$ACCENT" "$MUTED" "$FAIL")"
SC="$HOME/.config/sway/config"
if [ -f "$SC" ]; then
    SC_TMP=$SC.tmp.$$
    sed \
        -e "s|^client\.focused .*|client.focused   #$FOC #$FOCB #$FTXT #$FOC #$FOCB|" \
        -e "s|^client\.unfocused .*|client.unfocused #00000000 #$BG #$MUTC #00000000 #00000000|" \
        -e "s|^client\.focused_inactive .*|client.focused_inactive #00000000 #$BG #$MUTC #00000000 #00000000|" \
        -e "s|^client\.placeholder .*|client.placeholder      #00000000 #$BG #$MUTC #00000000 #00000000|" \
        -e "s|^client\.background .*|client.background       #$BG|" \
        -e "s|^client\.urgent .*|client.urgent           #$FOC #$URGB #$UTXT #$FOC #$URGB|" \
        "$SC" > "$SC_TMP"
    # Write through the symlink; sed -i would replace it with a regular file.
    cat "$SC_TMP" > "$SC"
    rm -f "$SC_TMP"
fi

# Overlays use same palette.
printf '%s' "$FOC" > "$HOME/.cache/slurp-color"
cat > "$HOME/.config/sway/scripts/swaynag-exit.sh" <<EOF
#!/usr/bin/dash
set -eu
exec swaynag -t warning -m 'Sair do Sway? A sessão será encerrada.' \
  --background=$BG --border=$FOC --border-bottom=$FOC \
  --text=$FG --button-background=$FOC --button-text=$BG \
  -B 'Sair' 'swaymsg exit'
EOF
chmod 0755 "$HOME/.config/sway/scripts/swaynag-exit.sh"

# ---- Qt (qt6ct/qt5ct): color scheme + ativação (guarded: só com config) ----
# [ColorScheme] = 21 slots na ordem QPalette::ColorRole(0..20) — Qt5 e Qt6
# idênticos até PlaceholderText; no Qt>=6.6 o qt6ct completa Accent=Highlight
# sozinho (count==Accent ⇒ append).
#
# O "#" é obrigatório: o qt5ct/qt6ct passa cada valor pro QColor como
# QString, e QColor só parseia "#AARRGGBB". Sem o # a cor fica inválida e o
# Qt pinta TUDO de preto — o arquivo parecia correto e nenhum app mudava.
_qt_slots() { # <cor-de-texto> → stdout com os 21 papéis
    _t=$1
    printf '#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s,#ff%s' \
        "$_t" \
        "$BG" \
        "$(mix_hex "$BG" ffffff 0.14)" \
        "$(mix_hex "$BG" ffffff 0.07)" \
        "$(mix_hex "$BG" 000000 0.11)" \
        "$(mix_hex "$BG" 000000 0.07)" \
        "$_t" \
        "$_t" \
        "$_t" \
        "$BASE" \
        "$BG" \
        "$(mix_hex "$BG" 000000 0.18)" \
        "$ACCENT" \
        "$(ensure_contrast "$_t" "$ACCENT" 4.5)" \
        "$ACCENT" \
        "$MUTED" \
        "$BG" \
        "$BG" \
        "$BG" \
        "$_t" \
        "$MUTED"
}
_qt_write() { # <app> — escreve colors/dotfiles.conf e aponta o <app>.conf
    _qd="${XDG_CONFIG_HOME:-$HOME/.config}/$1"
    _qc="$_qd/$1.conf"
    [ -f "$_qc" ] || return 0
    mkdir -p "$_qd/colors"
    _qt_tmp=$(mktemp)
    printf '[ColorScheme]\nactive_colors=%s\ninactive_colors=%s\ndisabled_colors=%s\n' \
        "$(_qt_slots "$FG")" "$(_qt_slots "$MUTED")" "$(_qt_slots "$MUTED")" > "$_qt_tmp"
    cat "$_qt_tmp" > "$_qd/colors/dotfiles.conf"
    rm -f "$_qt_tmp"
    # Ativa (QSettings INI). As chaves só existem no [Appearance] (fonte
    # qt5ct/qt6ct) ⇒ replace linha-âncora; sem a seção, anexa uma nova.
    _qt_tmp=$(mktemp)
    sed \
        -e "s|^color_scheme_path[[:space:]]*=.*|color_scheme_path=$_qd/colors/dotfiles.conf|" \
        -e "s|^custom_palette[[:space:]]*=.*|custom_palette=true|" \
        "$_qc" > "$_qt_tmp"
    if ! grep -q '^\[Appearance\]' "$_qt_tmp"; then
        printf '\n[Appearance]\n' >> "$_qt_tmp"
    fi
    # A chave é o que FAZ o qt5ct/qt6ct usar a paleta. O teste antigo era
    # "não tem color_scheme_path E não tem [Appearance]": um .conf com
    # [Appearance] mas sem a chave (estado normal de um config recém-criado)
    # passava pelo teste, não recebia a chave, e o qt5ct ficava com a paleta
    # padrão do Qt para sempre — o dotfiles.conf era escrito e ninguém lia.
    if ! grep -q '^color_scheme_path=' "$_qt_tmp"; then
        printf 'color_scheme_path=%s\n' "$_qd/colors/dotfiles.conf" >> "$_qt_tmp"
    fi
    if ! grep -q '^custom_palette=' "$_qt_tmp"; then
        printf 'custom_palette=true\n' >> "$_qt_tmp"
    fi
    cat "$_qt_tmp" > "$_qc"
    rm -f "$_qt_tmp"
}
_qt_write qt6ct
_qt_write qt5ct

# ---- ly (greeter): cores do tema em /etc/ly/config.ini (root-only ⇒ guarded)
# Formato 0xSSRRGGBB (SS = styling; 0x01 = TB_BOLD). LY_CONF só p/ teste.
_ly=${LY_CONF:-/etc/ly/config.ini}
if [ -w "$_ly" ]; then
    _ly_tmp=$(mktemp)
    awk -v bg="0x00$BG" -v fg="0x00$FG" -v bd="0x00$ACCENT" -v er="0x01$FAIL" '
        /^bg[ \t]*=/ { print "bg = " bg; next }
        /^fg[ \t]*=/ { print "fg = " fg; next }
        /^border_fg[ \t]*=/ { print "border_fg = " bd; next }
        /^error_fg[ \t]*=/ { print "error_fg = " er; next }
        { print }' "$_ly" > "$_ly_tmp"
    cat "$_ly_tmp" > "$_ly"
    rm -f "$_ly_tmp"
fi

# One reload per consumer.
if pgrep -x mako >/dev/null 2>&1; then makoctl reload >/dev/null 2>&1 || true; else mako >/dev/null 2>&1 & fi
pkill -USR1 kitty 2>/dev/null || true
# lxqt-policykit-agent (Qt6) so le a paleta no inicio: reinicia para seguir o tema.
# pkill -x NAO serve aqui: o comm do kernel trunca em 15 chars
# ("lxqt-policykit-") e o padrao nunca casa, entao cada apply deixava um
# agente a mais rodando (6 no pico, medido). -f casa pela linha de comando.
if command -v lxqt-policykit-agent >/dev/null 2>&1; then
    pkill -f '(^|/)lxqt-policykit-agent( |$)' >/dev/null 2>&1 || true
    sleep 0.3
    lxqt-policykit-agent >/dev/null 2>&1 &
fi
pkill -x yambar 2>/dev/null || true
sleep 0.3
LC_TIME=C yambar >/dev/null 2>&1 &
swaymsg reload >/dev/null 2>&1 || true
