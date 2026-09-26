#!/usr/bin/dash
# schemelib.sh — envelopes HSL do esquema Gogh selecionado.
#   . "$HOME/.config/sway/scripts/schemelib.sh"
#   scheme_init <dark|light>
#
# Contrato: exporta ENV_<PAPEL>_{S,L}_{MIN,MAX} (0 ≤ min ≤ max ≤ 100) para os
# papéis BG FG ACC MUT BRI, e ENV_<PAPEL>_H (hue em graus) para BG/FG/ACC/MUT.
#
# Divisão de trabalho (wallpaper > paleta > scheme): a IMAGEM dá a cor
# (hue + croma, via WALL_H/WALL_S lidos do pywal) e o SCHEME dá a
# envelope — contraste, S/L por papel, espelhamento de L. Por isso o
# clamp de papel (theme-mode.sh _env_role) preserva o hue do wallpaper
# usando ENV_<PAPEL>_H: sem ele um envelope saturado pintava o verde do
# wallpaper num scheme azul.
#
# Scheme quase acromático (bg com S<6) não exporta _H e o humor do
# wallpaper segue como antes. Wallpaper acromático (preto e branco) não
# exporta WALL_H e o hue do scheme volta a mandar.
# SCHEME_NAME/SCHEME_VARIANT/SCHEME_MATCH são
# exportados SÓ quando as ENV_* estão completas — presença de SCHEME_NAME é
# marcador confiável de sucesso. Sem estado / jq ausente / JSON ausente /
# esquema desconhecido ⇒ exporta NADA: o colorlib cai nas constantes
# Apprentice atuais (${ENV_*:-default}).
#
# Derivação: cores do esquema → rgb2hsl_hex (colorlib) → min/max por papel
# com pad S±4 L±3, clamp 0..100. Override (sway/schemes/overrides/<slug>[.light].env)
# tem precedência e é orientado por modo: <slug>.env = dark, <slug>.light.env = light.
# Se variante ≠ modo (sem override) ⇒ espelha L: lmin'=100−lmax, lmax'=100−lmin.
#
# Paths sobrescrevíveis por env (usado pelos testes): SCHEME_STATE,
# SCHEME_JSON, SCHEME_OVERRIDE_DIR.

if ! command -v rgb2hsl_hex >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    . "$HOME/.config/sway/scripts/colorlib.sh"
fi

_scheme_unset() {
    for _r in BG FG ACC MUT BRI; do
        unset "ENV_${_r}_S_MIN" "ENV_${_r}_S_MAX" "ENV_${_r}_L_MIN" "ENV_${_r}_L_MAX" "ENV_${_r}_H"
    done
    unset SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH SCHEME_BG_HEX SCHEME_FG_HEX SCHEME_ACC_CAND
    unset WALL_H WALL_S WALL_SPREAD
}

_scheme_slug() { # "1984 Light" → "1984-light"
    LC_ALL=C printf '%s' "$1" | LC_ALL=C awk '{
        s = tolower($0)
        gsub(/[^a-z0-9]+/, "-", s)
        gsub(/^-+/, "", s); gsub(/-+$/, "", s)
        printf "%s", s
    }'
}

_env1() { # "hex,hex,..." → "smin smax lmin lmax" (pad S±4 L±3, clamp 0..100)
    # printf '%s\n' garante newline final (sem ele o read descarta a 1ª linha
    # quando não há vírgula); cada cor vira uma linha "H S L" pro awk.
    printf '%s\n' "$1" | tr ',' '\n' |
        while IFS= read -r _h; do
            [ -n "$_h" ] || continue
            rgb2hsl_hex "${_h#\#}"
            printf '\n'
        done |
        LC_ALL=C awk '
        {
            s = $2 + 0; l = $3 + 0
            if (NR == 1) { smin = smax = s; lmin = lmax = l }
            else {
                if (s < smin) smin = s
                if (s > smax) smax = s
                if (l < lmin) lmin = l
                if (l > lmax) lmax = l
            }
        }
        END {
            if (NR == 0) exit 1
            smin = int(smin - 4 + 0.5); smax = int(smax + 4 + 0.5)
            lmin = int(lmin - 3 + 0.5); lmax = int(lmax + 3 + 0.5)
            if (smin < 0) smin = 0; if (smax > 100) smax = 100
            if (lmin < 0) lmin = 0; if (lmax > 100) lmax = 100
            if (smin > smax) smax = smin
            if (lmin > lmax) lmax = lmin
            printf "%d %d %d %d", smin, smax, lmin, lmax
        }'
}

_mirror() { # "smin smax lmin lmax" → L espelhado em torno de 50%, S intacto
    LC_ALL=C printf '%s\n' "$1" | LC_ALL=C awk \
        '{ printf "%d %d %d %d", $1, $2, 100 - $4, 100 - $3 }'
}

_set_env() { # <PAPEL> <smin smax lmin lmax>
    _r=$1 _smin=$2 _smax=$3 _lmin=$4 _lmax=$5
    eval "ENV_${_r}_S_MIN=\$_smin ENV_${_r}_S_MAX=\$_smax ENV_${_r}_L_MIN=\$_lmin ENV_${_r}_L_MAX=\$_lmax"
    eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX ENV_${_r}_L_MIN ENV_${_r}_L_MAX"
}

# Teto de croma da imagem: WALL_S × CHROMA_HEADROOM, aplicado às envelopes já
# exportadas. A envelope do scheme dá o PISO de S (para o accent não sumir)
# mas não pode impor mais cor do que a imagem tem — sem isto um scheme S=100
# num wallpaper de S=23 punha um azul elétrico de seleção num desktop azul
# pálido. Vale para os dois consumidores (este clamp e o python do
# theme-mode) porque o teto é o mesmo.
#
# smin acompanha o teto quando o piso passaria de smax: o contrato da
# envelope é min ≤ max, e um min=85 com max=41 é pior que um clamp inútil.
# Largura mínima da envelope. Derivada de UMA cor, a envelope sai estreita
# demais (L 39-45 no Ascendancy) e os 8 slots "regular" do terminal ficam com
# o mesmo L e o mesmo S — uma parede de azul, impossível de ler. Abre a faixa
# em torno do centro do scheme até a largura mínima, sem mover o centro: o
# scheme continua decidindo ONDE a faixa fica, e o wallpaper continua
# decidindo a família de cor.
_env_widen() {
    for _r in BG FG ACC MUT BRI; do
        eval "_smin=\${ENV_${_r}_S_MIN:-}"; eval "_smax=\${ENV_${_r}_S_MAX:-}"
        eval "_lmin=\${ENV_${_r}_L_MIN:-}"; eval "_lmax=\${ENV_${_r}_L_MAX:-}"
        [ -n "$_smin" ] || continue
        case $_r in
            ACC) ws=14; wl=16 ;;
            BRI) ws=14; wl=16 ;;
            FG)  ws=8;  wl=12 ;;
            *)   ws=0;  wl=0 ;;
        esac
        [ "$wl" -gt 0 ] || continue
        _sw=$((_smax - _smin))
        if [ "$_sw" -lt "$ws" ]; then
            _pad=$(((ws - _sw) / 2))
            _smin=$((_smin - _pad)); _smax=$((_smax + _pad))
            [ "$_smin" -ge 0 ] || _smin=0
            [ "$_smax" -le 100 ] || _smax=100
            eval "ENV_${_r}_S_MIN=\$_smin ENV_${_r}_S_MAX=\$_smax"
        fi
        _lw=$((_lmax - _lmin))
        if [ "$_lw" -lt "$wl" ]; then
            _pad=$(((wl - _lw) / 2))
            _lmin=$((_lmin - _pad)); _lmax=$((_lmax + _pad))
            [ "$_lmin" -ge 0 ] || _lmin=0
            [ "$_lmax" -le 100 ] || _lmax=100
            eval "ENV_${_r}_L_MIN=\$_lmin ENV_${_r}_L_MAX=\$_lmax"
        fi
        eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX ENV_${_r}_L_MIN ENV_${_r}_L_MAX"
    done
    unset _r _smin _smax _lmin _lmax _sw _lw _pad ws wl
}

_chroma_cap() {
    [ -n "${WALL_S:-}" ] || return 0
    _cc=$(LC_ALL=C awk -v s="$WALL_S" 'BEGIN { printf "%d", s * 1.8 }')
    for _r in BG FG ACC MUT BRI; do
        eval "_cur=\${ENV_${_r}_S_MAX:-}"
        [ -n "$_cur" ] || continue
        if [ "$_cur" -gt "$_cc" ]; then
            eval "ENV_${_r}_S_MAX=\$_cc"
            eval "_lo=\${ENV_${_r}_S_MIN:-0}"
            [ "$_lo" -le "$_cc" ] || eval "ENV_${_r}_S_MIN=\$_cc"
            eval "export ENV_${_r}_S_MAX ENV_${_r}_S_MIN"
        fi
    done
    unset _cc _cur _lo _r
}

# Com âncora do wallpaper, a envelope de S é abandonada: quem manda no croma
# é a imagem. A de L continua valendo — é onde o scheme expressa contraste e
# brilho. O teto de _chroma_cap segura o outro extremo.
#
# Sem isto o PISO de S do scheme continua colorindo uma paleta que não tem
# essa cor: o envelope BG do Ascendancy (S 0-4, tirado de um fundo quase
# cinza) deixava o desktop cinza neutro mesmo com a imagem azul, e o FG
# (S 34-42) punha no texto mais croma que o wallpaper inteiro tem.
_chroma_free() {
    for _r in BG FG ACC MUT BRI; do
        eval "ENV_${_r}_S_MIN=0 ENV_${_r}_S_MAX=100"
        eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX"
    done
    # Piso do accent: a imagem pode ser tão dessaturada que a seleção vira
    # cinza indistinguível do fundo (foi o que aconteceu com este wallpaper,
    # S=23). O accent é o único papel que precisa GRITAR que algo está
    # selecionado, então ganha um piso no próprio croma do wallpaper — não no
    # do scheme, que é a cor que a gente está tentando não importar.
    if [ -n "${WALL_S:-}" ]; then
        _cf=$(LC_ALL=C awk -v s="$WALL_S" 'BEGIN { printf "%d", s }')
        [ "$_cf" -gt "${ENV_ACC_S_MIN:-0}" ] && ENV_ACC_S_MIN=$_cf
        [ "$_cf" -gt "${ENV_ACC_S_MAX:-0}" ] && ENV_ACC_S_MAX=$_cf
        export ENV_ACC_S_MIN ENV_ACC_S_MAX
        unset _cf
    fi
    unset _r
}

_hue_chroma() { # <hex> → "H" se S>=6 (scheme cromático), vazio se quase cinza
    # O clamp de papel preserva o hue do wallpaper; num envelope saturado
    # (ex.: Aardvark Blue, S56-64) isso pintava verde num scheme azul.
    # Esquema quase acromático (Apprentice #262626) não exporta nada — aí o
    # humor do wallpaper segue como antes.
    _hc=${1#\#}
    [ -n "$_hc" ] || return 0
    _hcl=$(rgb2hsl_hex "$_hc")
    _hcs=${_hcl#* }; _hcs=${_hcs%% *}
    if LC_ALL=C awk -v s="$_hcs" 'BEGIN { exit !(s + 0 < 6) }'; then
        return 0
    fi
    printf '%s' "${_hcl%% *}"
}

_acc_pick() { # "hex,hex,..." <hue-bg> → hex do accent de menor distância circular
    _ap_h=$2
    printf '%s\n' "$1" | tr ',' '\n' | while IFS= read -r _ap_c; do
        [ -n "$_ap_c" ] || continue
        _ap_hl=$(rgb2hsl_hex "${_ap_c#\#}")
        LC_ALL=C awk -v a="${_ap_hl%% *}" -v b="$_ap_h" -v c="$_ap_c" 'BEGIN {
            d = a - b; if (d < 0) d = -d; if (d > 180) d = 360 - d
            printf "%d\t%s\n", d, c }'
    done | sort -n | head -1 | cut -f2
}

_acc_center() { # "hex,hex,..." → hue médio circular (graus) da família accent
    # Caracteriza o esquema; usado pelo render.sh para puxar os 16 ANSI do
    # terminal na direção da assinatura do wallpaper.
    chroma_mean "$1" | cut -d' ' -f1
}

_acc_nearest_center() { # "hex,hex,..." → hex do accent mais próximo do centro
    # Para derivar a envelope do papel ACC a partir de UMA cor (ver scheme_init).
    _anc=$(_acc_center "$1") || return 0
    [ -n "$_anc" ] || return 0
    _acc_pick "$1" "$_anc"
}

# Assinatura do wallpaper: "H S" (hue + croma médio dos color1..6 do pywal).
# Lê a paleta crua — a imagem, não o scheme. Importante: ACCENT não serve,
# ele já é uma cor do scheme (_acc_pick sobre SCHEME_ACC_CAND), então ancorar
# nele tornaria a rotação autorreferencial.
_wall_anchor() {
    [ -f "$HOME/.cache/wal/colors.sh" ] || return 0
    set +u
    # shellcheck disable=SC1091
    . "$HOME/.cache/wal/colors.sh" 2>/dev/null
    set -u
    _wa=''
    for _wai in 1 2 3 4 5 6; do
        eval "_wac=\${color$_wai:-}"
        [ -n "$_wac" ] || continue
        _wa="$_wa${_wa:+,}${_wac#\#}"
    done
    [ -n "$_wa" ] || return 0
    chroma_mean "$_wa" || return 0
}

_mirror_hex() { # "rrggbb" → mesma cor com L espelhado (100−L), p.ex. variante ≠ modo
    _mh=${1#\#}
    [ -n "$_mh" ] || return 0
    _mhl=$(rgb2hsl_hex "$_mh")
    _mhr=${_mhl#* }; _mhs=${_mhr%% *}; _mhlv=${_mhr#* }
    hsl2rgb_hex "${_mhl%% *}" "$_mhs" \
        "$(LC_ALL=C awk -v l="$_mhlv" 'BEGIN { printf "%.2f", 100 - l }')"
}

scheme_init() {
    _mode=${1:-dark}
    case "$_mode" in dark|light) ;; *) _mode=dark ;; esac
    _scheme_unset

    _state="${SCHEME_STATE:-${XDG_CACHE_HOME:-$HOME/.cache}/theme-scheme}"
    _json="${SCHEME_JSON:-$HOME/.config/sway/schemes/gogh-themes-min.json}"
    _ovr="${SCHEME_OVERRIDE_DIR:-$HOME/.config/sway/schemes/overrides}"

    _name=$(cat "$_state" 2>/dev/null) || _name=''
    [ -n "$_name" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    [ -f "$_json" ] || return 0

    _rows=$(jq -r --arg n "$_name" '
        .[] | select(.name == $n) |
        ["VARIANT=" + .variant,
         "BG=" + .background,
         "FG=" + .foreground,
         "ACC=" + ([.color_02,.color_03,.color_04,.color_05,.color_06,.color_07] | join(",")),
         "MUT=" + ([.color_08,.color_09] | join(",")),
         "BRI=" + ([.color_10,.color_11,.color_12,.color_13,.color_14,.color_15,.color_16] | join(","))] | .[]
    ' "$_json") || _rows=''
    [ -n "$_rows" ] || return 0   # esquema desconhecido ⇒ fallback

    _v='' _bg='' _fg='' _acc='' _mut='' _bri=''
    while IFS= read -r _line; do
        case $_line in
            VARIANT=*) _v=${_line#VARIANT=} ;;
            BG=*)      _bg=${_line#BG=} ;;
            FG=*)      _fg=${_line#FG=} ;;
            ACC=*)     _acc=${_line#ACC=} ;;
            MUT=*)     _mut=${_line#MUT=} ;;
            BRI=*)     _bri=${_line#BRI=} ;;
        esac
    done <<EOF
$_rows
EOF
    case "$_v" in dark|light) ;; *) return 0 ;; esac
    [ -n "$_bg$_fg$_acc$_mut$_bri" ] || return 0

    if [ "$_v" = "$_mode" ]; then _match=1; else _match=0; fi

    # Fundos do próprio scheme, já no modo ativo (L espelhado em variante ≠
    # modo). É isto que faz o fundo — inclusive o chip do yambar — mudar ao
    # trocar de scheme: o envelope + hue do wallpaper convergia todos os
    # schemes escuros quase-acromáticos no mesmo carvão.
    _bgx=$_bg; _fgx=$_fg
    if [ "$_match" -eq 0 ]; then
        _bgx=$(_mirror_hex "$_bg") || return 0
        _fgx=$(_mirror_hex "$_fg") || return 0
    fi
    SCHEME_BG_HEX=${_bgx#\#} SCHEME_FG_HEX=${_fgx#\#}
    export SCHEME_BG_HEX SCHEME_FG_HEX
    # Candidatos de accent (color_02..07) pro python escolher quando o scheme é
    # quase acromático (sem ENV_ACC_H): sem isso o accent fica no hue do
    # wallpaper e a seleção do GTK/terminal não muda entre schemes.
    SCHEME_ACC_CAND=$(printf '%s' "$_acc" | tr 'A-F' 'a-f' | tr -d '#')
    export SCHEME_ACC_CAND

    # Assinatura do wallpaper: "H S" dos color1..6 do pywal. Se a imagem é
    # cromática, ELA define o hue de todos os papéis e o croma dos 16 ANSI
    # (ver render.sh); o scheme fica só com a envelope. Se a imagem é P&B,
    # WALL_H sai vazio e o hue do scheme volta a mandar.
    _wa=$(_wall_anchor) || _wa=''
    if [ -n "$_wa" ]; then
        WALL_H=${_wa%% *}
        _wa_rest=${_wa#* }
        WALL_S=${_wa_rest%% *}
        WALL_SPREAD=${_wa_rest#* }
        export WALL_H WALL_S WALL_SPREAD
    fi
    unset _wa _wa_rest

    # ---- override por modo (precedência sobre derivação) ----
    _slug=$(_scheme_slug "$_name")
    if [ "$_mode" = light ]; then
        _ov="$_ovr/$_slug.light.env"
    else
        _ov="$_ovr/$_slug.env"
    fi
    if [ -f "$_ov" ]; then
        # shellcheck disable=SC1090
        . "$_ov" || return 0
        # override sem envelope ACC ⇒ arquivo ruim, ignora inteiro (fallback)
        [ -n "${ENV_ACC_S_MIN:-}${ENV_ACC_S_MAX:-}${ENV_ACC_L_MIN:-}${ENV_ACC_L_MAX:-}" ] || return 0
        for _r in BG FG ACC MUT BRI; do
            eval "export ENV_${_r}_S_MIN ENV_${_r}_S_MAX ENV_${_r}_L_MIN ENV_${_r}_L_MAX" 2>/dev/null || true
        done
        if [ -n "${WALL_H:-}" ]; then
            for _r in BG FG ACC MUT; do
                eval "ENV_${_r}_H=\$WALL_H; export ENV_${_r}_H"
            done
            # Só o hue da imagem. As envelopes de um override são curadas à
            # mão — a largura e os pisos de S são escolha de quem escreveu o
            # arquivo, e o contrato é que apprentice.env (+ .light) siga
            # byte-idêntico. Free/cap/widen só valem no caminho derivado.
        fi
        SCHEME_NAME=$_name SCHEME_VARIANT=$_v SCHEME_MATCH=$_match
        export SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH
        return 0
    fi

    # ---- derivação + espelhamento (variante ≠ modo) ----
    _hbg=$(_hue_chroma "$_bg") || true
    _hfg=$(_hue_chroma "$_fg") || true
    _e_bg=$(_env1 "$_bg")   || return 0
    _e_fg=$(_env1 "$_fg")   || return 0
    _e_acc=$(_env1 "$_acc") || return 0
    _e_mut=$(_env1 "$_mut") || return 0
    _e_bri=$(_env1 "$_bri") || return 0
    # O envelope do accent é derivado de UM accent representativo, não dos
    # seis. Os seis de um scheme varam ~300° de hue e S de 20 a 100; a
    # min/max da união abria S 29-100 e L 9-63, ou seja a envelope não
    # apertava nada e o clamp final virava o único responsável pelo
    # contraste. Escolhe o mais próximo do hue do bg (ou do centro, se o
    # scheme é quase acromático) e deriva a envelope só dele.
    if [ -n "$_hbg" ]; then
        _acc_sel=$(_acc_pick "$_acc" "$_hbg") || return 0
    else
        _acc_sel=$(_acc_nearest_center "$_acc") || return 0
    fi
    if [ -n "$_acc_sel" ]; then
        _e_acc=$(_env1 "$_acc_sel") || return 0
    else
        _e_acc=$(_env1 "$_acc") || return 0
    fi
    # Mesma lógica para BRI: os 7 "bright" de um scheme são often vezes
    # repetição dos accents (Ascendancy repete color_02..07 em 10..15), e a
    # min/max da união só produzia uma envelope que não apertava. Pega o
    # representativo mais próximo do accent escolhido — o "bright" é, por
    # definição, a versão mais clara do mesmo matiz.
    _bri_sel=''
    if [ -n "$_acc_sel" ]; then
        _ac_h=$(rgb2hsl_hex "$_acc_sel")
        _bri_sel=$(_acc_pick "$_bri" "${_ac_h%% *}") || _bri_sel=''
    fi
    if [ -n "$_bri_sel" ]; then
        _e_bri=$(_env1 "$_bri_sel") || return 0
    fi
    if [ "$_match" -eq 0 ]; then
        _e_bg=$(_mirror "$_e_bg")
        _e_fg=$(_mirror "$_e_fg")
        _e_acc=$(_mirror "$_e_acc")
        _e_mut=$(_mirror "$_e_mut")
        _e_bri=$(_mirror "$_e_bri")
    fi
    _set_env BG $_e_bg
    _set_env FG $_e_fg
    _set_env ACC $_e_acc
    _set_env MUT $_e_mut
    _set_env BRI $_e_bri
    # Hue dos papéis = assinatura do wallpaper, não do scheme (SCHEME_MATCH
    # já espelhou o L acima; o H é da imagem). Wallpaper P&B ⇒ sem _H, e o
    # clamp preserva o hue de cada papel como sempre fez.
    if [ -n "${WALL_H:-}" ]; then
        for _r in BG FG ACC MUT; do
            eval "ENV_${_r}_H=\$WALL_H; export ENV_${_r}_H"
        done
        _chroma_free
        _chroma_cap
        _env_widen
    elif [ -n "$_hbg" ]; then
        # Sem assinatura do wallpaper: scheme cromático manda no hue do bg.
        ENV_BG_H=$_hbg; export ENV_BG_H
    fi
    if [ -n "$_acc_sel" ] && [ -z "${WALL_H:-}" ]; then
        _hac=$(_hue_chroma "$_acc_sel") || true
        if [ -n "$_hac" ]; then ENV_ACC_H=$_hac; export ENV_ACC_H; fi
    fi
    SCHEME_NAME=$_name SCHEME_VARIANT=$_v SCHEME_MATCH=$_match
    export SCHEME_NAME SCHEME_VARIANT SCHEME_MATCH
    return 0
}
